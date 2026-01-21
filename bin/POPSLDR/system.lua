--[[
  ___  ___  ___  ___ _                 _         
 | _ \/ _ \| _ \/ __| |   ___  __ _ __| |___ _ _ 
 |  _/ (_) |  _/\__ \ |__/ _ \/ _` / _` / -_) '_|
 |_|  \___/|_|  |___/____\___/\__,_\__,_\___|_|  
                                                 

  POPSLoader Main script. dont touch unless you know what youre doing
  to do cosmetic changes, please check the `ui.lua` and `images.lua` files
  to add custom popstarter profiles check `pops_profiles.lua`

  Licensed under GNU General public license v3.0
--]]
LOG(System.currentDirectory())
local APP_DIR_LOCAL = APP_DIR or System.currentDirectory()
if string.sub(APP_DIR_LOCAL, -1) ~= "/" then APP_DIR_LOCAL = APP_DIR_LOCAL.."/" end

local function ResolveAsset(rel)
  return System.resolveAsset(rel) or (APP_DIR_LOCAL..rel)
end

local function ResolveWritablePath(rel)
  local legacy = APP_DIR_LOCAL.."POPSLDR/"..rel
  local modern = APP_DIR_LOCAL..rel
  if doesFileExist(legacy) or doesFolderExist(APP_DIR_LOCAL.."POPSLDR/") then
    return legacy
  end
  return modern
end

local function IsAbsoluteDevicePath(path)
  return path ~= nil and string.match(path, "^[%a]+%d*:/") ~= nil
end

local function ResolvePopstarterPath(path)
  local fallback = "mass:/POPS/POPSTARTER.ELF"
  local chosen = path
  if chosen == nil or chosen == "" then
    chosen = APP_DIR_LOCAL.."POPSTARTER.ELF"
  elseif not IsAbsoluteDevicePath(chosen) then
    chosen = APP_DIR_LOCAL..chosen
  end
  if doesFileExist(chosen) then
    return chosen
  end
  if chosen ~= fallback and doesFileExist(fallback) then
    return fallback
  end
  return chosen
end

local function ResolveIrx(name)
  return System.resolveAssetType(name, ASSET_IRX) or (APP_DIR_LOCAL..name)
end

local function LoadIrxFromDir(dir)
  if not doesFolderExist(dir) then return false end
  local IRXDIR = System.listDirectory(dir)
  if IRXDIR == nil then return false end
  local loaded = false
  for x=1, #IRXDIR do
    local entry = IRXDIR[x]
    if entry ~= nil and not entry.directory then
      local name = entry.name
      if name ~= nil and string.lower(string.sub(name, -4)) == ".irx" then
        local PATH = ResolveIrx(name) or (dir..name)
        local ID, RET = IOP.loadModule(PATH)
        LOG(PATH, ID, RET)
        loaded = true
      end
    end
  end
  return loaded
end

local loadedIrx = LoadIrxFromDir(APP_DIR_LOCAL)
if not loadedIrx then
  loadedIrx = LoadIrxFromDir(APP_DIR_LOCAL.."IRX/")
end
if not loadedIrx then
  LoadIrxFromDir(APP_DIR_LOCAL.."POPSLDR/IRX/")
end
PLDR = {
  REBOOT_IOP_WHILE_LOADING_POPSTARTER = 0;
  POPSTARTER_PATH = "mass:/POPS/POPSTARTER.ELF";--"mass:/POPS/POPSTARTER.ELF";
  CHECK_POPSTARTER_FILES = false;
  GAMEPATH = ".";
  GAMES = {};
  HDDCACHE = nil;
  PROFILES = {};
  HDD = {
    USECACHE = false;
    LOADSTATE = 0; -- 0:NOT_LOADED, 1:LOADED, -1:LOADED_BUT_FAILED
    EXTRAPARTS = {false, false, false, false, false, false, false, false, false};
    MAINPART = false;
    FOUNDANY = false;
    HAS_CHECKED = false;
    HAS_CHECKED_DEPS = false;
    STATUS = 3
  };
  USB = {
    MASSINDX = 0
  },
  MMCE = {
    PROBED = false,
    PREFIX = nil,
    SLOTS = {},
    INDEX = 1
  }
}
if BOOTPATH ~= nil then
  PLDR.HDD.LOADSTATE = 1
  PLDR.HDD.STATUS = HDD.GetHDDStatus()
