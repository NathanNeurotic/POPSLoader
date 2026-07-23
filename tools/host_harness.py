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

# T32 EXP42 COVER_ART: cover art moved from a session-only Square toggle to a persisted
# setting, so it must round-trip like any other, DEFAULT ON, and drive the live list via
# UI.SetCoverPreview. Default-ON booleans are the easy ones to get wrong: the `~= false`
# idiom is what makes an absent key mean ON rather than OFF, so assert the absent-key
# case explicitly (an older sidecar with no COVER_ART= line must not turn covers off).
t32 = E('''function()
  if PLDR.COVER_ART ~= true then return false, "default should be ON, got "..tostring(PLDR.COVER_ART) end
  -- OFF round-trips through the sidecar
  PLDR.COVER_ART = false
  local saved = PLDR.SaveSettingsAtomic()
  local sidecar = nil
  for path, content in pairs(FAKEFS.files) do
    if string.match(path, "%.pldrs$") and string.find(content, "COVER_ART=", 1, true) then sidecar = content end
  end
  if not saved then return false, "save failed" end
  if not (sidecar and string.find(sidecar, "COVER_ART=0", 1, true)) then return false, "COVER_ART=0 not persisted" end
  PLDR.COVER_ART = true
  PLDR.LoadSettingsNonFatal()
  if PLDR.COVER_ART ~= false then return false, "OFF did not reload, got "..tostring(PLDR.COVER_ART) end
  -- and the live list follows the loaded value
  if UI.CoverPreviewEnabled ~= false then return false, "UI.CoverPreviewEnabled not applied on load" end
  -- ON round-trips too
  PLDR.COVER_ART = true
  PLDR.SaveSettingsAtomic()
  PLDR.COVER_ART = false
  PLDR.LoadSettingsNonFatal()
  if PLDR.COVER_ART ~= true then return false, "ON did not reload" end
  if UI.CoverPreviewEnabled ~= true then return false, "UI.CoverPreviewEnabled not re-enabled on load" end
  -- SetCoverPreview carries the old Square handler's side effects
  if type(UI.SetCoverPreview) ~= "function" then return false, "UI.SetCoverPreview missing" end
  UI.SetCoverPreview(false)
  if UI.CoverPreviewEnabled ~= false then return false, "SetCoverPreview(false) did not take" end
  if UI.GameList.CoverPending ~= false then return false, "CoverPending should clear when off" end
  UI.SetCoverPreview(true)
  if UI.CoverPreviewEnabled ~= true then return false, "SetCoverPreview(true) did not take" end
  if UI.GameList.CoverPending ~= true then return false, "CoverPending should re-arm when on" end
  -- An OLD sidecar with no COVER_ART= line must default to ON, not OFF.
  for path, content in pairs(FAKEFS.files) do
    if string.match(path, "%.pldrs$") then
      FAKEFS.files[path] = string.gsub(content, "COVER_ART=[^\\n]*\\n", "")
    end
  end
  PLDR.COVER_ART = false
  PLDR.LoadSettingsNonFatal()
  if PLDR.COVER_ART ~= true then return false, "absent COVER_ART key must default ON, got "..tostring(PLDR.COVER_ART) end
  return true
end''')()
check("T32 EXP42 COVER_ART persists, defaults ON, and drives the live cover box", t32)

