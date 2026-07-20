#!/usr/bin/env python3
from pathlib import Path
import re


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


def sub_once(text: str, pattern: str, replacement: str, label: str) -> str:
    out, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one regex match, found {count}")
    return out


system_path = Path("bin/POPSLDR/system.lua")
system = system_path.read_text(encoding="utf-8")

# MMCE: module-load success is not mounted-filesystem readiness. Keep a failed
# first probe retryable and reinitialize the shared SIO2 pad path only once.
mmce_replacement = '''local function IsAnyMmceRootReady()
  local candidates = {"mmce0:/", "mmce1:/"}
  for i = 1, #candidates do
    local root = candidates[i]
    local ok_root, has_root = pcall(doesFolderExist, root)
    if ok_root and has_root == true then
      return true
    end
    local ok_pops, has_pops = pcall(doesFolderExist, root.."POPS/")
    if ok_pops and has_pops == true then
      return true
    end
  end
  return false
end

function PLDR.EnsureMmceReadyOnce()
  if PLDR._mmce_ready then
    return true
  end

  if type(System) == "table" and type(System.ensureMmceman) == "function" then
    local ok_load, loaded = pcall(System.ensureMmceman)
    if not ok_load or loaded ~= true then
      return false
    end
  end

  if not PLDR._mmce_pad_reinitialized then
    if type(System) == "table" and type(System.reinitPad) == "function" then
      pcall(System.reinitPad)
    end
    PLDR._mmce_pad_reinitialized = true
  end

  for attempt = 1, 5 do
    if IsAnyMmceRootReady() then
      PLDR._mmce_ready = true
      return true
    end
    if attempt < 5 and type(System) == "table" and type(System.sleep) == "function" then
      pcall(System.sleep, 1)
    end
  end

  -- A slow mount, missing card, or hot-plug transition must not poison every
  -- later page entry and launch preflight with a false permanent ready latch.
  return false
end

function PLDR.ExpandMcAlias'''
system = sub_once(
    system,
    r'function PLDR\.EnsureMmceReadyOnce\(\)\n.*?\nend\n\nfunction PLDR\.ExpandMcAlias',
    mmce_replacement,
    "MMCE readiness state machine",
)

# BDM identity is already available without opening every mass filesystem. Use
# driver name + parId for MX4SIO discovery only; USB and ATA retain dev behavior.
bdm_helper = '''local function BuildBdmMassIdentity()
  local identity = {
    usb = {},
    mx4sio = {},
    ata = {},
    present_roots = {}
  }
  if type(System) ~= "table" or type(System.bdmList) ~= "function" then
    return identity
  end

  local ok, list = pcall(System.bdmList)
  if not ok or type(list) ~= "table" then
    return identity
  end

  local seen_present = {}
  local seen_usb = {}
  local seen_mx4 = {}
  local seen_ata = {}
  for _, info in pairs(list) do
    if type(info) == "table" then
      local slot = tonumber(info.parId)
      if slot ~= nil and slot >= 0 and slot <= 9 then
        local root = (slot == 0) and "mass:/" or ("mass"..tostring(slot)..":/")
        root = NormalizeMassRoot(root)
        if root ~= nil then
          if seen_present[root] ~= true then
            seen_present[root] = true
            table.insert(identity.present_roots, root)
          end
          local kind = ClassifyMassRootDriver(info.name)
          if kind == "mx4sio" then
            if seen_mx4[root] ~= true then
              seen_mx4[root] = true
              table.insert(identity.mx4sio, root)
            end
          elseif kind == "ata" then
            if seen_ata[root] ~= true then
              seen_ata[root] = true
              table.insert(identity.ata, root)
            end
          else
            if seen_usb[root] ~= true then
              seen_usb[root] = true
              table.insert(identity.usb, root)
            end
          end
        end
      end
    end
  end
  return identity
end

'''
system = replace_once(
    system,
    "local function ClassifyStartupMassTargets(targets)\n",
    bdm_helper + "local function ClassifyStartupMassTargets(targets)\n",
    "BDM identity helper insertion",
)

