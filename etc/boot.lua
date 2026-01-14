DEBUG_BUILD = DEBUG_BUILD or false

function LOG(...)
  print_uart(...)
end
function LOGF(S, ...)
  print_uart(string.format(S, ...))
end

local function normalizeRoot(devroot)
  local dev = tostring(devroot or "")
  local prefix = dev:match("^(.-):") or dev
  prefix = string.lower(prefix)
  if prefix ~= "mmce0" and prefix ~= "mmce1" and
     prefix ~= "mass0" and prefix ~= "mass1" and
     prefix ~= "mass2" and prefix ~= "mass3" and
     prefix ~= "mass" and prefix ~= "mc0" and prefix ~= "mc1" then
    prefix = "mmce0"
  end
  return prefix..":/"
end

local function isValidRoot(root)
  if root == nil then return false end
  if root == "mmce0:/" or root == "mmce1:/" then return true end
  if root == "mass0:/" or root == "mass1:/" or root == "mass2:/" or root == "mass3:/" then return true end
  if root == "mass:/" or root == "mc0:/" or root == "mc1:/" then return true end
  return false
end

local function joinPath(root, rel)
  local base = tostring(root or "")
  local extra = tostring(rel or "")

  if extra ~= "" and string.find(extra, ":") then
    return extra:gsub("//+", "/"):gsub(":(/+)", ":/")
  end

  if base == "" then
    return extra:gsub("//+", "/")
  end

  base = base:gsub("//+", "/"):gsub(":(/+)", ":/")
  if extra == "" then
    return base
  end

  base = base:gsub("/+$", "")
  extra = extra:gsub("^/+", "")
  return (base.."/"..extra):gsub("//+", "/"):gsub(":(/+)", ":/")
end

NormalizeRoot = normalizeRoot
JoinPath = joinPath
IsValidRoot = isValidRoot

local DEVICE_READY_TIMEOUT_MS = 2000
local DEVICE_READY_SLEEP_MS = 100
local OPEN_RETRY_COUNT = 3
local OPEN_RETRY_SLEEP_MS = 100

local function emit_fatal(message)
  LOG(message)
  System.dprintf(message)
  print(message)
  if Screen and Screen.clear then
    Screen.clear()
  end
  pcall(function()
    Font.ftInit()
    Font.fmLoad()
    Font.fmPrint(20, 20, 0.6, message)
  end)
  if Screen and Screen.flip then
    Screen.flip()
  end
  while true do
    System.sleep(1)
  end
end

local function wait_for_ready(path, timeout_ms)
  local elapsed = 0
  local last_ret = nil
  while elapsed <= timeout_ms do
    local stat_ret = System.fileXioGetStat(path)
    if stat_ret == 0 then
      return true, 0
    end
    local dopen_ret = System.fileXioDopen(path)
    if dopen_ret >= 0 then
      System.fileXioDclose(dopen_ret)
      return true, 0
    end
    last_ret = (dopen_ret < 0) and dopen_ret or stat_ret
    System.sleepMs(DEVICE_READY_SLEEP_MS)
    elapsed = elapsed + DEVICE_READY_SLEEP_MS
  end
  return false, last_ret
end

local function open_with_retry(path, flags)
  local last_ret = nil
  for attempt = 1, OPEN_RETRY_COUNT do
    local fd = System.fileXioOpen(path, flags)
    LOGF("fileXioOpen attempt %d ret: %d", attempt, fd)
    if fd >= 0 then
      return fd, 0
    end
    last_ret = fd
    System.sleepMs(OPEN_RETRY_SLEEP_MS)
  end
  return -1, last_ret
end

local function sanitize_device(value)
  if value == nil then
    return nil
  end
  local dev = tostring(value)
  dev = dev:gsub("#.*$", ""):gsub("%s+$", ""):gsub("^%s+", "")
  dev = dev:gsub(":/?$", ""):gsub(":$", "")
  if dev == "" then
    return nil
  end
  return dev
end

local function read_file(path)
  local stat_ret, size = System.fileXioGetStat(path)
  LOGF("fileXioGetStat %s ret: %d", path, stat_ret)
  if stat_ret ~= 0 then
    return nil, stat_ret
  end
  local fd, open_ret = open_with_retry(path, FREAD)
  if fd < 0 then
    return nil, open_ret
  end
  local data, read_ret = System.fileXioRead(fd, size)
  local close_ret = System.fileXioClose(fd)
  LOGF("fileXioClose %s ret: %d", path, close_ret)
  if data == nil then
    return nil, read_ret
  end
  return data, 0
end

