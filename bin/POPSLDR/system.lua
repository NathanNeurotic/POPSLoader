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
_G.PLDR = _G.PLDR or {}
PLDR = _G.PLDR
local BOOT_PATH_RAW = System.currentDirectory()
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

local function NormalizeFsPathRaw(path)
  if path == nil then return "" end
  local normalized = string.gsub(path, "\\", "/")
  if string.match(normalized, "^host:") and not string.match(normalized, "^host:/") then
    normalized = "host:/"..string.sub(normalized, 6)
  end
  local prefix = ""
  if string.match(normalized, "^host:/") then
    prefix = "host:/"
    normalized = string.sub(normalized, 7)
  end
  normalized = string.gsub(normalized, "/+", "/")
  return prefix..normalized
end

local function EnsureTrailingSlashNormRaw(path)
  local normalized = NormalizeFsPathRaw(path)
  normalized = string.gsub(normalized, "/+$", "")
  return normalized.."/"
end

function NormalizeDirPath(path)
  if path == nil or path == "" then return "" end
  local normalized = NormalizeFsPathRaw(path)
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

local APP_DIR_LOCAL = EnsureTrailingSlashNormRaw(APP_DIR or System.currentDirectory() or "")
APP_DIR_NORM = APP_DIR_LOCAL
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

local function IsMassPath(path)
  return path ~= nil and string.match(path, "^mass%d*:/") ~= nil
end

function PLDR.EnsureMmceReadyOnce()
  if PLDR._mmce_ready then
    return true
  end

  if type(_G.ensureMmceInit) == "function" then
    pcall(_G.ensureMmceInit)
  end
  if type(System) == "table" and type(System.initMMCE) == "function" then
    pcall(System.initMMCE)
  end

  PLDR._mmce_ready = true
  return true
end

function PLDR.PopstarterProbeWithEnsure(path)
  local function probe(p)
    local candidate = tostring(p or "")
    if candidate == "" then
      return false
    end
    local ok, fd_or_err = pcall(System.openFile, candidate, FREAD)
    if ok and type(fd_or_err) == "number" and fd_or_err >= 0 then
      System.closeFile(fd_or_err)
      return true
    end
    local exists_ok, exists = pcall(doesFileExist, candidate)
    return exists_ok and exists == true
  end

  local candidate = tostring(path or "")
  local low = string.lower(candidate)
  local is_mass = low:find("^mass") ~= nil
  local is_mmce = low:find("^mmce") ~= nil

  for pass = 1, 2 do
    if probe(candidate) then
      return true
    end
    if pass == 1 then
      if is_mass then
        if type(PLDR) == "table" and type(PLDR.EnsureUsbMassReadyOnce) == "function" then
          pcall(PLDR.EnsureUsbMassReadyOnce)
        end
      elseif is_mmce then
        if type(PLDR) == "table" and type(PLDR.EnsureMmceReadyOnce) == "function" then
          pcall(PLDR.EnsureMmceReadyOnce)
        end
      end
    end
  end
  return false
end

local function ResolvePopstarterPath(path)
  local chosen = path
  if chosen == nil or chosen == "" then
    chosen = JoinPath(APP_DIR_LOCAL, "POPSTARTER.ELF")
  elseif not IsAbsoluteDevicePath(chosen) then
    chosen = JoinPath(APP_DIR_LOCAL, chosen)
  end
  if PLDR.PopstarterProbeWithEnsure(chosen) then
    return chosen
  end

  local fallbacks = {
    JoinPath(APP_DIR_LOCAL, "POPSTARTER.ELF"),
    "mc0:/POPSTARTER/POPSTARTER.ELF",
    "mc1:/POPSTARTER/POPSTARTER.ELF"
  }
  for i = 1, #fallbacks do
    local candidate = fallbacks[i]
    if candidate ~= chosen and PLDR.PopstarterProbeWithEnsure(candidate) then
      return candidate
    end
  end

  return chosen
end

local function ResolveIrx(name)
  return System.resolveAssetType(name, ASSET_IRX) or JoinPath(APP_DIR_LOCAL, name)
end

function PLDR.ResolvePopstarterPath(path)
  return ResolvePopstarterPath(path)
end

local function DetectBootDevice()
  local boot_path = NormalizeDirPath(BOOT_PATH_RAW or "")
  local prefix = string.match(boot_path, "^([%a]+%d*):")
  if prefix == nil then
    return nil, boot_path, prefix
  end
  if string.match(prefix, "^mmce%d*$") then
    return "MMCE", boot_path, prefix
  end
  if string.match(prefix, "^mx4sio%d*$") then
    return "MX4SIO", boot_path, prefix
  end
  if string.match(prefix, "^mass%d*$") then
    local mx_marker = JoinPath(APP_DIR_LOCAL, ".boot_mx4sio")
    local usb_marker = JoinPath(APP_DIR_LOCAL, ".boot_usb")
    if doesFileExist(mx_marker) then
      return "MX4SIO", boot_path, prefix
    end
    if doesFileExist(usb_marker) then
      return "USB", boot_path, prefix
    end
  end
  return nil, boot_path, prefix
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
local pldr_defaults = {
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
  MX4SIO = {
    READY = false,
    ROOT = nil,
    MASSINDX = nil,
    IS_MASS_ALIAS = false,
    PREFIX_HINT = nil
  },
  MMCE = {
    PROBED = false,
    PREFIX = nil,
    SLOTS = {},
    INDEX = 1
  }
}
for k, v in pairs(pldr_defaults) do
  if PLDR[k] == nil then
    PLDR[k] = v
  end