end

if MMCE_SLOT0_READY ~= nil and MMCE_SLOT0_READY >= 0 then
  PLDR.MMCE.PROBED = true
  PLDR.MMCE.SLOTS = {}
  PLDR.MMCE.INDEX = 1
  if MMCE_SLOT0_READY == 1 then
    table.insert(PLDR.MMCE.SLOTS, "mmce0:/")
  end
  if MMCE_SLOT1_READY == 1 then
    table.insert(PLDR.MMCE.SLOTS, "mmce1:/")
  end
  if #PLDR.MMCE.SLOTS > 0 then
    PLDR.MMCE.PREFIX = PLDR.MMCE.SLOTS[PLDR.MMCE.INDEX]
    LOG("MMCE slot selected: "..PLDR.MMCE.PREFIX)
  else
    LOG("MMCE not found")
  end
end

require("pops_profiles")
require("ui")
require("images")

function PLDR.DetectMMCESlot()
  if PLDR.MMCE.PROBED then
    return PLDR.MMCE.PREFIX
  end
  PLDR.MMCE.PROBED = true
  PLDR.MMCE.SLOTS = {}
  PLDR.MMCE.INDEX = 1
  local candidates = {"mmce0:/", "mmce1:/"}
  for i = 1, #candidates do
    local candidate = candidates[i]
    if doesFolderExist(candidate) then
      table.insert(PLDR.MMCE.SLOTS, candidate)
    end
  end
  if #PLDR.MMCE.SLOTS > 0 then
    PLDR.MMCE.PREFIX = PLDR.MMCE.SLOTS[PLDR.MMCE.INDEX]
    LOG("MMCE slot selected: "..PLDR.MMCE.PREFIX)
    return PLDR.MMCE.PREFIX
  end
  LOG("MMCE not found")
  return nil
end

function PLDR.GetMMCESlots()
  if not PLDR.MMCE.PROBED then
    PLDR.DetectMMCESlot()
  end
  return PLDR.MMCE.SLOTS
end

function PLDR.SetMMCESlot(index)
  local slots = PLDR.GetMMCESlots()
  if #slots < 1 then
    return nil
  end
  if index < 1 then index = #slots end
  if index > #slots then index = 1 end
  PLDR.MMCE.INDEX = index
  PLDR.MMCE.PREFIX = slots[index]
  LOG("MMCE slot selected: "..PLDR.MMCE.PREFIX)
  return PLDR.MMCE.PREFIX
end


function CLAMP(a, MIN, MAX)
  if a < MIN then return MIN end
  if a > MAX then return MAX end
  return a
end

function CYCLE_CLAMP(a, MIN, MAX)
  if a < MIN then return MAX end
  if a > MAX then return MIN end
  return a
end

function Font.ftPrintMultiLineAligned(font, x, y, spacing, width, height, text, color)
  local internal_y = y
  local COL = 128
  if type(color) == "number" then COL = color end
  for line in text:gmatch("([^\n]*)\n?") do
    Font.ftPrint(font, x, internal_y, 8, width, height, line, COL)
    internal_y = internal_y+spacing
  end
end

function PLDR.CheckPOPStarterDEPS(device)
  if not PLDR.CHECK_POPSTARTER_FILES then return true, true, true end
  if device == UI.SCENES.GUSB then
    return doesFileExist("mass:/POPS/POPS_IOX.PAK")
  elseif device == UI.SCENES.GHDD then
    local a = HDD.MountPartition("hdd0:__common", 1, FIO_MT_RDONLY)
    if a then
      return a, doesFileExist("pfs1:/POPS/POPS.ELF"), doesFileExist("pfs1:/POPS/IOPRP252.IMG")
    else
      return a, false, false
    end
  end
