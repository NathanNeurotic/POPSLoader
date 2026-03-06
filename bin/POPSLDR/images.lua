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
  {"default", "default.png"},
  {"disable_art", "disable_art.png"},
  {"frame", "frame.png"},
  {"MISSING", "missing.png"},
}

local IMG_SOURCES = {}
for x = 1, #IMG_REGISTRATIONS do
  local name = IMG_REGISTRATIONS[x][1]
  local path = IMG_REGISTRATIONS[x][2]
  IMG_SOURCES[name] = path
end

local IMG_FAILED = {}

local function LoadExternalImage(source)
  if source == nil or source == "" then return nil end
  if type(Graphics) ~= "table" or type(Graphics.loadImage) ~= "function" then
    return nil
  end
  local candidates = {
    source,
    "IMG/"..source,
    "POPSLDR/IMG/"..source
  }
  if type(System) == "table" and type(System.resolveAsset) == "function" then
    local ok, resolved = pcall(System.resolveAsset, source)
    if ok and type(resolved) == "string" and resolved ~= "" then
      table.insert(candidates, 1, resolved)
    end
  end
  for i = 1, #candidates do
    local path = candidates[i]
    local exists = true
    if type(doesFileExist) == "function" then
      local ok_exists, res = pcall(doesFileExist, path)
      exists = ok_exists and res == true
    end
    if exists then
      local ok_img, img = pcall(Graphics.loadImage, path)
      if ok_img and img ~= nil then
        return img
      end
    end
  end
  return nil
end

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
      img = LoadExternalImage(source)
    end

    if img == nil then
      IMG_FAILED[key] = true
      return nil
    end

    if type(Graphics.setImageFilters) == "function" then
      Graphics.setImageFilters(img, LINEAR)
    end
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
