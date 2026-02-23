--[[
  ___  ___  ___  ___ _                 _         
 | _ \/ _ \| _ \/ __| |   ___  __ _ __| |___ _ _ 
 |  _/ (_) |  _/\__ \ |__/ _ \/ _` / _` / -_) '_|
 |_|  \___/|_|  |___/____\___/\__,_\__,_\___|_|  
  Licensed under GNU General public license v3.0
--]]

LOG("Registering images")
local function ResolveImage(name)
  local logical = "IMG/"..name
  return System.resolveAssetType(name, ASSET_IMG) or System.resolveAsset(logical) or JoinPath(APP_DIR_LOCAL, logical)
end

local function IsBootBgKey(key)
  return key == "BG" or key == "BGM" or key == "BKG" or key == "PSL"
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
  "BG.png",
  "BKG.png",
  "BGM.png",
  "DISC.png",
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
    if IsBootBgKey(key) then
      LOGF("IMGLOAD: key=IMG/%s handle=%s", tostring(source), tostring(img))
      LOGF("IMGTYPE key=%s type=%s", tostring(key), type(img))
      if img ~= nil then
        local iw = Graphics.getImageWidth(img)
        local ih = Graphics.getImageHeight(img)
        LOGF("IMGDIM key=%s width=%s height=%s path=%s", tostring(key), tostring(iw), tostring(ih), tostring(path))
      end
    end
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