end

function PLDR.GetPS1GameLists(path, updating)
  LOG("Listing games on ", path)
  local RET = {}
  local found_smth = false
  if path ~= nil then PLDR.GAMEPATH = path end
  local DIR = System.listDirectory(PLDR.GAMEPATH)
  if DIR ~= nil then
    for i = 1, #DIR do
      if not DIR[i].directory then -- not a folder
        if string.lower(string.sub(DIR[i].name,-4)) == ".vcd" then
          LOG(" Found", DIR[i].name)
          found_smth = true
          if updating then
            table.insert(PLDR.GAMES, DIR[i].name)
          else
            table.insert(RET, DIR[i].name)
          end
        end
      end
    end
  else
    LOG("cannot opendir")
  end
  if found_smth then
    if not updating then
      PLDR.GAMES = RET
    end
    table.sort(PLDR.GAMES)
    return PLDR.GAMES
  else
    return nil
  end
end

---DONT TOUCH ME
function PLDR.GetVCDGameID(path)
  local RET = "ERR"
  local fd = System.openFile(path, FREAD)
  if System.sizeFile(fd) < 0x10d900 then
    LOG("ERROR: VCD Size is not big enough to pull ID")
  else
    System.seekFile(fd, 0x10c900, SET)
    local buffer = System.readFile(fd, 4096)
    RET = string.match(buffer, "[A-Z][A-Z][A-Z][A-Z][_-][0-9][0-9][0-9].[0-9][0-9]")
  end
  System.closeFile(fd)
  return RET
end

function PLDR.replace_device(VAL, NEWDEV)
  local FINAL
  local niee = string.find(VAL, ":", 1, true)
  FINAL = NEWDEV..VAL:sub(niee)
    return FINAL
end

function PLDR.replace_extension(VAL, NEWEXT)
  local FINAL = string.sub(VAL,1,-4)
  FINAL = FINAL..NEWEXT
  return FINAL 
end

function PLDR.HDD.CheckAvailableHddPopsParts()
  if not PLDR.HDD.HAS_CHECKED then --HDD is checked only once since it cannot be removed/replaced without damaging the console
    LOG("Checking available __.POPS Partitions")
    if HDD.MountPartition("hdd0:__.POPS", 1, FIO_MT_RDONLY) then
      PLDR.HDD.MAINPART = true
      HDD.UMountPartition(1)
    end
    LOG("__.POPS", PLDR.HDD.MAINPART)
    PLDR.HDD.FOUNDANY = PLDR.HDD.MAINPART
    for i=1, 9 do
      if HDD.MountPartition(("hdd0:__.POPS%d"):format(i), 1, FIO_MT_RDONLY) then
        PLDR.HDD.EXTRAPARTS[i] = true
        PLDR.HDD.FOUNDANY = true
        HDD.UMountPartition(1)
      end
      LOG("__.POPS"..i, PLDR.HDD.EXTRAPARTS[i])
    end
    PLDR.HDD.HAS_CHECKED = true
  end
end

function PLDR.HDD.BuildGameList()
  PLDR.GAMES = {}
  if type(PLDR.HDDCACHE) == "table" and PLDR.HDD.USECACHE then PLDR.GAMES = PLDR.HDDCACHE end
  if not PLDR.HDD.FOUNDANY then return end
  if PLDR.HDD.MAINPART then
    if HDD.MountPartition("hdd0:__.POPS", 1, FIO_MT_RDONLY) then
      PLDR.GetPS1GameLists("pfs1:/", true)
      HDD.UMountPartition(1)
    end
  end
  for i=1, 9 do
    if PLDR.HDD.EXTRAPARTS[i] then
      if HDD.MountPartition("hdd0:__.POPS"..i, 1, FIO_MT_RDONLY) then
        PLDR.GetPS1GameLists("pfs1:/", true)
        HDD.UMountPartition(1)
      end
    end
  end
