--[[
  ___  ___  ___  ___ _                 _         
 | _ \/ _ \| _ \/ __| |   ___  __ _ __| |___ _ _ 
 |  _/ (_) |  _/\__ \ |__/ _ \/ _` / _` / -_) '_|
 |_|  \___/|_|  |___/____\___/\__,_\__,_\___|_|  
  Licensed under GNU General public license v3.0
--]]
LOG("Registering POPStarter profiles...")
local DEFAULT_PROFILE = 1 -- change this for a different default profile. default package points to classic popstarter path
-- to register an ELF that is stored on the same folder than POPSLOADER, please do it this way:
-- System.currentDirectory().."/POPSLDR/PROFILES/YOUR_CUSTOM_PROFILE/POPSTARTER.ELF"

local APP_DIR_LOCAL = APP_DIR or System.currentDirectory()
if string.sub(APP_DIR_LOCAL, -1) ~= "/" then APP_DIR_LOCAL = APP_DIR_LOCAL.."/" end

local function ResolveProfilePath(rel)
  return System.resolveAsset(rel) or (APP_DIR_LOCAL..rel)
end

PLDR.PROFILES = {
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
