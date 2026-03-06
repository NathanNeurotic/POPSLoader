--[[
  ___  ___  ___  ___ _                 _         
 | _ \/ _ \| _ \/ __| |   ___  __ _ __| |___ _ _ 
 |  _/ (_) |  _/\__ \ |__/ _ \/ _` / _` / -_) '_|
 |_|  \___/|_|  |___/____\___/\__,_\__,_\___|_|  
  Licensed under GNU General public license v3.0
--]]

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
  {"MISSING", "MISSING.png"},
  {"default", "default.png"},
  {"frame", "frame.png"},
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
  {"left",  "left.png"},
  {"right", "right.png"},
  {"up",    "up.png"},
  {"down",  "down.png"},
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
