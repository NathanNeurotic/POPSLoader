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
local BOOT_PATH_RAW = System.currentDirectory()
LOG("BOOT_PATH_RAW="..tostring(BOOT_PATH_RAW))
local function EnsureTrailingSlash(path)
  if path == nil then
    return nil
  end
  if string.sub(path, -1) == "/" then
    return path
  end
  return path.."/"
end
_G.EnsureTrailingSlash = EnsureTrailingSlash
LOG("EnsureTrailingSlash loaded from system.lua")
local function NormalizeDeviceRoot(path)
  if path == nil or path == "" then return path end
  if string.match(path, "^host:/") then
    return path
  end
  local device = string.match(path, "^([%a]+%d*):/?$")
  if device ~= nil then
    return device..":/"
  end
  return path
end

local function NormalizeHostPath(path)
  if path == nil or path == "" then return path end
  if not string.match(path, "^host:") then
    return path
  end
  local rest = string.sub(path, 6)
  if string.sub(rest, 1, 1) == "/" then
    rest = string.sub(rest, 2)
  end
  rest = string.gsub(rest, "\\", "/")
  if string.match(rest, "^[%a]:[^/]") then
    rest = string.sub(rest, 1, 2).."/"..string.sub(rest, 3)
  end
  return "host:/"..rest
end

function NormalizeDirPath(path)
  if path == nil or path == "" then return "" end
  local normalized = string.gsub(path, "\\", "/")
  normalized = NormalizeHostPath(NormalizeDeviceRoot(normalized))
  normalized = string.gsub(normalized, "/+$", "/")
  if string.sub(normalized, -1) ~= "/" then
    normalized = normalized.."/"
  end
  return normalized
end

function JoinPath(base, rel)
  local normalized = NormalizeDirPath(base)
  if rel == nil or rel == "" then
    return normalized
  end
  local cleaned = string.gsub(rel, "^/+", "")
  return normalized..cleaned
end

local APP_DIR_LOCAL = NormalizeDirPath(APP_DIR or BOOT_PATH_RAW)
LOG("APP_DIR_NORM="..APP_DIR_LOCAL)
LOG("APP_DIR_POPSTARTER_JOIN="..JoinPath(APP_DIR_LOCAL, "POPSTARTER.ELF"))
local SELECTOR_MODE = "basename"

local function ResolveAsset(rel)
  return System.resolveAsset(rel) or JoinPath(APP_DIR_LOCAL, rel)
end

local function ResolveWritablePath(rel)
  local legacy_root = JoinPath(APP_DIR_LOCAL, "POPSLDR")
  local legacy = JoinPath(legacy_root, rel)
  local modern = JoinPath(APP_DIR_LOCAL, rel)
  if doesFileExist(legacy) or doesFolderExist(legacy_root) then
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
    chosen = JoinPath(APP_DIR_LOCAL, "POPSTARTER.ELF")
  elseif not IsAbsoluteDevicePath(chosen) then
    chosen = JoinPath(APP_DIR_LOCAL, chosen)
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
  return System.resolveAssetType(name, ASSET_IRX) or JoinPath(APP_DIR_LOCAL, name)
end

local function LoadIrxFromDir(dir)
  local normalized = NormalizeDirPath(dir)
  if not doesFolderExist(normalized) then return false end
  local IRXDIR = System.listDirectory(normalized)
  if IRXDIR == nil then return false end
  local loaded = false
  for x=1, #IRXDIR do
    local entry = IRXDIR[x]
    if entry ~= nil and not entry.directory then
      local name = entry.name
      if name ~= nil and string.lower(string.sub(name, -4)) == ".irx" then
        local PATH = ResolveIrx(name) or JoinPath(normalized, name)
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
  loadedIrx = LoadIrxFromDir(JoinPath(APP_DIR_LOCAL, "IRX"))
end
if not loadedIrx then
  LoadIrxFromDir(JoinPath(APP_DIR_LOCAL, "POPSLDR/IRX"))