mx4_ready_old = '''  if mode == "mx4sio" then
    if type(System) == "table" and type(System.initMX4SIO) == "function" then
      pcall(System.initMX4SIO)
    end
    return
  end
'''
mx4_ready_new = '''  if mode == "mx4sio" then
    local initialized = false
    if type(System) == "table" and type(System.initMX4SIO) == "function" then
      local ok, ready = pcall(System.initMX4SIO)
      initialized = ok and ready == true
    end
    -- mx4sio_bd publishes the card asynchronously after module load. Pay one
    -- registration settle, then let the existing six-attempt retry loop handle
    -- later misses without ever entering the filesystem-lock discovery sweep.
    if initialized and not PLDR._mx4_initial_settle_done then
      if type(System) == "table" and type(System.sleep) == "function" then
        pcall(System.sleep, 1)
      end
      PLDR._mx4_initial_settle_done = true
    end
    return
  end
'''
system = replace_once(system, mx4_ready_old, mx4_ready_new, "MX4SIO initial settle")

identity_start_old = '''local function BuildMassRootIdentity(mode)
  EnsureMassBackendsReady(mode)

  local identity = {
'''
identity_start_new = '''local function BuildMassRootIdentity(mode)
  EnsureMassBackendsReady(mode)

  -- Discovery by opening mass:/ through mass9:/ can block forever while
  -- bdmfs_fatfs owns its mount lock. For MX4SIO, bdm_query already provides the
  -- same identity as a lock-free driver-name/parId table.
  if mode == "mx4sio" then
    return BuildBdmMassIdentity()
  end

  local identity = {
'''
system = replace_once(system, identity_start_old, identity_start_new, "MX4SIO lock-free identity route")

mmce_detect_replacement = '''function PLDR.DetectMMCESlot(force_refresh)
  if PLDR.MMCE.PROBED and not force_refresh then
    return PLDR.MMCE.PREFIX
  end

  PLDR.MMCE.PROBED = false
  PLDR.MMCE.SLOTS = {}
  PLDR.MMCE.INDEX = 1
  PLDR.MMCE.PREFIX = nil

  if type(PLDR.EnsureMmceReadyOnce) == "function" then
    local ok_ready, ready = pcall(PLDR.EnsureMmceReadyOnce)
    if not ok_ready or ready ~= true then
      return nil
    end
  end

  local candidates = {"mmce0:/", "mmce1:/"}
  for i = 1, #candidates do
    local candidate = candidates[i]
    if doesFolderExist(candidate) or doesFolderExist(candidate.."POPS/") then
      table.insert(PLDR.MMCE.SLOTS, candidate)
    end
  end
  if #PLDR.MMCE.SLOTS > 0 then
    PLDR.MMCE.PROBED = true
    PLDR.MMCE.PREFIX = PLDR.MMCE.SLOTS[PLDR.MMCE.INDEX]
    return PLDR.MMCE.PREFIX
  end

  -- Negative discovery can be transient during lazy mount or hot-plug.
  return nil
end

function PLDR.GetMMCESlots'''
system = sub_once(
    system,
    r'function PLDR\.DetectMMCESlot\(force_refresh\)\n.*?\nend\n\nfunction PLDR\.GetMMCESlots',
    mmce_detect_replacement,
    "MMCE retryable slot detection",
)

# Avoid slow memory-card rewrite/rename cycles when the exact requested BDMA IRX
# bytes are already installed but the marker is stale or missing.
file_match_helper = '''local function FileBytesMatch(path, expected)
  if type(expected) ~= "string" then
    return false
  end
  if GetFileSizeSafe(path) ~= string.len(expected) then
    return false
  end
  local ok_read, actual = pcall(ReadWholeFile, path)
  return ok_read and type(actual) == "string" and actual == expected
end

'''
system = replace_once(
    system,
    "local function WriteBdmaModeMarker(mode_key)\n",
    file_match_helper + "local function WriteBdmaModeMarker(mode_key)\n",
    "BDMA byte comparison helper",
)