end

local function ParseMassIndexFromRoot(root)
  if type(root) ~= "string" then return nil end
  if string.match(root, "^mass:/") then
    return 0
  end
  local idx = string.match(root, "^mass(%d+):/")
  if idx ~= nil then
    return tonumber(idx)
  end
  return nil
end

function PLDR.SetMX4SIORoot(root)
  PLDR.MX4SIO.ROOT = root
  local idx = ParseMassIndexFromRoot(root)
  PLDR.MX4SIO.MASSINDX = idx
  PLDR.MX4SIO.IS_MASS_ALIAS = (idx ~= nil)
  PLDR.MX4SIO.READY = (root ~= nil)
  return root
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
  else
  end
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

require("pops_profiles")
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

if UI.DEVLOCK ~= nil then
  local boot_name, boot_path, boot_prefix = DetectBootDevice()
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
  else
  end
end
require("images")

PLDR.POPSTARTER_DIR = "mc0:/POPSTARTER"
PLDR.SETTINGS_PATH = "mc0:/POPSTARTER/.pldrs"
PLDR.BDMA_MODE_KEY = "FAT32"
PLDR.SELECTED_PROFILE = tonumber(PLDR.DEFAULT_PROFILE) or 1

local POPSTARTER_PACK_ROOT = PLDR.POPSTARTER_DIR
local BDMA_MODE_MARKER_PATH = POPSTARTER_PACK_ROOT.."/.pldr_bdma_mode"
local BDMA_COPY_FILES = {
  "usbd.irx",
  "usbhdfsd.irx"
}
local BDMA_UI_FILES = {
  { src = "icon.sys.bdma", dst = "icon.sys" },
  { src = "list.icn.bdma", dst = "list.icn" },
  { src = "del.icn.bdma", dst = "del.icn" }
}
local BDMA_SUFFIX = {
  USBEXFAT = ".usbexfat",
  MX4SIO = ".mx4sio",
  MMCE = ".mmce"
}

PLDR.MASS = PLDR.MASS or {
  CACHE = {},
  ORDER = {},
  REFRESHED = false
}

PLDR._bdma_apply_guard = PLDR._bdma_apply_guard or { in_progress = false, last_token = nil }
PLDR._bdma_apply_seq = PLDR._bdma_apply_seq or 0

