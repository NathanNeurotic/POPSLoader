#!/usr/bin/env python3
from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


# 1. Restore device-specific lazy BDM startup. usbd remains at boot for DS3/DS4,
# but USB mass, ATA and MX4SIO must not contaminate an MC/MMCE launch before UI.
main_path = Path("src/main.cpp")
main = main_path.read_text(encoding="utf-8")
main_old = '''    // Bring the USB mass stack up HERE, adjacent to usbd -- matching what the two
    // launchers that read sAGA's drive actually do. wLaunchELF_R3Z's loadUsbModules()
    // does loadUsbDModule() then bdm/bdmfs_fatfs/settle/usbmass_bd in ONE function;
    // OPL's bdmsupport.c LoadModules() does bdm/bdmfs_fatfs/usbd/usbmass_bd back to
    // back. POPSLoader was the ONLY one loading usbd at boot and usbmass_bd minutes
    // later on page entry, which is the only configuration that depends on usbd's
    // late re-probe path (doRegisterDriver -> probeDeviceTree) to match a pendrive
    // that was ALREADY enumerated at boot. On OPL/R3Z the drive is matched by the
    // normal connect callback because usbmass_bd's driver is registered before the
    // device is ever seen.
    // Idempotent: EnsureUsbMass latches on success, so the lazy Lua-side call on
    // USB-page entry becomes a no-op rather than a second load.
    // Costs boot time (this is why the EXP6 boot profile landed first).
    EnsureUsbMass();
    BootStamp("usb mass stack");  // bdm+bdmfs_fatfs+usbmass_bd -- keep the label short: it must fit the Credits line

    // Bring the ATA/BDM block stack up HERE too, back-to-back with usbmass_bd --
    // the same coordinated window OPL and wLaunchELF_R3Z load ALL their block
    // device drivers in, and the same fix already applied to usbmass_bd above.
    //
    // The exFAT-page freeze was ata_bd being loaded LATE (minutes after boot, on
    // the page, synchronously on the UI thread) onto a bdm core that has been live
    // since boot -- the one configuration neither working launcher uses. OPL loads
    // bdm/bdmfs/usbd/usbmass THEN ata_bd back-to-back at init (bdmsupport.c +
    // hddLoadModules, on a worker thread); R3Z loads the whole ATA stack together
    // on a lean/just-reset IOP (loadAtaBlockDriver). EXP18/19 proved the driver
    // BYTES are byte-for-byte R3Z's and still froze, so the difference was never
    // the driver -- it was WHEN we load it. Loading it here makes the exFAT page's
    // System.initATA a no-op (g_ata_bd_loaded already latched), so step 45 can no
    // longer be the hang point.
    //
    // Safe on a driveless console: ata_bd's _start exits immediately when SPD
    // reports no ATA device ("HDD is not connected, exiting"). An APA-HDD boot
    // already loads this via HDD.Initialize, so g_ata_bd_loaded makes it a no-op
    // there. Costs boot time only when an internal drive is actually present --
    // and that cost buys an exFAT page that no longer blocks the UI.
    EnsureAtaBdm();
    BootStamp("ata bdm stack");  // dev9+ata_bd -- keep the label short for the Credits line
'''
main_new = '''    // Keep block-device stacks device-specific and lazy. usbd must remain here for
    // DS3/DS4 pad support, but bdm/bdmfs_fatfs, usbmass_bd, ata_bd and mx4sio_bd
    // are loaded only when their page or boot source requires them. Loading every
    // BDM backend before graphics caused a 5+ second black screen on MC boot and
    // left a long-lived mixed BDM environment that regressed MX4SIO and POPStarter
    // removable-device handoff. This restores the 1.0.1 startup boundary while the
    // load-once native helpers still prevent duplicate drivers.
'''
main = replace_once(main, main_old, main_new, "main eager BDM block")
main_path.write_text(main, encoding="utf-8")


