"""Host-side execution harness for POPSLoader's embedded Lua.

EXECUTES the real system.lua chunk (truncated just before the splash /
main-loop handoff) under a mocked PS2 environment, in the app's real load
order (boot globals -> system.lua -> ui.lua require'd at its real point),
then runs a functional battery over the launch-adjacent logic.

Why this exists: successful chunk EXECUTION verifies the runtime class that
`luac -p` and the CI syntax gate cannot see -- attach-before-init load-order
bricks (d4b04be), nil-global calls, and type errors at load time. That class
has shipped un-bootable rolling builds before. The battery then exercises the
newest logic (Adaptive BDMA, partition-installed games, HDD diagnostics)
against controlled filesystem/HDD state.

Needs: python3 + lupa (pip install lupa). Exit 0 = all pass; 1 = failures.
Run from anywhere: paths resolve relative to this file's checkout.
"""
import sys, pathlib
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
from lupa import lua54

REPO = pathlib.Path(__file__).resolve().parent.parent
UI_SRC = (REPO / "bin/POPSLDR/ui.lua").read_text(encoding="utf-8")
SYS_SRC = (REPO / "bin/POPSLDR/system.lua").read_text(encoding="utf-8")

# Truncate system.lua at the splash/main-loop handoff: everything above (every
# definition + the settings load) still executes for real.
CUT = SYS_SRC.find("UI.WelcomeDraw.Play(initial_scene")
assert CUT > 0, "truncation anchor not found"
SYS_TRUNC = SYS_SRC[:CUT] + "\nreturn true\n"

lua = lua54.LuaRuntime(unpack_returned_tuples=True)

MOCKS = r'''
-- ==== permissive module helper: unknown members become no-op fns returning 0
local function permissive(overrides)
  return setmetatable(overrides or {}, {__index=function(t,k)
    local f = function(...) return 0 end
    rawset(t,k,f); return f
  end})
end

-- ==== fake filesystem (files: path->content; dirs: path->array of entries)
FAKEFS = { files = {}, dirs = {} }
local function norm(p) return tostring(p or "") end

FREAD, FCREATE, FRDWR = 1, 2, 3

-- ==== fake HDD with mount state (partition data set from the test battery)
FAKEHDD = {
  parts = {},          -- name -> { files = {["IMAGE0.VCD"]=true,...}, listing = {...} }
  names = {},          -- APA enumeration order
  mounted = {},        -- slot -> partition name
  status = 0,
  init_ok = true,
}
HDD = {
  Initialize = function() if FAKEHDD.init_ok then return true end return false, "PS2HDD", -1, 1 end,
  GetHDDStatus = function() return FAKEHDD.status end,
  MountPartition = function(part, slot, mode)
    local name = string.gsub(norm(part), "^hdd0:", "")
    if FAKEHDD.parts[name] == nil then return false, -2 end
    FAKEHDD.mounted[slot or 0] = name
    return true, 0
  end,
  UMountPartition = function(slot) FAKEHDD.mounted[slot or 0] = nil; return 0 end,
  ListPartitions = function()
    local out = {}
    for i = 1, #FAKEHDD.names do out[i] = FAKEHDD.names[i] end
    return out
  end,
}
FIO_MT_RDWR, FIO_MT_RDONLY = 0, 1

local function pfs_slot_of(path)
  local s = string.match(norm(path), "^pfs(%d+):/")
  if s then return tonumber(s) end
  return nil
end
local function pfs_rel_of(path) return string.gsub(norm(path), "^pfs%d+:/+", "") end

doesFileExist = function(path)
  path = norm(path)
  local slot = pfs_slot_of(path)
  if slot ~= nil then
    local part = FAKEHDD.mounted[slot]
    if part == nil then return false end
    local rel = pfs_rel_of(path)
    return (FAKEHDD.parts[part].files or {})[rel] == true
  end
  return FAKEFS.files[path] ~= nil
end
doesFolderExist = function(path)
  path = norm(path)
  if FAKEFS.dirs[path] ~= nil then return true end
  if path == "mc0:/" or path == "mc0:/POPSTARTER" or path == "mc0:/POPSTARTER/" then return true end
  if pfs_slot_of(path) ~= nil then return FAKEHDD.mounted[pfs_slot_of(path)] ~= nil end
  return false
end

EMBEDDED = {}  -- name -> bytes (nil = missing)
System = permissive({
  openFile = function(path, mode)
    path = norm(path)
    if mode == FREAD then
      if pfs_slot_of(path) ~= nil then return -1 end
      if FAKEFS.files[path] == nil then return -1 end
      return { path = path, pos = 1, r = true }
    end
    FAKEFS.files[path] = ""
    return { path = path, pos = 1, w = true }
  end,
  readFile = function(fd, n)
    if type(fd) ~= "table" or not fd.r then return nil end
    local data = FAKEFS.files[fd.path] or ""
    if fd.pos > #data then return "" end
    local chunk = string.sub(data, fd.pos, fd.pos + (n or 4096) - 1)
    fd.pos = fd.pos + #chunk
    return chunk
  end,
  writeFile = function(fd, data, len)
    if type(fd) ~= "table" or not fd.w then return -1 end
    FAKEFS.files[fd.path] = (FAKEFS.files[fd.path] or "") .. tostring(data)
    return #tostring(data)
  end,
  closeFile = function(fd) return 0 end,
  sizeFile = function(fd)
    if type(fd) == "table" then return #(FAKEFS.files[fd.path] or "") end
    return #(FAKEFS.files[norm(fd)] or "")
  end,
  removeFile = function(path) FAKEFS.files[norm(path)] = nil; return 0 end,
  rename = function(a, b)
    a, b = norm(a), norm(b)
    if FAKEFS.files[a] == nil then return -1 end
    FAKEFS.files[b] = FAKEFS.files[a]; FAKEFS.files[a] = nil
    return 0
  end,
  listDirectory = function(path)
    path = norm(path)
    local slot = pfs_slot_of(path)
    if slot ~= nil then
      local part = FAKEHDD.mounted[slot]
      if part == nil then return nil end
      return FAKEHDD.parts[part].listing or {}
    end
    return FAKEFS.dirs[path]
  end,
  currentDirectory = function() return "mc0:/POPSLOADER/" end,
  sleep = function() end,
  getEmbeddedAsset = function(name) return EMBEDDED[norm(name)] end,
  getLaunchArgs = function() return {} end,
  getBootDeviceHint = function() return "mc" end,
  GetArgv = function() return { "mc0:/POPSLOADER/POPSLOADER.ELF" } end,
  getMassMountDriver = function() return nil end,
  getMassDriverName = function() return nil end,
  ensureUsbMass = function() return true end,
  ensureMmceman = function() return true end,
  reinitPad = function() return true end,
  refreshMassBackends = function() return true end,
  smbNetUp = function() return false end,
  initMX = function() return true end,
  initUSB = function() return true end,
  initATA = function() return true end,
  initSMB = function() return true end,
  initMMCE = function() return true end,
  setExecKeepPfsMask = function() return 0 end,
  loadELF = function() error("EXEC loadELF reached in harness") end,
  loadELFWithPartition = function() error("EXEC loadELFWithPartition reached in harness") end,
})

Screen = permissive({
  getMode = function() return { mode = 2, width = 640, height = 448, interlace = 1, ffmd = 0 } end,
  setMode = function() end, clear = function() end, flip = function() end,
  waitVblankStart = function() end, setOverscan = function() end, getOverscan = function() return 0 end,
  setVSync = function() end,
})
Graphics = permissive({ loadImage = function() return 1 end, getImageWidth = function() return 64 end,
  getImageHeight = function() return 64 end, freeImage = function() end, drawImage = function() end,
  drawRect = function() end, drawScaleImage = function() end })
Font = permissive({ ftLoad = function() return 1 end, ftPrint = function() end,
  fontHeight = function() return 16 end, ftSetPixelSize = function() end })
Color = { new = function(r, g, b, a) return ((a or 128) * 16777216) + ((b or 0) * 65536) + ((g or 0) * 256) + (r or 0) end }
local _t = 0
Timer = { getTime = function() _t = _t + 16000; return _t end, new = function() return 1 end }
Sound = permissive({ loadADPCM = function() return 1 end, playADPCM = function() end,
  freeADPCM = function() end, setFormat = function() end, setVolume = function() end, setADPCMVolume = function() end })
Pads = permissive({ get = function() return { btns = 0xFFFF } end, getMode = function() return 4 end,
  getType = function() return 4 end })
IMG = setmetatable({}, { __index = function(t, k) rawset(t, k, 1); return 1 end })

-- boot.lua exports
POPSLDR_VER = "harness"
GPAD = 0
BFONT, SFONT, LFONT = 1, 1, 1

-- requires: images is stubbed (IMG above)
package = package or {}
package.preload = package.preload or {}
package.preload["images"] = function() return true end
'''

