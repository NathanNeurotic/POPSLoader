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

local function each_path_variant(path, fn)
  local normalized = normalize_path(path)
  if normalized == nil or normalized == "" then
    return nil
  end
  local result = fn(normalized)
  if result ~= nil then
    return result
  end
  if string.sub(normalized, 1, 6) == "mass:/" then
    return fn("mass:"..string.sub(normalized, 7))
  end
  return nil
end

local function resolve_script_path(path)
  return each_path_variant(path, function (candidate)
    local resolved = System.resolveAsset(candidate)
    if type(resolved) == "string" and resolved ~= "" then
      return resolved
    end
    if doesFileExist(candidate) then
      return candidate
    end
    return nil
  end)
end

local function folder_exists(path)
  if path == nil or path == "" then
    return false
  end
  return each_path_variant(path, function (candidate)
    local with_trailing = ensure_dir(candidate)
    if doesFolderExist(with_trailing) == true then
      return true
    end
    local without_trailing = string.gsub(with_trailing, "/+$", "")
    if doesFolderExist(without_trailing) == true then
      return true
    end
    return nil
  end) == true
end

local function pick_accessible_dir(path)
  return each_path_variant(path, function (candidate)
    if folder_exists(candidate) then
      return ensure_dir(candidate)
    end
    return nil
  end)
end

local function first_valid_dir(...)
  local paths = {...}
  for i = 1, #paths do
    local picked = pick_accessible_dir(paths[i])
    if picked ~= nil then
      return picked
    end
  end
  return nil
end

local function dir_exists(path)
  return folder_exists(path)
end

local ARGV0 = normalize_path(System.GetArgv0())
local BASE_DIR = dirname(ARGV0)
BASE_DIR = first_valid_dir(
  BASE_DIR,
  normalize_path(APP_DIR),
  normalize_path(System.currentDirectory())
)
if BASE_DIR == nil then
  BASE_DIR = ensure_dir(normalize_path(System.currentDirectory()))
end
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

local function LoadLuaFile(path)
  local loader, load_err = loadfile(path)
  if loader ~= nil then
    return loader
  end
  return nil, load_err
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

if SYS ~= nil then
  RunScript(SYS)
else
  error("Cant access system.lua (flat) or POPSLDR/system.lua (fallback)\n\n\targv0: "..tostring(ARGV0).."\n\tcwd: "..tostring(System.currentDirectory()))
end
