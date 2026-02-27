--[[
  ___  ___  ___  ___ _                 _         
 | _ \/ _ \| _ \/ __| |   ___  __ _ __| |___ _ _ 
 |  _/ (_) |  _/\__ \ |__/ _ \/ _` / _` / -_) '_|
 |_|  \___/|_|  |___/____\___/\__,_\__,_\___|_|  
  Licensed under GNU General public license v3.0
--]]

LOG("Registering images")
--- Add your images to this table, just write the name of the file.
--- FILES MUST HAVE EXTENSION. filename is parsed to create the access key: USB.PNG will be accesed by typing `IMG["USB"]`
local IMG_REGISTRATIONS = {
  {"USB", "USB.png"},
  {"SMB", "SMB.png"},
  {"MMCE", "MMCE.png"},
  {"MX4SIO", "MX4SIO.png"},
  {"HDD", "HDD.png"},
  {"APAHDD", "APAHDD.png"},
  {"BDHDD", "BDHDD.png"},
  {"BG", "BG.png"},
  {"BKG", "BKG.png"},
  {"BGM", "BGM.png"},
  {"DISC", "DISC.png"},
  {"splash_bg", "splash_bg.png"},
  {"splash_logo", "splash_logo.png"},
  {"splash_appname", "splash_appname.png"},
  {"splash_credits", "splash_credits.png"},
  {"select", "select.png"},
  {"start", "start.png"},
  {"triangle", "triangle.png"},
  {"circle", "circle.png"},
  {"cross", "cross.png"},
  {"R2", "R2.png"},
  {"square", "square.png"},
}

local IMG_SOURCES = {}
for x = 1, #IMG_REGISTRATIONS do
  local name = IMG_REGISTRATIONS[x][1]
  local path = IMG_REGISTRATIONS[x][2]
  IMG_SOURCES[name] = path
end

local IMG_EMBED_ROOT = "embed:/POPSLDR/IMG/"

local IMG_EMBED_OVERRIDES = {
  BG = "embed:/POPSLDR/IMG/BG.png",
  BKG = "embed:/POPSLDR/IMG/BKG.png",
  BGM = "embed:/POPSLDR/IMG/BGM.png",

  splash_bg = "embed:/POPSLDR/IMG/splash_bg.png",
  splash_logo = "embed:/POPSLDR/IMG/splash_logo.png",
  splash_appname = "embed:/POPSLDR/IMG/splash_appname.png",
  splash_credits = "embed:/POPSLDR/IMG/splash_credits.png",
}

local function ResolveImage(name, key)
  if IMG_EMBED_OVERRIDES[key] then
    return IMG_EMBED_OVERRIDES[key]
  end
  return IMG_EMBED_ROOT .. name
end

local IMG_FAILED = {}

IMG = setmetatable({}, {
  __index = function (tbl, key)
    if IMG_FAILED[key] then return nil end
    local name = IMG_SOURCES[key]
    if name == nil then return nil end
    if BOOT_PROF and BOOT_PROF.stamp and not BOOT_PROF.textures_ready then
      BOOT_PROF.textures_ready = true
      BOOT_PROF.stamp("UI assets init (textures)")
    end

    local path = ResolveImage(name, key)
    local img = Graphics.loadImage(path)

    if img == nil then
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