lua.execute(MOCKS)
preload = lua.eval(
    "function(src, name) return function() return load(src, name)() end end")
# ui.lua is require'd FROM system.lua (line ~2578), after PLDR exists -- the
# app's real order. Preload the real source so that require executes it.
lua.globals().package.preload["ui"] = preload(UI_SRC, "ui.lua")

results = []
def check(name, cond, detail=""):
    # Lua tests return `false, "reason"`; with unpack_returned_tuples that
    # arrives as a PYTHON TUPLE, and bool((False, "reason")) is True -- every
    # two-value failure used to false-PASS. Unpack before truth-testing.
    if isinstance(cond, tuple):
        if len(cond) > 1 and detail == "":
            detail = str(cond[1])
        cond = cond[0]
    ok = cond is True or (cond not in (None, False) and not isinstance(cond, bool) and bool(cond))
    results.append((name, ok, detail))
    print(f"{'PASS' if ok else 'FAIL'}  {name}" + (f"  [{detail}]" if detail and not ok else ""))

# ---- load the real chunks in app order ----
def load_chunk(name, src):
    f = lua.eval("function(src, name) local c, e = load(src, name); if not c then error(e) end return c end")
    chunk = f(src, name)
    chunk()

try:
    load_chunk("system.lua", SYS_TRUNC)
    check("system.lua chunk executes up to the boot handoff (ui.lua require'd inside)", True)
except Exception as e:
    check("system.lua chunk executes up to the boot handoff (ui.lua require'd inside)", False, str(e)[:300])
    print("FATAL: system.lua failed; aborting"); sys.exit(1)

g = lua.globals()
PLDR = g.PLDR
UI = g.UI
# system.lua pcall's the ui require, so verify it actually loaded
ui_ok = lua.eval("type(UI) == 'table' and type(UI.SCENES) == 'table' and UI.SCENES.GBDMHDD ~= nil")
check("ui.lua executed via system.lua's require (UI.SCENES live)", ui_ok)

# ---- battery ----
E = lua.eval

