--[[
  ___  ___  ___  ___ _                 _         
 | _ \/ _ \| _ \/ __| |   ___  __ _ __| |___ _ _ 
 |  _/ (_) |  _/\__ \ |__/ _ \/ _` / _` / -_) '_|
 |_|  \___/|_|  |___/____\___/\__,_\__,_\___|_|  
  Licensed under GNU General public license v3.0
--]]
LOG("Registering POPStarter profiles...")
local DEFAULT_PROFILE = 1 -- change this for a different default profile. default package points to local popstarter path
-- to register an ELF that is stored on the same folder than POPSLOADER, please do it this way:
-- System.currentDirectory().."/POPSTARTER.ELF"

local function NormalizeDirPath(path)
  if path == nil or path == "" then return "" end
  if string.sub(path, -1) ~= "/" then
    return path.."/"
  end
  return path
end

local function JoinPath(base, rel)
  local normalized = NormalizeDirPath(base)
  if rel == nil or rel == "" then
    return normalized
  end
  if string.sub(rel, 1, 1) == "/" then
    rel = string.sub(rel, 2)
  end
  return normalized..rel
end

local APP_DIR_LOCAL = NormalizeDirPath(APP_DIR or System.currentDirectory())

local function ResolveProfilePath(rel)
  return System.resolveAsset(rel) or JoinPath(APP_DIR_LOCAL, rel)
end

PLDR.PROFILES = {
  {
    ELF="POPSTARTER.ELF";
    DESC="PopStarter located next to POPSLOADER.ELF";
  },
  {
    ELF=ResolveProfilePath("PROFILES/MAIN/POPSTARTER.ELF");
    DESC="Latest popstarter without any modifications";
  },
  {
    ELF=ResolveProfilePath("PROFILES/DEBUG/POPSTARTER.ELF");
    DESC="Latest popstarter with debug menus enabled";
  },
  {
    ELF=ResolveProfilePath("PROFILES/USBDELAY/POPSTARTER.ELF");
    DESC="Latest popstarter with increased USB delay";
  },
  {
    ELF=ResolveProfilePath("PROFILES/USBDELAY_DEBUG/POPSTARTER.ELF");
    DESC="Latest popstarter with increased USB delay & debug menus enabled";
  },
  {
    ELF="mass:/POPS/POPSTARTER.ELF";
    DESC="the POPSTARTER ELF located on the POPS folder";
  },
}

if DEFAULT_PROFILE > 0 and DEFAULT_PROFILE <= #PLDR.PROFILES then
  PLDR.POPSTARTER_PATH = PLDR.PROFILES[DEFAULT_PROFILE].ELF
end