end
HDD_DIAG_BYPASS = 1
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
    STATUS = 3,
    GAMEPARTS = {}
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
local ok_ui, ui_or_err = pcall(require, "ui")
if not ok_ui then
  LOG("UI load failed")
  LOG("APP_DIR:", APP_DIR_LOCAL)
  LOG("Boot cwd:", System.currentDirectory())
  LOG("package.path:", package.path)
  error("UI module failed to load: "..tostring(ui_or_err))
end
if ui_or_err ~= nil and ui_or_err ~= true then
  UI = ui_or_err
end
if UI == nil then
  LOG("UI global is nil after require('ui')")
  LOG("APP_DIR:", APP_DIR_LOCAL)
  LOG("Boot cwd:", System.currentDirectory())
  LOG("package.path:", package.path)
  error("UI global not initialized (module returned nil or did not set UI)")
end
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
    local a = HDD.MountPartition("hdd0:__common", 0, FIO_MT_RDONLY)
    if a then
      return a, doesFileExist("pfs0:/POPS/POPS.ELF"), doesFileExist("pfs0:/POPS/IOPRP252.IMG")
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
    if HDD.MountPartition("hdd0:__.POPS", 0, FIO_MT_RDONLY) then
      PLDR.HDD.MAINPART = true
      HDD.UMountPartition(0)
    end
    LOG("__.POPS", PLDR.HDD.MAINPART)
    PLDR.HDD.FOUNDANY = PLDR.HDD.MAINPART
    for i=1, 9 do
      if HDD.MountPartition(("hdd0:__.POPS%d"):format(i), 0, FIO_MT_RDONLY) then
        PLDR.HDD.EXTRAPARTS[i] = true
        PLDR.HDD.FOUNDANY = true
        HDD.UMountPartition(0)
      end
      LOG("__.POPS"..i, PLDR.HDD.EXTRAPARTS[i])
    end
    PLDR.HDD.HAS_CHECKED = true
  end
end

function PLDR.HDD.BuildGameList()
  PLDR.GAMES = {}
  if type(PLDR.HDDCACHE) == "table" and PLDR.HDD.USECACHE then PLDR.GAMES = PLDR.HDDCACHE end
  PLDR.HDD.GAMEPARTS = {}
  if not PLDR.HDD.FOUNDANY then return end
  if PLDR.HDD.MAINPART then
    if HDD.MountPartition("hdd0:__.POPS", 0, FIO_MT_RDONLY) then
      local start_index = #PLDR.GAMES
      PLDR.GetPS1GameLists("pfs0:/", true)
      for i = start_index + 1, #PLDR.GAMES do
        PLDR.HDD.GAMEPARTS[PLDR.GAMES[i]] = "hdd0:__.POPS"
      end
      HDD.UMountPartition(0)
    end
  end
  for i=1, 9 do
    if PLDR.HDD.EXTRAPARTS[i] then
      if HDD.MountPartition("hdd0:__.POPS"..i, 0, FIO_MT_RDONLY) then
        local start_index = #PLDR.GAMES
        local partition = "hdd0:__.POPS"..i
        PLDR.GetPS1GameLists("pfs0:/", true)
        for j = start_index + 1, #PLDR.GAMES do
          PLDR.HDD.GAMEPARTS[PLDR.GAMES[j]] = partition
        end
        HDD.UMountPartition(0)
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
    temp = temp..("  %q,\n"):format(PLDR.GAMES[i])
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
    local loader, load_err = loadfile(C)
    if loader == nil then
      LOG("HDD cache load failed:", load_err)
      System.removeFile(C)
      PLDR.HDD.HAS_CHECKED = false
      return
    end
    local ok, run_err = pcall(loader)
    if not ok then
      LOG("HDD cache run failed:", run_err)
      System.removeFile(C)
      PLDR.HDD.HAS_CHECKED = false
      return
    end
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