# T33 EXP43: the internal-exFAT bring-up must report each step BEFORE the call it
# names. This is the EXP11 freeze channel, which the EXP32 device-layer rebuild
# silently dropped -- and its absence is why EXP38, EXP39 and EXP40 each burned a
# hardware round without producing any evidence. A frozen IOP call never returns to
# repaint, so the message already on screen IS the diagnosis; if these steps stop
# firing, a failed exFAT round goes back to telling us nothing. Assert the channel
# exists, is ordered, names the slot, and stays optional (nil reporter must be safe).
t33 = E('''function()
  local seen = {}
  local rep = function(msg) seen[#seen + 1] = tostring(msg) end
  System.initATAAsync = function() return 2 end
  System.initATAStatus = function() return 2 end
  local real_dfe = doesFolderExist
  local real_drv = PLDR.GetMassMountDriver
  doesFolderExist = function(p)
    if p == "mass:/" or p == "mass0:/" then return true end
    return real_dfe(p)
  end
  PLDR.GetMassMountDriver = function(root) return "ata" end
  local root = PLDR.InitATAPopsRoot(rep)
  doesFolderExist = real_dfe
  PLDR.GetMassMountDriver = real_drv
  if root == nil then return false, "ata root should resolve in this fixture" end
  if #seen == 0 then return false, "NO steps reported -- the freeze channel is gone" end
  local joined = table.concat(seen, " | ")
  -- step 1 must come first: it is painted before the drive is started, which is the
  -- call most likely to hang on a wedged 4TB adapter.
  if not string.find(seen[1], "step 1", 1, true) then
    return false, "first step should be 'step 1', got: "..tostring(seen[1])
  end
  -- the per-slot steps must name the slot, or a photo cannot identify WHICH slot hung
  if not string.find(joined, "checking mass", 1, true) then
    return false, "no per-slot 'checking mass<N>:' step: "..joined
  end
  if not string.find(joined, "identifying mass", 1, true) then
    return false, "no per-slot 'identifying mass<N>:' step: "..joined
  end
  -- and a nil reporter must remain completely safe (every other caller passes none)
  local ok_nil = pcall(function() return PLDR.InitATAPopsRoot() end)
  if not ok_nil then return false, "InitATAPopsRoot() with no reporter must not error" end
  return true
end''')()
check("T33 EXP43 exFAT bring-up reports each step before the call that can freeze", t33)


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

# ---- T21-T23: the EXP32 reference-parity device core -------------------------
# The device layer's contract (NHDDL/OPL model): a transport that is not ready
# is NEVER swept (no fileXio probes against a half-registered core), the page
# gets a truthful status ("notready" vs "nodevice"), and a ready transport
# enumerates by driver-name classification. All through the public PLDR API
# with System.* overridden per scenario.
t21 = lua.execute(r'''
  -- (a) mx4sio boot-load failed and the page-entry retry also fails:
  -- GetMX4SIOMassRootNow must report "notready" WITHOUT sweeping massN:.
  System.initMX4SIO = function() return false end
  local swept = false
  local real_dfe = doesFolderExist
  doesFolderExist = function(p) swept = true; return real_dfe(p) end
  local root, status = PLDR.GetMX4SIOMassRootNow()
  doesFolderExist = real_dfe
  if root ~= nil then return false, "expected nil root, got "..tostring(root) end
  if status ~= "notready" then return false, "expected notready, got "..tostring(status) end
  if swept then return false, "swept massN: while transport not ready" end
  return true
''')
check("T21 mx4sio not-ready: no sweep + truthful 'notready' status", t21)

t22 = lua.execute(r'''
  -- (b) ata worker still running: bounded poll expires -> "notready", no sweep.
  System.initATAAsync = function() return 1 end
  System.initATAStatus = function() return 1 end
  local swept = false
  local real_dfe = doesFolderExist
  doesFolderExist = function(p) swept = true; return real_dfe(p) end
  local root, status = PLDR.GetATAMassRootNow()
  doesFolderExist = real_dfe
  if root ~= nil then return false, "expected nil root" end
  if status ~= "notready" then return false, "expected notready, got "..tostring(status) end
  if swept then return false, "swept while worker still running" end
  -- (c) worker done-ok but no ata device mounted: clean "nodevice".
  System.initATAAsync = function() return 2 end
  System.initATAStatus = function() return 2 end
  local root2, status2 = PLDR.GetATAMassRootNow()
  if root2 ~= nil then return false, "expected nil root for empty sweep" end
  if status2 ~= "nodevice" then return false, "expected nodevice, got "..tostring(status2) end
  return true
''')
check("T22 ata worker states: bounded 'notready' poll + clean 'nodevice' sweep", t22)