# T1 candidate names
t1 = E('''function()
  local f = PLDR.HDD.IsPartitionGameCandidateName
  return f("PP.Game") == true and f("__.Game") == true and f("__.POPS") == false
     and f("__.POPS5") == false and f("__.POPS12") == true and f("__system") == false
     and f("__common") == false and f("PP.") == false and f("pp.game") == false
     and f("+OPL") == false and f(nil) == false
end''')()
check("T1 partition-game candidate-name matrix", t1)

# T2 entry detection
t2 = E('''function()
  local f = PLDR.IsPartitionInstalledHddEntry
  return f("PP.Game", "IMAGE0.VCD") == true and f("PP.Game", "image0.vcd") == true
     and f("PP.Game", "GAME.VCD") == false and f("__.POPS", "IMAGE0.VCD") == false
     and f("__.Hidden", "IMAGE0.VCD") == true and f(nil, "IMAGE0.VCD") == false
end''')()
check("T2 partition-installed entry detection", t2)

# T3 display-name sort
t3 = E('''function()
  local t = { "__.POPS|Crash Bandicoot.VCD", "PP.Alpha Game|IMAGE0.VCD",
              "__.POPS0|Alien Trilogy.VCD", "__.Zeta|IMAGE0.VCD" }
  table.sort(t, PLDR.HDD.CompareGameEntriesByDisplay)
  return t[1] == "__.POPS0|Alien Trilogy.VCD" and t[2] == "PP.Alpha Game|IMAGE0.VCD"
     and t[3] == "__.POPS|Crash Bandicoot.VCD" and t[4] == "__.Zeta|IMAGE0.VCD"
end''')()
check("T3 HDD list sorts by DISPLAYED name (PP. no longer floats to top)", t3)

# T5 adaptive target matrix (UI.SCENES is the real table from ui.lua)
t5 = E('''function()
  local f = PLDR.ResolveAdaptiveBdmaTarget
  local S = UI.SCENES
  PLDR.BDMA_MODE_KEY = "MMCE"
  local a = f(S.GBDMHDD, "USB") == "ATA"          -- exFAT HDD masquerades as USB
  local b = f(nil, "MX4SIO") == "MX4SIO"
  local c = f(nil, "MMCE") == "MMCE"
  local d = f(nil, "SMB/MMCE") == "MMCE"
  local e = f(nil, "USB") == "FAT32"              -- saved MMCE: USB drive is FAT32
  PLDR.BDMA_MODE_KEY = "USBEXFAT"
  local g2 = f(nil, "USB") == "USBEXFAT"          -- saved exFAT preference honored
  local h = f(nil, "HDD") == nil and f(nil, "SMB") == nil and f(nil, "unknown") == nil
  PLDR.BDMA_MODE_KEY = "FAT32"
  return a and b and c and d and e and g2 and h
end''')()
check("T5 adaptive-BDMA target matrix (incl. USB saved-preference rule)", t5)

# T6 equipped check against the fake card
t6 = E('''function()
  local root = PLDR.POPSTARTER_DIR
  -- state 1: nothing staged
  FAKEFS.files[root.."/usbd.irx"] = nil
  FAKEFS.files[root.."/usbhdfsd.irx"] = nil
  FAKEFS.files[root.."/bdma_mode.txt"] = nil
  local a = PLDR.IsBdmaModeEquipped("FAT32") == true
  local b = PLDR.IsBdmaModeEquipped("MMCE") == false
  -- state 2: MMCE fully staged
  FAKEFS.files[root.."/usbd.irx"] = "X"
  FAKEFS.files[root.."/usbhdfsd.irx"] = "Y"
  FAKEFS.files[root.."/bdma_mode.txt"] = "MMCE"
  local c = PLDR.IsBdmaModeEquipped("MMCE") == true
  local d = PLDR.IsBdmaModeEquipped("ATA") == false
  local e = PLDR.IsBdmaModeEquipped("FAT32") == false
  -- state 3: marker says MMCE but a module file is missing
  FAKEFS.files[root.."/usbhdfsd.irx"] = nil
  local f = PLDR.IsBdmaModeEquipped("MMCE") == false
  return a and b and c and d and e and f
end''')()
check("T6 equipped-check (marker + on-card files, all states)", t6)

# T10 full adaptive staging cycle through the REAL ApplyBdmaMode
t10 = E('''function()
  local root = PLDR.POPSTARTER_DIR
  EMBEDDED["usbd.irx.mmce"] = "FAKE-USBD-MMCE"
  EMBEDDED["usbhdfsd.irx.mmce"] = "FAKE-HDFSD-MMCE"
  EMBEDDED["icon.sys.bdma"] = "I"; EMBEDDED["list.icn.bdma"] = "L"; EMBEDDED["del.icn.bdma"] = "D"
  FAKEFS.files[root.."/usbd.irx"] = nil
  FAKEFS.files[root.."/usbhdfsd.irx"] = nil
  FAKEFS.files[root.."/bdma_mode.txt"] = nil
  PLDR.BDMA_ADAPTIVE = true
  PLDR.POPSTARTER_MC_FOLDER = true
  local n0 = #UI.Notif_queue.msg
  local ok = PLDR.MaybeApplyAdaptiveBdma(nil, "MMCE")   -- stage needed
  local staged = FAKEFS.files[root.."/usbd.irx"] == "FAKE-USBD-MMCE"
             and FAKEFS.files[root.."/usbhdfsd.irx"] == "FAKE-HDFSD-MMCE"
             and FAKEFS.files[root.."/bdma_mode.txt"] == "MMCE"
  local no_toast = (#UI.Notif_queue.msg == n0)          -- success is silent
  local eq = PLDR.IsBdmaModeEquipped("MMCE") == true
  -- second call: equipped -> zero writes (poison the embedded source to prove no re-read)
  EMBEDDED["usbd.irx.mmce"] = nil
  local ok2 = PLDR.MaybeApplyAdaptiveBdma(nil, "MMCE")
  local intact = FAKEFS.files[root.."/usbd.irx"] == "FAKE-USBD-MMCE"
  -- FAT32 arm removes the modules
  local ok3 = PLDR.MaybeApplyAdaptiveBdma(nil, "USB")   -- saved FAT32 -> remove
  local removed = FAKEFS.files[root.."/usbd.irx"] == nil and FAKEFS.files[root.."/bdma_mode.txt"] == "FAT32"
  return ok == true and staged and no_toast and eq and ok2 == true and intact and ok3 == true and removed
end''')()
check("T10 adaptive staging cycle (stage -> skip-when-equipped -> FAT32 removal)", t10)

