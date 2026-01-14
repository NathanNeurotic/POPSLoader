DEBUG_BUILD = DEBUG_BUILD or false

function LOG(...)
  print_uart(...)
end
function LOGF(S, ...)
  print_uart(string.format(S, ...))
end

local function safeDoesFolderExist(path)
  local ok, result = pcall(doesFolderExist, path)
  return ok and result
end

local function normalizeRoot(devroot)
  local dev = tostring(devroot or "")
  local prefix = dev:match("^(.-):") or dev
  prefix = string.lower(prefix)
  if prefix ~= "mmce0" and prefix ~= "mmce1" and
     prefix ~= "mass0" and prefix ~= "mass1" and
     prefix ~= "mass2" and prefix ~= "mass3" then
    prefix = "mmce0"
  end
  return prefix..":/"
end

local function isValidRoot(root)
  if root == nil then return false end
  if root == "mmce0:/" or root == "mmce1:/" then return true end
  if root == "mass0:/" or root == "mass1:/" or root == "mass2:/" or root == "mass3:/" then return true end
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

local function detectPreferredDevice()
  local probe_roots = {
    "mass0:/",
    "mass1:/",
    "mass2:/",
    "mass3:/",
  }

  if MMCE_AVAILABLE then
    table.insert(probe_roots, 1, "mmce1:/")
    table.insert(probe_roots, 2, "mmce0:/")
  end

  while true do
    for _, root in ipairs(probe_roots) do
      if safeDoesFolderExist(root.."POPS/") then
        return root
      end
    end
    System.sleep(1)
  end
end

local current_bootpath = tostring(System.currentDirectory() or "")
local base_dir = System.deriveBaseDir(current_bootpath)

local base_stat_ret = System.fileXioGetStat(base_dir)
if base_stat_ret ~= 0 then
  for _ = 1, 2 do
    System.sleep(1)
    base_stat_ret = System.fileXioGetStat(base_dir)
    if base_stat_ret == 0 then
      break
    end
  end
end
LOGF("base_dir stat ret: %d", base_stat_ret)

BOOT_PATH = base_dir

PREFERRED_DEVICE = normalizeRoot(detectPreferredDevice())
BOOT_DEVICE_ROOT = PREFERRED_DEVICE

LOGF("Boot device root: %s", BOOT_DEVICE_ROOT)
if DEBUG_BUILD then
  assert(isValidRoot(BOOT_DEVICE_ROOT), "Invalid boot device root: "..BOOT_DEVICE_ROOT)
elseif not isValidRoot(BOOT_DEVICE_ROOT) then
  LOG("WARNING: invalid boot device root", BOOT_DEVICE_ROOT)
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

local system_path = System.resolveLocal(base_dir, "system.lua")
local system_stat_ret = System.fileXioGetStat(system_path)
LOGF("system.lua stat ret: %d", system_stat_ret)
if system_stat_ret ~= 0 then
  error("Cant access system.lua\n\n\tcurrent_bootpath: "..current_bootpath.."\n\tbase_dir: "..base_dir.."\n\tsystem_path: "..system_path.."\n\tstat_ret: "..tostring(system_stat_ret))
end

local system_fd, system_errno = System.openFileRaw(system_path, FREAD)
LOGF("system.lua open fd: %d errno: %d", system_fd, system_errno)
if system_fd < 0 then
  error("Cant open system.lua\n\n\tcurrent_bootpath: "..current_bootpath.."\n\tbase_dir: "..base_dir.."\n\tsystem_path: "..system_path.."\n\terrno: "..tostring(system_errno))
end

local system_size = System.sizeFile(system_fd)
local system_data = System.readFile(system_fd, system_size)
System.closeFile(system_fd)

local system_chunk, system_err = loadstring(system_data, "@"..system_path)
if system_chunk == nil then
  error("Cant load system.lua\n\n\tcurrent_bootpath: "..current_bootpath.."\n\tbase_dir: "..base_dir.."\n\tsystem_path: "..system_path.."\n\terr: "..tostring(system_err))
end
system_chunk()
