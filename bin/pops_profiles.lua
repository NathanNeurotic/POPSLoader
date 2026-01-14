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
-- System.currentDirectory().."/POPSTARTER.ELF"

PLDR.PROFILES = {
  {
    ELF=JoinPath(System.currentDirectory(), "POPSTARTER.ELF");
    DESC="POPSTARTER.ELF next to POPSLOADER.ELF";
  },
  {
    ELF=JoinPath(System.currentDirectory(), "POPSTARTER_DEBUG.ELF");
    DESC="Debug build of POPSTARTER in the same folder";
  },
  {
    ELF=JoinPath(System.currentDirectory(), "POPSTARTER_USBDELAY.ELF");
    DESC="POPSTARTER with increased USB delay (same folder)";
  },
  {
    ELF=JoinPath(System.currentDirectory(), "POPSTARTER_USBDELAY_DEBUG.ELF");
    DESC="USB delay + debug POPSTARTER build (same folder)";
  },
  {
    ELF=JoinPath(System.currentDirectory(), "POPSTARTER.ELF");
    DESC="Default POPSTARTER.ELF (same folder)";
  },
}

if DEFAULT_PROFILE > 0 and DEFAULT_PROFILE <= #PLDR.PROFILES then
  PLDR.POPSTARTER_PATH = PLDR.PROFILES[DEFAULT_PROFILE].ELF
end