# T11 staging FAILURE cancels (returns false) + visible warn queued
t11 = E('''function()
  local root = PLDR.POPSTARTER_DIR
  EMBEDDED["usbd.irx.mx4sio"] = nil
  EMBEDDED["usbhdfsd.irx.mx4sio"] = nil
  FAKEFS.files[root.."/usbd.irx"] = nil
  FAKEFS.files[root.."/usbhdfsd.irx"] = nil
  FAKEFS.files[root.."/bdma_mode.txt"] = nil
  PLDR.BDMA_ADAPTIVE = true
  local n0 = #UI.Notif_queue.msg
  local ok = PLDR.MaybeApplyAdaptiveBdma(nil, "MX4SIO")  -- no source anywhere -> fail
  local warned = #UI.Notif_queue.msg > n0
  return ok == false and warned
end''')()
check("T11 staging failure returns false (launch-cancel) + queues the warn", t11)

# T7 settings round-trip for BDMA_ADAPTIVE
t7 = E('''function()
  PLDR.BDMA_ADAPTIVE = true
  local saved = PLDR.SaveSettingsAtomic()
  local sidecar = nil
  for path, content in pairs(FAKEFS.files) do
    if string.match(path, "%.pldrs$") and string.find(content, "BDMA_ADAPTIVE=", 1, true) then sidecar = content end
  end
  if not (saved and sidecar and string.find(sidecar, "BDMA_ADAPTIVE=1", 1, true)) then return false, "save" end
  PLDR.BDMA_ADAPTIVE = false
  PLDR.LoadSettingsNonFatal()
  return PLDR.BDMA_ADAPTIVE == true
end''')()
check("T7 BDMA_ADAPTIVE persists (save -> sidecar -> reload)", t7)

# T12 adaptive OFF restages the chosen mode (CommitSettingsChanges arm)
t12 = E('''function()
  local root = PLDR.POPSTARTER_DIR
  -- card holds MMCE from a previous adaptive launch; chosen mode is FAT32
  FAKEFS.files[root.."/usbd.irx"] = "X"
  FAKEFS.files[root.."/usbhdfsd.irx"] = "Y"
  FAKEFS.files[root.."/bdma_mode.txt"] = "MMCE"
  PLDR.BDMA_ADAPTIVE = true
  PLDR.BDMA_MODE_KEY = "FAT32"
  local ok, why = PLDR.CommitSettingsChanges({ bdma_adaptive = false })
  local restored = FAKEFS.files[root.."/usbd.irx"] == nil
               and FAKEFS.files[root.."/bdma_mode.txt"] == "FAT32"
  local key_kept = PLDR.BDMA_MODE_KEY == "FAT32"
  return ok == true and restored and key_kept and PLDR.BDMA_ADAPTIVE == false
end''')()
check("T12 adaptive OFF restages the chosen mode (no marker adoption)", t12)

