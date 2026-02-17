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
LOG("system.lua start")
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

local function ClassifyMassDevice(path_hint)
  -- Keep classification non-blocking during boot/UI routing; avoid loading extra IRX here.
  -- TODO: verify whether enabling RPC module autoload is safe on all target hardware.
  local ok, result = pcall(System.classifyMassDevice, path_hint, APP_DIR_LOCAL, false)
  if ok and type(result) == "table" then
    return result
  end
  return {
    class = "UNKNOWN",
    source = "fallback"
  }
end

local function DetectBootDevice()
  local boot_path = NormalizeDirPath(BOOT_PATH_RAW or "")
  local prefix = string.match(boot_path, "^([%a]+%d*):")
  if prefix == nil then
    return nil, boot_path, prefix, {
      class = "UNKNOWN",
      source = "prefix"
    }
  end
  if string.match(prefix, "^mmce%d*$") then
    return "MMCE", boot_path, prefix, {
      class = "UNKNOWN",
      source = "prefix"
    }
  end
  if string.match(prefix, "^mx4sio%d*$") then
    return "MX4SIO", boot_path, prefix, {
      class = "MX4SIO",
      source = "prefix"
    }
  end
  if string.match(prefix, "^mass%d*$") then
    local mx_marker = JoinPath(APP_DIR_LOCAL, ".boot_mx4sio")
    local usb_marker = JoinPath(APP_DIR_LOCAL, ".boot_usb")
    if doesFileExist(mx_marker) then
      return "MX4SIO", boot_path, prefix, {
        class = "MX4SIO",
        source = "marker"
      }
    end
    if doesFileExist(usb_marker) then
      return "USB", boot_path, prefix, {
        class = "USB",
        source = "marker"
      }
    end
    return "USB", boot_path, prefix, {
      class = "USB",
      source = "prefix"
    }
  end
  return nil, boot_path, prefix, {
    class = "UNKNOWN",
    source = "prefix"
  }
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
HDD_DIAG_BYPASS = 0
PLDR = {
  REBOOT_IOP_WHILE_LOADING_POPSTARTER = 0;
  POPSTARTER_PATH = "mass:/POPS/POPSTARTER.ELF";--"mass:/POPS/POPSTARTER.ELF";
  CHECK_POPSTARTER_FILES = false;
  GAMEPATH = ".";
  GAMES = {};
  HDDCACHE = nil;
  PROFILES = {};
  SETTINGS = {
    BDMA_MODE = "NONE",
    PROFILE_INDEX = 1,
    DKWDRV_PATH = "mc0:/PS1_DKWDRV/DKWDRV.ELF"
  };
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
    MASSINDX = 0,
    ROOTS = {},
    GAME_SOURCES = {},
    GAME_META = {}
  },
  MX4SIO = {
    READY = false,
    ROOT = nil,
    PREFIX_HINT = nil
  },
  MMCE = {
    PROBED = false,
    PREFIX = nil,
    SLOTS = {},
    INDEX = 1
  }
}

local SETTINGS_FILE = "settings.lua"
local BDMA_MODES = {
  { key = "NONE", label = "None", suffix = nil },
  { key = "USBEXFAT", label = "USB exFAT", suffix = ".usbexfat" },
  { key = "MMCE", label = "MMCE", suffix = ".mmce" },
  { key = "MX4SIO", label = "MX4SIO", suffix = ".mx4sio" }
}
local BDMA_MODE_INDEX = {}
for i = 1, #BDMA_MODES do
  BDMA_MODE_INDEX[BDMA_MODES[i].key] = i
end

function PLDR.GetBdmaModes()
  return BDMA_MODES
end

function PLDR.GetBdmaModeIndex(mode_key)
  return BDMA_MODE_INDEX[mode_key] or 1
end

function PLDR.GetDefaultDkwdrvPath()
  return "mc0:/PS1_DKWDRV/DKWDRV.ELF"
end

local function ClampValue(value, min_val, max_val)
  if value < min_val then return min_val end
  if value > max_val then return max_val end
  return value
end

local function LoadSettingsFile()
  local path = ResolveWritablePath(SETTINGS_FILE)
  if not doesFileExist(path) then
    return nil
  end
  local loader, err = loadfile(path)
  if loader == nil then
    LOG("Settings load failed:", err)
    return nil
  end
  local ok, data = pcall(loader)
  if not ok then
    LOG("Settings run failed:", data)
    return nil
  end
  if type(data) == "table" then
    return data
  end
  return nil
end

