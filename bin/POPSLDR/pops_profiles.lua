--[[
  ___  ___  ___  ___ _                 _         
 | _ \/ _ \| _ \/ __| |   ___  __ _ __| |___ _ _ 
 |  _/ (_) |  _/\__ \ |__/ _ \/ _` / _` / -_) '_|
 |_|  \___/|_|  |___/____\___/\__,_\__,_\___|_|  
  Licensed under GNU General public license v3.0
--]]
LOG("Registering POPStarter profiles...")
local DEFAULT_PROFILE = 1
PLDR.DEFAULT_PROFILE = DEFAULT_PROFILE

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

PLDR.PROFILES = {
  {
    ELF=JoinPathCompat(APP_DIR_LOCAL, "POPSTARTER.ELF");
    DESC="PopStarter located next to POPSLOADER.ELF";
  },
}

if DEFAULT_PROFILE > 0 and DEFAULT_PROFILE <= #PLDR.PROFILES then
  PLDR.POPSTARTER_PATH = PLDR.PROFILES[DEFAULT_PROFILE].ELF
end
