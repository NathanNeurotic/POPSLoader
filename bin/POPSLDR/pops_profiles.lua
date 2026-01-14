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

PLDR.PROFILES = {
  {
    ELF=JoinPath(System.currentDirectory(), "POPSLDR/PROFILES/MAIN/POPSTARTER.ELF");
    DESC="Latest popstarter without any modifications";
  },
  {
    ELF=JoinPath(System.currentDirectory(), "POPSLDR/PROFILES/DEBUG/POPSTARTER.ELF");
    DESC="Latest popstarter with debug menus enabled";
  },
  {
    ELF=JoinPath(System.currentDirectory(), "POPSLDR/PROFILES/USBDELAY/POPSTARTER.ELF");
    DESC="Latest popstarter with increased USB delay";
  },
  {
    ELF=JoinPath(System.currentDirectory(), "POPSLDR/PROFILES/USBDELAY_DEBUG/POPSTARTER.ELF");
    DESC="Latest popstarter with increased USB delay & debug menus enabled";
  },
  {
    ELF=ResolvePreferredPath("POPS/POPSTARTER.ELF");
    DESC="the POPSTARTER ELF located on the POPS folder";
  },
}

if DEFAULT_PROFILE > 0 and DEFAULT_PROFILE <= #PLDR.PROFILES then
  PLDR.POPSTARTER_PATH = PLDR.PROFILES[DEFAULT_PROFILE].ELF
end
