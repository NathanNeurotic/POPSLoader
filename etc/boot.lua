DEBUG_BUILD = DEBUG_BUILD or false

function LOG(...)
  print_uart(...)
end
function LOGF(S, ...)
  print_uart(string.format(S, ...))
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

JoinPath = joinPath

local DEVICE_READY_TIMEOUT_MS = 2000
local DEVICE_READY_SLEEP_MS = 100

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

local function find_pops_device()
  local roots = {}
  local mmce_devices = {"mmce1:/", "mmce0:/"}
  local mass_devices = {"mass:/", "mass0:/", "mass1:/", "mass2:/", "mass3:/"}
  local mass_retry_devices = {"mass:/", "mass0:/"}

  for _ = 1, 2 do
    for _, dev in ipairs(mmce_devices) do
      table.insert(roots, dev)
    end
  end
  for _, dev in ipairs(mass_devices) do
    table.insert(roots, dev)
  end
  for _, dev in ipairs(mass_retry_devices) do
    table.insert(roots, dev)
  end
  for _, root in ipairs(roots) do
    local path = root.."POPS/"
    local ready_ok, _ = wait_for_ready(path, DEVICE_READY_TIMEOUT_MS)
    if ready_ok then
      local dopen_ret = System.fileXioDopen(path)
      if dopen_ret >= 0 then
        System.fileXioDclose(dopen_ret)
        return root
      end
    end
  end
  return nil
end

BOOT_DEVICE_ROOT = find_pops_device()

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

local system_source = SYSTEM_LUA or ""
local system_path = "@embedded:system.lua"
if system_source == "" then
  emit_fatal("Cant load system.lua\n\n\tboot_path: "..current_bootpath.."\n\tdeps_base_dir: "..deps_base_dir.."\n\tsystem_path: "..system_path.."\n\terr: embedded system.lua missing")
end

local loader = loadstring or load
if loader == nil then
  emit_fatal("Cant load system.lua\n\n\tboot_path: "..current_bootpath.."\n\tdeps_base_dir: "..deps_base_dir.."\n\tsystem_path: "..system_path.."\n\terr: loader unavailable")
end

local system_chunk, system_err = loader(system_source, system_path)
if system_chunk == nil then
  emit_fatal("Cant load system.lua\n\n\tboot_path: "..current_bootpath.."\n\tdeps_base_dir: "..deps_base_dir.."\n\tsystem_path: "..system_path.."\n\terr: "..tostring(system_err))
end
system_chunk()
