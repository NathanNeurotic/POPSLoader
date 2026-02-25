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

local SETTINGS_DIR = "mc0:/POPSTARTER/"
local SETTINGS_FILE = SETTINGS_DIR.."settings.lua"
local SESSION_STAMP_FILE = SETTINGS_DIR..".pldrs"
local WARN_ONCE = {}
local PENDING_NOTIFS = {}

local function NotifyOnce(key, msg)
  if WARN_ONCE[key] then
    return
  end
  WARN_ONCE[key] = true
  if UI ~= nil and UI.Notif_queue ~= nil and UI.Notif_queue.add ~= nil then
    UI.Notif_queue.add(msg)
  else
    table.insert(PENDING_NOTIFS, msg)
  end
end

local function FlushPendingNotifications()
  if UI == nil or UI.Notif_queue == nil or UI.Notif_queue.add == nil then
    return
  end
  for i = 1, #PENDING_NOTIFS do
    UI.Notif_queue.add(PENDING_NOTIFS[i])
  end
  PENDING_NOTIFS = {}
end

local function EnsureDirectory(path)
  if doesFolderExist(path) then
    return true
  end
  local ok, _ = pcall(System.createDirectory, path)
  return ok
end

local function EnsureParentDirectory(path)
  if type(path) ~= "string" then
    return false
  end
  local parent = string.match(path, "^(.*)/[^/]+$")
  if parent == nil or parent == "" then
    return true
  end
  return EnsureDirectory(parent.."/")
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

HDD_DIAG_BYPASS = 0
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
    EXTRAPARTS = {[0]=false, false, false, false, false, false, false, false, false, false};
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
  MX4SIO = {
    READY = false,
    ROOT = nil,
    PREFIX_HINT = nil,
    MASSINDX = nil
  },
  MMCE = {
    PROBED = false,
    PREFIX = nil,
    SLOTS = {},
    INDEX = 1
  },
  SETTINGS = {
    bdma_mode = 1,
    hide_ui = false,
    show_cover = true,
    profile_index = nil,
    bdma_last_label = nil,
    dkwdrv_path = "mc0:/PS1_DKWDRV/DKWDRV.ELF"
  }
}

function PLDR.ResolvePopstarterPath(path)
  return ResolvePopstarterPath(path)
end

-- Mass backend detection via USBMASS_IOCTL_GET_DRIVERNAME (requires fileXio + ps2sdk usbhdfsd-common.h support).
-- Returns a short driver code like: "usb" (USB), "sdc" (MX4SIO SD), "udp" (UDPBD), "sd" (iLink SD), "ata" (HDD).
function PLDR.GetMassDriverName(index)
  if System == nil or System.getMassDriverName == nil then
    return nil
  end
  local ok, name = pcall(System.getMassDriverName, index)
  if not ok then
    return nil
  end
  if type(name) ~= "string" or name == "" then
    return nil
  end
  return name
end

function PLDR.FindMassByDriver(driver, max_index)
  local want = type(driver) == "string" and driver or nil
  if want == nil then
    return nil
  end
  local max = tonumber(max_index) or 4
  if max < 0 then max = 0 end
  if max > 9 then max = 9 end
  for i = 0, max do
    local name = PLDR.GetMassDriverName(i)
    if name == want then
      return i
    end
  end
  return nil
end

function PLDR.DetectMassBackends()
  -- Default behavior: keep existing MASSINDX unless we can positively detect a better one.
  local usb = PLDR.FindMassByDriver("usb", 4)
  if usb ~= nil then
    PLDR.USB.MASSINDX = usb
  end
  local mx = PLDR.FindMassByDriver("sdc", 4)
  if mx ~= nil then
    PLDR.MX4SIO.MASSINDX = mx
  else
    PLDR.MX4SIO.MASSINDX = nil
  end
end