# T8 partition scan end-to-end (classic + PP + false-positive + hidden + reserved)
t8 = E('''function()
  FAKEHDD.parts = {
    ["__.POPS"] = { files = {}, listing = {
      { name = "Crash Bandicoot.VCD", directory = false },
      { name = "Alien Trilogy.VCD", directory = false } } },
    ["PP.Vagrant Story"] = { files = { ["IMAGE0.VCD"] = true }, listing = { { name = "IMAGE0.VCD", directory = false } } },
    ["PP.CodeBreaker"] = { files = {}, listing = { { name = "CB.PCB", directory = false } } },
    ["__.HiddenGame"] = { files = { ["IMAGE0.VCD"] = true, ["IMAGE0.hide"] = true },
                          listing = { { name = "IMAGE0.VCD", directory = false }, { name = "IMAGE0.hide", directory = false } } },
  }
  FAKEHDD.names = { "__mbr", "__system", "__common", "__.POPS", "PP.Vagrant Story", "PP.CodeBreaker", "__.HiddenGame" }
  FAKEHDD.status = 0
  PLDR.HDD.LOADSTATE = 0
  PLDR.LoadHDDModules()
  if PLDR.HDD.LOADSTATE ~= 1 then return false, "modules" end
  PLDR.GLOBAL_HIDE = true
  PLDR.COLLAPSE_MULTIDISC = false
  PLDR.HDD.HAS_CHECKED = false
  PLDR.HDD.CheckAvailableHddPopsParts(nil)
  if PLDR.HDD.FOUNDANY ~= true then return false, "foundany" end
  PLDR.HDD.BuildGameList(nil)
  local names = table.concat(PLDR.GAMES, ";")
  -- expected: Alien, Crash (classic, display-sorted) + PP.Vagrant Story; CodeBreaker
  -- excluded (no IMAGE0.VCD); __.HiddenGame excluded (GLOBAL_HIDE + IMAGE0.hide)
  local want = "__.POPS|Alien Trilogy.VCD;__.POPS|Crash Bandicoot.VCD;PP.Vagrant Story|IMAGE0.VCD"
  if names ~= want then return false, "list="..names end
  if PLDR.HDD.GAMEPARTS["PP.Vagrant Story|IMAGE0.VCD"] ~= "hdd0:PP.Vagrant Story" then return false, "gameparts" end
  -- reveal pass: GLOBAL_HIDE off lists the hidden PP game and marks it hidden
  PLDR.GLOBAL_HIDE = false
  PLDR.HDD.HAS_CHECKED = false
  PLDR.HDD.CheckAvailableHddPopsParts(nil)
  PLDR.HDD.BuildGameList(nil)
  local has_hidden, marked = false, false
  for i = 1, #PLDR.GAMES do
    if PLDR.GAMES[i] == "__.HiddenGame|IMAGE0.VCD" then has_hidden = true end
  end
  marked = PLDR.HIDDEN["__.HiddenGame|IMAGE0.VCD"] == true
  return has_hidden and marked
end''')()
check("T8 partition scan end-to-end (probe gate, hidden, reserved skip, sort)", t8)

# T9 multi-disc collapse on partition names
t9 = E('''function()
  FAKEHDD.parts["PP.Final Fantasy VII (Disc 2)"] = { files = { ["IMAGE0.VCD"] = true }, listing = { { name = "IMAGE0.VCD", directory = false } } }
  FAKEHDD.parts["PP.Final Fantasy VII (Disc 1)"] = { files = { ["IMAGE0.VCD"] = true }, listing = { { name = "IMAGE0.VCD", directory = false } } }
  FAKEHDD.names = { "__.POPS", "PP.Final Fantasy VII (Disc 1)", "PP.Final Fantasy VII (Disc 2)" }
  PLDR.GLOBAL_HIDE = false
  PLDR.COLLAPSE_MULTIDISC = true
  PLDR.HDD.HAS_CHECKED = false
  PLDR.HDD.CheckAvailableHddPopsParts(nil)
  PLDR.HDD.BuildGameList(nil)
  local d1, d2 = false, false
  for i = 1, #PLDR.GAMES do
    if string.find(PLDR.GAMES[i], "Disc 1", 1, true) then d1 = true end
    if string.find(PLDR.GAMES[i], "Disc 2", 1, true) then d2 = true end
  end
  PLDR.COLLAPSE_MULTIDISC = false
  return d1 == true and d2 == false
end''')()
check("T9 multi-disc collapse applies to partition-installed games", t9)

# T13 HDD status re-probe un-latches
t13 = E('''function()
  FAKEHDD.status = 3            -- "no HDD" on first probe
  PLDR.HDD.LOADSTATE = 0
  PLDR.LoadHDDModules()
  if PLDR.HDD.LOADSTATE ~= -1 then return false, "no latch" end
  FAKEHDD.status = 0            -- drive settled
  PLDR.LoadHDDModules()         -- re-probe arm
  return PLDR.HDD.LOADSTATE == 1
end''')()
check("T13 bad first HDD status recovers on re-probe (no dead latch)", t13)

# T14 i18n: PLDR.L translates when a language is set, falls back to English otherwise
t14 = E('''function()
  local langs = 0
  for _ in pairs(PLDR.I18N) do langs = langs + 1 end
  if langs < 5 then return false, "langs="..langs end
  PLDR.LANGUAGE = "EN"
  if PLDR.L("Settings") ~= "Settings" then return false, "EN passthrough" end
  PLDR.LANGUAGE = "FR"
  if PLDR.L("Settings") == "Settings" then return false, "FR did not translate Settings" end
  if PLDR.L("Back") ~= "Retour" then return false, "FR Back="..tostring(PLDR.L("Back")) end
  -- unlisted / path-like strings fall back to English unchanged
  if PLDR.L("mc0:/POPS/GAME.VCD") ~= "mc0:/POPS/GAME.VCD" then return false, "path not passthrough" end
  if PLDR.L("some string with no translation") ~= "some string with no translation" then return false, "unlisted not passthrough" end
  -- a bogus language falls back to English
  PLDR.LANGUAGE = "ZZ"
  if PLDR.L("Settings") ~= "Settings" then return false, "bad-lang fallback" end
  PLDR.LANGUAGE = "EN"
  return true
end''')()
check("T14 i18n L() translates + falls back to English for unlisted/paths/bad-lang", t14)

# T15 LANGUAGE persists (save -> sidecar -> reload)
t15 = E('''function()
  PLDR.LANGUAGE = "DE"
  local saved = PLDR.SaveSettingsAtomic()
  local sidecar = nil
  for path, content in pairs(FAKEFS.files) do
    if string.match(path, "%.pldrs$") and string.find(content, "LANGUAGE=", 1, true) then sidecar = content end
  end
  if not (saved and sidecar and string.find(sidecar, "LANGUAGE=DE", 1, true)) then return false, "save" end
  PLDR.LANGUAGE = "EN"
  PLDR.LoadSettingsNonFatal()
  return PLDR.LANGUAGE == "DE"
end''')()
check("T15 LANGUAGE persists (save -> sidecar -> reload)", t15)