local function NormalizeBootBasename(basename, desired_prefix)
  if basename == nil or basename == "" then
    return ""
  end
  local cleaned = basename
  if desired_prefix ~= nil and desired_prefix ~= "" then
    if string.upper(string.sub(cleaned, 1, #desired_prefix)) ~= string.upper(desired_prefix) then
      cleaned = desired_prefix..cleaned
    end
  end
  return cleaned
end

local function ExtractVcdFilename(path)
  if path == nil or path == "" then
    return ""
  end
  local basename = string.match(path, "([^/]+)$") or path
  local without_device = string.match(basename, "^[%a]+%d*:(.+)$")
  if without_device ~= nil and without_device ~= "" then
    return without_device
  end
  return basename
end

local function StripVcdExtension(filename)
  if filename == nil or filename == "" then
    return ""
  end
  local without_ext = string.gsub(filename, "%.[Vv][Cc][Dd]$", "")
  return without_ext
end

local function SanitizeGameName(name)
  if name == nil or name == "" then
    return ""
  end
  local sanitized = string.gsub(name, "[%z\1-\31]", "")
  sanitized = string.gsub(sanitized, "\"", "")
  sanitized = string.gsub(sanitized, "%s+", " ")
  sanitized = string.gsub(sanitized, "%s+$", "")
  return sanitized
end

local function BuildPopstarterSelector(prefix, vcd_filename)
  if vcd_filename == nil or vcd_filename == "" then
    return ""
  end
  if prefix == nil then
    prefix = ""
  end
  return prefix..vcd_filename..".ELF"
end

local function SelectPopstarterSelectorPrefix(device_page)
  if device_page == "USB" or device_page == "MMCE" or device_page == "SMB/MMCE" then
    return "XX."
  end
  if device_page == "HDD" then
    return ""
  end
  return "XX."
end

local function BuildPopstarterSelectorPath(device_page, game_name)
  if game_name == nil or game_name == "" then
    return ""
  end
  if device_page == "HDD" then
    return "hdd0:__.POPS/"..game_name..".ELF"
  end
  if device_page == "USB" or device_page == "MMCE" or device_page == "SMB/MMCE" then
    return "mass:/POPS/XX."..game_name..".ELF"
  end
  return game_name..".ELF"
end

local function DeriveGameNameFromSelection(raw_selection)
  local vcd_filename = ExtractVcdFilename(raw_selection or "")
  return SanitizeGameName(StripVcdExtension(vcd_filename))
end

local function HasBootPrefix(basename, desired_prefix)
  if basename == nil or basename == "" or desired_prefix == nil or desired_prefix == "" then
    return false
  end
  return string.upper(string.sub(basename, 1, #desired_prefix)) == string.upper(desired_prefix)
end

local function BuildPopstarterBootString(source_mode, pops_root, basename)
  local prefix = ""
  if source_mode == "pfs" then
    prefix = ""
  elseif source_mode == "smb" then
    prefix = "SB."
  else
    prefix = "XX."
  end
  if pops_root == nil then
    pops_root = ""
  end
  local normalized_root = EnsureTrailingSlash(pops_root)
  local normalized_basename = NormalizeBootBasename(basename, prefix)
  local prefix_added = normalized_basename ~= basename
  return normalized_root..normalized_basename, prefix, normalized_basename, prefix_added
end

local function GetDevicePrefix(path)
  if path == nil then
    return nil
  end
  return string.match(path, "^([%a]+%d*):")
end

local function NormalizeIsraPath(path, device_prefix)
  if path == nil then
    return path
  end
  if string.match(path, "^isra:") then
    return device_prefix..":/"..string.sub(path, 6)
  end
  return path
end

local function TranslateMMCEPathForPopStarter(path)
  if path == nil then
    return path
  end
  return string.gsub(path, "^mmce%d:/", "mass:/")
end

local function BuildLaunchPolicy(name, mode, isra_prefix, handoff_transform)
  return {
    name = name,
    mode = mode,
    isra_prefix = isra_prefix,
    normalize = function (path)
      return NormalizeIsraPath(path, isra_prefix)
    end,
    handoff = function (path)
      local normalized = NormalizeIsraPath(path, isra_prefix)
      if handoff_transform ~= nil then
        return handoff_transform(normalized)
      end
      return normalized
    end
  }
end

local function EnsureHDDReadyForLaunch(game)
  local result = {
    init_ok = false,
    status = nil,
    mount_partition = nil,
    mount_ok = nil
  }
  PLDR.LoadHDDModules()
  result.status = PLDR.HDD.STATUS
  result.init_ok = PLDR.HDD.LOADSTATE == 1
  if not result.init_ok or result.status ~= 0 then
    return result
  end
  local partition = PLDR.HDD.GAMEPARTS[game] or "hdd0:__.POPS"
  result.mount_partition = partition
  result.mount_ok = HDD.MountPartition(partition, 0, FIO_MT_RDONLY)
  return result
end

local function LogPopstarterArgs(args)
  if args == nil then
    LaunchLog("LAUNCH: argv: nil")
    return
  end
  LaunchLog("LAUNCH: argv_count:", #args)
  for i = 1, #args do
    LaunchLog("LAUNCH: argv["..(i - 1).."]:", args[i])
  end
end

local function AppendLaunchLog(line)
  local path = ResolveWritablePath("launch.log")
  local fd
  local ok, rc = pcall(System.openFile, path, FRDWR)
  if ok then
    fd = rc
    System.seekFile(fd, 0, END)
  else
    ok, rc = pcall(System.openFile, path, FCREATE)
    if ok then
      fd = rc
    end
  end
  if fd ~= nil then
    System.writeFile(fd, line, #line)
    System.closeFile(fd)
  end
end

function LaunchLog(...)
  LOG(...)
  local parts = {...}
  for i = 1, #parts do
    parts[i] = tostring(parts[i])
  end
  local line = table.concat(parts, " ").."\n"
  AppendLaunchLog(line)
end

local LaunchState = {
  PHASE_VALIDATE = "LAUNCH_VALIDATE",
  PHASE_FADEOUT = "LAUNCH_FADEOUT",
  PHASE_EXEC = "LAUNCH_EXEC",
  PHASE_FAILED = "LAUNCH_FAILED",
  phase = "IDLE",
  watchdog_ms = 3000,
  fade_timer = nil,
  fade_start = 0
}

local function SetLaunchPhase(phase)
  LaunchState.phase = phase
  LaunchLog("LAUNCH: phase:", phase)
end

local function HostAltPath(path)
  if path == nil then
    return nil
  end
  if string.match(path, "^host:/") then
    return "host:"..string.sub(path, 7)
  end
  return nil
end

local function TryOpenForLaunch(path)
  local ok, fd_or_err = pcall(System.openFile, path, FREAD)
  if not ok or type(fd_or_err) ~= "number" or fd_or_err < 0 then
    local alt = HostAltPath(path)
    if alt ~= nil then
      local alt_ok, alt_fd = pcall(System.openFile, alt, FREAD)
      if alt_ok and type(alt_fd) == "number" and alt_fd >= 0 then
        local size = System.sizeFile(alt_fd)
        System.closeFile(alt_fd)
        if type(size) ~= "number" or size < 0 then
          return false, size, "stat", "sizeFile", alt
        end
        return true, size, "stat", "open(host_alt)", alt
      end
    end
    return false, fd_or_err, "open", "open", path
  end
  local size = System.sizeFile(fd_or_err)
  System.closeFile(fd_or_err)
  if type(size) ~= "number" or size < 0 then
    return false, size, "stat", "sizeFile", path
  end
  return true, size, "stat", "open", path
end

local function BlockLaunchFailure(rc, popstarter, device_page, argv0, game_path, app_dir, open_rc, open_api)
  SetLaunchPhase(LaunchState.PHASE_FAILED)
  UI.LAUNCHING = false
  local body = string.format(
    "LAUNCH RETURNED\nrc=%s\nDevice: %s\nPOPSTARTER: %s\nOpen/stat rc: %s\nOpen API: %s\nAPP_DIR: %s\nargv[0]: %s\nGame arg: %s\nPress X/O to continue.",
    tostring(rc),
    tostring(device_page),
    tostring(popstarter),
    tostring(open_rc),
    tostring(open_api),
    tostring(app_dir),
    tostring(argv0),
    tostring(game_path)
  )
  while true do
    UI.BottomDraw.Play()
    Font.ftPrintMultiLineAligned(LFONT, UI.SCR.X_MID, 120, 20, UI.SCR.X, UI.SCR.Y, "LAUNCH FAILED", UI.CCOL.YELLOW)
    Font.ftPrintMultiLineAligned(BFONT, UI.SCR.X_MID, 170, 18, UI.SCR.X, UI.SCR.Y, body, UI.CCOL.GREY)
    Input_GetEvent()
    if UI.Pad.Events.CONFIRM or UI.Pad.Events.BACK or UI.Pad.Events.EXIT then
      break
    end
    UI.flip()
  end
  UI.SceneChange(UI.SCENES.MMAIN)
end

local function LaunchEngine(popstarter, argv, reboot_iop, context)
  local app_dir = EnsureTrailingSlash(APP_DIR_LOCAL)
  local boot_path = EnsureTrailingSlash(System.currentDirectory())
  local argv0 = argv and argv[1] or nil
  local unpack_fn = table.unpack or unpack
  SetLaunchPhase(LaunchState.PHASE_VALIDATE)
  LaunchLog("LAUNCH BEGIN")
  LaunchLog("LAUNCH: boot path raw:", BOOT_PATH_RAW, "boot path cwd:", boot_path)
  LaunchLog("LAUNCH: app dir normalized:", app_dir, "APP_DIR join POPSTARTER:", JoinPath(app_dir, "POPSTARTER.ELF"))
  LaunchLog("LAUNCH: reboot_iop flag:", reboot_iop)
  LaunchLog("LAUNCH: exec =", popstarter)
  LaunchLog("LAUNCH: argv0 selector =", argv0)
  if context ~= nil and context.game_name ~= nil then
    LaunchLog("LAUNCH: derived GameName =", context.game_name)
  end
  LogPopstarterArgs(argv)
  if context ~= nil then
    LaunchLog("LAUNCH: device page:", context.device_page, "device mode:", context.device_mode, "UI scene:", context.ui_scene)
    LaunchLog("LAUNCH: source mode:", context.source_mode, "raw_source:", context.raw_source_mode)
    LaunchLog("LAUNCH: game path (raw):", context.gamelocation, "handoff:", context.handoff_gamelocation, "game:", context.game, "vcd_path:", context.vcd_path)
    LaunchLog("LAUNCH: vcd raw:", context.vcd_path)
    if context.bootparam_basename_raw ~= nil then
      LaunchLog("LAUNCH: vcd basename raw:", context.bootparam_basename_raw)
      LaunchLog("LAUNCH: vcd basename prefixed:", context.bootparam_basename_prefixed)
      LaunchLog("LAUNCH: vcd basename used:", context.bootparam_basename)
    else
      LaunchLog("LAUNCH: vcd basename:", context.bootparam_basename)
    end
    LaunchLog("LAUNCH: pops root:", context.bootparam_root)
    LaunchLog("LAUNCH: bootparam:", context.bootparam)
    LaunchLog(
      "LAUNCH: bootparam prefix required:",
      context.bootparam_prefix_required or "none",
      "used:",
      context.bootparam_prefix_used or "none",
      "prefix added:",
      tostring(context.bootparam_prefix_added)
    )
    if context.hdd_init ~= nil then
      LaunchLog("LAUNCH: hdd init ok:", context.hdd_init.init_ok, "status:", context.hdd_init.status,
        "mount:", context.hdd_init.mount_partition, "mount_ok:", context.hdd_init.mount_ok)
    end
  end
  local open_ok, open_rc, open_stage, open_api, open_path = TryOpenForLaunch(popstarter)
  if open_ok then
    LaunchLog("LAUNCH: popstarter stat ok:", open_rc)
  else
    LaunchLog("LAUNCH: popstarter "..tostring(open_stage).." failed:", open_rc, "api:", open_api)
    BlockLaunchFailure(
      "popstarter "..tostring(open_stage).." failed: "..tostring(open_rc),
      popstarter,
      context and context.device_page or "unknown",
      argv and argv[1] or nil,
      context and context.vcd_path or nil,
      app_dir,
      open_rc,
      open_api
    )
    return
  end
  if open_path ~= nil and open_path ~= popstarter then
    LaunchLog("LAUNCH: popstarter path adjusted:", popstarter, "->", open_path)
    popstarter = open_path
  end
  local exec_args = argv or {}
  SetLaunchPhase(LaunchState.PHASE_FADEOUT)
  UI.LAUNCHING = true
  LaunchState.fade_timer = Timer.new()
  LaunchState.fade_start = Timer.getTime(LaunchState.fade_timer)
  Screen.clear(Color.new(0, 0, 0))
  Screen.flip()
  if (Timer.getTime(LaunchState.fade_timer) - LaunchState.fade_start) >= LaunchState.watchdog_ms then
    BlockLaunchFailure(
      "Launch timeout: exec did not transfer control",
      popstarter,
      context and context.device_page or "unknown",
      argv0,
      argv0,
      app_dir,
      nil,
      nil
    )
    return
  end
  SetLaunchPhase(LaunchState.PHASE_EXEC)
  LaunchLog("LAUNCH: exec popstarter path:", popstarter)
  LaunchLog(
    "LAUNCH: exec boot source:",
    context and context.bootparam_source or "unknown",
    "pops root:",
    context and context.bootparam_root or "unknown",
    "vcd basename:",
    context and context.bootparam_basename or "unknown",
    "prefix required:",
    context and context.bootparam_prefix_required or "none",
    "prefix used:",
    context and context.bootparam_prefix_used or "none",
    "boot string:",
    context and context.bootparam or "unknown"
  )
  LaunchLog(
    "LAUNCH: stage A boot root:",
    context and context.bootparam_root or "unknown",
    "prefix required:",
    context and context.bootparam_prefix_required or "none",
    "prefix used:",
    context and context.bootparam_prefix_used or "none",
    "boot string:",
    context and context.bootparam or "unknown"
  )
  LaunchLog("LAUNCH: stage A argv_count:", exec_args and #exec_args or 0)
  LaunchLog(
    "LAUNCH: selector="..tostring(argv0),
    "popstarter="..tostring(popstarter),
    "reboot_iop="..tostring(reboot_iop)
  )
  LaunchLog("LAUNCH: loadELF argc (caller):", exec_args and #exec_args or 0)
  local rc
  if exec_args ~= nil and #exec_args > 0 and unpack_fn ~= nil then
    rc = System.loadELF(popstarter, reboot_iop, unpack_fn(exec_args))
  elseif exec_args ~= nil and #exec_args == 1 then
    rc = System.loadELF(popstarter, reboot_iop, exec_args[1])
  else
    rc = System.loadELF(popstarter, reboot_iop)
  end
  LaunchLog("LAUNCH RETURNED rc="..tostring(rc))
  LOG(">>> UNHANDLED ERROR at Launching game '", context and context.game or "unknown", " via ", popstarter, " Failed")
  if (Timer.getTime(LaunchState.fade_timer) - LaunchState.fade_start) >= LaunchState.watchdog_ms then
    BlockLaunchFailure(
      "Launch timeout: exec did not transfer control",
      popstarter,
      context and context.device_page or "unknown",
      argv0,
      argv0,
      app_dir,
      nil,
      nil
    )
    return
  end
  BlockLaunchFailure(
    rc,
    popstarter,
    context and context.device_page or "unknown",
    argv0,
    argv0,
    app_dir,
    nil,
    nil
  )
end

local function ResolveLaunchPolicy(gamelocation)
  local ui_scene = UI and UI.CURSCENE or "unknown"
  if string.match(gamelocation, "^mass") then
    return BuildLaunchPolicy("USB", "mass", "mass", nil), "USB"
  end
  if string.match(gamelocation, "^mmce") then
    local mmce_prefix = PLDR.MMCE.PREFIX or "mmce0:/"
    local mmce_device = string.match(mmce_prefix, "^([%a]+%d*)") or "mmce0"
    return BuildLaunchPolicy("MMCE", "mass", mmce_device, TranslateMMCEPathForPopStarter), "MMCE"
  end
  if string.match(gamelocation, "^pfs") then
    local prefix = GetDevicePrefix(gamelocation) or "pfs"
    return BuildLaunchPolicy("HDD", prefix, prefix, nil), "HDD"
  end
  if ui_scene == UI.SCENES.GUSB then
    return BuildLaunchPolicy("USB", "mass", "mass", nil), "USB"
  end
  if ui_scene == UI.SCENES.GSMB then
    local mmce_prefix = PLDR.MMCE.PREFIX or "mmce0:/"
    local mmce_device = string.match(mmce_prefix, "^([%a]+%d*)") or "mmce0"
    return BuildLaunchPolicy("MMCE", "mass", mmce_device, TranslateMMCEPathForPopStarter), "SMB/MMCE"
  end
  if ui_scene == UI.SCENES.GHDD then
    return BuildLaunchPolicy("HDD", "pfs", "pfs", nil), "HDD"
  end
  return BuildLaunchPolicy("unknown", "mass", "mass", nil), "unknown"
end

function PLDR.RunPOPStarterGame(gamelocation, game)
  local policy, device_page = ResolveLaunchPolicy(gamelocation)
  local hdd_init = nil
  if policy.name == "HDD" then
    if HDD_DIAG_BYPASS == 1 then
      local popstarter = ResolvePopstarterPath(PLDR.POPSTARTER_PATH)
      local argv = {popstarter}
      UI.BottomDraw.Play()
      Font.ftPrintMultiLineAligned(
        LFONT,
        UI.SCR.X_MID,
        120,
        20,
        UI.SCR.X,
        UI.SCR.Y,
        "ABOUT TO EXEC POPSTARTER (HDD BYPASS)",
        UI.CCOL.YELLOW
      )
      UI.flip()
      local context = {
        device_page = device_page,
        device_mode = "pfs",
        ui_scene = UI and UI.CURSCENE or "unknown",
        source_mode = "pfs",
        raw_source_mode = "pfs",
        gamelocation = gamelocation,
        game = game,
        argv0_selector = popstarter,
        bootparam_source = "pfs"
      }
      LaunchEngine(popstarter, argv, PLDR.REBOOT_IOP_WHILE_LOADING_POPSTARTER, context)
      return
    end
    hdd_init = EnsureHDDReadyForLaunch(game)
    if not hdd_init.init_ok or hdd_init.status ~= 0 or not hdd_init.mount_ok then
      LaunchLog("LAUNCH: HDD not ready; aborting launch.")
      BlockLaunchFailure(
        "HDD init/mount failed",
        ResolvePopstarterPath(PLDR.POPSTARTER_PATH),
        device_page,
        nil,
        nil,
        APP_DIR_LOCAL,
        nil,
        nil
      )
      return
    end
  end
  local normalized_gamelocation = policy.normalize(gamelocation)
  local handoff_gamelocation = policy.handoff(normalized_gamelocation)
  local source_mode = policy.mode
  local raw_source_mode = source_mode
  local vcd_path = normalized_gamelocation..game
  local popstarter = ResolvePopstarterPath(PLDR.POPSTARTER_PATH)
  local pops_root = normalized_gamelocation
  local boot_source_mode = source_mode
  local device_mode = "unknown"
  local mmce_prefix = nil
  if string.match(source_mode, "^pfs") then
    pops_root = normalized_gamelocation
    boot_source_mode = "pfs"
    device_mode = "pfs"
  elseif string.match(normalized_gamelocation, "^mmce%d:/") then
    mmce_prefix = PLDR.MMCE.PREFIX or string.match(normalized_gamelocation, "^(mmce%d:/)")
    if mmce_prefix == nil then
      mmce_prefix = "mmce0:/"
    end
    pops_root = mmce_prefix.."POPS/"
    boot_source_mode = "mass"
    device_mode = mmce_prefix
  elseif string.match(normalized_gamelocation, "^smb:/") or device_page == "SMB/MMCE" then
    pops_root = "smb:/POPS/"
    boot_source_mode = "smb"
    device_mode = "smb"
  else
    pops_root = "mass:/POPS/"
    boot_source_mode = "mass"
    device_mode = "mass"
  end
  local bootparam, prefix, normalized_basename, prefix_added = BuildPopstarterBootString(
    boot_source_mode,
    pops_root,
    game
  )
  local bootparam_exists = doesFileExist(bootparam)
  local fallback_bootparam = nil
  local fallback_exists = false
  local bootparam_basename_used = normalized_basename
  local prefix_used = HasBootPrefix(normalized_basename, prefix) and prefix or ""
  local game_name = DeriveGameNameFromSelection(game)
  if game_name == "" or string.upper(game_name) == "POPSTARTER" then
    LaunchLog("LAUNCH: GameName derivation failed for selection:", game)
    BlockLaunchFailure(
      "GameName derivation failed",
      popstarter,
      device_page,
      nil,
      game,
      APP_DIR_LOCAL,
      nil,
      nil
    )
    return
  end
  local selector_prefix = SelectPopstarterSelectorPrefix(device_page)
  local argv0_selector = BuildPopstarterSelectorPath(device_page, game_name)
  if selector_prefix == "" and string.upper(game_name) == "POPSTARTER" then
    LaunchLog("LAUNCH: Internal error: game_base derived as POPSTARTER; refusing to launch.", game)
    BlockLaunchFailure(
      "Internal error: game_base derived as POPSTARTER; refusing to launch.",
      popstarter,
      device_page,
      nil,
      game,
      APP_DIR_LOCAL,
      nil,
      nil
    )
    return
  end
  if boot_source_mode == "mass" and prefix_added and not bootparam_exists then
    fallback_bootparam = EnsureTrailingSlash(pops_root)..game
    fallback_exists = doesFileExist(fallback_bootparam)
    if fallback_exists then
      bootparam = fallback_bootparam
      bootparam_basename_used = game
      bootparam_exists = true
      prefix_used = ""
    end
  end
  local argv = {argv0_selector}

  LOG("Boot APP_DIR: "..APP_DIR_LOCAL)
  LOG("PopStarter selected: "..popstarter)
  LOG("PopStarter:", popstarter, "VCD:", vcd_path, "mode:", source_mode, "argv_count:", #argv)
  LaunchLog("LAUNCH: device mode:", device_mode)
  LaunchLog("LAUNCH: pops root:", pops_root)
  LaunchLog("LAUNCH: vcd basename raw:", game)
  LaunchLog("LAUNCH: vcd basename prefixed:", normalized_basename)
  LaunchLog("LAUNCH: vcd basename used:", bootparam_basename_used)
  LaunchLog("LAUNCH: bootparam candidate:", bootparam, "exists:", tostring(bootparam_exists))
  LaunchLog("LAUNCH: derived GameName:", game_name)
  LaunchLog("LAUNCH: selector mode:", SELECTOR_MODE)
  LaunchLog("LAUNCH: selector prefix:", selector_prefix)
  LaunchLog("LAUNCH: argv0 selector:", argv0_selector)
  LaunchLog("LAUNCH: loadELF argc (caller):", #argv)
  if fallback_bootparam ~= nil then
    LaunchLog("LAUNCH: bootparam fallback:", fallback_bootparam, "exists:", tostring(fallback_exists))
  end
  local context = {
    device_page = device_page,
    device_mode = device_mode,
    ui_scene = UI and UI.CURSCENE or "unknown",
    source_mode = source_mode,
    raw_source_mode = raw_source_mode,
    gamelocation = gamelocation,
    handoff_gamelocation = handoff_gamelocation,
    game = game,
    vcd_path = vcd_path,
    bootparam = bootparam,
    bootparam_prefix_required = prefix,
    bootparam_prefix_used = prefix_used,
    bootparam_prefix_added = prefix_added,
    bootparam_root = pops_root,
    bootparam_basename_raw = game,
    bootparam_basename_prefixed = normalized_basename,
    bootparam_basename = bootparam_basename_used,
    argv0_selector = argv0_selector,
    game_name = game_name,
    bootparam_source = boot_source_mode,
    hdd_init = hdd_init
  }
  LaunchEngine(popstarter, argv, PLDR.REBOOT_IOP_WHILE_LOADING_POPSTARTER, context)
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
  if BOOT_PROF and not BOOT_PROF.first_main_menu and UI.CURSCENE == UI.SCENES.MMAIN then
    BOOT_PROF.first_main_menu = true
    BOOT_PROF.stamp("first frame / main menu visible")
  end
end