local function parse_cfg(text)
  local cfg = {}
  for line in tostring(text or ""):gmatch("[^\r\n]+") do
    local trimmed = line:gsub("#.*$", ""):gsub("%s+$", ""):gsub("^%s+", "")
    if trimmed ~= "" then
      local key, val = trimmed:match("^([%w_]+)%s*=%s*(.+)$")
      if key and val then
        cfg[key] = sanitize_device(val) or val
      end
    end
  end
  return cfg
end

local boot_path = tostring(System.GetArgv0() or System.currentDirectory() or "")
local current_bootpath = boot_path
local deps_base_dir = System.deriveBaseDir(current_bootpath)

local ready_ok, ready_ret = wait_for_ready(deps_base_dir, DEVICE_READY_TIMEOUT_MS)
if not ready_ok then
  emit_fatal("FATAL: base_dir not ready\n\n\tboot_path: "..current_bootpath.."\n\tdeps_base_dir: "..deps_base_dir.."\n\tlast_ret: "..tostring(ready_ret))
end

local base_stat_ret, _ = System.fileXioGetStat(deps_base_dir)
LOGF("base_dir stat ret: %d", base_stat_ret)

BOOT_PATH = deps_base_dir

local cfg_path = System.resolveLocal(deps_base_dir, "POPSLDR.CFG")
local cfg_data, cfg_ret = read_file(cfg_path)
local cfg = parse_cfg(cfg_data)
local cfg_pops_device = sanitize_device(cfg.POPS_DEVICE)

local attempt_logs = {}
local function record_attempt(label, path, stat_ret, ready_ret, dopen_ret)
  table.insert(attempt_logs, string.format("%s => %s stat:%s ready:%s dopen:%s", label, path, tostring(stat_ret), tostring(ready_ret), tostring(dopen_ret)))
end

local function validate_pops_root(label, path)
  local stat_ret = System.fileXioGetStat(path)
  local ready_ok_local, ready_ret_local = wait_for_ready(path, DEVICE_READY_TIMEOUT_MS)
  local dopen_ret = System.fileXioDopen(path)
  if dopen_ret >= 0 then
    System.fileXioDclose(dopen_ret)
  end
  record_attempt(label, path, stat_ret, ready_ok_local and 0 or ready_ret_local, dopen_ret)
  return ready_ok_local and dopen_ret >= 0
end

local pops_root_dir = nil
local pops_device = nil

if cfg_pops_device ~= nil then
  local candidate = cfg_pops_device
  local path = candidate..":/POPS/"
  if validate_pops_root("cfg", path) then
    pops_root_dir = path
    pops_device = candidate
  end
end

if pops_root_dir == nil then
  local device_of_boot = sanitize_device(current_bootpath:match("^(.-):"))
  local candidates = {device_of_boot, "mmce0", "mmce1", "mass", "mc0", "mc1"}
  local seen = {}
  for _, candidate in ipairs(candidates) do
    if candidate ~= nil and not seen[candidate] then
      seen[candidate] = true
      local path = candidate..":/POPS/"
      if validate_pops_root(candidate, path) then
        pops_root_dir = path
        pops_device = candidate
        break
      end
    end
  end
end

if pops_root_dir == nil then
  emit_fatal("FATAL: No valid POPS device found.\n\n\tboot_path: "..current_bootpath..
    "\n\tdeps_base_dir: "..deps_base_dir..
    "\n\tcfg_pops_device: "..tostring(cfg_pops_device)..
    "\n\tattempts:\n\t"..table.concat(attempt_logs, "\n\t")..
    "\n\nSet POPS_DEVICE in POPSLDR.CFG next to POPSLDR.ELF.")
end

POPS_DEVICE = pops_device
POPS_ROOT_DIR = pops_root_dir
POPS_DEVICE_ROOT = normalizeRoot(pops_device)
BOOT_DEVICE_ROOT = POPS_DEVICE_ROOT

LOGF("POPS device root: %s", POPS_DEVICE_ROOT)
LOGF("POPS root dir: %s", POPS_ROOT_DIR)
if DEBUG_BUILD then
  assert(isValidRoot(POPS_DEVICE_ROOT), "Invalid POPS device root: "..POPS_DEVICE_ROOT)
elseif not isValidRoot(POPS_DEVICE_ROOT) then
  LOG("WARNING: invalid POPS device root", POPS_DEVICE_ROOT)
end

package.path = string.format("%s?.lua", BOOT_PATH)

POPSLDR_VER = "v1.0.0 - rev3"