# T16 the newly-wired "English holdout" draw sites (modal body/hints, busy overlay,
# path-editor title, empty-states, share picker) must have their keys in the table so
# PLDR.L() at those sites actually translates. A future table regen dropping any of
# these would silently regress those spots back to English, so assert them explicitly.
t16 = E('''function()
  PLDR.LANGUAGE = "FR"
  local holdouts = {
    "Not implemented yet",                                  -- game-list stub
    "No games found",                                       -- empty device
    "Saving/Applying...",                                   -- busy overlay
    "Working...",                                           -- busy overlay (indeterminate)
    "Yes", "No",                                            -- RunConfirm hint words (composed, region-aware)
    "Keep", "Revert",                                       -- RunVideoModeConfirm hint words
    "Delete the POPSTARTER folder from the memory card?",   -- RunConfirm prose
    "Return to OSDSYS?",                                    -- modal body
    "Edit POPStarter Path",                                 -- path editor title
    "Select a share",                                       -- SMB share picker
    "Select", "Cancel",                                     -- share picker hint words
    "Automatic",                                            -- POPSTARTER Path row (empty = ladder)
    "Device List",                                          -- renamed section (was Carousel Devices)
    "About", "Credits",                                     -- Credits moved into Settings
    "How to hide a game", "L3 on the game list",            -- the L3 discoverability hint
  }
  for _, k in ipairs(holdouts) do
    local t = PLDR.L(k)
    if t == nil or t == k then return false, "not translated: "..k end
  end
  PLDR.LANGUAGE = "EN"
  return true
end''')()
check("T16 newly-wired holdout keys (modal/overlay/picker/empty-state) translate", t16)

# T17 POPSTARTER_PATH (profiles dropped): "" = Automatic round-trips; a custom
# path round-trips; the legacy keys are never written; and a legacy PROFILE=N
# pick MIGRATES into POPSTARTER_PATH on load (the __common presets are the
# load-bearing case: HDD POPSTARTER + removable game = the supported D-14
# setup, which the Automatic ladder does not cover -- adversarial-review
# finding). PROFILE=1 and the mc?:/POPS presets 13/14 land on Automatic (a
# memory card never carries a POPS folder -- maintainer).
t17 = E('''function()
  -- custom path round-trip
  PLDR.POPSTARTER_PATH = "mass:/POPS/CUSTOM.ELF"
  if not PLDR.SaveSettingsAtomic() then return false, "save custom" end
  PLDR.POPSTARTER_PATH = "sentinel"
  PLDR.LoadSettingsNonFatal()
  if PLDR.POPSTARTER_PATH ~= "mass:/POPS/CUSTOM.ELF" then
    return false, "custom reload="..tostring(PLDR.POPSTARTER_PATH)
  end
  -- Automatic ("" round-trip)
  PLDR.POPSTARTER_PATH = ""
  if not PLDR.SaveSettingsAtomic() then return false, "save auto" end
  PLDR.POPSTARTER_PATH = "sentinel"
  PLDR.LoadSettingsNonFatal()
  if PLDR.POPSTARTER_PATH ~= "" then return false, "auto reload="..tostring(PLDR.POPSTARTER_PATH) end
  -- the sidecar must not carry the legacy keys anymore
  local sidecar = nil
  for path, content in pairs(FAKEFS.files) do
    if string.match(path, "%.pldrs$") and string.find(content, "POPSTARTER_PATH=", 1, true) then sidecar = content end
  end
  if sidecar == nil then return false, "no sidecar" end
  if string.find(sidecar, "POPSTARTER_MODE=", 1, true) or string.match(sidecar, "\\nPROFILE=") then
    return false, "legacy keys still written"
  end
  -- legacy config, preset selected: PROFILE=2 (hdd0:__common -- the D-14
  -- HDD-POPSTARTER-with-removable-games setup the ladder doesn't cover)
  -- + empty path -> migrates to that preset's path
  local base = nil
  for path, content in pairs(FAKEFS.files) do
    if string.match(path, "%.pldrs$") then
      if base == nil then base = {} end
      base[path] = content
      FAKEFS.files[path] = "PROFILE=2\\nPOPSTARTER_PATH=\\nPOPSTARTER_MODE=PROFILE_DEFAULT\\n"..content
    end
  end
  if base == nil then return false, "no sidecar for legacy test" end
  PLDR.POPSTARTER_PATH = "sentinel"
  PLDR.LoadSettingsNonFatal()
  if PLDR.POPSTARTER_PATH ~= "hdd0:__common:pfs:/POPS/POPSTARTER.ELF" then
    return false, "legacy preset reload="..tostring(PLDR.POPSTARTER_PATH)
  end
  -- legacy defaults -> Automatic: PROFILE=1 (relative default) and
  -- PROFILE=13 (mc?:/POPS -- never a real location, dropped from the map)
  for _, legacy_n in ipairs({"1", "13"}) do
    for path, content in pairs(base) do
      FAKEFS.files[path] = "PROFILE="..legacy_n.."\\nPOPSTARTER_PATH=\\nPOPSTARTER_MODE=PROFILE_DEFAULT\\n"..content
    end
    PLDR.POPSTARTER_PATH = "sentinel"
    PLDR.LoadSettingsNonFatal()
    if PLDR.POPSTARTER_PATH ~= "" then
      return false, "legacy PROFILE="..legacy_n.." reload="..tostring(PLDR.POPSTARTER_PATH)
    end
  end
  -- a real persisted path beats any legacy PROFILE= leftover
  for path, content in pairs(base) do
    FAKEFS.files[path] = "PROFILE=2\\nPOPSTARTER_PATH=mass:/POPS/MINE.ELF\\n"..content
  end
  PLDR.LoadSettingsNonFatal()
  if PLDR.POPSTARTER_PATH ~= "mass:/POPS/MINE.ELF" then
    return false, "explicit-beats-legacy reload="..tostring(PLDR.POPSTARTER_PATH)
  end
  return true
end''')()
check("T17 POPSTARTER_PATH round-trips (custom + Automatic) + legacy PROFILE=N migrates (2->__common, 1/13->Automatic, explicit wins)", t17)

