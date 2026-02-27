--[[
  ___  ___  ___  ___ _                 _         
 | _ \/ _ \| _ \/ __| |   ___  __ _ __| |___ _ _ 
 |  _/ (_) |  _/\__ \ |__/ _ \/ _` / _` / -_) '_|
 |_|  \___/|_|  |___/____\___/\__,_\__,_\___|_|  
  Licensed under GNU General public license v3.0
--]]

LOG("Registering images")
--- Add your images to this table, just write the file name.
--- Access key is generated from basename without extension (e.g. USB.png -> IMG["USB"]).
local IMG_REGISTRATIONS = {
  "USB.png",
  "SMB.png",
  "MMCE.png",
  "MX4SIO.png",
  "HDD.png",
  "APAHDD.png",
  "BDHDD.png",
  "BG.png",
  "BKG.png",
  "BGM.png",
  "DISC.png",
  "splash_bg.png",
  "splash_logo.png",
  "splash_appname.png",
  "splash_credits.png",
  "select.png",
  "start.png",
  "triangle.png",
  "circle.png",
  "cross.png",
  "R2.png",
  "square.png",
}

local IMG_SOURCES = {}
for x = 1, #IMG_REGISTRATIONS do
  local file = IMG_REGISTRATIONS[x]
  local name = string.match(file, "^(.*)%.[^%.]+$") or file
  IMG_SOURCES[name] = file
end

-- legacy splash aliases
IMG_SOURCES["SPLASH1"] = "splash_bg.png"
IMG_SOURCES["SPLASH2"] = "splash_logo.png"
IMG_SOURCES["SPLASH3"] = "splash_appname.png"
IMG_SOURCES["SPLASH4"] = "splash_credits.png"

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

    local img = nil
    if type(System) == "table" and type(System.getEmbeddedAsset) == "function" and type(Graphics) == "table" and type(Graphics.loadImageEmbedded) == "function" then
      local ok, blob = pcall(System.getEmbeddedAsset, source)
      if ok and blob ~= nil then
        img = Graphics.loadImageEmbedded(blob, string.len(blob))
      end
    end

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