end

function PLDR.LoadHDDModules()
  local ID, RET, SUCCESS, MODULE
  if PLDR.HDD.LOADSTATE == 0 then
    SUCCESS, MODULE, ID, RET = HDD.Initialize()
    if not SUCCESS then
      PLDR.HDD.LOADSTATE = -1
      UI.Notif_queue.add(string.format("failed to load %s.IRX\nid:%d, ret:%d", MODULE, ID, RET))
      return
    end
    SUCCESS = HDD.GetHDDStatus()
    PLDR.HDD.STATUS = SUCCESS
    if SUCCESS ~= 0 then
      PLDR.HDD.LOADSTATE = -1
      if SUCCESS == 1 then
        UI.Notif_queue.add(string.format("WARNING: HDD has no APA format", MODULE, ID, RET))
      elseif SUCCESS == 2 then
        UI.Notif_queue.add(string.format("ERROR: HDD is not accessible", MODULE, ID, RET))
      elseif SUCCESS == 3 then
        UI.Notif_queue.add(string.format("WARNING: No HDD detected", MODULE, ID, RET))
      elseif SUCCESS == -19 then
        UI.Notif_queue.add(string.format("ERROR: Hardware issue detected\nCheck your HDD, network adapter and connection", MODULE, ID, RET))
      end
    end
    PLDR.HDD.LOADSTATE = 1
    PLDR.HDD.CheckAvailableHddPopsParts()
    PLDR.HDD.CreateCache()
  end
end

function PLDR.CleanupGameList()
  LOG("gamelist cleanup")
  local count = #PLDR.GAMES
  for i=0, count do PLDR.GAMES[i]=nil end
end

function PLDR.HDD.CreateCache()
  if not PLDR.HDD.USECACHE then return end
  LOG("> HDD Cache Create")
  local C = ResolveWritablePath("hdd_gamecache.lua")
  local temp = "LOG(\">HDD CACHE LOAD\")\nPLDR.HDDCACHE = {\n"
  PLDR.HDD.BuildGameList()
  for i = 1, #PLDR.GAMES do
    temp = temp..("  \"%s\",\n"):format(PLDR.GAMES[i])
  end
  temp = temp.."\n}\n"
  local fd = System.openFile(C, FCREATE)
  System.writeFile(fd, temp, temp:len())
  System.closeFile(fd)
  PLDR.HDD.HAS_CHECKED = true
end

function PLDR.HDD.ReadCache()
  LOG("> HDD Cache Read")
  local C = ResolveWritablePath("hdd_gamecache.lua")
  if doesFileExist(C) then
    dofile(C)
    PLDR.HDD.HAS_CHECKED = true
  end
end

function PLDR.HDD.WipeCache(CACHE)
  LOG("> HDD Cache Wipe")
  local C = ResolveWritablePath("hdd_gamecache.lua")
  if doesFileExist(C) then
    System.removeFile(C)
    PLDR.HDD.HAS_CHECKED = false
  end
end

---DONT TOUCH ME
local function BuildXXUsageArgs(gamelocation, game, source_mode)
  -- XX usage: PopStarter expects an XX.-prefixed ELF name for USB-style launches.
  -- USB (mass:/...) and MMCE (mmce0:/...) share this format; only the source mode changes.
  return PLDR.replace_device(gamelocation, source_mode).."XX."..PLDR.replace_extension(game, "ELF")
end

local function GetLaunchSourceMode(gamelocation)
  -- Mode/source should reflect the actual device for PopStarter.
  -- USB/mass uses "isra", MMCE uses its device string (mmce0), SMB should use its own mode if enabled.
  local device = string.match(gamelocation, "^(.-):")
  if device ~= nil and string.match(device, "^mmce") then
    return device
  end
  return "isra"
