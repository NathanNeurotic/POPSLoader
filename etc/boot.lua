local function ensure_dir(path)
  if path == nil or path == "" then return "./" end
  if string.sub(path, -1) ~= "/" then
    return path.."/"
  end
  return path
end

function LOG(...)
  print_uart(...)
end
function LOGF(S, ...)
  print_uart(string.format(S, ...))
end

local function DIAG_LOG(msg)
  if BOOT_DIAG and System.bootLog ~= nil then
    System.bootLog(msg)
  end
end

BOOT_PROF = {
  timer = Timer.new(),
  stamp = function (label)
    local now = Timer.getTime(BOOT_PROF.timer)
    LOGF("BOOT: %s %d", label, now)
  end
}
BOOT_PROF.stamp("Lua init start")
DIAG_LOG("Lua init start")

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

local function MountHddPartition(partition, pfs_index)
  local SUCCESS, MODULE, ID, RET = HDD.Initialize()
  if not SUCCESS then
    LOG("ERROR", MODULE..".IRX", ID, RET)
    return false
  end
  System.sleep(2) -- lets give it time to get ready
  return HDD.MountPartition(partition, pfs_index)
end

local function SetBootPathFromFilepath(filepath, pfs_index)
  local bootpath = string.gsub(filepath, "^pfs%d*:", pfs_index..":")
  bootpath, _, _ = string.match(bootpath, "(.-)([^/]-([^%.]+))$")
  BOOTPATH = bootpath
  System.currentDirectory(BOOTPATH)
  LOGF("new bootpath: '%s'\n", BOOTPATH)
end


local ARGV0 = System.GetArgv0()
if string.find(ARGV0, "^hdd0:") then
  LOG("Booting from HDD!", ARGV0)
  BOOTPATH = nil
  local mountpart, _, filepath = GetMountData(ARGV0)
  if filepath ~= "" and string.find(filepath, "^pfs") then
    if MountHddPartition(mountpart, 1) then -- mount to "pfs1:" and NEVER USE IT FOR ANYTHING ELSE
      SetBootPathFromFilepath(filepath, "pfs1")
    end
  else
    local part_label, rest = string.match(ARGV0, "^hdd0:([^/]+)/(.+)$")
    if part_label ~= nil and rest ~= nil then
      mountpart = string.format("hdd0:%s", part_label)
      if MountHddPartition(mountpart, 1) then -- mount to "pfs1:" and NEVER USE IT FOR ANYTHING ELSE
        local remapped = string.format("pfs1:/%s", rest)
        SetBootPathFromFilepath(remapped, "pfs1")
      end
    end
  end
end
local BASE_DIR = ensure_dir(BOOTPATH or APP_DIR or System.currentDirectory())
package.path = BASE_DIR.."?.lua;"..BASE_DIR.."?/init.lua;"..BASE_DIR.."POPSLDR/?.lua;./?.lua;./POPSLDR/?.lua;mass:/POPSLDR/?.lua;mc0:/POPSLDR/?.lua;mc1:/POPSLDR/?.lua"
GPAD = 0
Font.ftInit()
BFONT = Font.LoadBuiltinFont()
SFONT = Font.LoadBuiltinFont()
LFONT = Font.LoadBuiltinFont()
Font.ftSetCharSize(BFONT, 800, 800)
Font.ftSetCharSize(SFONT, 600, 600)
BOOT_PROF.stamp("UI assets init (fonts)")
function STOP() LOG("PROGRAM STOP") Screen.clear(Color.new(255,0,0)) Screen.flip() while true do end end

function RunScript(S)
  local loader, load_err = loadfile(S)
  if loader == nil then
    error(load_err)
  end
  local ok, run_err = pcall(loader)
  if not ok then
    error(run_err)
  end
end

local function FullPathForAttempt(path)
  if path == nil then return "<nil>" end
  if string.match(path, "^[%a]+%d*:/") then
    return path
  end
  local cwd = ensure_dir(System.currentDirectory() or "")
  return cwd..path
end

local function ExpandDevicePrefix(path)
  local expanded = { path }
  if path == nil then
    return expanded
  end
  if string.find(path, "^mass:/") then
    local suffix = string.sub(path, 6)
    for i = 0, 6 do
      expanded[#expanded + 1] = string.format("mass%d:/%s", i, suffix)
    end
  elseif string.find(path, "^mmce:/") then
    local suffix = string.sub(path, 6)
    for i = 0, 1 do
      expanded[#expanded + 1] = string.format("mmce%d:/%s", i, suffix)
    end
  end
  return expanded
end

local function BuildAttemptList()
  -- Prefer packaged app layout first to avoid expensive misses on slow devices.
  local base_attempts = {
    BASE_DIR.."bin/POPSLDR/system.lua",
    BASE_DIR.."POPSLDR/system.lua",
    BASE_DIR.."system.lua",
    BASE_DIR.."bin/system.lua",
    "bin/POPSLDR/system.lua",
    "POPSLDR/system.lua",
    "system.lua",
    "bin/system.lua"
  }
  local out = {}
  local seen = {}
  for i = 1, #base_attempts do
    local variants = ExpandDevicePrefix(base_attempts[i])
    for j = 1, #variants do
      local candidate = variants[j]
      if candidate ~= nil and seen[candidate] ~= true then
        seen[candidate] = true
        out[#out + 1] = candidate
      end
    end
  end
  return out
end

local ATTEMPTS = BuildAttemptList()

local tried = {}
local errs = {}
local loaded = false
for i = 1, #ATTEMPTS do
  local candidate = ATTEMPTS[i]
  tried[#tried + 1] = FullPathForAttempt(candidate)
  local ok, err = pcall(RunScript, candidate)
  if ok then
    loaded = true
    break
  end
  errs[#errs + 1] = tostring(err)
end

if not loaded then
  local msg = "Cant access system.lua\n\nboot_dir: "..tostring(BASE_DIR).."\ncwd: "..tostring(System.currentDirectory()).."\nargv0: "..tostring(System.GetArgv0()).."\n\nattempted paths:\n - "..table.concat(tried, "\n - ")
  if #errs > 0 then
    msg = msg.."\n\nlast error:\n"..errs[#errs]
  end
  error(msg)
end
