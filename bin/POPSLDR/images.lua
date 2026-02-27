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
  {"BKG", "BKG.png"},
  {"BGM", "BGM.png"},
  {"BG", "BG.png"},
  {"DISC", "DISC.png"},
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
  {"square", "square.png"},
}

local IMG_SOURCES = {}
for x = 1, #IMG_REGISTRATIONS do
  local name = IMG_REGISTRATIONS[x][1]
  local path = IMG_REGISTRATIONS[x][2]
  IMG_SOURCES[name] = path
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

    local img = nil
    if type(System) == "table" and type(System.getEmbeddedAsset) == "function" and type(Graphics) == "table" and type(Graphics.loadImageEmbedded) == "function" then
      local ok, blob = pcall(System.getEmbeddedAsset, source)
      if ok and blob ~= nil then
        img = Graphics.loadImageEmbedded(blob, string.len(blob))
      end
    end

    if img == nil and type(Graphics) == "table" and type(Graphics.loadImage) == "function" then
      local candidates = {source, "IMG/"..source}
      for i = 1, #candidates do
        local rel = candidates[i]
        local path = rel
        if type(System) == "table" and type(System.resolveAsset) == "function" then
          local ok_resolve, resolved = pcall(System.resolveAsset, rel)
          if ok_resolve and resolved ~= nil then
            path = resolved
          end
        end
        local ok_load, loaded = pcall(Graphics.loadImage, path)
        if ok_load and loaded ~= nil then
          img = loaded
          break
        end
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