# 2. Make lazy ATA initialization follow the actual wLaunchELF-R3Z order:
# bdm -> bdmfs_fatfs -> dev9 -> ata_bd. The current implementation said that in
# comments but called dev9 first and inserted an extra pre-driver second.
lua_cpp_path = Path("src/luasystem.cpp")
lua_cpp = lua_cpp_path.read_text(encoding="utf-8")
pattern = re.compile(
    r"bool EnsureAtaBdm\(\)\n\{.*?\n\}\n\nstatic int lua_ata_init",
    re.S,
)
replacement = '''bool EnsureAtaBdm()
{
    // Match wLaunchELF-R3Z's device-specific loadAtaBlockDriver sequence. The
    // BDM filesystem base is established first; loading dev9 next provides the
    // natural separation before ata_bd registers both atad and the BDM device.
    if (!EnsureBDMFatFs()) {
        return false;
    }
    if (!EnsureDev9()) {
        return false;
    }
    if (!g_ata_bd_loaded) {
        if (!LoadIrxCheckedBuffer("ata_bd.irx", ata_bd_irx, size_ata_bd_irx, NULL, NULL)) {
            return false;
        }
        g_ata_bd_loaded = true;
        // Let the drive and BDM partition registration settle before the first
        // page query. This delay is paid only when ATA is actually requested.
        sleep(1);
    }
    return true;
}

static int lua_ata_init'''
lua_cpp, count = pattern.subn(replacement, lua_cpp, count=1)
if count != 1:
    raise SystemExit(f"EnsureAtaBdm replacement: expected one match, found {count}")
lua_cpp_path.write_text(lua_cpp, encoding="utf-8")


# 3. Adaptive BDMA: a missing/stale marker must not force two expensive atomic
# memory-card rewrites when the exact driver bytes are already installed.
system_path = Path("bin/POPSLDR/system.lua")
system = system_path.read_text(encoding="utf-8")
size_helper = '''local function GetFileSizeSafe(path)
  if path == nil or path == "" then
    return nil
  end
  if not doesFileExist(path) then
    return nil
  end
  local ok_open, fd = pcall(System.openFile, path, FREAD)
  if not ok_open or fd == nil or (type(fd) == "number" and fd < 0) then
    return nil
  end
  local ok_size, size_val = pcall(System.sizeFile, fd)
  pcall(System.closeFile, fd)
  if not ok_size or type(size_val) ~= "number" or size_val < 0 then
    return nil
  end
  return size_val
end
'''
size_helper_new = size_helper + '''
local function FileBytesMatch(path, expected)
  if type(expected) ~= "string" then
    return false
  end
  local expected_size = string.len(expected)
  if GetFileSizeSafe(path) ~= expected_size then
    return false
  end
  local ok_read, actual = pcall(ReadWholeFile, path)
  return ok_read and type(actual) == "string" and actual == expected
end
'''
system = replace_once(system, size_helper, size_helper_new, "FileBytesMatch insertion")

