--[[
  ___  ___  ___  ___ _                 _         
 | _ \/ _ \| _ \/ __| |   ___  __ _ __| |___ _ _ 
 |  _/ (_) |  _/\__ \ |__/ _ \/ _` / _` / -_) '_|
 |_|  \___/|_|  |___/____\___/\__,_\__,_\___|_|  
  Licensed under GNU General public license v3.0
--]]

LOG("Registering images")
local IMG_EMBED_OVERRIDES = {
  BG = "embed:/POPSLDR/IMG/BG.png",
  BKG = "embed:/POPSLDR/IMG/BKG.png",
  BGM = "embed:/POPSLDR/IMG/BGM.png",
  splash_bg = "embed:/POPSLDR/IMG/splash_bg.png",
}

local function ResolveImage(name, key)
  if key ~= nil then
    local explicit = IMG_EMBED_OVERRIDES[key]
    if explicit ~= nil then
      return explicit
    end
  end
  return "embed:/POPSLDR/IMG/"..name
end
--- Add your images to this table, just write the name of the file.
--- Flat layout places images beside POPSLOADER.ELF; legacy installs can still use POPSLDR/IMG/*
--- FILES MUST HAVE EXTENSION. filename is parsed to create the access key: USB.PNG will be accesed by typing `IMG["USB"]`
local IMGS = {
  "USB.png",
  "USBEXFAT.png",
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
  "MISSING.png",
  "PSL.png",
  "splash_bg.png",
  "splash_appname.png",
  "splash_logo.png",
  "splash_credits.png",
  "select.png",
  "start.png",
  "triangle.png",
  "circle.png",
  "cross.png",
  "R2.png",
  "down.png",
  --"L1.png",
  --"L2.png",
  --"L3.png",
  "left.png",
  --"R1.png",
  --"R3.png",
  "right.png",
  "square.png",
  "up.png",
}
local IMG_SOURCES = {}
for x=1, #IMGS do
  local key = IMGS[x]:match("(.+)%..+$")
  IMG_SOURCES[key] = IMGS[x]
end
IMG_SOURCES["MMCE"] = "MMCE.png"
IMG_SOURCES["MX4SIO"] = "MX4SIO.png"

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
    local path = ResolveImage(source, key)
    local img = Graphics.loadImage(path)
    if img == nil then
      LOGF("Image load failed: %s", path)
      IMG_FAILED[key] = true
      if key ~= "MISSING" then
        local missing_source = IMG_SOURCES["MISSING"]
        if missing_source ~= nil and not IMG_FAILED["MISSING"] then
          local missing_path = ResolveImage(missing_source)
          local missing_img = Graphics.loadImage(missing_path)
          if missing_img ~= nil then
            Graphics.setImageFilters(missing_img, LINEAR)
            rawset(tbl, "MISSING", missing_img)
            rawset(tbl, key, missing_img)
            return missing_img
          end
          LOGF("Image load failed: %s", missing_path)
          IMG_FAILED["MISSING"] = true
        end
      end
      return nil
    end
    Graphics.setImageFilters(img, LINEAR)
    rawset(tbl, key, img)
    return img
  end
})

local BACKGROUND_EMBED_URIS = IMG_EMBED_OVERRIDES

local backgrounds_realized = false
local function ForceRealizeBackground(key, uri)
  local img = Graphics.loadImage(uri, false)
  if img == nil then
    return
  end
  Graphics.setImageFilters(img, LINEAR)
  IMG_FAILED[key] = nil
  rawset(IMG, key, img)
end

local function ForceRealizeBackgrounds()
  if backgrounds_realized then
    return
  end
  backgrounds_realized = true
  for key, uri in pairs(BACKGROUND_EMBED_URIS) do
    ForceRealizeBackground(key, uri)
  end
end

ForceRealizeBackgrounds()

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
LOGF("%d images registered (lazy)", #IMGS)