# T18 Internal-HDD page visibility truth table (EXP4: HDD_FS gains "BOTH").
# No test covered IsDeviceHidden at all before. The load-bearing cases are the
# back-compat ones: a missing/unknown HDD_FS, and an -page=ata session, must
# behave EXACTLY as they did when the setting was 2-valued.
t18 = E('''function()
  local saved_fs, saved_args = PLDR.HDD_FS, PLDR.LAUNCH_ARGS
  local function vis(fs, page)
    PLDR.HDD_FS = fs
    PLDR.LAUNCH_ARGS = page and {page = page} or {}
    -- IsDeviceHidden returns HIDDEN; invert to "shown" for readability
    return (not PLDR.IsDeviceHidden("PFS")), (not PLDR.IsDeviceHidden("EXFAT"))
  end
  local cases = {
    -- fs,        page,   want_pfs, want_exfat, why
    {"PFS",       nil,    true,  false, "default: PFS only"},
    {nil,         nil,    true,  false, "MISSING key must resolve to PFS (back-compat)"},
    {"garbage",   nil,    true,  false, "unknown value must resolve to PFS"},
    {"EXFAT",     nil,    false, true,  "exFAT only"},
    {"BOTH",      nil,    true,  true,  "BOTH shows both (the EXP4 point)"},
    {"both",      nil,    true,  true,  "value is case-insensitive"},
    {"PFS",       "ATA",  false, true,  "-page=ata forces exFAT even when set to PFS"},
    {"BOTH",      "ATA",  false, true,  "-page=ata isolation still wins over BOTH"},
  }
  for _, c in ipairs(cases) do
    local p, e = vis(c[1], c[2])
    if p ~= c[3] or e ~= c[4] then
      PLDR.HDD_FS, PLDR.LAUNCH_ARGS = saved_fs, saved_args
      return false, string.format("%s: fs=%s page=%s -> pfs=%s exfat=%s (want pfs=%s exfat=%s)",
        c[5], tostring(c[1]), tostring(c[2]), tostring(p), tostring(e), tostring(c[3]), tostring(c[4]))
    end
  end
  -- BOTH must survive a save -> sidecar -> reload round trip
  PLDR.HDD_FS = "BOTH"
  if not PLDR.SaveSettingsAtomic() then
    PLDR.HDD_FS, PLDR.LAUNCH_ARGS = saved_fs, saved_args
    return false, "save failed"
  end
  local wrote = false
  for path, content in pairs(FAKEFS.files) do
    if string.match(path, "%.pldrs$") and string.find(content, "HDD_FS=BOTH", 1, true) then wrote = true end
  end
  PLDR.HDD_FS = "sentinel"
  PLDR.LoadSettingsNonFatal()
  local reloaded = PLDR.HDD_FS
  PLDR.HDD_FS, PLDR.LAUNCH_ARGS = saved_fs, saved_args
  if not wrote then return false, "HDD_FS=BOTH not written to the sidecar" end
  if reloaded ~= "BOTH" then return false, "reload gave "..tostring(reloaded) end
  return true
end''')()
check("T18 Internal-HDD visibility truth table (PFS/EXFAT/BOTH x -page=ata) + BOTH persists", t18)

# ---------------------------------------------------------------------------
# T19 USB diagnostics (EXP5). PLDR.GetUsbDiagText turns System.getUsbDiag()'s raw
# IRX codes into the line a tester reads off the screen and relays back to us.
# This is the ONLY telemetry this bug has, so its branch logic has to be right:
# it must name the FIRST broken link (everything after is a cascade), and it must
# distinguish "a module failed" from "modules are up, no drive enumerated" --
# exactly the split we could not make for four days, which is why two shipped
# "root cause found" fixes were aimed at the wrong half of the problem.
OK = 0  # a good load is id >= 0 and ret >= 0
def usb_diag(**kw):
    d = dict(usbd_id=OK, usbd_ret=OK, bdm_id=OK, bdm_ret=OK,
             bdmfs_id=OK, bdmfs_ret=OK, usbmass_id=OK, usbmass_ret=OK)
    d.update(kw)
    # Must be a REAL Lua function: GetUsbDiagText gates on
    # type(System.getUsbDiag) == "function", which is correct for the actual C
    # binding, but lupa marshals a Python callable as *userdata* and the
    # permissive mock's __index auto-stub returns 0 rather than a table. Either
    # one makes the guard (correctly) bail, so build the mock in Lua.
    fields = ", ".join("%s = %d" % (k, v) for k, v in sorted(d.items()))
    lua.execute("System.getUsbDiag = function() return { %s } end" % fields)
    r = lua.globals().PLDR.GetUsbDiagText()
    return r if isinstance(r, str) else str(r)