t23 = lua.execute(r'''
  -- (d) happy paths: ready transports enumerate by driver-name classification.
  System.initMX4SIO = function() return true end
  System.initATAAsync = function() return 2 end
  System.initATAStatus = function() return 2 end
  local real_dfe = doesFolderExist
  local real_drv = PLDR.GetMassMountDriver
  doesFolderExist = function(p)
    if p == "mass:/" or p == "mass0:/" then return true end
    return real_dfe(p)
  end
  PLDR.GetMassMountDriver = function(root) return "sdc" end
  local mx_root, mx_status = PLDR.GetMX4SIOMassRootNow()
  PLDR.GetMassMountDriver = function(root) return "ata" end
  local ata_root, ata_status = PLDR.GetATAMassRootNow()
  PLDR.GetMassMountDriver = function(root) return "usb" end
  local none_root, none_status = PLDR.GetMX4SIOMassRootNow()
  doesFolderExist = real_dfe
  PLDR.GetMassMountDriver = real_drv
  if mx_root ~= "mass:/" or mx_status ~= "ready" then
    return false, "mx4sio: expected mass:/ ready, got "..tostring(mx_root).."/"..tostring(mx_status)
  end
  if ata_root ~= "mass:/" or ata_status ~= "ready" then
    return false, "ata: expected mass:/ ready, got "..tostring(ata_root).."/"..tostring(ata_status)
  end
  if none_root ~= nil or none_status ~= "nodevice" then
    return false, "usb-driver slot must not classify as mx4sio"
  end
  return true
''')
check("T23 ready transports classify by driver name (sdc->mx4sio, ata->ata, usb excluded)", t23)

t24 = lua.execute(r'''
  -- (e) MMCE<->MX4SIO COEXISTENCE (maintainer call, 2026-07-21: official OPL
  -- runs both drivers resident on freesio2; no gate). Neither side may decline
  -- because of the other being resident -- this locks the decision in so a
  -- future change can't silently reintroduce a gate.
  local load_attempted = false
  System.initMX4SIO = function() load_attempted = true; return true end
  System.getSio2Owner = function() return "MMCE" end
  PLDR.GetMX4SIOMassRootNow()
  if not load_attempted then
    return false, "mx4sio_bd load must proceed even with mmceman resident (no gate)"
  end
  -- mirror: MMCE bring-up proceeds while mx4sio_bd is resident
  System.getSio2Owner = function() return "MX4SIO" end
  PLDR._mmce_ready = nil
  local mmce_load_attempted = false
  System.ensureMmceman = function() mmce_load_attempted = true; return true end
  local ok_m = PLDR.EnsureMmceReadyOnce()
  if ok_m == false or not mmce_load_attempted then
    return false, "EnsureMmceReadyOnce must proceed with mx4sio_bd resident (no gate)"
  end
  System.getSio2Owner = function() return "" end
  return true
''')
check("T24 MMCE<->MX4SIO coexistence: neither driver declines because the other is resident", t24)

t25 = lua.execute(r'''
  -- (f) cascade bound: while the ata worker holds the IOP module loader
  -- (state==1), a MX4SIO page entry must wait BOUNDED and report not-ready --
  -- never queue its synchronous IRX load behind a possibly-wedged loader.
  local load_attempted = false
  System.initMX4SIO = function() load_attempted = true; return true end
  System.initATAStatus = function() return 1 end
  local root, status = PLDR.GetMX4SIOMassRootNow()
  if status ~= "notready" then
    return false, "expected notready while ata load in flight, got "..tostring(status)
  end
  if load_attempted then
    return false, "mx4sio IRX load queued behind an in-flight ata load"
  end
  -- loader free again: the load proceeds
  System.initATAStatus = function() return 2 end
  PLDR.GetMX4SIOMassRootNow()
  if not load_attempted then
    return false, "mx4sio load should proceed once the ata load finished"
  end
  return true
''')
check("T25 cascade bound: MX4SIO waits bounded while the ata load holds the IOP loader", t25)

# T26 APA scan diagnostics: a __.POPS partition that mounts (FOUNDANY) but whose
# listing has NO .vcd files must yield zero games AND a SCAN_DIAG that names the
# "mounted-but-empty" case (avail>0, remount_fail==0, entries>0, vcds==0) -- the
# self-diagnosing readout behind the EXP33 "no games" toast.
t26 = E('''function()
  FAKEHDD.parts = {
    ["__.POPS"] = { files = {}, listing = {
      { name = "README.TXT", directory = false },
      { name = "ART", directory = true } } },
  }
  FAKEHDD.names = { "__.POPS" }
  FAKEHDD.status = 0
  PLDR.HDD.LOADSTATE = 0
  PLDR.LoadHDDModules()
  PLDR.GLOBAL_HIDE = false
  PLDR.COLLAPSE_MULTIDISC = false
  PLDR.HDD.HAS_CHECKED = false
  PLDR.HDD.CheckAvailableHddPopsParts(nil)
  if PLDR.HDD.FOUNDANY ~= true then return false, "foundany should be true (partition mounted)" end
  PLDR.HDD.BuildGameList(nil)
  if #PLDR.GAMES ~= 0 then return false, "expected 0 games, got "..#PLDR.GAMES end
  local d = PLDR.HDD.SCAN_DIAG
  if type(d) ~= "table" then return false, "no SCAN_DIAG" end
  if (d.avail or 0) < 1 then return false, "avail should be >=1" end
  if (d.remount_fail or 0) ~= 0 then return false, "remount_fail should be 0 (mount ok)" end
  if (d.entries or 0) < 2 then return false, "entries should count the listing" end
  if (d.vcds or 0) ~= 0 then return false, "vcds should be 0" end
  return true
end''')()
check("T26 APA scan diag: mounted-but-empty partition yields 0 games + legible SCAN_DIAG", t26)