bdma_copy_old = '''  for i = 1, #BDMA_COPY_FILES do
    local name = BDMA_COPY_FILES[i]
    local rel = name..suffix
    local paths = PLDR.BdmaSourceCandidates(rel)
    local fd, source = PLDR.TryOpenFirst(paths)
    if fd ~= nil and (type(fd) ~= "number" or fd >= 0) then
      System.closeFile(fd)
    end
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
  end
'''
bdma_copy_new = '''  for i = 1, #BDMA_COPY_FILES do
    local name = BDMA_COPY_FILES[i]
    local rel = name..suffix
    local paths = PLDR.BdmaSourceCandidates(rel)
    local fd, source = PLDR.TryOpenFirst(paths)
    if fd ~= nil and (type(fd) ~= "number" or fd >= 0) then
      System.closeFile(fd)
    end
    local dest = POPSTARTER_PACK_ROOT.."/"..name
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
      if not FileBytesMatch(dest, bytes) then
        local ok_write, wrote = pcall(WriteBytesAtomicBounded, bytes, dest)
        if not ok_write or not wrote then
          return false
        end
      end
    else
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
  end
'''
system = replace_once(system, bdma_copy_old, bdma_copy_new, "BDMA byte-identical write skip")
system_path.write_text(system, encoding="utf-8")


# MX4SIO boot-path translation must use the same lock-free BDM identity rule.
boot_path = Path("etc/boot.lua")
boot = boot_path.read_text(encoding="utf-8")
boot_scan_old = '''  local function scan_for_mx4sio_root()
    if type(System.refreshMassBackends) == "function" then
      pcall(System.refreshMassBackends)
    end
    if type(System.getMassMountDriver) ~= "function" then
      return nil, "no_getMassMountDriver"
    end
    for slot = 0, 9 do
      local root = (slot == 0) and "mass:/" or ("mass"..tostring(slot)..":/")
      local ok, driver = pcall(System.getMassMountDriver, root)
      if ok and type(driver) == "string" and driver ~= "" then
        local lowered = string.lower(driver)
        if string.find(lowered, "mx4", 1, true) ~= nil or string.find(lowered, "sdc", 1, true) ~= nil then
          return root, "found:"..root.."="..driver
        end
      end
    end
    return nil, "no_match"
  end
'''
boot_scan_new = '''  local function scan_for_mx4sio_root()
    if type(System) == "table" and type(System.refreshMassBackends) == "function" then
      pcall(System.refreshMassBackends)
    end
    if type(System) ~= "table" or type(System.bdmList) ~= "function" then
      return nil, "no_bdm_list"
    end
    local ok, list = pcall(System.bdmList)
    if not ok or type(list) ~= "table" then
      return nil, "no_bdm_list"
    end
    for _, info in pairs(list) do
      if type(info) == "table" then
        local driver = tostring(info.name or "")
        local lowered = string.lower(driver)
        if string.find(lowered, "mx4", 1, true) ~= nil or string.find(lowered, "sdc", 1, true) ~= nil then
          local slot = tonumber(info.parId)
          if slot ~= nil and slot >= 0 and slot <= 9 then
            local root = (slot == 0) and "mass:/" or ("mass"..tostring(slot)..":/")
            return root, "found:"..root.."="..driver
          end
        end
      end
    end
    return nil, "no_match"
  end
'''
boot = replace_once(boot, boot_scan_old, boot_scan_new, "boot-time MX4SIO BDM identity")
boot = boot.replace(
    "dynamically by the same ioctl driver-name rule PR #472 uses for\n  -- boot-device classification: sdc/mx4 ioctl => MX4SIO.",
    "dynamically from the lock-free BDM device table: sdc/mx4 driver name plus\n  -- parId identifies the writable mass slot without opening every filesystem root.",
    1,
)
boot_path.write_text(boot, encoding="utf-8")


