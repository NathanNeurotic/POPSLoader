#!/usr/bin/env python3
from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


system_path = Path("bin/POPSLDR/system.lua")
system = system_path.read_text(encoding="utf-8")

ata_old = '''  if mode == "ata" then
    -- ata_bd is the BDM block driver for the internal exFAT drive. Idempotent;
    -- mirrors the MX4SIO bring-up (usbmass first, then the device driver).
    -- EXP11: staged. Each blocking module load gets its own painted integer
    -- percent FIRST, so a frozen overlay names the stalled step (the 42%-freeze
    -- investigation: SifExecModuleBuffer has no timeout; ata_bd's module start
    -- runs the whole ATA probe + BDM cache alloc before returning). ensureDev9 /
    -- ensureBDMFatFs are load-once latched, so pre-calling them reduces initATA
    -- to settle + ata_bd + settle. All three stay pcall'd and order-identical to
    -- the old single initATA call (EnsureAtaBdm re-runs the latched steps).
    if type(System) == "table" then
      if type(System.ensureDev9) == "function" then
        PLDR._AtaStage(0.43, "exFAT HDD: starting dev9 (43)...")
        pcall(System.ensureDev9)
      end
      if type(System.ensureBDMFatFs) == "function" then
        PLDR._AtaStage(0.44, "exFAT HDD: starting the filesystem base (44)...")
        pcall(System.ensureBDMFatFs)
      end
      if type(System.initATA) == "function" then
        PLDR._AtaStage(0.45, "exFAT HDD: starting the ATA driver (45)...")
        pcall(System.initATA)
      end
    end
    return
  end
'''
ata_new = '''  if mode == "ata" then
    -- Device-specific lazy ATA sequence, matching wLaunchELF-R3Z end to end:
    -- bdm -> bdmfs_fatfs -> dev9 -> ata_bd. Each blocking module boundary gets
    -- a painted stage before the call. The native helpers are load-once latched,
    -- so System.initATA only performs the remaining ata_bd load and final settle.
    if type(System) == "table" then
      if type(System.ensureBDMFatFs) == "function" then
        PLDR._AtaStage(0.43, "exFAT HDD: starting the filesystem base (43)...")
        pcall(System.ensureBDMFatFs)
      end
      if type(System.ensureDev9) == "function" then
        PLDR._AtaStage(0.44, "exFAT HDD: starting dev9 (44)...")
        pcall(System.ensureDev9)
      end
      if type(System.initATA) == "function" then
        PLDR._AtaStage(0.45, "exFAT HDD: starting the ATA driver (45)...")
        pcall(System.initATA)
      end
    end
    return
  end
'''
system = replace_once(system, ata_old, ata_new, "ATA staged order")
system_path.write_text(system, encoding="utf-8")


cpp_path = Path("src/luasystem.cpp")
cpp = cpp_path.read_text(encoding="utf-8")
cpp = replace_once(
    cpp,
    '''// Non-static so main.cpp can bring the USB mass stack up at BOOT, adjacent to
// usbd, instead of minutes later on USB-page entry. Idempotent via the latches
// below, so the later Lua-side call becomes a no-op -- which MATTERS: loading a
// second copy of a block driver onto a live bus is the exact bug class that
// caused the old 42% ATA freeze.
''',
    '''// Device-specific lazy USB mass entry point. usbd itself remains boot-loaded
// for DS3/DS4 pad support; bdm/bdmfs_fatfs/usbmass_bd are loaded only when USB
// or MX4SIO actually requests the shared mass stack. Idempotent via the latches.
''',
    "EnsureUsbMass comment",
)
cpp = replace_once(
    cpp,
    '''// Staged ATA bring-up (EXP11 diagnostics): expose dev9 alone so the Lua side can
// paint a distinct progress step before EACH blocking module load. EnsureAtaBdm
// re-runs EnsureDev9/EnsureBDMFatFs internally, but both are load-once latched,
// so pre-calling them from Lua reduces System.initATA to settle + ata_bd + settle
// -- and a frozen on-screen percent then names the exact stalled module start.
''',
    '''// Staged ATA bring-up diagnostics: expose dev9 separately so Lua can paint a
// distinct progress step while preserving the actual lazy order
// bdm -> bdmfs_fatfs -> dev9 -> ata_bd.
''',
    "ensureDev9 comment",
)
cpp = replace_once(
    cpp,
    '''// Bring up the BDM-enabled ATA stack ONCE: dev9 -> bdm -> bdmfs_fatfs -> ata_bd.
''',
    '''// Bring up the BDM-enabled ATA stack ONCE: bdm -> bdmfs_fatfs -> dev9 -> ata_bd.
''',
    "ATA order heading",
)
cpp_path.write_text(cpp, encoding="utf-8")