# T27 EXP34 hidden-count: a __.POPS partition with ONE .vcd whose basename is
# hidden (a matching .hide sidecar) + Global Hide ON must yield zero games AND
# SCAN_DIAG.hidden==1 (vcds==1) -- so the toast can say "1 hidden -- Global Hide
# is on" instead of reading as a device fault (the FifthFox APA "hidden by
# accident" case). Turning Global Hide off must then reveal the game.
t27 = E('''function()
  FAKEHDD.parts = {
    ["__.POPS"] = { files = {}, listing = {
      { name = "MyGame.vcd", directory = false },
      { name = "MyGame.hide", directory = false } } },
  }
  FAKEHDD.names = { "__.POPS" }
  FAKEHDD.status = 0
  PLDR.HDD.LOADSTATE = 0
  PLDR.LoadHDDModules()
  PLDR.COLLAPSE_MULTIDISC = false
  PLDR.HDD.HAS_CHECKED = false
  PLDR.HDD.CheckAvailableHddPopsParts(nil)
  PLDR.GLOBAL_HIDE = true
  PLDR.HDD.BuildGameList(nil)
  if #PLDR.GAMES ~= 0 then return false, "expected 0 games with Global Hide on, got "..#PLDR.GAMES end
  local d = PLDR.HDD.SCAN_DIAG
  if type(d) ~= "table" then return false, "no SCAN_DIAG" end
  if (d.vcds or 0) ~= 1 then return false, "vcds should be 1, got "..tostring(d.vcds) end
  if (d.hidden or 0) ~= 1 then return false, "hidden should be 1, got "..tostring(d.hidden) end
  if (d.collapsed or 0) ~= 0 then return false, "collapsed should be 0" end
  PLDR.GLOBAL_HIDE = false
  PLDR.HDD.BuildGameList(nil)
  if #PLDR.GAMES ~= 1 then return false, "expected 1 game with Global Hide off, got "..#PLDR.GAMES end
  return true
end''')()
check("T27 EXP34 hidden-count: hidden VCD yields 0 games + SCAN_DIAG.hidden, reveals when unhidden", t27)

# T28 EXP34 config defaults: fresh settings (no sidecar override) must carry the
# maintainer's new defaults -- ART_LOCATION "art", HDD_FS "BOTH", i.Link hidden,
# and the SMB/network block (IP/gateway/DNS/server/share/user/port).
t28 = E('''function()
  PLDR.LoadSettingsNonFatal()
  if PLDR.ART_LOCATION ~= "art" then return false, "ART_LOCATION default should be 'art', got "..tostring(PLDR.ART_LOCATION) end
  if PLDR.HDD_FS ~= "BOTH" then return false, "HDD_FS default should be 'BOTH', got "..tostring(PLDR.HDD_FS) end
  local hd = string.upper(tostring(PLDR.HIDDEN_DEVICES or ""))
  if string.find(hd, "ILINK", 1, true) == nil then return false, "i.Link should be hidden by default, HIDDEN_DEVICES="..tostring(PLDR.HIDDEN_DEVICES) end
  local smb = PLDR.SmbDefaults()
  local want = { PS2_IP="192.168.1.10", GATEWAY="192.168.1.1", DNS="192.168.1.1",
                 SERVER="192.168.1.100", SHARE="games", USER="guest", PORT="1111" }
  for k, v in pairs(want) do
    if tostring(smb[k]) ~= v then return false, "SMB "..k.." should be "..v..", got "..tostring(smb[k]) end
  end
  return true
end''')()
check("T28 EXP34 config defaults: ART=art, HDD=BOTH, i.Link hidden, SMB/network block", t28)