# Permanent tests for the exact hardware regressions and the suspected selector
# handoff. The latter captures the full LaunchEngine -> System.loadELF triple.
harness_path = Path("tools/host_harness.py")
harness = harness_path.read_text(encoding="utf-8")
anchor = '''check("T20 Boot profile reports slowest stage by DELTA (not biggest cumulative stamp)", t20)

print()
'''
addition = r'''check("T20 Boot profile reports slowest stage by DELTA (not biggest cumulative stamp)", t20)

# T21 MMCE readiness is truthful and retryable.
t21 = E('''function()
  local raw_exists = doesFolderExist
  local raw_ensure = System.ensureMmceman
  local raw_reinit = System.reinitPad
  local phase = 0
  local pad_reinits = 0
  doesFolderExist = function(path)
    if phase == 1 and path == "mmce0:/" then return true end
    return false
  end
  System.ensureMmceman = function() return true end
  System.reinitPad = function() pad_reinits = pad_reinits + 1; return true end
  PLDR._mmce_ready = nil
  PLDR._mmce_pad_reinitialized = nil
  PLDR.MMCE.PROBED = false
  PLDR.MMCE.SLOTS = {}
  PLDR.MMCE.PREFIX = nil

  local first = PLDR.DetectMMCESlot(true)
  local first_retryable = first == nil and PLDR._mmce_ready ~= true
                       and PLDR.MMCE.PROBED == false and PLDR.MMCE.PREFIX == nil
  phase = 1
  local second = PLDR.DetectMMCESlot(true)
  local second_ready = second == "mmce0:/" and PLDR._mmce_ready == true
                    and PLDR.MMCE.PROBED == true and PLDR.MMCE.PREFIX == "mmce0:/"
  local pad_once = pad_reinits == 1

  doesFolderExist = raw_exists
  System.ensureMmceman = raw_ensure
  System.reinitPad = raw_reinit
  return first_retryable and second_ready and pad_once
end''')()
check("T21 MMCE timeout stays retryable; later root appearance succeeds without double pad reinit", t21)

# T22 MX4SIO identity must use bdmList and never open all mass roots.
t22 = E('''function()
  local raw_list = System.bdmList
  local raw_init = System.initMX4SIO
  local raw_refresh = System.refreshMassBackends
  local raw_mount_driver = System.getMassMountDriver
  local raw_exists = doesFolderExist
  local fs_root_probes = 0
  local native_driver_probes = 0

  System.bdmList = function()
    return {
      { name = "usb", parId = 0 },
      { name = "sdc", parId = 3 }
    }
  end
  System.initMX4SIO = function() return true end
  System.refreshMassBackends = function() return true end
  System.getMassMountDriver = function(root)
    native_driver_probes = native_driver_probes + 1
    return nil
  end
  doesFolderExist = function(path)
    if string.match(tostring(path), "^mass%d*:/$") then
      fs_root_probes = fs_root_probes + 1
    end
    return false
  end
  PLDR._mx4_initial_settle_done = nil

  local root = PLDR.GetMX4SIOMassRootNow()

  System.bdmList = raw_list
  System.initMX4SIO = raw_init
  System.refreshMassBackends = raw_refresh
  System.getMassMountDriver = raw_mount_driver
  doesFolderExist = raw_exists
  return root == "mass3:/" and fs_root_probes == 0 and native_driver_probes == 0
