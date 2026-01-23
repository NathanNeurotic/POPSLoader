local function ensure_dir(path)
  if path == nil or path == "" then return "./" end
  if string.sub(path, -1) ~= "/" then
    return path.."/"
  end
  return path
end

local BASE_DIR = ensure_dir(APP_DIR or System.currentDirectory())
package.path = BASE_DIR.."?.lua;"..BASE_DIR.."?/init.lua;"..BASE_DIR.."POPSLDR/?.lua;./?.lua;./POPSLDR/?.lua;mass:/POPSLDR/?.lua;mc0:/POPSLDR/?.lua;mc1:/POPSLDR/?.lua"
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
      if HDD.MountPartition(MNTPART, 1) then -- mount to "pfs1:" and NEVER USE IT FOR ANYTHING ELSE
        BOOTPATH, _, _ = string.match(BOOTPATH, "(.-)([^/]-([^%.]+))$")
        System.currentDirectory(BOOTPATH)
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
  if fd == nil then
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
  local sanitized, count = string.gsub(data, "[\128-\255]", "?")
  if count > 0 then
    LOGF("Sanitized %d non-ASCII bytes in %s", count, path)
  end
  return loadstring(sanitized, "@"..path)
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

local function ResolveSystemScript()
  local resolved = System.resolveAsset("system.lua")
  if resolved ~= nil then
    return resolved
  end
  local tried = {}
  local function push_dir(dir)
    if dir == nil or dir == "" then
      return
    end
    local normalized = ensure_dir(dir)
    if tried[normalized] then
      return
    end
    tried[normalized] = true
    local direct = normalized.."system.lua"
    if doesFileExist(direct) then
      return direct
    end
    local legacy = normalized.."POPSLDR/system.lua"
    if doesFileExist(legacy) then
      return legacy
    end
  end
  local fallback = push_dir(APP_DIR)
  if fallback ~= nil then
    return fallback
  end
  fallback = push_dir(System.currentDirectory())
  if fallback ~= nil then
    return fallback
  end
  return nil
end

local SYS = ResolveSystemScript()
if SYS ~= nil then
	RunScript(SYS);
else
  error("Cant access POPSLDR/system.lua\n\n\tcurrent_bootpath: "..System.currentDirectory())
end