end

local function TranslateMMCEPathForPopStarter(gamelocation)
  return string.gsub(gamelocation, "^mmce%d:/", "mass:/")
end

function PLDR.RunPOPStarterGame(gamelocation, game)
  local is_mmce = string.match(gamelocation, "^mmce") ~= nil
  local source_mode = GetLaunchSourceMode(gamelocation)
  if is_mmce then
    source_mode = "isra"
  end
  local handoff_gamelocation = gamelocation
  if is_mmce then
    handoff_gamelocation = TranslateMMCEPathForPopStarter(gamelocation)
  end
  local vcd_path = gamelocation..game
  local popstarter = ResolvePopstarterPath(PLDR.POPSTARTER_PATH)

  local BOOTPARAM
  if UI.CURSCENE == UI.SCENES.GSMB and not is_mmce then
    -- SMB uses a distinct SB usage format when enabled.
    BOOTPARAM = PLDR.replace_device(handoff_gamelocation, source_mode).."SB."..PLDR.replace_extension(game, "ELF")
  else
    BOOTPARAM = BuildXXUsageArgs(handoff_gamelocation, game, source_mode)
  end

  LOG("Boot APP_DIR: "..APP_DIR_LOCAL)
  LOG("PopStarter selected: "..popstarter)
  LOG("PopStarter:", popstarter, "VCD:", vcd_path, "mode:", source_mode, "argv_count:", 2, "args:", BOOTPARAM, "--nr")
  local device_page = "unknown"
  if string.match(gamelocation, "^mass") then
    device_page = "USB"
  elseif string.match(gamelocation, "^mmce") then
    device_page = "MMCE"
  elseif string.match(gamelocation, "^pfs") then
    device_page = "HDD"
  elseif UI and UI.CURSCENE then
    if UI.CURSCENE == UI.SCENES.GUSB then
      device_page = "USB"
    elseif UI.CURSCENE == UI.SCENES.GSMB then
      device_page = "SMB/MMCE"
    elseif UI.CURSCENE == UI.SCENES.GHDD then
      device_page = "HDD"
    end
  end
  LOG("PopStarter handoff device page:", device_page, "UI scene:", UI and UI.CURSCENE or "unknown")
  LOG("PopStarter handoff source mode:", source_mode)
  LOG("PopStarter handoff path:", popstarter)
  LOG("PopStarter handoff game path (raw):", gamelocation, "translated:", handoff_gamelocation, "game:", game, "vcd_path:", vcd_path)
  LOG("PopStarter argv[0]:", BOOTPARAM)
  LOG("PopStarter argv[1]:", "--nr")
  UI.LAUNCHING = true
  System.loadELF(popstarter,
    PLDR.REBOOT_IOP_WHILE_LOADING_POPSTARTER,
    BOOTPARAM, "--nr")
    LOG(">>> UNHANDLED ERROR at Launching game '", game, " via ", popstarter, " Failed")
  error("ERROR: ELF loading failure")
end

function Touch(FILE)
  if not doesFileExist(FILE) then
    local FD = System.openFile(FILE, FCREATE)
    System.closeFile(FD)
    return true
  else
    return false
  end
end

---MAIN PROGRAM BEHAVIOUR BEGINS
UI.WelcomeDraw.Play()
if Touch(ResolveWritablePath(".pldrs")) then
  UI.CURSCENE = UI.SCENES.CREDITS
end

while true do
  UI.BottomDraw.Play()
  if UI.CURSCENE == UI.SCENES.MMAIN then
    UI.MainMenu.Play()
  elseif UI.CURSCENE == UI.SCENES.MPROFILE then
    UI.ProfileQuery.Play()
  elseif UI.CURSCENE <= UI.SCENES.GHDD then
    UI.GameList.Play()
  elseif UI.CURSCENE == UI.SCENES.CREDITS then
    UI.Credits.Play()
  end
  UI.flip()
end
