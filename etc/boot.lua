local function normalize_path(path)
  if path == nil then
    return nil
  end
  local normalized = tostring(path)
  normalized = string.gsub(normalized, "\\", "/")
  normalized = string.gsub(normalized, "([%a%d_]+)::+", "%1:")
  normalized = string.gsub(normalized, "//+", "/")
  return normalized
end

local function ensure_dir(path)
  local normalized = normalize_path(path)
  if normalized == nil or normalized == "" then return "./" end
  if string.sub(normalized, -1) ~= "/" then
    return normalized.."/"
  end
  return normalized
end

local function dirname(p)
  p = normalize_path(p)
  if p == nil or p == "" then
    return nil
  end
  local dir = string.match(p, "^(.*)/[^/]*$")
  if dir == nil or dir == "" then
    return nil
  end
  return dir
end

local function parent_dir(path)
  local dir = ensure_dir(path)
  if dir == nil or dir == "" then
    return nil
  end
  local trimmed = string.gsub(dir, "/+$", "")
  local parent = string.match(trimmed, "^(.*)/[^/]*$")
  if parent == nil or parent == "" then
    return nil
  end
  return ensure_dir(parent)
end

local function add_candidate(list, path)
  local normalized = normalize_path(path)
  if normalized == nil or normalized == "" then
    return
  end
  list[#list + 1] = normalized
  if string.sub(normalized, 1, 6) == "mass:/" then
    list[#list + 1] = "mass:"..string.sub(normalized, 7)
  end
end

local function mass_compact_path(path)
  local normalized = normalize_path(path)
  if normalized == nil then
    return nil
  end
  local head, tail = string.match(normalized, "^(mass%d*):/(.*)$")
  if head == nil then
    return nil
  end
  return head..":"..tail
end

local function resolve_script_path(path)
  local normalized = normalize_path(path)
  if normalized == nil or normalized == "" then
    return nil
  end
  local resolved = System.resolveAsset(normalized)
  if resolved ~= nil then
    return resolved
  end
  if doesFileExist(normalized) then
    return normalized
  end
  local compact = mass_compact_path(normalized)
  if compact ~= nil then
    resolved = System.resolveAsset(compact)
    if resolved ~= nil then
      return resolved
    end
    if doesFileExist(compact) then
      return compact
    end
  end
  return nil
end

local function is_usb_mass_root(path)
  local normalized = normalize_path(path)
  if normalized == nil then
    return false
  end
  return string.sub(normalized, 1, 4) == "mass"
end

local function wait_for_readable_script(path)
  if not is_usb_mass_root(path) then
    return path
  end
  local attempts = 100
  for i = 1, attempts do
    local fd = System.openFile(path, FREAD)
    if type(fd) == "number" and fd >= 0 then
      System.closeFile(fd)
      return path
    end
    local compact = mass_compact_path(path)
    if compact ~= nil then
      local fd2 = System.openFile(compact, FREAD)
      if type(fd2) == "number" and fd2 >= 0 then
        System.closeFile(fd2)
        return compact
      end
    end
    if i < attempts then
      System.delayThreadMs(250)
    end
  end
  return path
end

local function dir_exists(path)
  if path == nil or path == "" then
    return false
  end
  return doesFolderExist(ensure_dir(path)) == true
end

local ARGV0 = normalize_path(System.GetArgv0())
local BASE_DIR = dirname(ARGV0)
if BASE_DIR == nil or BASE_DIR == "" or not dir_exists(BASE_DIR) then
  BASE_DIR = normalize_path(APP_DIR) or normalize_path(System.currentDirectory())
end
if BASE_DIR == nil or BASE_DIR == "" or not dir_exists(BASE_DIR) then
  BASE_DIR = normalize_path(System.currentDirectory())
end
BASE_DIR = ensure_dir(BASE_DIR)
System.currentDirectory(BASE_DIR)

package.path = BASE_DIR.."?.lua;"..BASE_DIR.."?/init.lua;"..BASE_DIR.."POPSLDR/?.lua;./?.lua;./?/init.lua;./POPSLDR/?.lua"
function LOG(...)
  print_uart(...)
end
function LOGF(S, ...)
  print_uart(string.format(S, ...))
end

BOOT_PROF = {
  timer = Timer.new(),
  stamp = function (label)
    local now = Timer.getTime(BOOT_PROF.timer)
    LOGF("BOOT: %s %d", label, now)
  end
}
BOOT_PROF.stamp("Lua init start")

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
      if HDD.MountPartition(MNTPART, 1) then -- mount to "pfs1:" and NEVER USE IT FOR ANYTHING ELSE
        BOOTPATH, _, _ = string.match(BOOTPATH, "(.-)([^/]-([^%.]+))$")
        BOOTPATH = string.gsub(BOOTPATH, "^pfs:/", "pfs1:/")
        System.currentDirectory(BOOTPATH)
        BASE_DIR = ensure_dir(BOOTPATH)
        LOGF("new bootpath: '%s'\n", BOOTPATH)
      end
    end
  end
end
GPAD = 0
Font.ftInit()
BFONT = Font.LoadBuiltinFont()
SFONT = Font.LoadBuiltinFont()
LFONT = Font.LoadBuiltinFont()
Font.ftSetCharSize(BFONT, 800, 800)
Font.ftSetCharSize(SFONT, 600, 600)
BOOT_PROF.stamp("UI assets init (fonts)")
function STOP() LOG("PROGRAM STOP") Screen.clear(Color.new(255,0,0)) Screen.flip() while true do end end

local function ReadWholeFile(path)
  local fd = System.openFile(path, FREAD)
  if (type(fd) ~= "number" or fd < 0) and is_usb_mass_root(path) then
    local compact = mass_compact_path(path)
    if compact ~= nil then
      fd = System.openFile(compact, FREAD)
      if type(fd) == "number" and fd >= 0 then
        path = compact
      end
    end
  end
  if type(fd) ~= "number" or fd < 0 then
    return nil, "open failed"
  end
  local chunks = {}
  while true do
    local buffer = System.readFile(fd, 4096)
    if buffer == nil or buffer == "" then
      break
    end
    chunks[#chunks + 1] = buffer
  end
  System.closeFile(fd)
  return table.concat(chunks)
end

local function IsLikelyTextLua(data)
  if data == nil or data == "" then
    return false
  end
  if string.find(data, "\0", 1, true) then
    return false
  end
  if string.find(data, "[\001-\008\011\012\014-\031]") then
    return false
  end
  return true
end

local function LoadLuaFile(path)
  local loader, load_err = loadfile(path)
  if loader ~= nil then
    return loader
  end
  LOG("Lua load failed:", load_err)
  local data, read_err = ReadWholeFile(path)
  if data == nil then
    return nil, read_err
  end
  if not IsLikelyTextLua(data) then
    return nil, load_err
  end
  local sanitized, count = string.gsub(data, "[\128-\255]", "?")
  if count > 0 then
    LOGF("Sanitized %d non-ASCII bytes in %s", count, path)
  end
  local text_loader, text_err = loadstring(sanitized, "@"..path)
  if text_loader ~= nil then
    return text_loader
  end
  return nil, (load_err or "loadfile failed").." | "..tostring(text_err)
end

function RunScript(S)
  local loader, load_err = LoadLuaFile(S)
  if loader == nil then
    error(load_err)
  end
  local ok, run_err = pcall(loader)
  if not ok then
    error(run_err)
  end
end

local APP_DIR_NORM = ensure_dir(normalize_path(APP_DIR))
local BASE_PARENT = parent_dir(BASE_DIR)
local SYS_CANDIDATES = {}
add_candidate(SYS_CANDIDATES, "system.lua")
add_candidate(SYS_CANDIDATES, "POPSLDR/system.lua")
add_candidate(SYS_CANDIDATES, BASE_DIR.."system.lua")
add_candidate(SYS_CANDIDATES, BASE_DIR.."POPSLDR/system.lua")
if APP_DIR_NORM ~= nil then
  add_candidate(SYS_CANDIDATES, APP_DIR_NORM.."system.lua")
  add_candidate(SYS_CANDIDATES, APP_DIR_NORM.."POPSLDR/system.lua")
end
if BASE_PARENT ~= nil then
  add_candidate(SYS_CANDIDATES, BASE_PARENT.."system.lua")
  add_candidate(SYS_CANDIDATES, BASE_PARENT.."POPSLDR/system.lua")
end

local SYS = nil
for i = 1, #SYS_CANDIDATES do
  SYS = resolve_script_path(SYS_CANDIDATES[i])
  if SYS ~= nil then
    break
  end
end

if SYS == nil then
  for i = 1, #SYS_CANDIDATES do
    local candidate = normalize_path(SYS_CANDIDATES[i])
    local loader = nil
    loader = LoadLuaFile(candidate)
    if loader ~= nil then
      SYS = candidate
      break
    end
    if string.sub(candidate, 1, 6) == "mass:/" then
      local compact = "mass:"..string.sub(candidate, 7)
      loader = LoadLuaFile(compact)
      if loader ~= nil then
        SYS = compact
        break
      end
    end
  end
end
if SYS ~= nil then
  SYS = wait_for_readable_script(SYS)
  RunScript(SYS)
else
  error("Cant access system.lua (flat) or POPSLDR/system.lua (fallback)\n\n\targv0: "..tostring(ARGV0).."\n\tcwd: "..tostring(System.currentDirectory()))
end
