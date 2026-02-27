--[[
  ___  ___  ___  ___ _                 _         
 | _ \/ _ \| _ \/ __| |   ___  __ _ __| |___ _ _ 
 |  _/ (_) |  _/\__ \ |__/ _ \/ _` / _` / -_) '_|
 |_|  \___/|_|  |___/____\___/\__,_\__,_\___|_|  
  Licensed under GNU General public license v3.0
--]]

LOG("Registering images")
local function ResolveImage(name)
  return System.resolveAssetType(name, ASSET_IMG) or name
end
local function DoesAssetExist(path)
  if path == nil or path == "" then return false end
  if type(System) == "table" and type(System.doesFileExist) == "function" then
    local ok, found = pcall(System.doesFileExist, path)
    if ok and found == true then return true end
  end
  if type(doesFileExist) == "function" then
    local ok, found = pcall(doesFileExist, path)
    if ok and found == true then return true end
  end
  return false
end
--- Add your images to this table, just write the name of the file.
--- Flat layout places images beside POPSLOADER.ELF; legacy installs can still use POPSLDR/IMG/*
--- FILES MUST HAVE EXTENSION. filename is parsed to create the access key: USB.PNG will be accesed by typing `IMG["USB"]`
local IMG_REGISTRATIONS = {
  {"USB", "USB.png"},
  {"SMB", "SMB.png"},
  {"MMCE", "MMCE.png"},
  {"MX4SIO", "MX4SIO.png"},
  {"HDD", "HDD.png"},
  {"APAHDD", "APAHDD.png"},
  {"BDHDD", "BDHDD.png"},
  {"BKG", "BKG.png"},
  {"BGM", "BGM.png"},
  {"DISC", "DISC.png"},
  {"MISSING", "MISSING.png"},
  {"SPLASH1", "splash_bg.png"},
  {"SPLASH2", "splash_logo.png"},
  {"SPLASH3", "splash_appname.png"},
  {"SPLASH4", "splash_credits.png"},
  {"select", "select.png"},
  {"start", "start.png"},
  {"triangle", "triangle.png"},
  {"circle", "circle.png"},
  {"cross", "cross.png"},
  {"R2", "R2.png"},
  --"down.png",
  --"L1.png",
  --"L2.png",
  --"L3.png",
  --"left.png",
  --"R1.png",
  --"R3.png",
  --"right.png",
  {"square", "square.png"},
  --"up.png",
}
local IMG_SOURCES = {}
local function RegisterImageIfExists(name, path)
  local resolved = ResolveImage(path)
  if DoesAssetExist(resolved) then
    IMG_SOURCES[name] = path
    return true
  end
  return false
end
for x=1, #IMG_REGISTRATIONS do
  local name = IMG_REGISTRATIONS[x][1]
  local path = IMG_REGISTRATIONS[x][2]
  RegisterImageIfExists(name, path)
end

local IMG_FAILED = {}

IMG = setmetatable({}, {
  __index = function (tbl, key)
    if IMG_FAILED[key] then return nil end
    local source = IMG_SOURCES[key]
    if source == nil then return nil end
    if BOOT_PROF and BOOT_PROF.stamp and not BOOT_PROF.textures_ready then
      BOOT_PROF.textures_ready = true
      BOOT_PROF.stamp("UI assets init (textures)")
    end
    local path = ResolveImage(source)
    local img = Graphics.loadImage(path)
    if img == nil then
      LOGF("Image load failed: %s", path)
      IMG_FAILED[key] = true
      return nil
    end
    Graphics.setImageFilters(img, LINEAR)
    rawset(tbl, key, img)
    return img
  end
})
function IMG.ReleaseAll()
  local free_ok = type(Graphics) == "table" and type(Graphics.freeImage) == "function"
  for key, _ in pairs(IMG_SOURCES) do
    local img = rawget(IMG, key)
    if img ~= nil then
      if free_ok then
        pcall(Graphics.freeImage, img)
      end
      rawset(IMG, key, nil)
    end
  end
  IMG_FAILED = {}
end
local registered_count = 0
for _, _ in pairs(IMG_SOURCES) do
  registered_count = registered_count + 1
end
LOGF("%d images registered (lazy)", registered_count)
