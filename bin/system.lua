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
do
  local IRXDIR = System.listDirectory(".")
  if IRXDIR ~= nil then
    for x=1, #IRXDIR do
      if string.lower(string.sub(IRXDIR[x].name, -4)) == ".irx" then
        local ID, RET = IOP.loadModule(IRXDIR[x].name)
        LOG(IRXDIR[x].name, ID, RET)
      end
    end
  end
end
local function resolvePreferredPath(relative_path)
  local candidate = JoinPath(BOOT_PATH or System.currentDirectory(), relative_path)
  if doesFileExist(candidate) then return candidate end
  return candidate
end

ResolvePreferredPath = resolvePreferredPath

local POPS_DEVICE_ORDER = {}
local mmce_devices = {"mmce1:/POPS/", "mmce0:/POPS/"}
local mass_devices = {"mass:/POPS/", "mass0:/POPS/", "mass1:/POPS/", "mass2:/POPS/", "mass3:/POPS/"}
local mass_retry_devices = {"mass:/POPS/", "mass0:/POPS/"}

for _ = 1, 2 do
  for _, dev in ipairs(mmce_devices) do
    table.insert(POPS_DEVICE_ORDER, dev)
  end
end
for _, dev in ipairs(mass_devices) do
  table.insert(POPS_DEVICE_ORDER, dev)
end
for _, dev in ipairs(mass_retry_devices) do
  table.insert(POPS_DEVICE_ORDER, dev)
end

PLDR_LAST_POPS_DEVICE = nil

local function canOpenDir(path)
  local ok, result = pcall(System.listDirectory, path)
  return ok and type(result) == "table"
end

local POPS_ROOT = BOOT_DEVICE_ROOT and (BOOT_DEVICE_ROOT.."POPS/") or "mass0:/POPS/"
PLDR = {
  REBOOT_IOP_WHILE_LOADING_POPSTARTER = 1;
  POPSTARTER_PATH = resolvePreferredPath("POPSTARTER.ELF");
  CHECK_POPSTARTER_FILES = false;
  GAMEPATH = POPS_ROOT;
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
}

function PLDR.FindPopsRoot()
  if BOOT_DEVICE_ROOT then
    local candidate = BOOT_DEVICE_ROOT.."POPS/"
    PLDR_LAST_POPS_DEVICE = candidate
    if canOpenDir(candidate) then
      return candidate
    end
  end
  for _, root in ipairs(POPS_DEVICE_ORDER) do
    PLDR_LAST_POPS_DEVICE = root
    if canOpenDir(root) then
      return root
    end
  end
  return nil
end
if BOOTPATH ~= nil then
  PLDR.HDD.LOADSTATE = 1
  PLDR.HDD.STATUS = HDD.GetHDDStatus()
end

require("pops_profiles")
require("ui")
require("images")


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
    local root = PLDR.FindPopsRoot()
    if root == nil then
      return false, false, false
    end
    return doesFileExist(JoinPath(root, "POPS_IOX.PAK"))
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
  local C = "hdd_gamecache.lua"
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
  local C = "hdd_gamecache.lua"
  if doesFileExist(C) then
    dofile(C)
    PLDR.HDD.HAS_CHECKED = true
  end
end

function PLDR.HDD.WipeCache(CACHE)
  LOG("> HDD Cache Wipe")
  local C = "hdd_gamecache.lua"
  if doesFileExist(C) then
    System.removeFile(C)
    PLDR.HDD.HAS_CHECKED = false
  end
end

---DONT TOUCH ME
function PLDR.RunPOPStarterGame(gamelocation, game)
  local PREFIX = "" --HDD has no prefix
  if UI.CURSCENE == UI.SCENES.GUSB then PREFIX = "XX."
  elseif UI.CURSCENE == UI.SCENES.GSMB then PREFIX = "SB." end
  local BOOTPARAM = PLDR.replace_device(gamelocation, "isra")..PREFIX..PLDR.replace_extension(game, "ELF")
  LOG("Loading", PLDR.POPSTARTER_PATH, BOOTPARAM)
  System.loadELF(PLDR.POPSTARTER_PATH,
    PLDR.REBOOT_IOP_WHILE_LOADING_POPSTARTER,
    BOOTPARAM, "--nr")
    LOG(">>> UNHANDLED ERROR at Launching game '", game, " via ", PLDR.POPSTARTER_PATH, " Failed")
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
if Touch(".pldrs") then
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