# T29 EXP41 REGRESSION GUARD: a mass slot's identity comes from THAT SLOT's driver
# name, never from the BDM device's parId.
#
# This test replaces the EXP36 test that asserted the opposite. That test passed only
# because its fixture invented `parId = 1` for the MX4SIO device. Real ps2sdk block
# drivers hardcode parId 0x00 for every whole-disk device (ps2atad.c:361,
# usbmass_bd/scsi.c:336, IEEE1394_bd/scsi.c:354, mx4sio spi_sdcard_driver.c:56); the
# partition drivers set the MBR partition-TYPE byte (part_driver_mbr.c:126) or 0
# (part_driver_gpt.c:146). parId is NEVER an index -- so on real hardware ATA and
# MX4SIO both mapped to mass:/ and the MX4SIO page listed the ATA drive's games.
#
# The fixture below therefore uses the REAL values: both devices report parId 0. If
# anyone reintroduces a parId->slot mapping, ata_root and mx_root collide and this
# fails. The per-slot driver name is the only authority.
t29 = lua.execute(r'''
  System.initMX4SIO = function() return true end
  System.initATAAsync = function() return 2 end
  System.initATAStatus = function() return 2 end
  local real_dfe = doesFolderExist
  local real_drv = PLDR.GetMassMountDriver
  -- Both parId 0, exactly as the real drivers report them.
  System.bdmList = function()
    return {
      { name = "ata", parId = 0, devNr = 0 },
      { name = "sdc", parId = 0, devNr = 1 },
    }
  end
  doesFolderExist = function(p)
    if p == "mass:/" or p == "mass0:/" or p == "mass1:/" then return true end
    return real_dfe(p)
  end
  -- The slot itself is authoritative: slot 0 is the ATA volume (it connected
  -- first, booting from MC with the internal drive present), slot 1 is the
  -- hot-inserted SD. This is the user-reported repro.
  PLDR.GetMassMountDriver = function(root)
    if root == "mass:/" or root == "mass0:/" then return "ata" end
    if root == "mass1:/" then return "sdc" end
    return ""
  end
  local ata_root, ata_status = PLDR.GetATAMassRootNow()
  local mx_root, mx_status = PLDR.GetMX4SIOMassRootNow()
  doesFolderExist = real_dfe
  PLDR.GetMassMountDriver = real_drv
  System.bdmList = nil
  if ata_root ~= "mass:/" or ata_status ~= "ready" then
    return false, "ata: expected mass:/ ready, got "..tostring(ata_root).."/"..tostring(ata_status)
  end
  if mx_root ~= "mass1:/" or mx_status ~= "ready" then
    return false, "mx4sio: expected mass1:/ ready, got "..tostring(mx_root).."/"..tostring(mx_status)
  end
  -- The actual bug, stated directly: the two pages must never share a root.
  if mx_root == ata_root then
    return false, "MX4SIO and ATA resolved to the SAME root ("..tostring(mx_root)..") -- parId regression"
  end
  return true
''')
check("T29 EXP41 slot identity comes from the slot's driver name, not parId", t29)