harness_path = Path("tools/host_harness.py")
harness = harness_path.read_text(encoding="utf-8")
anchor = '''check("T24 adaptive BDMA can skip byte-identical driver rewrites", t24)

print()
'''
addition = r'''check("T24 adaptive BDMA can skip byte-identical driver rewrites", t24)

# T25 Exercise the real MMCE launch path through RunPOPStarterGame and capture the
# arguments presented to System.loadELF. This pins the POPStarter one-selector
# contract, not just the string builder in isolation.
t25 = E('''function()
  local raw_load = System.loadELF
  local raw_adaptive = PLDR.BDMA_ADAPTIVE
  local raw_path = PLDR.POPSTARTER_PATH
  local raw_reboot = PLDR.REBOOT_IOP_WHILE_LOADING_POPSTARTER
  local raw_prefix = PLDR.MMCE.PREFIX
  local raw_confirm = UI.Pad.Events.CONFIRM
  local captured = nil

  PLDR.BDMA_ADAPTIVE = false
  PLDR.POPSTARTER_PATH = "mc0:/POPSTARTER/POPSTARTER.ELF"
  PLDR.REBOOT_IOP_WHILE_LOADING_POPSTARTER = 1
  PLDR.MMCE.PREFIX = "mmce0:/"
  FAKEFS.files["mc0:/POPSTARTER/POPSTARTER.ELF"] = "ELF"
  FAKEFS.files["mmce0:/POPS/Test Game.VCD"] = "VCD"
  FAKEFS.files["mass:/POPS/XX.Test Game.ELF"] = "SELECTOR"
  UI.Pad.Events.CONFIRM = true
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

  return type(captured) == "table"
     and captured.path == "mc0:/POPSTARTER/POPSTARTER.ELF"
     and captured.reboot == 1
     and captured.selector == "mass:/POPS/XX.Test Game.ELF"
end''')()
check("T25 MMCE launch hands System.loadELF exactly one mass:/POPS/XX selector", t25)

# T26 Pin the C registration/packing side of the same contract. System.loadELF
# must map to lua_loadELF, read reboot_iop from slot 2 and selector from slot 3.
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

# T27 Verify the page-level preloads preserve the same BDM-FS -> dev9 -> ATA order.
t27 = True
ata_lua_start = SYS_SRC.index('if mode == "ata" then')
ata_lua_end = SYS_SRC.index('return\n  end', ata_lua_start)
ata_lua = SYS_SRC[ata_lua_start:ata_lua_end]
if not (ata_lua.index("System.ensureBDMFatFs") < ata_lua.index("System.ensureDev9") < ata_lua.index("System.initATA")):
    t27 = False
    print("    T27 FAIL: Lua ATA staging order differs from native lazy order")
check("T27 exFAT page stages BDM-FS -> dev9 -> ATA in native order", t27)

print()
'''
harness = replace_once(harness, anchor, addition, "host harness T25-T27")
harness_path.write_text(harness, encoding="utf-8")

print("Applied ATA-order and launch-handoff validation patch")