-- Run detection once during boot.
PLDR.DetectMassBackends()
PLDR.DEFAULT_DKWDRV_PATH = "mc0:/PS1_DKWDRV/DKWDRV.ELF"
local BDMA_MODES = {
  {
    label = "USBFAT32(None)",
    ext = nil,
    action = "delete"
  },
  {
    label = "USBEXFAT",
    ext = ".usbexfat",
    action = "copy"
  },
  {
    label = "MMCE",
    ext = ".mmce",
    action = "copy"
  },
  {
    label = "MX4SIO",
    ext = ".mx4sio",
    action = "copy"
  }
}

local function LoadSettingsTable(path)
  if path == nil or path == "" then
    return nil, "missing"
  end
  if not doesFileExist(path) then
    return nil, "missing"
  end
  local loader, load_err = loadfile(path)
  if loader == nil then
    LOG("Settings load failed:", load_err)
    return nil, "parse"
  end
  local ok, data = pcall(loader)
  if not ok then
    LOG("Settings exec failed:", data)
    return nil, "parse"
  end
  if type(data) ~= "table" then
    return nil, "parse"
  end
  return data, nil
end

function PLDR.LoadSettings()
  local data, err = LoadSettingsTable(SETTINGS_FILE)
  if type(data) == "table" then
    local mode = tonumber(data.bdma_mode)
    if mode ~= nil then
      PLDR.SETTINGS.bdma_mode = mode
    end
    if type(data.hide_ui) == "boolean" then
      PLDR.SETTINGS.hide_ui = data.hide_ui
    end
    if type(data.show_cover) == "boolean" then
      PLDR.SETTINGS.show_cover = data.show_cover
    end
    local profile_index = tonumber(data.profile_index)
    if profile_index ~= nil then
      PLDR.SETTINGS.profile_index = profile_index
    end
    if type(data.bdma_last_label) == "string" then
      PLDR.SETTINGS.bdma_last_label = data.bdma_last_label
    end
    if type(data.dkwdrv_path) == "string" and data.dkwdrv_path ~= "" then
      PLDR.SETTINGS.dkwdrv_path = data.dkwdrv_path
    end
  else
    NotifyOnce("settings_load", "Settings unavailable, using defaults")
    if err == "missing" then
      EnsureDirectory(SETTINGS_DIR)
    end
  end
  if PLDR.SETTINGS.bdma_mode == nil then
    PLDR.SETTINGS.bdma_mode = 1
  end
  if PLDR.SETTINGS.hide_ui == nil then
    PLDR.SETTINGS.hide_ui = false
  end
  if PLDR.SETTINGS.show_cover == nil then
    PLDR.SETTINGS.show_cover = true
  end
  if PLDR.SETTINGS.dkwdrv_path == nil or PLDR.SETTINGS.dkwdrv_path == "" then
    PLDR.SETTINGS.dkwdrv_path = PLDR.DEFAULT_DKWDRV_PATH
  end
  local count = PLDR.GetBDMAModeCount()
  if PLDR.SETTINGS.bdma_mode < 1 or PLDR.SETTINGS.bdma_mode > count then
    PLDR.SETTINGS.bdma_mode = 1
  end
end