end''')()
check("T22 MX4SIO root identity comes from lock-free BDM table (no mass0-9 filesystem sweep)", t22)

# T23 The broad storage revert must keep ATA out of the pre-graphics MC boot path.
t23 = True
main_src = (REPO / "src" / "main.cpp").read_text(encoding="utf-8")
main_fn = main_src[main_src.index("int main(int argc, char * argv[])"):]
pre_graphics = main_fn[:main_fn.index("initGraphics();")]
if "EnsureAtaBdm();" in pre_graphics:
    t23 = False
    print("    T23 FAIL: ATA BDM is still loaded before graphics")
check("T23 MC boot does not initialize the ATA BDM stack before graphics", t23)

# T24 A stale marker must not force byte-identical BDMA driver rewrites.
t24 = "local function FileBytesMatch" in SYS_SRC
bdma_pos = SYS_SRC.find("function PLDR.ApplyBdmaMode(mode_key)")
if bdma_pos < 0 or "FileBytesMatch(dest, bytes)" not in SYS_SRC[bdma_pos:bdma_pos + 7000]:
    t24 = False
check("T24 adaptive BDMA can skip byte-identical driver rewrites", t24)

# T25 Exercise the MMCE launch path and capture the exact native call triple.
t25 = E('''function()
  local raw_load = System.loadELF
  local raw_adaptive = PLDR.BDMA_ADAPTIVE
  local raw_path = PLDR.POPSTARTER_PATH
  local raw_reboot = PLDR.REBOOT_IOP_WHILE_LOADING_POPSTARTER
  local raw_prefix = PLDR.MMCE.PREFIX
  local raw_confirm = UI.Pad.Events.CONFIRM
  local raw_input = Input_GetEvent
  local raw_resolve = PLDR.ResolveLaunchPopstarterPath
  local raw_probe = PLDR.PopstarterProbeWithEnsure
  local raw_stage = PLDR.MaybeApplyAdaptiveBdma
  local raw_open = System.openFile
  local raw_size = System.sizeFile
  local raw_close = System.closeFile
  local captured = nil

  PLDR.BDMA_ADAPTIVE = false
  PLDR.POPSTARTER_PATH = "mc0:/POPSTARTER/POPSTARTER.ELF"
  PLDR.REBOOT_IOP_WHILE_LOADING_POPSTARTER = 1
  PLDR.MMCE.PREFIX = "mmce0:/"
  UI.Pad.Events.CONFIRM = true
  Input_GetEvent = function() return 0 end
  PLDR.ResolveLaunchPopstarterPath = function() return "mc0:/POPSTARTER/POPSTARTER.ELF" end
  PLDR.PopstarterProbeWithEnsure = function() return true end
  PLDR.MaybeApplyAdaptiveBdma = function() return true end
  System.openFile = function(path, mode)
    if path == "mc0:/POPSTARTER/POPSTARTER.ELF" and mode == FREAD then return 25 end
    return raw_open(path, mode)
  end
  System.sizeFile = function(fd) if fd == 25 then return 3 end return raw_size(fd) end
  System.closeFile = function(fd) if fd == 25 then return 0 end return raw_close(fd) end
  System.loadELF = function(path, reboot_iop, selector)
    captured = { path = path, reboot = reboot_iop, selector = selector }
    return 0
  end

  PLDR.RunPOPStarterGame("mmce0:/POPS/", "Test Game.VCD", nil)

  System.loadELF = raw_load
  PLDR.BDMA_ADAPTIVE = raw_adaptive
  PLDR.POPSTARTER_PATH = raw_path
  PLDR.REBOOT_IOP_WHILE_LOADING_POPSTARTER = raw_reboot
  PLDR.MMCE.PREFIX = raw_prefix
  UI.Pad.Events.CONFIRM = raw_confirm
  Input_GetEvent = raw_input
  PLDR.ResolveLaunchPopstarterPath = raw_resolve
  PLDR.PopstarterProbeWithEnsure = raw_probe
  PLDR.MaybeApplyAdaptiveBdma = raw_stage
  System.openFile = raw_open
  System.sizeFile = raw_size
  System.closeFile = raw_close

  return type(captured) == "table"
     and captured.path == "mc0:/POPSTARTER/POPSTARTER.ELF"
     and captured.reboot == 1
     and captured.selector == "mass:/POPS/XX.Test Game.ELF"
end''')()
check("T25 MMCE launch hands System.loadELF exactly one mass:/POPS/XX selector", t25)

# T26 Pin the native registration and argv packing side of the contract.
t26 = True
cpp_contract = (REPO / "src" / "luasystem.cpp").read_text(encoding="utf-8")
start = cpp_contract.index("static int lua_loadELF(lua_State *L)")
end = cpp_contract.index("static int lua_loadELFWithPartition", start)
bridge = cpp_contract[start:end]
for token in [
    "luaL_checkinteger(L, 2)",
    "luaL_checkstring(L, 3)",
    "LoadELFFromFileExecPS2RebootIOP(elftoload, 1, argv_static)",
]:
    if token not in bridge:
        t26 = False
        print("    T26 FAIL: missing native bridge token: " + token)
if '{"loadELF",' not in cpp_contract or "lua_loadELF}" not in cpp_contract:
    t26 = False
    print("    T26 FAIL: System.loadELF is not registered to lua_loadELF")
check("T26 native System.loadELF packs reboot flag separately from selector argv0", t26)

print()
'''
harness = replace_once(harness, anchor, addition, "host harness storage follow-up tests")
harness_path.write_text(harness, encoding="utf-8")

print("Applied targeted MMCE/MX4SIO/BDMA follow-up on reverted storage baseline")
