--[[
  ___  ___  ___  ___ _                 _         
 | _ \/ _ \| _ \/ __| |   ___  __ _ __| |___ _ _ 
 |  _/ (_) |  _/\__ \ |__/ _ \/ _` / _` / -_) '_|
 |_|  \___/|_|  |___/____\___/\__,_\__,_\___|_|  
  Licensed under GNU General public license v3.0
--]]
local DEFAULT_PROFILE = 1 -- change this for a different default profile. default package points to local popstarter path
PLDR.DEFAULT_PROFILE = DEFAULT_PROFILE
-- to register an ELF that is stored on the same folder than POPSLOADER, please do it this way:
-- System.currentDirectory().."/POPSTARTER.ELF"

local function NormalizeDirPathCompat(path)
  if NormalizeDirPath ~= nil then
    return NormalizeDirPath(path)
  end
  if path == nil or path == "" then return "" end
  if string.sub(path, -1) ~= "/" then
    return path.."/"
  end
  return path
end

local function JoinPathCompat(base, rel)
  if JoinPath ~= nil then
    return JoinPath(base, rel)
  end
  local normalized = NormalizeDirPathCompat(base)
  if rel == nil or rel == "" then
    return normalized
  end
  if string.sub(rel, 1, 1) == "/" then
    rel = string.sub(rel, 2)
  end
  return normalized..rel
end

local APP_DIR_LOCAL = NormalizeDirPathCompat(APP_DIR or System.currentDirectory())

local function ResolveProfilePath(rel)
  return System.resolveAsset(rel) or JoinPathCompat(APP_DIR_LOCAL, rel)
end

PLDR.PROFILES = {
  {
    ELF="POPSTARTER.ELF";
    DESC="PopStarter located in the same folder as POPSLOADER.ELF";
  },
  {
    ELF="hdd0:__common:pfs:/POPS/POPSTARTER.ELF";
    DESC="the POPSTARTER ELF located on Hdd in the POPS folder";
  },
  {
    ELF="hdd0:__common:pfs0:/POPS/POPSTARTER.ELF";
    DESC="the POPSTARTER ELF located on Hdd in the POPS folder";
  },
  {
    ELF="hdd0:__common:pfs1:/POPS/POPSTARTER.ELF";
    DESC="the POPSTARTER ELF located on Hdd in the POPS folder";
  },
  {
    ELF="hdd0:__common:pfs2:/POPS/POPSTARTER.ELF";
    DESC="the POPSTARTER ELF located on Hdd in the POPS folder";
  },
  {
    ELF="mass:/POPS/POPSTARTER.ELF";
    DESC="the POPSTARTER ELF located on USB in the POPS folder";
  },
  {
    ELF="mass0:/POPS/POPSTARTER.ELF";
    DESC="the POPSTARTER ELF located on USB in the POPS folder";
  },
  {
    ELF="mass1:/POPS/POPSTARTER.ELF";
    DESC="the POPSTARTER ELF located on USB in the POPS folder";
  },
  {
    ELF="mass2:/POPS/POPSTARTER.ELF";
    DESC="the POPSTARTER ELF located on USB in the POPS folder";
  },
  {
    ELF="mx4sio:/POPS/POPSTARTER.ELF";
    DESC="the POPSTARTER ELF located on MX4SIO in the POPS folder";
  },
  {
    ELF="mmce0:/POPS/POPSTARTER.ELF";
    DESC="the POPSTARTER ELF located on MMCE in the POPS folder";
  },
  {
    ELF="mmce1:/POPS/POPSTARTER.ELF";
    DESC="the POPSTARTER ELF located on MMCE in the POPS folder";
  },
  {
    ELF="mc0:/POPS/POPSTARTER.ELF";
    DESC="the POPSTARTER ELF located on MemoryCard in the POPS folder";
  },
  {
    ELF="mc1:/POPS/POPSTARTER.ELF";
    DESC="the POPSTARTER ELF located on MemoryCard in the POPS folder";
  },
 {
    ELF="mc1:/POPSTARTER/POPSTARTER.ELF";
    DESC="the POPSTARTER ELF located on MemoryCard in the POPS folder";
  },
 {
    ELF="mc0:/POPSTARTER/POPSTARTER.ELF";
    DESC="the POPSTARTER ELF located on MemoryCard in the POPS folder";
  },
}

if DEFAULT_PROFILE > 0 and DEFAULT_PROFILE <= #PLDR.PROFILES then
  PLDR.POPSTARTER_PATH = PLDR.PROFILES[DEFAULT_PROFILE].ELF
end