function PLDR.SaveSettings()
  EnsureDirectory(SETTINGS_DIR)
  local path = SETTINGS_FILE
  local tmp_path = path..".tmp"
  local fd = System.openFile(tmp_path, FCREATE)
  if fd == nil or fd < 0 then
    NotifyOnce("settings_save", "Failed to save settings")
    Touch(SESSION_STAMP_FILE, "pldrs_create")
    return
  end
  local mode = tonumber(PLDR.SETTINGS.bdma_mode) or 1
  local hide_ui = PLDR.SETTINGS.hide_ui == true
  local show_cover = PLDR.SETTINGS.show_cover ~= false
  local profile_index = tonumber(PLDR.SETTINGS.profile_index)
  local bdma_last_label = PLDR.SETTINGS.bdma_last_label
  local dkwdrv_path = PLDR.SETTINGS.dkwdrv_path or PLDR.DEFAULT_DKWDRV_PATH
  local line = "return {\n"
    ..string.format("  bdma_mode = %d,\n", mode)
    ..string.format("  hide_ui = %s,\n", tostring(hide_ui))
    ..string.format("  show_cover = %s,\n", tostring(show_cover))
    ..string.format("  profile_index = %s,\n", profile_index ~= nil and tostring(profile_index) or "nil")
    ..string.format("  bdma_last_label = %s,\n", bdma_last_label ~= nil and string.format("%q", bdma_last_label) or "nil")
    ..string.format("  dkwdrv_path = %s,\n", dkwdrv_path ~= nil and string.format("%q", dkwdrv_path) or "nil")
    .."}\n"
  local wr = System.writeFile(fd, line, #line)
  System.closeFile(fd)
  if wr == nil or wr < 0 then
    pcall(System.removeFile, tmp_path)
    NotifyOnce("settings_save", "Failed to save settings")
    Touch(SESSION_STAMP_FILE, "pldrs_create")
    return
  end
  local ok_rename, rename_rc = pcall(System.rename, tmp_path, path)
  if (not ok_rename) or (type(rename_rc) == "number" and rename_rc < 0) then
    pcall(System.removeFile, path)
    ok_rename, rename_rc = pcall(System.rename, tmp_path, path)
  end
  if (not ok_rename) or (type(rename_rc) == "number" and rename_rc < 0) then
    pcall(System.removeFile, tmp_path)
    NotifyOnce("settings_save", "Failed to save settings")
  end
  Touch(SESSION_STAMP_FILE, "pldrs_create")
end

function PLDR.GetBDMAModeCount()
  return #BDMA_MODES
end

function PLDR.GetBDMAModeText(mode)
  local entry = BDMA_MODES[mode or PLDR.SETTINGS.bdma_mode or 1]
  if entry == nil then
    entry = BDMA_MODES[1]
  end
  return entry.label
end

function PLDR.SetBDMAMode(mode)
  local count = PLDR.GetBDMAModeCount()
  local value = tonumber(mode) or 1
  if value < 1 then value = 1 end
  if value > count then value = count end
  if PLDR.SETTINGS.bdma_mode ~= value then
    PLDR.SETTINGS.bdma_mode = value
    LOG("BDMA mode set to: "..PLDR.GetBDMAModeText(value))
  end
end

function PLDR.GetBDMAMode()
  return tonumber(PLDR.SETTINGS.bdma_mode) or 1
end

function PLDR.GetBDMADetectedLabel()
  if not doesFolderExist("mc0:/POPSTARTER/") then
    return "NONE"
  end
  if type(PLDR.SETTINGS.bdma_last_label) == "string" and PLDR.SETTINGS.bdma_last_label ~= "" then
    return PLDR.SETTINGS.bdma_last_label
  end
  return "UNKNOWN"
end

function PLDR.ApplyProfileSetting()
  local default_profile = tonumber(PLDR.DEFAULT_PROFILE) or 1
  local index = tonumber(PLDR.SETTINGS.profile_index)
  if index == nil then
    index = default_profile
  end
  if index < 1 or index > #PLDR.PROFILES then
    index = default_profile
  end
  PLDR.SETTINGS.profile_index = index
  if PLDR.PROFILES[index] ~= nil and PLDR.PROFILES[index].ELF ~= nil then
    PLDR.POPSTARTER_PATH = ResolvePopstarterPath(PLDR.PROFILES[index].ELF)
  else
    PLDR.POPSTARTER_PATH = ResolvePopstarterPath(PLDR.POPSTARTER_PATH)
  end
end

local function StripSuffixCaseInsensitive(name, suffix)
  if name == nil or suffix == nil then
    return nil
  end
  local lower_name = string.lower(name)
  local lower_suffix = string.lower(suffix)
  if string.sub(lower_name, -#lower_suffix) ~= lower_suffix then
    return nil
  end
  return string.sub(name, 1, #name - #suffix)
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

PLDR.LoadSettings()

require("pops_profiles")
if PLDR.ApplyProfileSetting ~= nil then
  PLDR.ApplyProfileSetting()
end
local ok_ui, ui_or_err = pcall(require, "ui")
if not ok_ui then
  local traceback = ui_or_err
  if debug ~= nil and debug.traceback ~= nil then
    traceback = debug.traceback(ui_or_err, 2)
  end
  error("UI module failed to load (expected ui.lua to return/set UI): "..tostring(traceback))
end
if ui_or_err ~= nil and ui_or_err ~= true then
  UI = ui_or_err
end
if UI == nil then
  error("UI global not initialized (expected ui.lua to return UI or set _G.UI)")
end
UI.LASTSCENE = UI.SCENES.MMAIN
FlushPendingNotifications()

require("images")

local POPSTARTER_PACK_ROOT = "mc0:/POPSTARTER"
local POPSTARTER_PACK_FILES = {
  "usbd.irx",
  "usbhdfsd.irx",
  "icon.sys",
  "list.icn",
  "del.icn"
}
local POPSTARTER_PACKS = {
  USBEXFAT = {
    label = "USB exFAT",
    folder = "USBEXFAT"
  },
  MMCE = {
    label = "MMCE",
    folder = "MMCE"
  },
  MX4SIO = {
    label = "MX4SIO",
    folder = "MX4SIO"
  }
}
for key, pack in pairs(POPSTARTER_PACKS) do
  pack.files = {}
  for i = 1, #POPSTARTER_PACK_FILES do
    local name = POPSTARTER_PACK_FILES[i]
    pack.files[i] = {
      dest = name,
      source = string.format("POPSTARTER/%s/%s", pack.folder, name)
    }
  end
end

local function ResolvePackSource(rel)
  return ResolveAsset(rel) or JoinPath(APP_DIR_LOCAL, rel)
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

function PLDR.ApplyBDMAMode()
  local mode = PLDR.GetBDMAMode()
  local entry = BDMA_MODES[mode] or BDMA_MODES[1]
  local label = entry.label
  LOG("BDMA apply start: "..label)
  local ok = true
  if entry.action == "delete" then
    LOG("BDMA delete: mc0:/POPSTARTER/")
    if doesFolderExist("mc0:/POPSTARTER/") then
      local rm_ok, rm_err = RemoveDirectoryRecursive("mc0:/POPSTARTER/")
      if not rm_ok then
        LOG("BDMA delete failed:", rm_err)
        ok = false
      end
      local dir_ok, dir_err = pcall(System.removeDirectory, "mc0:/POPSTARTER/")
      if not dir_ok then
        LOG("BDMA remove dir failed:", dir_err)
        ok = false
      end
    end
  else
    local dest_root = NormalizeDirPath("mc0:/POPSTARTER/")
    if not EnsureDirectory(dest_root) then
      ok = false
    end
    local source_root = NormalizeDirPath(APP_DIR_LOCAL)
    local ok_list, entries = pcall(System.listDirectory, source_root)
    if not ok_list or entries == nil then
      LOG("BDMA list failed:", source_root, entries)
      ok = false
    else
      local suffix = entry.ext
      for i = 1, #entries do
        local file = entries[i]
        if file ~= nil and not file.directory and file.name ~= nil then
          local dest_name = StripSuffixCaseInsensitive(file.name, suffix)
          if dest_name ~= nil and dest_name ~= "" then
            local src = JoinPath(source_root, file.name)
            local dst = JoinPath(dest_root, dest_name)
            LOG("BDMA copy: "..src.." -> "..dst)
            local ok_copy, copy_err = pcall(System.copyFile, src, dst)
            if not ok_copy then
              LOG("BDMA copy failed:", copy_err)
              ok = false
            end
          end
        end
      end
    end
  end
  LOG("BDMA apply done: "..label.." ("..(ok and "ok" or "fail")..")")
  if ok then
    if entry.action == "delete" then
      PLDR.SETTINGS.bdma_last_label = nil
    else
      PLDR.SETTINGS.bdma_last_label = label
    end
  end
  if ok and UI ~= nil and UI.Notif_queue ~= nil and UI.Notif_queue.add ~= nil then
    UI.Notif_queue.add("BDMA Applied")
  end
  return ok
end

function PLDR.ApplyPopstarterPack(pack_key)
  local pack = POPSTARTER_PACKS[pack_key]
  if pack == nil then
    UI.Notif_queue.add("Unknown POPSTARTER pack: "..tostring(pack_key))
    return false
  end
  if not EnsureDirectory(POPSTARTER_PACK_ROOT) then
    UI.Notif_queue.add("Failed to create "..POPSTARTER_PACK_ROOT)
    return false
  end
  local failures = {}
  for i = 1, #pack.files do
    local file = pack.files[i]
    local source = ResolvePackSource(file.source)
    local dest = POPSTARTER_PACK_ROOT.."/"..file.dest
    if source == nil or not doesFileExist(source) then
      failures[#failures + 1] = file.dest
    else
      local ok, err = pcall(System.copyFile, source, dest)
      if not ok then
        LOG("Copy failed:", source, dest, err)
        failures[#failures + 1] = file.dest
      end
    end
  end
  if #failures > 0 then
    UI.Notif_queue.add("Failed to install "..pack.label.." pack")
    return false
  end
  UI.Notif_queue.add("Installed "..pack.label.." pack to "..POPSTARTER_PACK_ROOT)
  return true
end

function PLDR.ResetPopstarterPack()
  if not doesFolderExist(POPSTARTER_PACK_ROOT) then
    UI.Notif_queue.add("POPSTARTER reset: folder not found")
    return true
  end
  local ok, err = RemoveDirectoryRecursive(POPSTARTER_PACK_ROOT)
  if not ok then
    UI.Notif_queue.add("POPSTARTER reset failed")
    LOG("Reset POPSTARTER failed:", err)
    return false
  end
  local rm_ok, rm_err = pcall(System.removeDirectory, POPSTARTER_PACK_ROOT)
  if not rm_ok then
    UI.Notif_queue.add("POPSTARTER reset failed")
    LOG("Remove POPSTARTER dir failed:", rm_err)
    return false
  end
  UI.Notif_queue.add("POPSTARTER reset: mc0:/POPSTARTER removed")
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
    for i=0, 9 do
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
  for i=0, 9 do
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
  if string.match(gamelocation, "^mx4sio") then
    return BuildLaunchPolicy("MX4SIO", "mx4sio", "mx4sio", nil), "MX4SIO"
  end
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

function PLDR.RunPOPStarterGame(gamelocation, game, ui_scene)
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
    pops_root = "mass:/POPS/"
    boot_source_mode = "mass"
    device_mode = "mass"
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
      game
    )
    bootparam_exists = doesFileExist(bootparam)
    bootparam_basename_used = normalized_basename
    prefix_used = HasBootPrefix(normalized_basename, prefix) and prefix or ""
  end
  local selection_for_name = game
  if policy.name == "HDD" then
    selection_for_name = NormalizeHddRelpath(hdd_relpath or game)
  end
  local game_name = DeriveGameNameFromSelection(selection_for_name)
  local vcd_basename_raw = game
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
  if UI ~= nil and UI.CoverCache ~= nil and UI.CoverCache.Clear ~= nil then
    UI.CoverCache:Clear()
  end
  LaunchEngine(popstarter, argv, reboot_iop, context)
end

function Touch(FILE, warn_key)
  if doesFileExist(FILE) then
    return false
  end
  EnsureParentDirectory(FILE)
  local FD = System.openFile(FILE, FCREATE)
  if FD == nil or FD < 0 then
    NotifyOnce(warn_key or "touch", "Storage not ready")
    return false
  end
  System.closeFile(FD)
  return true
end

---MAIN PROGRAM BEHAVIOUR BEGINS
local initial_scene = UI.SCENES.MMAIN
if Touch(SESSION_STAMP_FILE, "pldrs_create") then
  initial_scene = UI.SCENES.CREDITS
end
UI.WelcomeDraw.Play(initial_scene)
if UI.Transition ~= nil then
  UI.Transition.allowSceneWrite = true
end
UI.CURSCENE = UI.SCENES.MMAIN
UI.LASTSCENE = UI.SCENES.MMAIN
if UI.Transition ~= nil then
  UI.Transition.allowSceneWrite = false
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