# T30 EXP49: THE invariant that this whole saga turned on. The game-list cover path
# must NEVER call a blocking image load -- the probe itself was always fine (one open
# per game, same as OPL); doing it on the thread that draws is what froze the list for
# ~0.3-0.6s per title on a large shared ART/ folder over SIO2. Four fixes (EXP37, 44,
# 46, and the EXP34/35 pair before them) all attacked probe COUNT and none of them
# moved it. If anyone reintroduces a synchronous load on this path, this fails loudly.
#
# Also pins the async contract: a finished load is adopted, a MISS is memoized so it is
# never probed twice, and a result that arrives after the selection moved is DROPPED
# and freed rather than shown on the wrong game.
t30 = E('''function()
  local cc = UI.CoverCache
  if type(cc) ~= "table" then return false, "UI.CoverCache missing" end
  if type(cc.Pump) ~= "function" then return false, "CoverCache:Pump missing -- async path gone" end
  local real_load, real_free = Graphics.loadImage, Graphics.freeImage
  local real_begin, real_poll = Graphics.coverLoadBegin, Graphics.coverLoadPoll
  local sync_loads, freed = 0, 0
  local begun, done = {}, nil
  Graphics.loadImage = function(p) sync_loads = sync_loads + 1; return 1 end
  Graphics.freeImage = function(t) freed = freed + 1 end
  Graphics.coverLoadBegin = function(path, token)
    begun[#begun + 1] = { path = path, token = token }
    return true
  end
  Graphics.coverLoadPoll = function() return done and done[1] or nil, done and done[2] or nil end

  cc:Clear()
  cc:UpdateSelection("mass0:/POPS/Game.VCD")
  local loads_after_select, requested = sync_loads, #begun
  -- a cover that lands for the CURRENT selection is adopted
  done = { begun[1].token, 1234 }
  cc:Pump()
  local adopted = cc.last_img
  done = nil

  -- a MISS must be memoized: re-selecting the same game must not re-request it
  cc:Clear(); begun = {}
  cc:UpdateSelection("mass0:/POPS/Game.VCD")
  local first_req = #begun
  done = { begun[1].token, nil }
  cc:Pump()          -- miss on candidate 1
  while cc.pending ~= nil do done = { cc.pending.token, nil }; cc:Pump() end
  local reqs_after_all_missed = #begun
  cc.last_key = nil
  cc:UpdateSelection("mass0:/POPS/Game.VCD")
  local reqs_after_revisit = #begun

  -- a result arriving after the selection moved is dropped, not shown
  cc:Clear(); begun = {}; freed = 0
  cc:UpdateSelection("mass0:/POPS/Game.VCD")
  cc.last_key = "something-else-entirely"
  done = { begun[1].token, 5678 }
  cc:Pump()
  local stale_img, stale_freed = cc.last_img, freed

  Graphics.loadImage, Graphics.freeImage = real_load, real_free
  Graphics.coverLoadBegin, Graphics.coverLoadPoll = real_begin, real_poll
  cc:Clear()

  if loads_after_select ~= 0 then
    return false, "render path called a BLOCKING load "..loads_after_select.." time(s) -- the whole bug"
  end
  if requested ~= 1 then return false, "expected exactly 1 async request, got "..requested end
  if adopted ~= 1234 then return false, "finished cover not adopted, last_img="..tostring(adopted) end
  if reqs_after_revisit ~= reqs_after_all_missed then
    return false, "a known-absent cover was re-requested on revisit ("..reqs_after_all_missed.." -> "..reqs_after_revisit..")"
  end
  if stale_img ~= nil then return false, "a stale result was shown on the wrong game" end
  if stale_freed ~= 1 then return false, "a stale texture was not freed, freed="..stale_freed end
  return true
end''')()
check("T30 EXP49 cover loads are async; render path never blocks", t30)

# T35 EXP54: the FULL no-blocking-IO invariant for a list navigation. T30 pinned that
# the COVER load is async; that was not enough -- EXP53 shipped with async covers and
# the list still froze solid (screen static, scrolling text stopped) because the game
# DETAILS .txt read was still synchronous on the render thread, 1-2 slow opens per
# newly selected title into the same large ART/ folder. Four builds missed it because
# every one of them only looked at the cover loader.
#
# So assert the invariant that actually matters: selecting a game performs NO blocking
# file read at all -- no image open, no text open. Covers go to the worker; the .txt
# rides a cover that already loaded (see CoverCache:Pump), so a game with no art costs
# nothing.
t35 = E('''function()
  local cc = UI.CoverCache
  if type(cc) ~= "table" then return false, "UI.CoverCache missing" end
  local real_load, real_open = Graphics.loadImage, System.openFile
  local real_begin, real_poll = Graphics.coverLoadBegin, Graphics.coverLoadPoll
  local img_opens, txt_opens = 0, 0
  Graphics.loadImage = function(p) img_opens = img_opens + 1; return 1 end
  System.openFile = function(p, m) txt_opens = txt_opens + 1; return -1 end
  Graphics.coverLoadBegin = function(path, token) return true end
  Graphics.coverLoadPoll = function() return nil end
  local saved_details = PLDR.SHOW_DETAILS
  PLDR.SHOW_DETAILS = true          -- the setting that used to make it worse
  cc:Clear()
  cc:UpdateSelection("mass0:/POPS/GameA.VCD")
  cc.last_key = nil
  cc:UpdateSelection("mass0:/POPS/GameB.VCD")
  cc.last_key = nil
  cc:UpdateSelection("mass0:/POPS/GameC.VCD")
  PLDR.SHOW_DETAILS = saved_details
  Graphics.loadImage, System.openFile = real_load, real_open
  Graphics.coverLoadBegin, Graphics.coverLoadPoll = real_begin, real_poll
  cc:Clear()
  if img_opens ~= 0 then
    return false, "render path opened an IMAGE "..img_opens.." time(s) -- must be async"
  end
  if txt_opens ~= 0 then
    return false, "render path opened a details .txt "..txt_opens.." time(s) -- this is the EXP53 freeze"
  end
  return true
end''')()
check("T35 EXP54 selecting a game does ZERO blocking file reads", t35)