t19_cases = [
    # (kwargs, expected substring, why it matters)
    ({},                                  "modules OK, no drive seen", "all good -> blame the drive, not a module"),
    ({"usbd_id": -1},                     "usbd failed",              "usbd rc<0 -> name usbd"),
    ({"usbd_ret": -1},                    "usbd failed",              "usbd ret<0 counts as failed too"),
    ({"usbd_id": -999},                   "usbd never loaded",        "-999 = never attempted, not a real rc"),
    ({"bdm_id": -1},                      "bdm failed",               "bdm rc<0 -> name bdm"),
    ({"bdmfs_id": -5},                    "bdmfs_fatfs failed",       "bdmfs rc<0 -> name bdmfs_fatfs"),
    ({"usbmass_id": -1},                  "usbmass_bd failed",        "usbmass rc<0 -> name usbmass_bd"),
    # first-broken-link ordering: usbd is upstream of everything
    ({"usbd_id": -1, "usbmass_id": -1},   "usbd failed",              "report the FIRST break, not the cascade"),
    ({"bdm_id": -1, "usbmass_id": -1},    "bdm failed",               "bdm upstream of usbmass"),
]
t19 = True
for kw, want, why in t19_cases:
    got = usb_diag(**kw)
    if want not in got:
        t19 = False
        print(f"    T19 FAIL ({why}): expected {want!r} in {got!r}")
# the rc numbers must actually reach the string, or a photo of the screen is useless
got = usb_diag(usbd_id=-17, usbd_ret=-23)
if "-17" not in got or "-23" not in got:
    t19 = False
    print(f"    T19 FAIL: rc values not surfaced: {got!r}")
# a binding that returns a non-table (older ELF, or the permissive stub's 0)
# must degrade to nil rather than crash the USB page mid-error-toast
lua.execute("System.getUsbDiag = function() return 0 end")
if lua.globals().PLDR.GetUsbDiagText() is not None:
    t19 = False
    print("    T19 FAIL: non-table getUsbDiag should yield nil, not a string")
# and a binding that throws must be caught (it is pcall'd)
lua.execute("System.getUsbDiag = function() error('boom') end")
if lua.globals().PLDR.GetUsbDiagText() is not None:
    t19 = False
    print("    T19 FAIL: throwing getUsbDiag should yield nil, not propagate")
check("T19 USB diag names the first broken module + splits module-fail from no-drive", t19)

# ---------------------------------------------------------------------------
# T20 Boot profile (EXP6). BootStamp's stamps are CUMULATIVE ms since EE start,
# so the cost of a module is the DELTA between consecutive stamps, not the stamp
# itself. Reporting the largest absolute stamp instead of the largest delta would
# always just name the LAST stage -- a plausible-looking readout that is wrong
# every single time. That is the whole value of this feature, so pin it.
def boot_prof(pairs):
    entries = ", ".join('{ stage = "%s", ms = %d }' % (n, ms) for n, ms in pairs)
    lua.execute("System.getBootProfile = function() return { %s } end" % entries)
    r = lua.globals().PLDR.GetBootProfileText()
    return r if isinstance(r, str) else str(r)

t20 = True
# ds34 is the expensive one (2000->5000 = +3000), even though "audsrv" has a bigger stamp
got = boot_prof([("iomanX", 100), ("usbd", 2000), ("ds34", 5000), ("audsrv", 5100)])
if "ds34" not in got or "+3000" not in got:
    t20 = False; print(f"    T20 FAIL: largest DELTA not identified: {got!r}")
if "5100" not in got:
    t20 = False; print(f"    T20 FAIL: total should be the LAST stamp: {got!r}")
# the first stage is a delta from 0, and can legitimately be the worst
got = boot_prof([("iomanX", 4000), ("usbd", 4100)])
if "iomanX" not in got or "+4000" not in got:
    t20 = False; print(f"    T20 FAIL: first stage delta (from 0) missed: {got!r}")
# a late-but-cheap stage must NOT win just for having the biggest absolute stamp
got = boot_prof([("a", 3000), ("b", 3010), ("c", 3020)])
if '"a"' in got or "+10" in got or "a +3000" not in got:
    t20 = False; print(f"    T20 FAIL: expected 'a +3000' to win on delta: {got!r}")
# degenerate inputs must not crash the credits screen
for bad in ["{}", "0", "nil"]:
    lua.execute("System.getBootProfile = function() return %s end" % bad)
    if lua.globals().PLDR.GetBootProfileText() is not None:
        t20 = False; print(f"    T20 FAIL: {bad} should yield nil")
lua.execute("System.getBootProfile = function() error('boom') end")
if lua.globals().PLDR.GetBootProfileText() is not None:
    t20 = False; print("    T20 FAIL: throwing getBootProfile should yield nil")
check("T20 Boot profile reports slowest stage by DELTA (not biggest cumulative stamp)", t20)

# ---------------------------------------------------------------------------
# T21 MMCE readiness is truthful and retryable. A successful mmceman IRX load
# must not permanently latch ready when mmce0:/mmce1:/ have not appeared yet.
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

# T22 MX4SIO identity discovery must use bdmList and never open all ten mass
# filesystems merely to learn which parId belongs to the sdc/mx4 driver.
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

print()
fails = [r for r in results if not r[1]]
print(f"=== {len(results) - len(fails)}/{len(results)} PASS ===")
for name, ok, detail in fails:
    print(f"  FAIL: {name}: {detail}")
sys.exit(1 if fails else 0)