copy_old = '''    if source == nil then
      local bytes = nil
      if type(System) == "table" and type(System.getEmbeddedAsset) == "function" then
        local ok_embedded, embedded = pcall(System.getEmbeddedAsset, rel)
        if ok_embedded and embedded ~= nil then
          bytes = embedded
        end
      end
      if bytes == nil then
        if UI ~= nil and UI.Notif_queue ~= nil then
          UI.Notif_queue.add(PLDR.L("Missing BDMA source (tried):").."\\n"..table.concat(paths, "\\n"))
        end
        return false
      end
      local dest = POPSTARTER_PACK_ROOT.."/"..name
      local ok_write, wrote = pcall(WriteBytesAtomicBounded, bytes, dest)
      if not ok_write or not wrote then
        return false
      end
    else
      local dest = POPSTARTER_PACK_ROOT.."/"..name
      local src_size = GetFileSizeSafe(source)
      local ok, copied = pcall(CopyExternalAtomicBounded, source, dest, src_size)
      if not ok or not copied then
        return false
      end
    end
'''
copy_new = '''    local dest = POPSTARTER_PACK_ROOT.."/"..name
    if source == nil then
      local bytes = nil
      if type(System) == "table" and type(System.getEmbeddedAsset) == "function" then
        local ok_embedded, embedded = pcall(System.getEmbeddedAsset, rel)
        if ok_embedded and embedded ~= nil then
          bytes = embedded
        end
      end
      if bytes == nil then
        if UI ~= nil and UI.Notif_queue ~= nil then
          UI.Notif_queue.add(PLDR.L("Missing BDMA source (tried):").."\\n"..table.concat(paths, "\\n"))
        end
        return false
      end
      -- Marker loss or an interrupted settings migration must not rewrite an
      -- already-identical IRX through the slow tmp/bak/copy/rename MC path.
      if not FileBytesMatch(dest, bytes) then
        local ok_write, wrote = pcall(WriteBytesAtomicBounded, bytes, dest)
        if not ok_write or not wrote then
          return false
        end
      end
    else
      -- Release packs may provide an external override instead of the embedded
      -- asset. Compare exact bytes first; if they differ, reuse the bytes already
      -- read for the write rather than reading the source a second time.
      local ok_source, source_bytes = pcall(ReadWholeFile, source)
      if ok_source and type(source_bytes) == "string" then
        if not FileBytesMatch(dest, source_bytes) then
          local ok_write, wrote = pcall(WriteBytesAtomicBounded, source_bytes, dest)
          if not ok_write or not wrote then
            return false
          end
        end
      else
        local src_size = GetFileSizeSafe(source)
        local ok, copied = pcall(CopyExternalAtomicBounded, source, dest, src_size)
        if not ok or not copied then
          return false
        end
      end
    end
'''
system = replace_once(system, copy_old, copy_new, "BDMA exact-byte skip")
system_path.write_text(system, encoding="utf-8")


# 4. Add source-level regression checks to the host harness. These cover the
# hardware-only boundary that Lua mocks cannot exercise.
harness_path = Path("tools/host_harness.py")
harness = harness_path.read_text(encoding="utf-8")
anchor = '''check("T22 MX4SIO root identity comes from lock-free BDM table (no mass0-9 filesystem sweep)", t22)

print()
'''
addition = '''check("T22 MX4SIO root identity comes from lock-free BDM table (no mass0-9 filesystem sweep)", t22)

# T23 Hardware-startup invariant: mass backends must remain lazy on MC boot.
# This is source-level because the host Lua harness cannot execute main.cpp/IOP.
t23 = True
main_src = (ROOT / "src" / "main.cpp").read_text(encoding="utf-8")
main_fn = main_src[main_src.index("int main(int argc, char * argv[])"):]
pre_graphics = main_fn[:main_fn.index("initGraphics();")]
if "EnsureUsbMass();" in pre_graphics or "EnsureAtaBdm();" in pre_graphics:
    t23 = False
    print("    T23 FAIL: USB/ATA BDM stack is still loaded before graphics")
cpp_src = (ROOT / "src" / "luasystem.cpp").read_text(encoding="utf-8")
ata_start = cpp_src.index("bool EnsureAtaBdm()")
ata_end = cpp_src.index("static int lua_ata_init", ata_start)
ata_body = cpp_src[ata_start:ata_end]
if ata_body.index("EnsureBDMFatFs()") > ata_body.index("EnsureDev9()"):
    t23 = False
    print("    T23 FAIL: lazy ATA order is dev9-first instead of BDM-FS-first")
check("T23 MC boot keeps USB/ATA BDM lazy; ATA uses BDM-FS -> dev9 -> ata order", t23)

# T24 BDMA restaging must exact-compare existing files before atomic rewriting.
t24 = "local function FileBytesMatch" in SYSTEM_SRC
bdma_pos = SYSTEM_SRC.find("function PLDR.ApplyBdmaMode(mode_key)")
if bdma_pos < 0 or "FileBytesMatch(dest, bytes)" not in SYSTEM_SRC[bdma_pos:bdma_pos + 7000]:
    t24 = False
check("T24 adaptive BDMA can skip byte-identical driver rewrites", t24)

print()
'''
harness = replace_once(harness, anchor, addition, "host harness T23/T24")
harness_path.write_text(harness, encoding="utf-8")

print("Applied storage hardware follow-up patch")