# T36 EXP55: devices resolve by the SDK's TYPED name (mx4sio0:/ ata0:/ usb0:/), not by
# a mass slot. fs_driver_resolve_volume's typed branch matches the MOUNTED device's
# bd->path, so mx4sio0: can only ever be an MX4SIO volume; the legacy "mass" branch
# returns the requested unit verbatim over indices handed out in raw connection order,
# which is why the MX4SIO page could list the ATA drive. Assert (a) the typed name is
# used when it exists, (b) the legacy mass walk is then SKIPPED entirely -- no devctl
# per slot -- and (c) it still falls back when no typed device is present, so a card on
# an older SDK is not stranded.
t36 = E('''function()
  local real_dfe, real_drv = doesFolderExist, PLDR.GetMassMountDriver
  System.initMX4SIO = function() return true end
  local devctl_calls = 0
  PLDR.GetMassMountDriver = function(root) devctl_calls = devctl_calls + 1; return "ata" end
  -- typed device present; mass slots ALSO present and backed by ATA (the bug setup)
  doesFolderExist = function(p)
    if p == "mx4sio0:/" then return true end
    if p == "mass:/" or p == "mass0:/" or p == "mass1:/" then return true end
    return false
  end
  local root, status = PLDR.GetMX4SIOMassRootNow()
  local typed_devctls = devctl_calls
  -- no typed device -> must still fall back to the legacy walk
  doesFolderExist = function(p)
    if p == "mass:/" or p == "mass0:/" then return true end
    return false
  end
  PLDR.GetMassMountDriver = function(root) devctl_calls = devctl_calls + 1; return "sdc" end
  local fb_root = PLDR.GetMX4SIOMassRootNow()
  doesFolderExist, PLDR.GetMassMountDriver = real_dfe, real_drv
  if root ~= "mx4sio0:/" then
    return false, "expected the typed device mx4sio0:/, got "..tostring(root)
  end
  if status ~= "ready" then return false, "typed device should be ready, got "..tostring(status) end
  if typed_devctls ~= 0 then
    return false, "legacy mass walk still ran ("..typed_devctls.." devctls) after a typed hit"
  end
  if fb_root ~= "mass:/" then
    return false, "fallback to the mass walk broke, got "..tostring(fb_root)
  end
  return true
end''')()
check("T36 EXP55 devices resolve by typed SDK name; mass walk is fallback only", t36)

# T37 EXP56: the cover-art layout, pinned to the maintainer's spec:
#     device:/POPS/<game>.VCD   ->   device:/ART/<game>_COV.png
# The old device-prefix pattern was `%a+%d*:` which CANNOT match a device whose NAME
# contains a digit -- mx4sio0: is exactly that. It matched mass0:, ata0: and usb0:, so
# the fault only surfaced once EXP55 began resolving devices by typed name, and only on
# MX4SIO: the prefix fell through to the whole directory and we searched
# device:/POPS/ART/ instead of device:/ART/. A correctly named, correctly placed cover
# never loaded. Pin every device name, including the one with the embedded digit.
t37 = E('''function()
  local cc = UI.CoverCache
  local real_begin, real_dfe = Graphics.coverLoadBegin, doesFolderExist
  local asked = nil
  Graphics.coverLoadBegin = function(path, token) asked = path; return true end
  doesFolderExist = function(p) return true end
  local cases = {
    { "mass0:/POPS/Soul Blade.VCD",    "mass0:/ART/Soul Blade_COV.png" },
    { "mass:/POPS/Soul Blade.VCD",     "mass:/ART/Soul Blade_COV.png" },
    { "mx4sio0:/POPS/Soul Blade.VCD",  "mx4sio0:/ART/Soul Blade_COV.png" },
    { "ata0:/POPS/Soul Blade.VCD",     "ata0:/ART/Soul Blade_COV.png" },
    { "usb0:/POPS/Soul Blade.VCD",     "usb0:/ART/Soul Blade_COV.png" },
  }
  local bad = nil
  for i = 1, #cases do
    cc:Clear()
    asked = nil
    cc:UpdateSelection(cases[i][1])
    if asked ~= cases[i][2] then
      bad = cases[i][1].." -> "..tostring(asked).." (expected "..cases[i][2]..")"
      break
    end
  end
  Graphics.coverLoadBegin, doesFolderExist = real_begin, real_dfe
  cc:Clear()
  if bad ~= nil then return false, bad end
  return true
end''')()
check("T37 EXP56 cover path is device:/ART/<game>_COV.png for every device name", t37)