--- Processes a HDD full path into its components. (eg: `hdd0:__system:pfs:/osd110/hosdsys.elf`)
---@param PATH string
---@return string mountpart: will return partition path for mounting (`hdd0:__system`)
---@return string pfsindx: will return pfs index (`pfs:`)
---@return string filepath: will return path to file when partition gets mounted (`pfs:/osd110/hosdsys.elf`)
function GetMountData(PATH)
  local CNT = 0
  local TBL = {}
  for i in string.gmatch(PATH, "[^:]*") do
    table.insert(TBL, i)
    CNT = CNT+1
  end
  local mountpart = ""
  local pfsindx   = ""
  local filepath  = ""
  if CNT == 4 then
    mountpart = string.format("%s:%s", TBL[1], TBL[2])
    pfsindx   = string.format("%s:", TBL[3])
    filepath  = string.format("%s:%s", TBL[3], TBL[4])
  end
  return mountpart, pfsindx, filepath
end


local ARGV0 = System.GetArgv0()
if string.find(ARGV0, "^hdd0:") then
  LOG("Booting from HDD!", ARGV0)
  local MNTPART
  BOOTPATH = nil
  MNTPART, _, BOOTPATH = GetMountData(ARGV0)
  if string.find(BOOTPATH, "^pfs") then
    SUCCESS, MODULE, ID, RET = HDD.Initialize()
    if not SUCCESS then
      LOG("ERROR", MODULE..".IRX", ID, RET)
    else
      System.sleep(2) -- lets give it time to get ready
      if HDD.MountPartition(MNTPART, 0) then -- mount to "pfs3:" and NEVER USE IT FOR ANYTHING ELSE
        BOOTPATH, _, _ = string.match(BOOTPATH, "(.-)([^/]-([^%.]+))$")
        System.currentDirectory(BOOTPATH)
        LOGF("new bootpath: '%s'\n", BOOTPATH)
      end
    end
  end
end
GPAD = 0
Font.ftInit()
local function loadBuiltinFont()
  local font = Font.LoadBuiltinFont()
  if font == nil and doesFileExist(BOOT_PATH.."builtin_font.ttf") then
    font = Font.ftLoad(BOOT_PATH.."builtin_font.ttf")
  end
  return font
end

BFONT = loadBuiltinFont()
SFONT = loadBuiltinFont()
LFONT = loadBuiltinFont()
if BFONT == nil or SFONT == nil or LFONT == nil then
  error("Failed to load builtin font (missing embedded font and builtin_font.ttf)")
end
Font.ftSetCharSize(BFONT, 800, 800)
Font.ftSetCharSize(SFONT, 600, 600)
function STOP() LOG("PROGRAM STOP") Screen.clear(Color.new(255,0,0)) Screen.flip() while true do end end
function RunScript(S)
  dofile(S)
end

RUNTIME_ROOT = BOOT_PATH
POPSTARTER_PATH = BOOT_PATH.."POPSTARTER.ELF"

local system_path = System.resolveLocal(deps_base_dir, "system.lua")
local system_stat_ret, system_size = System.fileXioGetStat(system_path)
LOGF("system.lua stat ret: %d", system_stat_ret)
if system_stat_ret ~= 0 then
  emit_fatal("Cant access system.lua\n\n\tboot_path: "..current_bootpath.."\n\tdeps_base_dir: "..deps_base_dir.."\n\tsystem_path: "..system_path.."\n\tstat_ret: "..tostring(system_stat_ret))
end

local system_fd, system_open_ret = open_with_retry(system_path, FREAD)
if system_fd < 0 then
  emit_fatal("Cant open system.lua\n\n\tboot_path: "..current_bootpath.."\n\tdeps_base_dir: "..deps_base_dir.."\n\tsystem_path: "..system_path.."\n\topen_ret: "..tostring(system_open_ret))
end

local system_data, system_read_ret = System.fileXioRead(system_fd, system_size)
LOGF("system.lua read ret: %d", system_read_ret)
local system_close_ret = System.fileXioClose(system_fd)
LOGF("system.lua close ret: %d", system_close_ret)
if system_data == nil then
  emit_fatal("Cant read system.lua\n\n\tboot_path: "..current_bootpath.."\n\tdeps_base_dir: "..deps_base_dir.."\n\tsystem_path: "..system_path.."\n\tread_ret: "..tostring(system_read_ret))
end

local system_chunk, system_err = loadstring(system_data, "@"..system_path)
if system_chunk == nil then
  emit_fatal("Cant load system.lua\n\n\tboot_path: "..current_bootpath.."\n\tdeps_base_dir: "..deps_base_dir.."\n\tsystem_path: "..system_path.."\n\terr: "..tostring(system_err))
end
system_chunk()