local function ReadWholeFile(path)
  local ok_open, fd = pcall(System.openFile, path, FREAD)
  if not ok_open or fd == nil or (type(fd) == "number" and fd < 0) then
    return nil, "open failed"
  end
  local chunks = {}
  local ok = true
  while true do
    local ok_read, buffer = pcall(System.readFile, fd, 32768)
    if not ok_read then
      ok = false
      break
    end
    if buffer == nil or buffer == "" then
      break
    end
    chunks[#chunks + 1] = buffer
  end
  pcall(System.closeFile, fd)
  if not ok then
    return nil, "read failed"
  end
  return table.concat(chunks)
end

local function WriteAtomic(dest, data)
  local tmp = dest..".tmp"
  if doesFileExist(tmp) then
    pcall(System.removeFile, tmp)
  end
  local ok_open, fd = pcall(System.openFile, tmp, FCREATE)
  if not ok_open or fd == nil or (type(fd) == "number" and fd < 0) then
    return false
  end
  local total = string.len(data)
  local offset = 1
  while offset <= total do
    local chunk = string.sub(data, offset, math.min(offset + 32768 - 1, total))
    local ok_write = pcall(System.writeFile, fd, chunk, string.len(chunk))
    if not ok_write then
      pcall(System.closeFile, fd)
      pcall(System.removeFile, tmp)
      return false
    end
    offset = offset + string.len(chunk)
  end
  pcall(System.closeFile, fd)
  if doesFileExist(dest) then
    pcall(System.removeFile, dest)
  end
  local ok = pcall(System.rename, tmp, dest)
  if not ok then
    pcall(System.removeFile, tmp)
    return false
  end
  return true
end

local function CopyExternalAtomic(source, dest)
  local tmp = dest..".tmp"
  if doesFileExist(tmp) then
    pcall(System.removeFile, tmp)
  end

  local ok_src, src_fd = pcall(System.openFile, source, FREAD)
  if not ok_src or src_fd == nil or (type(src_fd) == "number" and src_fd < 0) then
    return false, "open source failed"
  end

  local ok_dst, dst_fd = pcall(System.openFile, tmp, FCREATE)
  if not ok_dst or dst_fd == nil or (type(dst_fd) == "number" and dst_fd < 0) then
    pcall(System.closeFile, src_fd)
    return false, "open destination failed"
  end

  local copied = true
  while true do
    local ok_read, chunk = pcall(System.readFile, src_fd, 32768)
    if not ok_read then
      copied = false
      break
    end
    if chunk == nil or chunk == "" then
      break
    end
    local chunk_len = string.len(chunk)
    local ok_write, wrote = pcall(System.writeFile, dst_fd, chunk, chunk_len)
    if not ok_write or type(wrote) ~= "number" or wrote ~= chunk_len then
      copied = false
      break
    end
  end

  pcall(System.closeFile, src_fd)
  pcall(System.closeFile, dst_fd)

  if not copied then
    pcall(System.removeFile, tmp)
    return false, "copy failed"
  end

  if doesFileExist(dest) then
    pcall(System.removeFile, dest)
  end
  local ok_rename = pcall(System.rename, tmp, dest)
  if not ok_rename then
    pcall(System.removeFile, tmp)
    return false, "rename failed"
  end
  return true
end


local function GetFileSizeSafe(path)
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

local function CopyExternalAtomicBounded(source, dest, expected_size)
  local tmp = dest..".tmp"
  if doesFileExist(tmp) then
    pcall(System.removeFile, tmp)
  end

  local ok_src, src_fd = pcall(System.openFile, source, FREAD)
  if not ok_src or src_fd == nil or (type(src_fd) == "number" and src_fd < 0) then
    return false, "open source failed"
  end

  local expected = nil
  if type(expected_size) == "number" and expected_size > 0 then
    expected = expected_size
  else
    local ok_size, size_val = pcall(System.sizeFile, src_fd)
    if ok_size and type(size_val) == "number" and size_val > 0 then
      expected = size_val
    end
  end

  local ok_dst, dst_fd = pcall(System.openFile, tmp, FCREATE)
  if not ok_dst or dst_fd == nil or (type(dst_fd) == "number" and dst_fd < 0) then
    pcall(System.closeFile, src_fd)
    return false, "open destination failed"
  end

  local copied = true
  local copied_bytes = 0
  local iters = 0
  local MAX_ITERS = 4096
  local max_bytes = (expected or 0) + 65536
  if max_bytes < 65536 then
    max_bytes = 65536
  end

  while true do
    iters = iters + 1
    if iters > MAX_ITERS then
      copied = false
      break
    end
    if expected ~= nil and copied_bytes >= expected then
      break
    end

    local before = copied_bytes
    local ok_read, chunk = pcall(System.readFile, src_fd, 32768)
    if not ok_read then
      copied = false
      break
    end
    if chunk == nil or chunk == "" then
      break
    end

    local chunk_len = string.len(chunk)
    local ok_write, wrote = pcall(System.writeFile, dst_fd, chunk, chunk_len)
    if not ok_write or type(wrote) ~= "number" then
      copied = false
      break
    end
    if wrote <= 0 then
      copied = false
      break
    end

    copied_bytes = copied_bytes + wrote
    if copied_bytes == before then
      copied = false
      break
    end
    if wrote ~= chunk_len then
      copied = false
      break
    end
    if copied_bytes > max_bytes then
      copied = false
      break
    end
  end

  pcall(System.closeFile, src_fd)
  pcall(System.closeFile, dst_fd)

  if expected ~= nil and copied and copied_bytes < expected then
    copied = false
  end

  if not copied then
    pcall(System.removeFile, tmp)
    return false, "copy failed"
  end

  if doesFileExist(dest) then
    pcall(System.removeFile, dest)
  end
  local ok_rename = pcall(System.rename, tmp, dest)
  if not ok_rename then
    pcall(System.removeFile, tmp)
    return false, "rename failed"
  end
  return true
end


local function WriteBytesAtomicBounded(data, dest)
  if type(data) ~= "string" then
    return false, "invalid data"
  end

  local tmp = dest..".tmp"
  if doesFileExist(tmp) then
    pcall(System.removeFile, tmp)
  end

  local ok_open, fd = pcall(System.openFile, tmp, FCREATE)
  if not ok_open or fd == nil or (type(fd) == "number" and fd < 0) then
    return false, "open destination failed"
  end

  local expected = string.len(data)
  local offset = 1
  local iters = 0
  local MAX_ITERS = 4096
  local wrote_all = true

  while offset <= expected and iters < MAX_ITERS do
    iters = iters + 1
    local chunk = string.sub(data, offset, math.min(offset + 32768 - 1, expected))
    local chunk_len = string.len(chunk)
    local ok_write, wrote = pcall(System.writeFile, fd, chunk, chunk_len)
    if not ok_write or type(wrote) ~= "number" or wrote ~= chunk_len then
      wrote_all = false
      break
    end
    offset = offset + chunk_len
  end

  if offset <= expected then
    wrote_all = false
  end

  pcall(System.closeFile, fd)

  if not wrote_all then
    pcall(System.removeFile, tmp)
    return false, "write failed"
  end

  if doesFileExist(dest) then
    pcall(System.removeFile, dest)
  end
  local ok_rename = pcall(System.rename, tmp, dest)
  if not ok_rename then
    pcall(System.removeFile, tmp)
    return false, "rename failed"
  end
  return true
end



local function EnsureDirectory(path)
  if doesFolderExist(path) then
    return true
  end
  local ok, err = pcall(System.createDirectory, path)
  if not ok then
  end
  return ok
end

function PLDR.EnsurePopstarterDir()
  return EnsureDirectory(PLDR.POPSTARTER_DIR)
end

function PLDR.NormalizeFsPath(p)
  return NormalizeFsPathRaw(p)
end

function PLDR.EnsureTrailingSlashNorm(p)
  return EnsureTrailingSlashNormRaw(p)
end

function PLDR.TryOpenFirst(paths)
  for _, path in ipairs(paths) do
    local ok, fd = pcall(System.openFile, path, FREAD)
    if ok and fd ~= nil and (type(fd) ~= "number" or fd >= 0) then
      return fd, path
    end
  end
  return -1, nil
end

APP_DIR_NORM = PLDR.EnsureTrailingSlashNorm(APP_DIR or System.currentDirectory() or "")
APP_DIR_LOCAL = APP_DIR_NORM

function PLDR.AppDirPath(rel)
  local base = APP_DIR_NORM or ""
  rel = (rel or ""):gsub("\\", "/")
  if rel:sub(1, 1) == "/" then rel = rel:sub(2) end
  return base..rel
end


function PLDR.BdmaSourceCandidates(rel)
  local out = {}
  local base = APP_DIR_NORM or APP_DIR_LOCAL or ""
  rel = (rel or ""):gsub("\\", "/")
  base = base:gsub("\\", "/")
  if base ~= "" and base:sub(-1) ~= "/" then
    base = base.."/"
  end

  if base:sub(1, 5) == "host:" then
    table.insert(out, "host:./"..rel)
    table.insert(out, "host:"..rel)
    table.insert(out, base..rel)
  else
    table.insert(out, base..rel)
  end
  return out
end

local function EncodeSettings()
  local lines = {
    "PROFILE="..tostring(tonumber(PLDR.SELECTED_PROFILE) or 1),
    "POPSTARTER_PATH="..tostring(PLDR.POPSTARTER_PATH or ""),
    "BDMA="..tostring(PLDR.BDMA_MODE_KEY or "FAT32")
  }
  return table.concat(lines, "\n").."\n"
end

function PLDR.SaveSettingsAtomic()
  PLDR.EnsurePopstarterDir()
  local data = EncodeSettings()
  local ok = WriteAtomic(PLDR.SETTINGS_PATH, data)
  if not ok and UI ~= nil and UI.Notif_queue ~= nil then
    UI.Notif_queue.add("Failed to save settings")
  end
  return ok
end

function PLDR.LoadSettingsNonFatal()
  local defaults_profile = tonumber(PLDR.DEFAULT_PROFILE) or 1
  PLDR.SELECTED_PROFILE = defaults_profile
  PLDR.BDMA_MODE_KEY = "FAT32"
  if PLDR.PROFILES ~= nil and PLDR.PROFILES[defaults_profile] ~= nil then
    PLDR.POPSTARTER_PATH = PLDR.PROFILES[defaults_profile].ELF
  end
  if not doesFileExist(PLDR.SETTINGS_PATH) then
    return false
  end
  local data = ReadWholeFile(PLDR.SETTINGS_PATH)
  if data == nil then
    return false
  end
  local profile = tonumber(string.match(data, "\nPROFILE=([^\n]+)")) or tonumber(string.match(data, "^PROFILE=([^\n]+)"))
  local popstarter_path = string.match(data, "\nPOPSTARTER_PATH=([^\n]*)") or string.match(data, "^POPSTARTER_PATH=([^\n]*)")
  local bdma_mode = string.match(data, "\nBDMA=([^\n]+)") or string.match(data, "^BDMA=([^\n]+)") or string.match(data, "\nBDMA_MODE=([^\n]+)") or string.match(data, "^BDMA_MODE=([^\n]+)")
  if profile ~= nil and PLDR.PROFILES ~= nil and PLDR.PROFILES[profile] ~= nil then
    PLDR.SELECTED_PROFILE = profile
    PLDR.POPSTARTER_PATH = PLDR.PROFILES[profile].ELF
  end
  if popstarter_path ~= nil and popstarter_path ~= "" then
    PLDR.POPSTARTER_PATH = popstarter_path
  end
  if bdma_mode == "FAT32" or bdma_mode == "USBEXFAT" or bdma_mode == "MX4SIO" or bdma_mode == "MMCE" then
    PLDR.BDMA_MODE_KEY = bdma_mode
  end
  return true
end

function PLDR.ParseMassIndexFromPath(path)
  local source = NormalizeDirPath(path or APP_DIR_NORM)
  local index = string.match(source, "^mass(%d+):/")
  if index ~= nil then
    return tonumber(index)
  end
  if string.match(source, "^mass:/") then
    return 0
  end
  return nil
end

function PLDR.GetMassDriverName(index)
  if index == nil then return nil end
  local cached = PLDR.MASS.CACHE[index]
  if cached ~= nil and cached.driver ~= nil then
    return cached.driver
  end
  if type(System) == "table" then
    if type(System.getMassDriverName) == "function" then
      local ok, driver = pcall(System.getMassDriverName, index)
      if ok and type(driver) == "string" and driver ~= "" then
        return string.lower(driver)
      end
    end
    if type(System.getMassDriver) == "function" then
      local ok, driver = pcall(System.getMassDriver, index)
      if ok and type(driver) == "string" and driver ~= "" then
        return string.lower(driver)
      end
    end
    if type(System.getMassBackendInfo) == "function" then
      local ok, info = pcall(System.getMassBackendInfo, index)
      if ok and type(info) == "table" then
        local driver = info.driver
        if type(driver) == "string" and driver ~= "" then
          return string.lower(driver)
        end
      end
    end
  end
  return nil
end

local function GetPresentMassRootsWithAliasRule()
  local present_roots = PLDR.GetPresentMassRootsBounded()
  local normalized_roots = {}
  local seen = {}
  for i = 1, #present_roots do
    local root = present_roots[i]
    local slot = PLDR.ParseMassIndexFromPath(root)
    if slot == 0 then
      root = "mass:/"
    end
    if root ~= nil and not seen[root] then
      table.insert(normalized_roots, root)
      seen[root] = true
    end
  end
  return normalized_roots
end

local function BuildMassRootIdentity()
  if type(PLDR.InvalidateMassBackends) == "function" then
    pcall(PLDR.InvalidateMassBackends)
  end
  if type(PLDR.RefreshMassBackends) == "function" then
    pcall(PLDR.RefreshMassBackends)
  end

  local present_roots = GetPresentMassRootsWithAliasRule()
  local present_slots = {}
  for i = 1, #present_roots do
    local slot = PLDR.ParseMassIndexFromPath(present_roots[i])
    if type(slot) == "number" and slot >= 0 and slot <= 9 then
      present_slots[slot] = true
    end
  end

  local slot_driver = {}
  if type(System) == "table" and type(System.getMassBackendInfo) == "function" then
    for backend = 0, 15 do
      local ok, info = pcall(System.getMassBackendInfo, backend)
      if ok and type(info) == "table" then
        local parId = info.parId
        local drv = info.driver or info.name
        if type(drv) == "string" and drv ~= "" then
          drv = string.lower(drv)
        else
          drv = nil
        end
        if type(parId) == "number" and parId >= 0 and parId <= 9 and drv ~= nil and slot_driver[parId] == nil then
          slot_driver[parId] = drv
        end
      end
    end
  end

  local identity = {
    usb = {},
    mx4sio = {},
    slot_driver = slot_driver,
    present_roots = present_roots
  }

  for i = 1, #present_roots do
    local root = present_roots[i]
    local slot = PLDR.ParseMassIndexFromPath(root)
    local drv = nil
    if type(slot) == "number" and slot >= 0 and slot <= 9 and present_slots[slot] then
      drv = slot_driver[slot]
    end
    if drv ~= nil and string.find(drv, "sdc", 1, true) then
      table.insert(identity.mx4sio, root)
    elseif drv ~= nil then
      table.insert(identity.usb, root)
    end
  end

  return identity
end

function PLDR.GetMX4SIOMassRootNow()
  local identity = BuildMassRootIdentity()
  return identity.mx4sio[1] or nil
end

function PLDR.RefreshMassBackends()
  if type(System) == "table" and type(System.refreshMassBackends) == "function" then
    local ok, res = pcall(System.refreshMassBackends)
    return ok and (res == nil or res == true)
  end
  return true
end

function PLDR.EnsureUsbMassReadyOnce()
  if PLDR._usb_mass_ready then
    return true
  end

  if type(System) == "table" and type(System.ensureUsbMass) == "function" then
    pcall(System.ensureUsbMass)
  elseif type(System) == "table" and type(System.initUSBMass) == "function" then
    pcall(System.initUSBMass)
  end
  if type(System) == "table" and type(System.initUSB) == "function" then
    pcall(System.initUSB)
  end
  if type(PLDR.RefreshMassStateSnapshot) == "function" then
    pcall(PLDR.RefreshMassStateSnapshot)
  elseif type(PLDR.RefreshMassBackends) == "function" then
    pcall(PLDR.RefreshMassBackends)
  end

  PLDR._usb_mass_ready = true
  return true
end

function PLDR.InvalidateMassBackends()
  PLDR.MASS.CACHE = {}
  PLDR.MASS.ORDER = {}
  PLDR.MASS.REFRESHED = false
end

function PLDR.RefreshMassStateSnapshot()
  local identity = BuildMassRootIdentity()
  return {
    mx4_root = identity.mx4sio[1],
    mx4_roots = identity.mx4sio,
    usb_roots = identity.usb
  }
end

function PLDR.GetPresentMassRootsBounded()
  local roots = {}
  for i = 0, 9 do
    local root = (i == 0) and "mass:/" or ("mass"..i..":/")
    if doesFolderExist(root) then
      table.insert(roots, root)
    end
  end
  return roots
end

function PLDR.GetRootsByType(kind, mass_snapshot)
  local wanted = string.lower(tostring(kind or ""))
  local identity = BuildMassRootIdentity()

  if wanted == "usb" then
    return identity.usb
  elseif wanted == "mx4sio" then
    return identity.mx4sio
  end
  return {}
end

function PLDR.EnsureBackendForAppDir()
  local path = APP_DIR_NORM
  if path == nil then return false end
  if string.match(path, "^host:/") then
    return true
  end
  if string.match(path, "^mmce%d*:/") then
    if type(System) == "table" and type(System.initMMCE) == "function" then
      local ok = pcall(System.initMMCE)
      return ok
    end
    return true
  end
  if string.match(path, "^mx4sio%d*:/") then
    if type(_G.ensureMx4sioInit) == "function" then
      local ok = pcall(_G.ensureMx4sioInit)
      if ok then return true end
    end
    if type(System) == "table" and type(System.initMX4SIO) == "function" then
      local ok = pcall(System.initMX4SIO)
      return ok
    end
    return true
  end
  if string.match(path, "^mass%d*:/") then
    local identity = BuildMassRootIdentity()
    local present_roots = identity.present_roots or {}
    local normalized_path = NormalizeDirPath(path)
    if string.match(normalized_path, "^mass0:/") then
      normalized_path = "mass:/"..string.sub(normalized_path, 8)
    end
    local matched_root = nil
    for i = 1, #present_roots do
      local root = present_roots[i]
      if string.sub(normalized_path, 1, string.len(root)) == root then
        matched_root = root
        break
      end
    end

    local drv = nil
    if matched_root ~= nil then
      local slot = PLDR.ParseMassIndexFromPath(matched_root)
      if type(slot) == "number" and slot >= 0 and slot <= 9 then
        drv = identity.slot_driver[slot]
      end
    end

    if drv ~= nil and string.find(drv, "sdc", 1, true) then
      if type(_G.ensureMx4sioInit) == "function" then
        local ok = pcall(_G.ensureMx4sioInit)
        if ok then return true end
      end
      if type(System) == "table" and type(System.initMX4SIO) == "function" then
        local ok = pcall(System.initMX4SIO)
        if ok then return true end
      end
    elseif drv ~= nil then
      if type(System) == "table" and type(System.initUSB) == "function" then
        local ok = pcall(System.initUSB)
        if ok then return true end
      end
    end
    return true
  end
  return true
end

local function ReadBdmaModeMarker()
  local marker = ReadWholeFile(BDMA_MODE_MARKER_PATH)
  if marker == nil then
    return nil
  end
  marker = string.gsub(marker, "[\r\n]+", "")
  if marker == "" then
    return nil
  end
  return marker
end

local function WriteBdmaModeMarker(mode_key)
  return WriteAtomic(BDMA_MODE_MARKER_PATH, tostring(mode_key or ""))
end

local function DeleteIfExists(path)
  local exists = false
  local ok_exists, file_exists = pcall(doesFileExist, path)
  if ok_exists and file_exists == true then
    exists = true
  end
  if not exists then
    local ok_open, fd = pcall(System.openFile, path, FREAD)
    if ok_open and type(fd) == "number" and fd >= 0 then
      exists = true
      pcall(System.closeFile, fd)
    end
  end
  if exists then
    pcall(System.removeFile, path)
  end
end

function PLDR.NextBdmaApplyToken()
  PLDR._bdma_apply_seq = (tonumber(PLDR._bdma_apply_seq) or 0) + 1
  return "bdma:"..tostring(PLDR._bdma_apply_seq)
end

function PLDR.ApplyBdmaModeOnce(mode_key, token)
  if PLDR._bdma_apply_guard.in_progress then
    return false, "busy"
  end
  if token ~= nil and PLDR._bdma_apply_guard.last_token == token then
    return true
  end

  PLDR._bdma_apply_guard.in_progress = true
  local ok, res, err = xpcall(function()
    local aok, aerr = PLDR.ApplyBdmaMode(mode_key)
    return aok, aerr
  end, function(e)
    return false, tostring(e)
  end)
  PLDR._bdma_apply_guard.in_progress = false

  if ok and res == true then
    PLDR._bdma_apply_guard.last_token = token
    return true
  end
  return false, err or res or "apply failed"
end

function PLDR.ApplyBdmaMode(mode_key)
  local selected = mode_key or "FAT32"
  if not PLDR.EnsurePopstarterUiAssets() then
    return false
  end
  if not PLDR.EnsurePopstarterDir() then
    if UI ~= nil and UI.Notif_queue ~= nil then
      UI.Notif_queue.add("Cannot access mc0:/POPSTARTER")
    end
    return false
  end

  if selected == "FAT32" then
    DeleteIfExists(POPSTARTER_PACK_ROOT.."/usbd.irx")
    DeleteIfExists(POPSTARTER_PACK_ROOT.."/usbhdfsd.irx")
    WriteBdmaModeMarker(selected)
    return true
  end

  local last_applied = ReadBdmaModeMarker()
  if last_applied == selected then
    return true
  end

  local suffix = BDMA_SUFFIX[selected]
  if suffix == nil then
    if UI ~= nil and UI.Notif_queue ~= nil then
      UI.Notif_queue.add("Unknown BDMA mode: "..tostring(selected))
    end
    return false
  end

  if not PLDR.EnsureBackendForAppDir() then
    if UI ~= nil and UI.Notif_queue ~= nil then
      UI.Notif_queue.add("BDMA source backend not ready:\n"..APP_DIR_NORM)
    end
    return false
  end

  local had_failure = false
  for i = 1, #BDMA_COPY_FILES do
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
          UI.Notif_queue.add("Missing BDMA source (tried):\n"..table.concat(paths, "\n"))
        end
        return false
      end
      local dest = POPSTARTER_PACK_ROOT.."/"..name
      local ok_write, wrote = pcall(WriteBytesAtomicBounded, bytes, dest)
      if not ok_write or not wrote then
        had_failure = true
        return false
      end
    else
      local dest = POPSTARTER_PACK_ROOT.."/"..name
      local src_size = GetFileSizeSafe(source)
      local ok, copied = pcall(CopyExternalAtomicBounded, source, dest, src_size)
      if not ok or not copied then
        had_failure = true
        return false
      end
    end
  end
  if had_failure then
    return false
  end
  WriteBdmaModeMarker(selected)
  return true
end

function PLDR.EnsurePopstarterUiAssets()
  if not PLDR.EnsurePopstarterDir() then
    if UI ~= nil and UI.Notif_queue ~= nil then
      UI.Notif_queue.add("Cannot access mc0:/POPSTARTER")
    end
    return false
  end

  if not PLDR.EnsureBackendForAppDir() then
    if UI ~= nil and UI.Notif_queue ~= nil then
      UI.Notif_queue.add("BDMA source backend not ready:\n"..APP_DIR_NORM)
    end
    return false
  end

  for i = 1, #BDMA_UI_FILES do
    local asset = BDMA_UI_FILES[i]
    local paths = PLDR.BdmaSourceCandidates(asset.src)
    local fd, source = PLDR.TryOpenFirst(paths)
    if fd ~= nil and (type(fd) ~= "number" or fd >= 0) then
      System.closeFile(fd)
    end

    local dest = POPSTARTER_PACK_ROOT.."/"..asset.dst
    if source == nil then
      local bytes = nil
      if type(System) == "table" and type(System.getEmbeddedAsset) == "function" then
        local ok_embedded, embedded = pcall(System.getEmbeddedAsset, asset.src)
        if ok_embedded and embedded ~= nil then
          bytes = embedded
        end
      end
      if bytes == nil then
        if UI ~= nil and UI.Notif_queue ~= nil then
          UI.Notif_queue.add("Missing BDMA UI source (tried):\n"..table.concat(paths, "\n"))
        end
        return false
      end
      local expected = string.len(bytes)
      local current_size = GetFileSizeSafe(dest)
      if current_size == nil or current_size ~= expected then
        local ok_write, wrote = pcall(WriteBytesAtomicBounded, bytes, dest)
        if not ok_write or not wrote then
          return false
        end
      end
    else
      local src_size = GetFileSizeSafe(source)
      local dst_size = GetFileSizeSafe(dest)
      if src_size == nil or dst_size == nil or src_size ~= dst_size then
        local ok_copy, copied = pcall(CopyExternalAtomicBounded, source, dest, src_size)
        if not ok_copy or not copied then
          return false
        end
      end
    end
  end

  return true
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

local function ResolvePackUiSource(name)
  local source = ResolveAsset(name)
  if source ~= nil and doesFileExist(source) then
    return source
  end
  local legacy = JoinPath(APP_DIR_LOCAL, "POPSLDR/"..name)
  if doesFileExist(legacy) then
    return legacy
  end
  return JoinPath(APP_DIR_LOCAL, name)
end

function PLDR.ApplyPopstarterPack(pack_key)
  return PLDR.ApplyBdmaMode(pack_key)
end

function PLDR.ResetPopstarterPack()
  if not doesFolderExist(POPSTARTER_PACK_ROOT) then
    UI.Notif_queue.add("POPSTARTER reset: folder not found")
    return true
  end
  local ok, err = RemoveDirectoryRecursive(POPSTARTER_PACK_ROOT)
  if not ok then
    UI.Notif_queue.add("POPSTARTER reset failed")
    return false
  end
  local rm_ok, rm_err = pcall(System.removeDirectory, POPSTARTER_PACK_ROOT)
  if not rm_ok then
    UI.Notif_queue.add("POPSTARTER reset failed")
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
    return PLDR.MMCE.PREFIX
  end
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
  return PLDR.MMCE.PREFIX
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
  local RET = {}
  local found_smth = false
  if path ~= nil then PLDR.GAMEPATH = path end
  local DIR = System.listDirectory(PLDR.GAMEPATH)
  if DIR ~= nil then
    for i = 1, #DIR do
      if not DIR[i].directory then -- not a folder
        if string.lower(string.sub(DIR[i].name,-4)) == ".vcd" then
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

function PLDR.BuildUsbGameListMulti()
  PLDR.CleanupGameList()
  local roots = PLDR.GetRootsByType("usb")
  local found_any = false
  for i = 1, #roots do
    local root = roots[i].."POPS/"
    local DIR = System.listDirectory(root)
    if DIR ~= nil then
      for j = 1, #DIR do
        local entry = DIR[j]
        if not entry.directory and string.lower(string.sub(entry.name, -4)) == ".vcd" then
          found_any = true
          table.insert(PLDR.GAMES, root.."|"..entry.name)
        end
      end
    end
  end
  if found_any then
    table.sort(PLDR.GAMES, function(a, b)
      local root_a, name_a = string.match(a or "", "^([^|]+)|(.+)$")
      local root_b, name_b = string.match(b or "", "^([^|]+)|(.+)$")
      name_a = name_a or (a or "")
      name_b = name_b or (b or "")
      if name_a == name_b then
        return (root_a or "") < (root_b or "")
      end
      return name_a < name_b
    end)
    return PLDR.GAMES
  end
  return nil
end

function PLDR.RefreshMassBackendsBoundedOnce()
  if PLDR._mass_refreshed_bounded then
    return true
  end

  pcall(PLDR.GetMX4SIOMassRootNow)

  PLDR._mass_refreshed_bounded = true
  return true
end

function PLDR.InitMX4SIOPopsRoot()
  PLDR.MX4SIO.READY = false
  PLDR.MX4SIO.ROOT = nil
  PLDR.MX4SIO.MASSINDX = nil
  PLDR.MX4SIO.IS_MASS_ALIAS = false

  if type(_G.ensureMx4sioInit) == "function" then
    pcall(_G.ensureMx4sioInit)
  end
  if type(System) == "table" and type(System.initMX4SIO) == "function" then
    pcall(System.initMX4SIO)
  end

  local root = PLDR.GetMX4SIOMassRootNow()
  if root ~= nil then
    local pops = root.."POPS/"
    if doesFolderExist(pops) then
      PLDR.SetMX4SIORoot(root)
      return pops
    end
  end

  return nil
end

function PLDR.BuildMassGameListByType(kind, mass_snapshot)
  PLDR.CleanupGameList()
  local roots = PLDR.GetRootsByType(kind, mass_snapshot)
  local found_any = false
  for i = 1, #roots do
    local pops_root = roots[i].."POPS/"
    if doesFolderExist(pops_root) then
      local DIR = System.listDirectory(pops_root)
      if DIR ~= nil then
        for j = 1, #DIR do
          local entry = DIR[j]
          if not entry.directory and string.lower(string.sub(entry.name, -4)) == ".vcd" then
            found_any = true
            table.insert(PLDR.GAMES, pops_root.."|"..entry.name)
          end
        end
      end
    end
  end
  if found_any then
    table.sort(PLDR.GAMES)
    return PLDR.GAMES
  end
  return nil
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
    if HDD.MountPartition("hdd0:__.POPS", 0, FIO_MT_RDONLY) then
      PLDR.HDD.MAINPART = true
      HDD.UMountPartition(0)
    end
    PLDR.HDD.FOUNDANY = PLDR.HDD.MAINPART
    for i=1, 9 do
      if HDD.MountPartition(("hdd0:__.POPS%d"):format(i), 0, FIO_MT_RDONLY) then
        PLDR.HDD.EXTRAPARTS[i] = true
        PLDR.HDD.FOUNDANY = true
        HDD.UMountPartition(0)
      end
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
  local count = #PLDR.GAMES
  for i=0, count do PLDR.GAMES[i]=nil end
end

function PLDR.HDD.CreateCache()
  if not PLDR.HDD.USECACHE then return end
  local C = ResolveWritablePath("hdd_gamecache.lua")
  local temp = "PLDR.HDDCACHE = {\n"
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
  local C = ResolveWritablePath("hdd_gamecache.lua")
  if doesFileExist(C) then
    local loader, load_err = loadfile(C)
    if loader == nil then
      System.removeFile(C)
      PLDR.HDD.HAS_CHECKED = false
      return
    end
    local ok, run_err = pcall(loader)
    if not ok then
      System.removeFile(C)
      PLDR.HDD.HAS_CHECKED = false
      return
    end
    PLDR.HDD.HAS_CHECKED = true
  end
end

function PLDR.HDD.WipeCache(CACHE)
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
    local root = PLDR and PLDR.MX4SIO and PLDR.MX4SIO.ROOT or "mass:/"
    root = EnsureTrailingSlash(root)
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
  if (not ok or type(fd_or_err) ~= "number" or fd_or_err < 0) and IsMassPath(path) and type(PLDR) == "table" and type(PLDR.EnsureUsbMassReadyOnce) == "function" then
    pcall(PLDR.EnsureUsbMassReadyOnce)
    ok, fd_or_err = pcall(System.openFile, path, FREAD)
  end
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
  if not PLDR.PopstarterProbeWithEnsure(popstarter) then
    BlockLaunchFailure(
      "popstarter missing",
      popstarter,
      context and context.device_page or "unknown",
      argv and argv[1] or nil,
      context and context.vcd_path or nil,
      app_dir,
      nil,
      nil
    )
    return
  end
  local open_ok, open_rc, open_stage, open_api, open_path = TryOpenForLaunch(popstarter)
  if not open_ok then
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
  local rc
  if exec_args ~= nil and #exec_args > 0 and unpack_fn ~= nil then
    rc = System.loadELF(popstarter, reboot_iop, unpack_fn(exec_args))
  elseif exec_args ~= nil and #exec_args == 1 then
    rc = System.loadELF(popstarter, reboot_iop, exec_args[1])
  else
    rc = System.loadELF(popstarter, reboot_iop)
  end
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

function Touch(FILE)
  if not doesFileExist(FILE) then
    local FD = System.openFile(FILE, FCREATE)
    System.closeFile(FD)
    return true
  else
    return false
  end
end

PLDR.LoadSettingsNonFatal()

---MAIN PROGRAM BEHAVIOUR BEGINS
local initial_scene = UI.SCENES.MMAIN
local show_boot_credits = true
UI.WelcomeDraw.Play(initial_scene, show_boot_credits)
if UI.Transition ~= nil then
  UI.Transition.allowSceneWrite = true
end
UI.CURSCENE = initial_scene
UI.LASTSCENE = initial_scene
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
end