function PLDR.LoadSettings()
  local cfg = LoadSettingsFile()
  local defaults = PLDR.SETTINGS
  if type(cfg) ~= "table" then
    cfg = {}
  end
  local mode = tostring(cfg.BDMA_MODE or defaults.BDMA_MODE)
  if BDMA_MODE_INDEX[mode] == nil then
    mode = defaults.BDMA_MODE
  end
  local profile = tonumber(cfg.PROFILE_INDEX) or defaults.PROFILE_INDEX
  profile = ClampValue(profile, 1, math.max(#PLDR.PROFILES, 1))
  local dkwdrv = tostring(cfg.DKWDRV_PATH or defaults.DKWDRV_PATH)
  if dkwdrv == "" then
    dkwdrv = defaults.DKWDRV_PATH
  end
  PLDR.SETTINGS = {
    BDMA_MODE = mode,
    PROFILE_INDEX = profile,
    DKWDRV_PATH = dkwdrv
  }
  if #PLDR.PROFILES > 0 and PLDR.PROFILES[profile] ~= nil then
    PLDR.POPSTARTER_PATH = PLDR.PROFILES[profile].ELF
  end
end

local function SaveSettingsFile(settings)
  local path = ResolveWritablePath(SETTINGS_FILE)
  local payload = string.format(
    "return {\n  BDMA_MODE = %q,\n  PROFILE_INDEX = %d,\n  DKWDRV_PATH = %q\n}\n",
    settings.BDMA_MODE,
    settings.PROFILE_INDEX,
    settings.DKWDRV_PATH
  )
  local ok, fd = pcall(System.openFile, path, FCREATE)
  if not ok or fd == nil or fd < 0 then
    LOG("Settings save open failed:", path, fd)
    return false
  end
  System.writeFile(fd, payload, #payload)
  System.closeFile(fd)
  return true
end
local function DetectMX4SIOPrefixHint()
  local mx_marker = JoinPath(APP_DIR_LOCAL, ".boot_mx4sio")
  if doesFileExist(mx_marker) then
    return "mx4sio:/"
  end
  return nil
end
PLDR.MX4SIO.PREFIX_HINT = DetectMX4SIOPrefixHint()
if PLDR.MX4SIO.PREFIX_HINT ~= nil then
  LOG("MX4SIO prefix hint: "..PLDR.MX4SIO.PREFIX_HINT)
end
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
PLDR.LoadSettings()
LOG("system.lua: before require('ui')")
local ok_ui, ui_or_err = pcall(require, "ui")
LOG("system.lua: after require('ui')")
if not ok_ui then
  local traceback = ui_or_err
  if debug ~= nil and debug.traceback ~= nil then
    traceback = debug.traceback(ui_or_err, 2)
  end
  LOG("UI load failed")
  LOG("APP_DIR:", APP_DIR_LOCAL)
  LOG("Boot cwd:", System.currentDirectory())
  LOG("package.path:", package.path)
  error("UI module failed to load (expected ui.lua to return/set UI): "..tostring(traceback))
end
if ui_or_err ~= nil and ui_or_err ~= true then
  UI = ui_or_err
end
if UI == nil then
  LOG("UI global is nil after require('ui')")
  LOG("APP_DIR:", APP_DIR_LOCAL)
  LOG("Boot cwd:", System.currentDirectory())
  LOG("package.path:", package.path)
  error("UI global not initialized (expected ui.lua to return UI or set _G.UI)")
end
UI.LASTSCENE = UI.SCENES.MMAIN

if UI.DEVLOCK ~= nil then
  local boot_name, boot_path, boot_prefix, boot_meta = DetectBootDevice()
  UI.boot_device = UI.DEVLOCK.NONE
  UI.boot_locks = {}
  if boot_name == "MX4SIO" then
    UI.boot_device = UI.DEVLOCK.MX4SIO
    UI.boot_locks[UI.DEVLOCK.USB] = true
    UI.boot_locks[UI.DEVLOCK.MMCE] = true
  elseif boot_name == "USB" then
    UI.boot_device = UI.DEVLOCK.USB
    UI.boot_locks[UI.DEVLOCK.MX4SIO] = true
  elseif boot_name == "MMCE" then
    UI.boot_device = UI.DEVLOCK.MMCE
    UI.boot_locks[UI.DEVLOCK.MX4SIO] = true
  end
  if boot_name ~= nil then
    LOG("Boot device detected:", boot_name, "prefix:", tostring(boot_prefix), "path:", tostring(boot_path), "source:", tostring(boot_meta and boot_meta.source), "class:", tostring(boot_meta and boot_meta.class), "port:", tostring(boot_meta and boot_meta.port), "index:", tostring(boot_meta and boot_meta.index))
  else
    LOG("Boot device detection ambiguous; no boot locks set.", "prefix:", tostring(boot_prefix), "path:", tostring(boot_path), "source:", tostring(boot_meta and boot_meta.source), "class:", tostring(boot_meta and boot_meta.class), "port:", tostring(boot_meta and boot_meta.port), "index:", tostring(boot_meta and boot_meta.index))
  end
end
require("images")

local POPSTARTER_PACK_ROOT = "mc0:/POPSTARTER"
local BDMA_PAYLOAD_SOURCE_DIR = "POPSLDR"
local BDMA_PAYLOAD_INVENTORY = {
  "usbd.irx",
  "usbhdfsd.irx",
  "icon.sys",
  "list.icn",
  "del.icn"
}

local function ResolveBdmaSource(name, mode)
  local suffix = mode.suffix
  if suffix == nil then
    return nil
  end
  local rel = BDMA_PAYLOAD_SOURCE_DIR.."/"..name..suffix
  return ResolveAsset(rel) or JoinPath(APP_DIR_LOCAL, rel)
end

local function EnsureDirectory(path)
  if doesFolderExist(path) then
    return true
  end
  local ok, err = pcall(System.createDirectory, path)
  if not ok then
    LOG("CreateDirectory failed:", path, err)
  end
  return ok
end

local function RemoveDirectoryRecursive(path)
  local normalized = NormalizeDirPath(path)
  if not doesFolderExist(normalized) then
    return true
  end
  local ok, entries = pcall(System.listDirectory, normalized)
  if not ok or entries == nil then
    return false, "list failed"
  end
  for i = 1, #entries do
    local entry = entries[i]
    if entry ~= nil and entry.name ~= nil then
      local name = entry.name
      if name ~= "." and name ~= ".." then
        local child = JoinPath(normalized, name)
        if entry.directory then
          local child_ok, child_err = RemoveDirectoryRecursive(child)
          if not child_ok then
            return false, child_err
          end
          local rm_ok, rm_err = pcall(System.removeDirectory, child)
          if not rm_ok then
            return false, rm_err
          end
        else
          local rm_ok, rm_err = pcall(System.removeFile, child)
          if not rm_ok then
            return false, rm_err
          end
        end
      end
    end
  end
  return true
end

function PLDR.ApplyBdmaMode(mode_key, progress_cb)
  local mode = nil
  local modes = PLDR.GetBdmaModes()
  for i = 1, #modes do
    if modes[i].key == mode_key then
      mode = modes[i]
      break
    end
  end
  if mode == nil then
    return false, "unknown mode"
  end

  local total_copy = 0
  if mode.suffix ~= nil then
    total_copy = #BDMA_PAYLOAD_INVENTORY
  end
  local total = total_copy + 3
  if total < 1 then total = 1 end

  local state = {
    stage = "Deleting/Preparing",
    current = 0,
    total = total,
    copied = 0,
    copy_total = total_copy,
    message = ""
  }
  local function tick()
    if progress_cb ~= nil then
      progress_cb(state)
    end
  end
  tick()

  local ok, err = RemoveDirectoryRecursive(POPSTARTER_PACK_ROOT)
  if not ok then
    state.stage = "Error"
    state.message = tostring(err)
    tick()
    return false, err
  end
  state.stage = "Deleting/Preparing"
  tick()
  if doesFolderExist(POPSTARTER_PACK_ROOT) then
    local rm_ok, rm_err = pcall(System.removeDirectory, POPSTARTER_PACK_ROOT)
    if not rm_ok then
      state.stage = "Error"
      state.message = tostring(rm_err)
      tick()
      return false, rm_err
    end
  end

  state.current = state.current + 1
  tick()

  if mode.suffix ~= nil then
    if not EnsureDirectory(POPSTARTER_PACK_ROOT) then
      state.stage = "Error"
      state.message = "create directory failed"
      tick()
      return false, state.message
    end
    state.stage = "Copying"
    tick()
    for i = 1, #BDMA_PAYLOAD_INVENTORY do
      local name = BDMA_PAYLOAD_INVENTORY[i]
      local source = ResolveBdmaSource(name, mode)
      local dest = JoinPath(POPSTARTER_PACK_ROOT, name)
      if source == nil or not doesFileExist(source) then
        state.stage = "Error"
        state.message = "missing payload "..name..mode.suffix
        tick()
        return false, state.message
      end
      local cp_ok, cp_err = pcall(System.copyFile, source, dest)
      if not cp_ok then
        state.stage = "Error"
        state.message = tostring(cp_err)
        tick()
        return false, cp_err
      end
      state.copied = i
      state.current = state.current + 1
      tick()
    end
  end

  state.stage = "Finalizing"
  state.current = total - 1
  tick()
  state.stage = "Done"
  state.current = total
  tick()
  return true
end

function PLDR.SaveSettings(settings, opts)
  local previous_mode = PLDR.SETTINGS.BDMA_MODE
  PLDR.SETTINGS = {
    BDMA_MODE = settings.BDMA_MODE,
    PROFILE_INDEX = settings.PROFILE_INDEX,
    DKWDRV_PATH = settings.DKWDRV_PATH
  }
  local ok = SaveSettingsFile(PLDR.SETTINGS)
  if not ok then
    return false, "save failed"
  end
  if #PLDR.PROFILES > 0 and PLDR.PROFILES[settings.PROFILE_INDEX] ~= nil then
    PLDR.POPSTARTER_PATH = PLDR.PROFILES[settings.PROFILE_INDEX].ELF
  end
  local apply_bdma = opts ~= nil and opts.apply_bdma == true
  if apply_bdma and previous_mode ~= settings.BDMA_MODE then
    return PLDR.ApplyBdmaMode(settings.BDMA_MODE, opts.progress_cb)
  end
  return true
end

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
  if UI.IsUsbScene(device) then
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
  if path ~= nil and string.match(path, "^mass%d*:/POPS/?$") then
    return PLDR.GetMergedUsbGameList(updating)
  end
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

local USB_SCAN_MAX_ROOTS = 8

local function SortUsbRoots(roots)
  table.sort(roots, function(a, b)
    local ai = tonumber(string.match(a, "^mass(%d*):/$") or "")
    local bi = tonumber(string.match(b, "^mass(%d*):/$") or "")
    if ai == nil then ai = 0 end
    if bi == nil then bi = 0 end
    if ai ~= bi then
      return ai < bi
    end
    return a < b
  end)
end

local function AddUniqueRoot(roots, seen, root)
  local normalized = NormalizeDirPath(root)
  if normalized == nil then
    return
  end
  if not string.match(normalized, "^mass%d*:/$") then
    return
  end
  if seen[normalized] then
    return
  end
  seen[normalized] = true
  table.insert(roots, normalized)
end

local function IsUsbClass(class_name)
  if class_name == nil then
    return false
  end
  return string.upper(class_name) == "USB"
end

local function ProbeUsbRootsByPopsDir(max_roots)
  local roots = {}
  local seen = {}
  for idx = 0, max_roots do
    local root = "mass"..idx..":/"
    local pops_root = root.."POPS/"
    local ok, exists = pcall(doesFolderExist, pops_root)
    if ok and exists then
      AddUniqueRoot(roots, seen, root)
    elseif not ok then
      LOG("USB root probe failed for", pops_root)
    end
  end
  SortUsbRoots(roots)
  return roots
end

function PLDR.USB.GetRoots()
  local roots = {}
  local seen = {}
  local bdm_list = nil
  local ok_bdm, bdm_result = pcall(System.bdmList)
  if ok_bdm and type(bdm_result) == "table" then
    bdm_list = bdm_result
  end
  for idx = 0, USB_SCAN_MAX_ROOTS do
    local root = "mass"..idx..":/"
    local metadata = ClassifyMassDevice(root)
    if IsUsbClass(metadata.class) then
      AddUniqueRoot(roots, seen, root)
    end
  end
  if type(bdm_list) == "table" then
    for i = 1, #bdm_list do
      local info = bdm_list[i]
      if type(info) == "table" and IsUsbClass(info.class) then
        -- TODO: verify bdm metadata mapping contract (`class`, `port`, `index`, `driver`)
        -- between src/luasystem.cpp:PushBdmInfo/lua_classify_mass_device and
        -- iop/bdm_query/bdm_query.c device copy fields before locking strict matching logic.
        local index = tonumber(info.index)
        if index ~= nil and index >= 0 then
          AddUniqueRoot(roots, seen, "mass"..index..":/")
        end
      end
    end
  end
  local fallback_roots = ProbeUsbRootsByPopsDir(USB_SCAN_MAX_ROOTS)
  for i = 1, #fallback_roots do
    AddUniqueRoot(roots, seen, fallback_roots[i])
  end
  SortUsbRoots(roots)
  PLDR.USB.ROOTS = roots
  return roots
end

local function BuildUsbSortKey(entry)
  local lower_display = string.lower(entry.display or "")
  local lower_root = string.lower(entry.source or "")
  local lower_name = string.lower(entry.name or "")
  return lower_display, lower_root, lower_name
end

local function UsbRootLabel(root)
  return string.match(root or "", "^([%a]+%d*):/$") or (root or "?")
end

function PLDR.GetMergedUsbGameList(updating)
  local roots = PLDR.USB.GetRoots()
  local collected = {}
  local source_map = {}
  local meta_map = {}
  local basename_counts = {}
  for i = 1, #roots do
    local root = roots[i]
    local pops_path = root.."POPS/"
    local ok, dir = pcall(System.listDirectory, pops_path)
    if not ok then
      LOG("cannot opendir", pops_path)
    elseif dir ~= nil then
      for j = 1, #dir do
        local entry = dir[j]
        if entry ~= nil and not entry.directory then
          local filename = entry.name
          if filename ~= nil and string.lower(string.sub(filename, -4)) == ".vcd" then
            local encoded = root.."|"..filename
            local display_base = string.gsub(filename, "%.[Vv][Cc][Dd]$", "")
            table.insert(collected, {
              id = encoded,
              source = root,
              name = filename,
              display = display_base
            })
            source_map[encoded] = root
            basename_counts[string.lower(display_base)] = (basename_counts[string.lower(display_base)] or 0) + 1
          end
        end
      end
    end
  end
  table.sort(collected, function(a, b)
    local ad, ar, an = BuildUsbSortKey(a)
    local bd, br, bn = BuildUsbSortKey(b)
    if ad ~= bd then
      return ad < bd
    end
    if ar ~= br then
      return ar < br
    end
    return an < bn
  end)
  local games = {}
  for i = 1, #collected do
    local item = collected[i]
    local display_name = item.display
    if (basename_counts[string.lower(item.display)] or 0) > 1 then
      display_name = item.display.." ["..UsbRootLabel(item.source).."]"
    end
    games[i] = item.id
    meta_map[item.id] = {
      key = item.id,
      source_root = item.source,
      filename = item.name,
      display_name = display_name,
      full_path = item.source.."POPS/"..item.name
    }
  end
  PLDR.USB.GAME_SOURCES = source_map
  PLDR.USB.GAME_META = meta_map
  if updating then
    PLDR.GAMES = games
  else
    PLDR.GAMES = games
  end
  if #games > 0 then
    return PLDR.GAMES
  end
  return nil
end

local function ParseUsbGameEntry(entry)
  if entry == nil then
    return nil, nil
  end
  local source, name = string.match(entry, "^(mass%d*:/)|(.+)$")
  return source, name
end

function PLDR.ResolveSelectedGamePath(base_path, entry)
  local usb_meta = PLDR.USB.GAME_META and PLDR.USB.GAME_META[entry] or nil
  if usb_meta ~= nil and usb_meta.full_path ~= nil then
    return usb_meta.full_path
  end
  local source_root, filename = ParseUsbGameEntry(entry)
  if source_root ~= nil and filename ~= nil then
    return source_root.."POPS/"..filename
  end
  return (base_path or "")..(entry or "")
end

function PLDR.GetSelectedUsbGameMeta(entry)
  if entry == nil then
    return nil
  end
  if PLDR.USB.GAME_META ~= nil then
    return PLDR.USB.GAME_META[entry]
  end
  return nil
end

function PLDR.GetGameDisplayName(entry)
  local usb_meta = PLDR.GetSelectedUsbGameMeta(entry)
  if usb_meta ~= nil and usb_meta.display_name ~= nil then
    return usb_meta.display_name
  end
  local display_name = entry
  local hdd_relpath = string.match(display_name or "", "^[^|]+|(.+)$")
  if hdd_relpath ~= nil then
    display_name = string.match(hdd_relpath, "([^/]+)$") or hdd_relpath
  end
  return string.gsub(display_name or "", "%.[Vv][Cc][Dd]$", "")
end

local function EncodeHddGameEntry(partition, relpath)
  if partition == nil or relpath == nil then
    return nil
  end
  return partition.."|"..relpath
end

local function AppendHddGameList(partition, list_path, rel_prefix)
  if list_path == nil then
    return
  end
  local DIR = System.listDirectory(list_path)
  if DIR == nil then
    LOG("cannot opendir")
    return
  end
  for i = 1, #DIR do
    if not DIR[i].directory then
      if string.lower(string.sub(DIR[i].name, -4)) == ".vcd" then
        local relpath = DIR[i].name
        if rel_prefix ~= nil and rel_prefix ~= "" then
          relpath = rel_prefix..relpath
        end
        local encoded = EncodeHddGameEntry(partition, relpath)
        if encoded ~= nil then
          LOG(" Found", encoded)
          table.insert(PLDR.GAMES, encoded)
          PLDR.HDD.GAMEPARTS[encoded] = "hdd0:"..partition
        end
      end
    end
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
  PLDR.GAMEPATH = "pfs0:/"
  if not PLDR.HDD.FOUNDANY then return end
  if PLDR.HDD.MAINPART then
    if HDD.MountPartition("hdd0:__.POPS", 0, FIO_MT_RDONLY) then
      AppendHddGameList("__.POPS", "pfs0:/", "")
      AppendHddGameList("__.POPS", "pfs0:/POPS/", "POPS/")
      HDD.UMountPartition(0)
    end
  end
  for i=1, 9 do
    if PLDR.HDD.EXTRAPARTS[i] then
      if HDD.MountPartition("hdd0:__.POPS"..i, 0, FIO_MT_RDONLY) then
        local partition = "__.POPS"..i
        AppendHddGameList(partition, "pfs0:/", "")
        AppendHddGameList(partition, "pfs0:/POPS/", "POPS/")
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
  PLDR.USB.GAME_SOURCES = {}
  PLDR.USB.GAME_META = {}
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

local function TrimTrailingWhitespace(value)
  if value == nil or value == "" then
    return ""
  end
  return string.gsub(value, "%s+$", "")
end

local function BuildLiteralElfName(value)
  if value == nil or value == "" then
    return ""
  end
  local trimmed = TrimTrailingWhitespace(value)
  if trimmed == "" then
    return ""
  end
  if string.match(trimmed, "%.[Ee][Ll][Ff]$") then
    return trimmed
  end
  return trimmed..".ELF"
end

local function BuildDisplayNameFromEntry(entry)
  if entry == nil or entry == "" then
    return ""
  end
  local display_name = entry
  local hdd_relpath = string.match(display_name, "^[^|]+|(.+)$")
  if hdd_relpath ~= nil then
    display_name = string.match(hdd_relpath, "([^/]+)$") or hdd_relpath
  end
  return string.gsub(display_name, "%.[Vv][Cc][Dd]$", "")
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
  if device_page == "USB" or device_page == "MMCE" or device_page == "SMB/MMCE" or device_page == "MX4SIO" then
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
  if device_page == "MX4SIO" then
    local root = PLDR and PLDR.MX4SIO and PLDR.MX4SIO.ROOT or "mx4sio:/"
    return root.."POPS/XX."..game_name..".ELF"
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

local function ParseHddGameEntry(entry)
  if entry == nil or entry == "" then
    return nil, nil
  end
  local partition, relpath = string.match(entry, "^([^|]+)|(.+)$")
  return partition, relpath
end

local function NormalizeHddRelpath(relpath)
  if relpath == nil then
    return ""
  end
  local cleaned = string.gsub(relpath, "^pfs%d:/", "")
  cleaned = string.gsub(cleaned, "^/+", "")
  return cleaned
end

local function EnsureHDDReadyForLaunch(game, partition_override)
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
  local partition = partition_override or PLDR.HDD.GAMEPARTS[game] or "hdd0:__.POPS"
  result.mount_partition = partition
  HDD.UMountPartition(0)
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

local function BlockHddLaunchMissingVcd(partition, relpath, vcd_path, open_rc, open_api)
  SetLaunchPhase(LaunchState.PHASE_FAILED)
  UI.LAUNCHING = false
  local body = string.format(
    "HDD VCD missing\nPartition: %s\nRelpath: %s\nPath: %s\nOpen/stat rc: %s\nOpen API: %s\nPress X/O to continue.",
    tostring(partition),
    tostring(relpath),
    tostring(vcd_path),
    tostring(open_rc),
    tostring(open_api)
  )
  while true do
    UI.BottomDraw.Play()
    Font.ftPrintMultiLineAligned(LFONT, UI.SCR.X_MID, 120, 20, UI.SCR.X, UI.SCR.Y, "HDD LAUNCH FAILED", UI.CCOL.YELLOW)
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

local function ResolveLaunchPolicy(gamelocation, ui_scene)
  local current_scene = ui_scene or (UI and UI.CURSCENE or "unknown")
  if current_scene == UI.SCENES.GHDD then
    return BuildLaunchPolicy("HDD", "pfs", "pfs", nil), "HDD"
  end
  if current_scene == UI.SCENES.GMX4SIO then
    return BuildLaunchPolicy("MX4SIO", "mx4sio", "mx4sio", nil), "MX4SIO"
  end
  local mass_classifier = ClassifyMassDevice(gamelocation)
  if mass_classifier.class == "MX4SIO" then
    return BuildLaunchPolicy("MX4SIO", "mx4sio", "mx4sio", nil), "MX4SIO"
  end
  if mass_classifier.class == "USB" then
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
  if UI.IsUsbScene(current_scene) then
    return BuildLaunchPolicy("USB", "mass", "mass", nil), "USB"
  end
  if current_scene == UI.SCENES.GSMB then
    local mmce_prefix = PLDR.MMCE.PREFIX or "mmce0:/"
    local mmce_device = string.match(mmce_prefix, "^([%a]+%d*)") or "mmce0"
    return BuildLaunchPolicy("MMCE", "mass", mmce_device, TranslateMMCEPathForPopStarter), "SMB/MMCE"
  end
  return BuildLaunchPolicy("unknown", "mass", "mass", nil), "unknown"
end

function PLDR.RunPOPStarterGame(gamelocation, game, ui_scene, selected_root)
  local policy, device_page = ResolveLaunchPolicy(gamelocation, ui_scene)
  local hdd_init = nil
  local hdd_partition_label = nil
  local hdd_relpath = nil
  local hdd_partition = nil
  if policy.name == "HDD" then
    hdd_partition_label, hdd_relpath = ParseHddGameEntry(game)
    hdd_relpath = NormalizeHddRelpath(hdd_relpath or game)
    if hdd_partition_label ~= nil then
      hdd_partition = "hdd0:"..hdd_partition_label
    end
  end
  local normalized_gamelocation = policy.normalize(gamelocation)
  local usb_root = nil
  local usb_file = nil
  if policy.name ~= "HDD" then
    usb_root, usb_file = ParseUsbGameEntry(game)
  end
  if usb_root == nil then
    local usb_meta = PLDR.GetSelectedUsbGameMeta(game)
    if usb_meta ~= nil then
      usb_root = usb_meta.source_root
      usb_file = usb_meta.filename
    end
  end
  if policy.name == "USB" and selected_root ~= nil and selected_root ~= "" then
    usb_root = selected_root
  end
  local handoff_gamelocation = policy.handoff(normalized_gamelocation)
  if usb_root ~= nil then
    handoff_gamelocation = policy.handoff(usb_root.."POPS/")
  end
  local source_mode = policy.mode
  local raw_source_mode = source_mode
  local game_entry_name = usb_file or game
  local vcd_path = normalized_gamelocation..game_entry_name
  local popstarter = ResolvePopstarterPath(PLDR.POPSTARTER_PATH)
  local pops_root = normalized_gamelocation
  local boot_source_mode = source_mode
  local device_mode = "unknown"
  local mmce_prefix = nil
  if string.match(source_mode, "^pfs") then
    pops_root = normalized_gamelocation
    boot_source_mode = "pfs"
    device_mode = "pfs"
  elseif string.match(normalized_gamelocation, "^mx4sio") then
    pops_root = normalized_gamelocation
    boot_source_mode = "mx4sio"
    device_mode = normalized_gamelocation
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
    if usb_root ~= nil then
      pops_root = usb_root.."POPS/"
      device_mode = usb_root
    else
      pops_root = "mass:/POPS/"
      device_mode = "mass"
    end
    boot_source_mode = "mass"
  end
  if policy.name == "HDD" then
    vcd_path = ""
    pops_root = ""
    boot_source_mode = "pfs"
    device_mode = "pfs"
    handoff_gamelocation = ""
  end
  local bootparam = nil
  local prefix = ""
  local normalized_basename = ""
  local prefix_added = false
  local bootparam_exists = false
  local fallback_bootparam = nil
  local fallback_exists = false
  local bootparam_basename_used = ""
  local prefix_used = ""
  if policy.name == "HDD" then
    normalized_basename = ""
    bootparam = ""
    bootparam_basename_used = ""
  else
    bootparam, prefix, normalized_basename, prefix_added = BuildPopstarterBootString(
      boot_source_mode,
      pops_root,
      game_entry_name
    )
    bootparam_exists = doesFileExist(bootparam)
    bootparam_basename_used = normalized_basename
    prefix_used = HasBootPrefix(normalized_basename, prefix) and prefix or ""
  end
  local selection_for_name = game_entry_name
  if policy.name == "HDD" then
    selection_for_name = NormalizeHddRelpath(hdd_relpath or game)
  end
  local game_name = DeriveGameNameFromSelection(selection_for_name)
  local vcd_basename_raw = game_entry_name
  if policy.name == "HDD" then
    vcd_basename_raw = NormalizeHddRelpath(hdd_relpath or game)
  end
  if policy.name == "HDD" then
    normalized_basename = game_name
    bootparam_basename_used = game_name
  end
  if game_name == "" or string.upper(game_name) == "POPSTARTER" then
    LaunchLog("LAUNCH: GameName derivation failed for selection:", vcd_basename_raw)
    BlockLaunchFailure(
      "GameName derivation failed",
      popstarter,
      device_page,
      nil,
      vcd_basename_raw,
      APP_DIR_LOCAL,
      nil,
      nil
    )
    return
  end
  local selector_prefix = SelectPopstarterSelectorPrefix(device_page)
  local argv0_selector = BuildPopstarterSelectorPath(device_page, game_name)
  if policy.name == "HDD" then
    local display_name = BuildDisplayNameFromEntry(game)
    argv0_selector = BuildLiteralElfName(display_name)
  end
  if selector_prefix == "" and string.upper(game_name) == "POPSTARTER" then
    LaunchLog("LAUNCH: Internal error: game_base derived as POPSTARTER; refusing to launch.", vcd_basename_raw)
    BlockLaunchFailure(
      "Internal error: game_base derived as POPSTARTER; refusing to launch.",
      popstarter,
      device_page,
      nil,
      vcd_basename_raw,
      APP_DIR_LOCAL,
      nil,
      nil
    )
    return
  end
  if boot_source_mode == "mass" and prefix_added and not bootparam_exists then
    fallback_bootparam = EnsureTrailingSlash(pops_root)..game_entry_name
    fallback_exists = doesFileExist(fallback_bootparam)
    if fallback_exists then
      bootparam = fallback_bootparam
      bootparam_basename_used = game_entry_name
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
  LaunchLog("LAUNCH: vcd basename raw:", vcd_basename_raw)
  LaunchLog("LAUNCH: vcd basename prefixed:", normalized_basename)
  LaunchLog("LAUNCH: vcd basename used:", bootparam_basename_used)
  LaunchLog("LAUNCH: bootparam candidate:", bootparam, "exists:", tostring(bootparam_exists))
  LaunchLog("LAUNCH: derived GameName:", game_name)
  LaunchLog("LAUNCH: selector mode:", SELECTOR_MODE)
  LaunchLog("LAUNCH: selector prefix:", selector_prefix)
  LaunchLog("LAUNCH: argv0 selector:", argv0_selector)
  if policy.name == "HDD" then
    LaunchLog("HDD LAUNCH argv0: ["..tostring(argv0_selector).."]")
  end
  LaunchLog("LAUNCH: loadELF argc (caller):", #argv)
  if fallback_bootparam ~= nil then
    LaunchLog("LAUNCH: bootparam fallback:", fallback_bootparam, "exists:", tostring(fallback_exists))
  end
  LOG("Resolved game path:", vcd_path)
  local context = {
    device_page = device_page,
    device_mode = device_mode,
    ui_scene = ui_scene or (UI and UI.CURSCENE or "unknown"),
    source_mode = source_mode,
    raw_source_mode = raw_source_mode,
    gamelocation = gamelocation,
    handoff_gamelocation = handoff_gamelocation,
    game = vcd_basename_raw,
    vcd_path = vcd_path,
    bootparam = bootparam,
    bootparam_prefix_required = prefix,
    bootparam_prefix_used = prefix_used,
    bootparam_prefix_added = prefix_added,
    bootparam_root = pops_root,
    bootparam_basename_raw = vcd_basename_raw,
    bootparam_basename_prefixed = normalized_basename,
    bootparam_basename = bootparam_basename_used,
    argv0_selector = argv0_selector,
    game_name = game_name,
    bootparam_source = boot_source_mode,
    hdd_init = hdd_init
  }
  local reboot_iop = PLDR.REBOOT_IOP_WHILE_LOADING_POPSTARTER
  if policy.name == "HDD" then
    reboot_iop = 0
  end
  LaunchEngine(popstarter, argv, reboot_iop, context)
end

---MAIN PROGRAM BEHAVIOUR BEGINS
local initial_scene = UI.SCENES.CREDITS
UI.WelcomeDraw.Play(initial_scene)
if UI.Transition ~= nil then
  UI.Transition.allowSceneWrite = true
end
UI.CURSCENE = initial_scene
UI.LASTSCENE = initial_scene
if UI.Transition ~= nil then
  UI.Transition.allowSceneWrite = false
end
if UI.Credits ~= nil and UI.Credits.PlayBootSequence ~= nil then
  UI.Credits.PlayBootSequence(4000)
end
if UI.Transition ~= nil then
  UI.Transition.allowSceneWrite = true
end
UI.CURSCENE = UI.SCENES.MMAIN
UI.LASTSCENE = UI.SCENES.MMAIN
if UI.Transition ~= nil then
  UI.Transition.allowSceneWrite = false
end
if UI.BootFadeInScene ~= nil then
  UI.BootFadeInScene(UI.SCENES.MMAIN, 24)
end

while true do
  UI.BottomDraw.Play()
  if UI.CURSCENE == UI.SCENES.MMAIN then
    UI.MainMenu.Play()
  elseif UI.CURSCENE == UI.SCENES.MPROFILE then
    UI.ProfileQuery.Play()
  elseif UI.IsGameScene(UI.CURSCENE) then
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