# T38 EXP57: hidden state must NOT leak between scans or devices. CleanupGameList
# cleared PLDR.GAMES but left PLDR.HIDDEN standing, and every fresh scan calls through
# it before rebuilding -- so a game hidden on one device was still in the map when the
# NEXT device's list was saved, and SaveGameListCache wrote an `H` line for it into that
# device's .gamecache. sAGA found it: an H entry for a game with no .hide sidecar.
# ApplyGameListCache always reset the map; only the fresh-scan path did not.
t38 = E('''function()
  PLDR.HIDDEN = { ["usb0:/POPS/|Some Other Game.VCD"] = true }
  PLDR.GAMES = { "a", "b" }
  PLDR.CleanupGameList()
  local leaked = nil
  for k in pairs(PLDR.HIDDEN) do leaked = k break end
  if leaked ~= nil then
    return false, "hidden state survived CleanupGameList: "..tostring(leaked)
  end
  if #PLDR.GAMES ~= 0 then return false, "games not cleared" end
  return true
end''')()
check("T38 EXP57 CleanupGameList clears hidden state so it cannot leak between devices", t38)

# T31 EXP40: RESTORE LAZY. The internal-HDD visibility setting (EXFAT/BOTH) must NOT
# boot-load ATA -- it only controls which HDD pages the carousel shows. Only an
# EXPLICIT request (-page=ata / -page=exfat) warms ATA at boot; a normal MC/USB boot
# with the exFAT page merely visible goes lazy (ATA loads when the page is opened).
# EXP38 broke this by warming on EXFAT/BOTH; pin the gate so it stays explicit-only.
t31 = lua.execute(r'''
  if type(PLDR.WantExfatBootBringup) ~= "function" then
    return false, "PLDR.WantExfatBootBringup missing"
  end
  local saved_fs, saved_args = PLDR.HDD_FS, PLDR.LAUNCH_ARGS
  local function want(fs, page)
    PLDR.HDD_FS = fs
    PLDR.LAUNCH_ARGS = page and {page = page} or {}
    return PLDR.WantExfatBootBringup() == true
  end
  local cases = {
    -- fs,      page,    want,  why
    {"PFS",     nil,     false, "PFS-only: no boot warm-up"},
    {nil,       nil,     false, "missing key: no boot warm-up"},
    {"garbage", nil,     false, "unknown value: no boot warm-up"},
    {"EXFAT",   nil,     false, "EXP40: EXFAT is a VISIBILITY setting -> NO boot warm-up (lazy at page)"},
    {"BOTH",    nil,     false, "EXP40: BOTH (default) must NOT boot-load ATA -- sAGA's case, goes lazy"},
    {"both",    nil,     false, "case-insensitive: still no warm-up"},
    {"PFS",     "ATA",   true,  "-page=ata is an EXPLICIT request -> warm at boot"},
    {"BOTH",    "ATA",   true,  "-page=ata wins even under BOTH"},
    {"PFS",     "EXFAT", true,  "-page=exfat is also an explicit request"},
  }
  for _, c in ipairs(cases) do
    local got = want(c[1], c[2])
    if got ~= c[3] then
      PLDR.HDD_FS, PLDR.LAUNCH_ARGS = saved_fs, saved_args
      return false, string.format("%s: fs=%s page=%s -> %s (want %s)",
        c[4], tostring(c[1]), tostring(c[2]), tostring(got), tostring(c[3]))
    end
  end
  PLDR.HDD_FS, PLDR.LAUNCH_ARGS = saved_fs, saved_args
  return true
''')
check("T31 EXP40 boot ATA gate: explicit -page=ata/exfat warms; EXFAT/BOTH/PFS stay lazy", t31)

print()
fails = [r for r in results if not r[1]]
print(f"=== {len(results) - len(fails)}/{len(results)} PASS ===")
for name, ok, detail in fails:
    print(f"  FAIL: {name}: {detail}")
sys.exit(1 if fails else 0)
