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
--- Add your images to this table, just write the name of the file.
--- Flat layout places images beside POPSLOADER.ELF; legacy installs can still use POPSLDR/IMG/*
--- FILES MUST HAVE EXTENSION. filename is parsed to create the access key: USB.PNG will be accesed by typing `IMG["USB"]`
local IMGS = {
  "USB.png",
  --"USBEXFAT.png",
  "SMB.png",
  "MMCE.png",
  "MX4SIO.png",
  --"HDD.png",
  "APAHDD.png",
  "BDHDD.png",
  "BKG.png",
  "MISSING.png",
  "PSL.png",
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

IMG = setmetatable({}, {
  __index = function (tbl, key)
    local source = IMG_SOURCES[key]
    if source == nil then return nil end
    if BOOT_PROF and BOOT_PROF.stamp and not BOOT_PROF.textures_ready then
      BOOT_PROF.textures_ready = true
      BOOT_PROF.stamp("UI assets init (textures)")
    end
    local path = ResolveImage(source)
    local img = Graphics.loadImage(path)
    if img == nil then error("Could not load '"..path.."'") end
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
end
LOGF("%d images registered (lazy)", #IMGS)
