package.path = "./POPSLDR/?.lua;./?.lua;mass:/POPSLDR/?.lua;mc0:/POPSLDR/?.lua;mc1:/POPSLDR/?.lua"
function LOG(...)
  print_uart(...)
end
function LOGF(S, ...)
  print_uart(string.format(S, ...))
end

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

local function PfsIndexFromPrefix(pfsindx)
  if pfsindx == nil then return 0 end
  local idx = string.match(pfsindx, "^pfs(%d+):")
  if idx == nil then
    return 0
  end
  return tonumber(idx) or 0
end

local function NormalizePfsPath(path, idx)
  if path == nil then return path end
  local prefix = string.format("pfs%d:", idx)
  if string.match(path, "^pfs:") then
    return string.gsub(path, "^pfs:", prefix)
  end
  if string.match(path, "^pfs%d+:") then
    return string.gsub(path, "^pfs%d+:", prefix)
  end
  return path
end


local ARGV0 = System.GetArgv0()
if string.find(ARGV0, "^hdd0:") then
  LOG("Booting from HDD!", ARGV0)
  local MNTPART
  BOOTPATH = nil
  local PFSINDX
  MNTPART, PFSINDX, BOOTPATH = GetMountData(ARGV0)
  if string.find(BOOTPATH, "^pfs") then
    SUCCESS, MODULE, ID, RET = HDD.Initialize()
    if not SUCCESS then
      LOG("ERROR", MODULE..".IRX", ID, RET)
    else
      System.sleep(2) -- lets give it time to get ready
      local idx = PfsIndexFromPrefix(PFSINDX)
      if HDD.MountPartition(MNTPART, idx) then -- mount to requested pfs index
        BOOTPATH, _, _ = string.match(BOOTPATH, "(.-)([^/]-([^%.]+))$")
        BOOTPATH = NormalizePfsPath(BOOTPATH, idx)
        System.currentDirectory(BOOTPATH)
        LOGF("new bootpath (pfs%d): '%s'\n", idx, BOOTPATH)
      else
        LOG("ERROR: HDD mount failed for", MNTPART, "pfs index", idx)
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
function STOP() LOG("PROGRAM STOP") Screen.clear(Color.new(255,0,0)) Screen.flip() while true do end end
function RunScript(S)
  dofile(S)
end

if doesFileExist("POPSLDR/system.lua") then
	RunScript("POPSLDR/system.lua");
else
  error("Cant access POPSLDR/system.lua\n\n\tcurrent_bootpath: "..System.currentDirectory())
end
