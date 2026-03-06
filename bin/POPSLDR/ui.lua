--[[
  ___  ___  ___  ___ _                 _         
 | _ \/ _ \| _ \/ __| |   ___  __ _ __| |___ _ _ 
 |  _/ (_) |  _/\__ \ |__/ _ \/ _` / _` / -_) '_|
 |_|  \___/|_|  |___/____\___/\__,_\__,_\___|_|  
  Licensed under GNU General public license v3.0
--]]

local DEVLOCK = { NONE = 0, USB = 1, MMCE = 2, MX4SIO = 3 }
local UI
local function Round(value)
  return math.floor(value + 0.5)
end
local function Clamp01(t)
  if t < 0 then return 0 end
  if t > 1 then return 1 end
  return t
end
local function Clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end
local function EaseInOutCubic(t)
  t = Clamp01(t)
  if t < 0.5 then
    return 4 * t * t * t
  end
  local f = -2 * t + 2
  return 1 - (f * f * f) / 2
end
local function SafeDoesFileExist(path)
  if path == nil or path == "" then return false end
  if type(doesFileExist) == "function" then
    local okcall, res = pcall(doesFileExist, path)
    return okcall and res == true
  end
  if type(System) == "table" and type(System.openFile) == "function" and type(System.closeFile) == "function" then
    local okfd, fd = pcall(System.openFile, path, O_RDONLY)
    if okfd and fd ~= nil and fd >= 0 then
      pcall(System.closeFile, fd)
      return true
    end
  end
  return false
end
local function ResolveFirstExistingElf(candidates)
  if candidates == nil then return nil end
  for i = 1, #candidates do
    local path = candidates[i]
    if SafeDoesFileExist(path) then
      return path
    end
  end
  return nil
end
local function ExtractGameRelPath(entry)
  if entry == nil then return nil end
  local relpath = string.match(entry, "^[^|]+|(.+)$")
  return relpath or entry
end
local function BuildListResolvedVcdPath(entry, game_path)
  if entry == nil or entry == "" then
    return nil
  end
  local root, rel = string.match(entry, "^([^|]+)|(.+)$")
  if root ~= nil then
    if string.match(root, "^__%.POPS%d*$") then
      local cleaned_rel = string.gsub(rel or "", "^/", "")
      return "hdd0:"..root.."/"..cleaned_rel
    end
    return root..(rel or "")
  end
  return tostring(game_path or "")..tostring(entry)
end
local function StripExtension(path)
  if path == nil then return nil end
  local stripped = string.match(path, "(.+)%.[^%.]+$")
  return stripped or path
end
local CoverCache = {
  max = 3,
  entries = {},
  order = {},
  failed = {},
  last_key = nil,
  last_img = nil
}
function CoverCache:Clear()
  local free_ok = type(Graphics) == "table" and type(Graphics.freeImage) == "function"
  for key, img in pairs(self.entries) do
    if free_ok then
      pcall(Graphics.freeImage, img)
    end
    self.entries[key] = nil
  end
  self.order = {}
  self.failed = {}
  self.last_key = nil
  self.last_img = nil
end
function CoverCache:EvictIfNeeded()
  while #self.order > self.max do
    local evict_key = table.remove(self.order, 1)
    local img = self.entries[evict_key]
    if img ~= nil then
      if type(Graphics) == "table" and type(Graphics.freeImage) == "function" then
        pcall(Graphics.freeImage, img)
      end
      self.entries[evict_key] = nil
    end
  end
end
function CoverCache:GetOrLoad(path)
  if path == nil or path == "" then return nil end
  local cached = self.entries[path]
  if cached ~= nil then
    return cached
  end
  if self.failed[path] then
    return nil
  end
  if not SafeDoesFileExist(path) then
    self.failed[path] = true
    return nil
  end
  if type(Graphics) ~= "table" or type(Graphics.loadImage) ~= "function" then
    self.failed[path] = true
    return nil
  end
  local img = Graphics.loadImage(path)
  if img == nil then
    self.failed[path] = true
    return nil
  end
  if type(Graphics.setImageFilters) == "function" then
    Graphics.setImageFilters(img, LINEAR)
  end
  self.entries[path] = img
  table.insert(self.order, path)
  self:EvictIfNeeded()
  return img
end
function CoverCache:UpdateSelection(path)
  local key = tostring(path or "")
  if self.last_key == key then
    return self.last_img
  end
  self.last_key = key
  self.last_img = nil
  if path == nil or path == "" then
    return nil
  end
  local img = self:GetOrLoad(path)
  if img ~= nil then
    self.last_img = img
    return img
  end
  return nil
end
UI = {
    LASTSCENE = 5;
    SCENES = {
      GUSBFAT = 1,
      GSMB = 3,
      GMX4SIO = 4,
      GHDD = 5,
      GAPAHDD = 5,
      GBDMHDD = 6,
      MMAIN = 8,
      MPROFILE = 9,
      CREDITS = 10
    };
    LAUNCHING = false;
    DEVLOCK = DEVLOCK;
    device_lock = DEVLOCK.NONE;
    boot_device = DEVLOCK.NONE;
    boot_locks = {};
    BOOT_SOUND = {
      ENABLED = true,
      PATH = "boot.adp",      -- relative to CWD (same folder as ui.lua on HostFS)
      SECONDS = 3.0,          -- splash minimum hold to cover audio (adjust to match boot.adp)
      PAD_SECONDS = 0.5,      -- extra padding to keep splash visible after audio starts
      BOOT_PHASE_SECONDS = 8.0,
      CREDITS_PHASE_SECONDS = 7.0,
      CHANNEL = 0,
      VOLUME = 100,           -- master volume (0-100 typical, scaled to audsrv range)
      ADPCM_VOLUME = 100      -- per-channel ADPCM volume (0-100 typical, scaled to audsrv range)
    };
    CoverCache = CoverCache;
    device_lock_name = function (lock)
      if lock == DEVLOCK.USB then return "USB" end
      if lock == DEVLOCK.MMCE then return "MMCE" end
      if lock == DEVLOCK.MX4SIO then return "MX4SIO" end
      return "None"
    end;
    canEnterDevice = function (target)
      if UI.boot_locks ~= nil and UI.boot_locks[target] == true then
        return false, "boot", UI.boot_device
      end
      if UI.device_lock == DEVLOCK.NONE then
        return true
      end
      if UI.device_lock == target then
        return true
      end
      return false, "session", UI.device_lock
    end;
    setDeviceLock = function (target)
      if UI.device_lock == DEVLOCK.NONE then
        UI.device_lock = target
      end
    end;
    RequestScene = function (SCENE)
      if UI.Transition ~= nil and UI.Transition.Start ~= nil then
        if UI.Transition.active then
          if UI.Transition.Queue ~= nil then
            UI.Transition.Queue(SCENE)
          end
          return
        end
        if UI.CURSCENE ~= SCENE then
          UI.Transition.Start(SCENE)
        end
      end
    end;
    SceneChange = function (SCENE)
      UI.RequestScene(SCENE)
    end;
    UpdateVmode = function ()
      Screen.setMode(UI.SCR.VMODE, UI.SCR.X, UI.SCR.Y, CT24, INTERLACED, FIELD)
    end;
    --- Color Constants
    CCOL = {
      GREY = Color.new(128,128,128,128);
      YELLOW = Color.new(80, 170, 255, 128);
      RED = Color.new(128,0,0);
      TRANSP_BLACK = Color.new(0,0,0,40);
    };
    COLORS = {
	      TEXT_PRIMARY = Color.new(140, 200, 255, 128);
	      -- PS2 menu-style blues for lists (selected/unselected)
	      LIST_SELECTED = Color.new(120, 205, 255, 128);
	      LIST_UNSELECTED = Color.new(45, 85, 155, 128);
    };
    FONT = {
      TITLE = Font.LoadBuiltinFont();
      LABEL = Font.LoadBuiltinFont();
      STATUS = SFONT;
      TITLE_SIZE = 960;
      LABEL_SIZE = 880;
    };
    --- UI Constants
    SCR = {
	      -- Match GS mode (NTSC 640x448 interlaced field) to prevent right-edge clipping.
	      X = 640;
	      X_MID = 640/2;
	      Y = 448;
	      Y_MID = 448/2;
      VMODE = _480p;
      BGCOL = Color.new(20, 30, 80);
    };
    LAYOUT = {
      SAFE = {L = 40, R = 40, T = 24, B = 28};
      BTN_BAR_SAFE_BOTTOM = 56;
      ICON_SPACING = 120;
      LIST_ROW_H = 20;
      PREVIEW_W = 240;
      PREVIEW_H = 240;
	      -- Match BETA-5 carousel/menu vertical placement.
      CAROUSEL_Y_OFFSET = 36;
      FOOTER_ICON_SCALE = 0.63;
      FOOTER_LABEL_W = 140;
      FOOTER_ICON_Y_OFFSET = 24;
      FOOTER_LABEL_Y_OFFSET = 10;
    };
    RecalcLayout = function ()
      UI.SCR.X_MID = Round(UI.SCR.X / 2)
      UI.SCR.Y_MID = Round(UI.SCR.Y / 2)
      local safe = UI.LAYOUT.SAFE
      -- Ensure footer layout constants are always defined (avoid nil arithmetic)
      UI.LAYOUT.BTN_BAR_SAFE_BOTTOM = UI.LAYOUT.BTN_BAR_SAFE_BOTTOM or (((safe and safe.B) or 0) + 44)
      local safe_w = UI.SCR.X - safe.L - safe.R
      local safe_h = UI.SCR.Y - safe.T - safe.B
      UI.LAYOUT.SAFE_W = safe_w
      UI.LAYOUT.SAFE_H = safe_h
      UI.LAYOUT.SAFE_X_MID = Round(safe.L + (safe_w / 2))
      UI.LAYOUT.TITLE_Y = Round(safe.T + 6)
      UI.LAYOUT.STATUS_Y = Round(UI.LAYOUT.TITLE_Y + 20)
      UI.LAYOUT.ICON_ROW_Y = Round(UI.SCR.Y_MID - 40)
      UI.LAYOUT.LIST_X = Round(safe.L)
      UI.LAYOUT.LIST_Y = Round(safe.T + 16)
      UI.LAYOUT.LIST_W = math.floor(safe_w * 0.52)
      UI.LAYOUT.LIST_MAX = math.floor((safe_h - 80) / UI.LAYOUT.LIST_ROW_H)
      if UI.LAYOUT.LIST_MAX < 1 then
        UI.LAYOUT.LIST_MAX = 1
      end
      local preview_w = UI.LAYOUT.PREVIEW_W
      local preview_h = UI.LAYOUT.PREVIEW_H
      local preview_gap = 24
      local max_preview_w = safe_w - UI.LAYOUT.LIST_W - preview_gap
      if max_preview_w < preview_w then
        preview_w = max_preview_w
      end
      if preview_w < 0 then preview_w = 0 end
      UI.LAYOUT.PREVIEW_W = preview_w
      UI.LAYOUT.PREVIEW_H = preview_h
      UI.LAYOUT.PREVIEW_X = Round(UI.SCR.X - safe.R - preview_w)
      UI.LAYOUT.PREVIEW_Y = Round(UI.SCR.Y_MID - (preview_h / 2))
      UI.LAYOUT.FOOTER_ICON_Y = Round(UI.SCR.Y - UI.LAYOUT.BTN_BAR_SAFE_BOTTOM)
      UI.LAYOUT.FOOTER_LABEL_Y = Round(UI.LAYOUT.FOOTER_ICON_Y + UI.LAYOUT.FOOTER_LABEL_Y_OFFSET)
    end;
    GetRowPosition = function (index, count)
      local spacing = UI.LAYOUT.ICON_SPACING
      local center = UI.SCR.X_MID
      local offset = (index - (count + 1) / 2) * spacing
      return center + offset
    end;
    InputConfig = {
      MIN_ACTION_MS = 220;
      DEBUG_INPUT_LOG = false;
    };
    BdmaModes = {
      { key = "FAT32", label = "FAT32-USB (None)" },
      { key = "USBEXFAT", label = "exFAT-USB" },
      { key = "MX4SIO", label = "MX4SIO" },
      { key = "MMCE", label = "MMCE" }
    };
    BdmaModeIndex = 1;
    BdmaDirty = false;
    ProfileDirty = false;
    SavingActive = false;
    ShowSavingOverlay = function ()
      UI.SavingActive = true
      UI.flip()
      UI.SavingActive = false
    end;
    --- Notifications queue handler
    Notif_queue = {
      display = function ()
        local Q
        if #UI.Notif_queue.msg < 1 then return end
        if #UI.Notif_queue.msg > 1 then
          Q = 0x50
        elseif UI.Notif_queue.ALFA > 0x50 then
          Q = 0x50
        else
          Q = math.floor(UI.Notif_queue.ALFA)
        end
        Graphics.drawRect(30, 30, UI.SCR.X_MID-30, 40, Color.new(0, 0, 0, Q))
        Font.ftPrint(BFONT, 32, 32, 0, UI.SCR.X_MID-30, 32, UI.Notif_queue.msg[1], Color.new(0, 100, 255, math.floor(UI.Notif_queue.ALFA)))
        UI.Notif_queue.ALFA = UI.Notif_queue.ALFA-.8
        if UI.Notif_queue.ALFA < 1 then
          UI.Notif_queue.ALFA = 0x90
          table.remove(UI.Notif_queue.msg, 1)
        end
      end;
      ALFA = 0x80;
      add = function (NOTIF)
        table.insert(UI.Notif_queue.msg, NOTIF)
      end;
      msg = {};
    };
    Notify = function (msg, _ms)
      UI.Notif_queue.add(msg)
    end;
    Footer = {
      order = {"triangle", "circle", "cross", "square"};
      order_with_r2 = {"triangle", "circle", "cross", "square"};
      order_with_start = {"triangle", "circle", "cross", "start"};
      order_with_start_r2 = {"triangle", "circle", "cross", "square", "start"};
      labels = {
        triangle = "Credits",
        circle_main = "Exit",
        circle_other = "Back",
        start_profiles = "Settings",
        start_reset = "Reset Defaults",
        cross_confirm = "Confirm",
        cross_enter = "Enter",
        cross_select = "Select",
        cross_launch = "Launch"
      };
      legend_cache = {};
      LegendKey = function (order_id, circle_label, cross_label, start_label, square_label, r2_label)
        return table.concat({
          tostring(order_id or ""),
          tostring(circle_label or ""),
          tostring(cross_label or ""),
          tostring(start_label or ""),
          tostring(square_label or ""),
          tostring(r2_label or "")
        }, "|")
      end;
      ResolveLegend = function (opts)
        local order = opts.order or UI.Footer.order
        local order_id = opts.order_id or "default"
        local circle_label = opts.circle or UI.Footer.labels.circle_other
        local cross_label = opts.cross or UI.Footer.labels.cross_confirm
        local start_label = opts.start or UI.Footer.labels.start_profiles
        local square_label = opts.square
        local r2_label = opts.R2
        local key = UI.Footer.LegendKey(order_id, circle_label, cross_label, start_label, square_label, r2_label)
        local cached = UI.Footer.legend_cache[key]
        if cached ~= nil then
          return cached.labels, cached.order
        end
        local labels = {
          triangle = UI.Footer.labels.triangle,
          circle = circle_label,
          cross = cross_label,
          start = start_label
        }
        if square_label ~= nil then
          labels.square = square_label
        end
        UI.Footer.legend_cache[key] = {labels = labels, order = order}
        return labels, order
      end;
      Draw = function (labels, order)
        local safe = UI.LAYOUT.SAFE
        local entries = order or UI.Footer.order
        local count = #entries
        local icon_scale = UI.LAYOUT.FOOTER_ICON_SCALE or 1.0
        local bar_height = 0
        for i = 1, count do
          local key = entries[i]
          local icon = IMG[key]
          if icon ~= nil then
            local h = Graphics.getImageHeight(icon)
            local scaled_h = Round((h or 0) * icon_scale)
            if scaled_h > 0 and h ~= nil and scaled_h > bar_height then
              bar_height = scaled_h
            end
          end
        end
        local barY = UI.LAYOUT.FOOTER_ICON_Y
        if bar_height > 0 and (barY + (bar_height / 2)) > (UI.SCR.Y - 8) then
          barY = UI.SCR.Y - 8 - (bar_height / 2)
        end
        local labelY = UI.LAYOUT.FOOTER_LABEL_Y
        -- Centered/tighter spacing (avoids running off-screen on real CRT overscan).
        local max_w = 0
        for i = 1, count do
          local key = entries[i]
          local icon = IMG[key]
          if icon ~= nil then
            local w = Graphics.getImageWidth(icon)
            local scaled_w = Round((w or 0) * icon_scale)
            if scaled_w > 0 and w ~= nil and scaled_w > max_w then
              max_w = scaled_w
            end
          end
        end
        local max_half_w = max_w / 2
        local spacing
        if count <= 1 then
          spacing = 0
        else
          local max_spacing = math.floor(UI.LAYOUT.SAFE_W / (count + 0.5))
          spacing = math.min(140, max_spacing)
          if spacing < 96 then spacing = 96 end
        end
        local safe_left = (safe and safe.L) or 0
        local safe_right = UI.SCR.X - ((safe and safe.R) or 0)
        local available = (safe_right - max_half_w) - (safe_left + max_half_w)
        if available < 0 then available = 0 end
        if count > 1 then
          local max_fit_spacing = math.floor(available / (count - 1))
          if spacing > max_fit_spacing then spacing = max_fit_spacing end
        end
        if spacing < 0 then spacing = 0 end
        local total_w = spacing * (count - 1)
        local safe_center = UI.LAYOUT.SAFE_X_MID or UI.SCR.X_MID
        local start_x = Round((safe_left + max_half_w) + ((available - total_w) / 2))
        if count <= 1 then
          start_x = safe_center
        end
        for i = 1, count do
          local key = entries[i]
          local icon = IMG[key]
	          local x = Round(start_x + spacing * (i - 1))
          local y = Round(barY)
          if icon ~= nil then
            local w = Graphics.getImageWidth(icon)
            local h = Graphics.getImageHeight(icon)
            local scaled_w = Round((w or 0) * icon_scale)
            local scaled_h = Round((h or 0) * icon_scale)
            if scaled_w > 0 and scaled_h > 0 then
              Graphics.drawScaleImage(icon, x - (scaled_w / 2), y - (scaled_h / 2), scaled_w, scaled_h, UI.CCOL.GREY)
            end
          end
          local label = labels and labels[key] or nil
          if label ~= nil then
            Font.ftPrint(SFONT, x, labelY, 8, UI.LAYOUT.FOOTER_LABEL_W, 16, label, UI.CCOL.GREY)
          end
        end
      end;
    };
    --- wrapper for Screen.flip(), here you add UI draws that renders on top of everything (for example, error notifications)
    flip = function (notif)
      UI.Notif_queue.display()
      UI.Modal.Draw()
      if UI.SavingActive then
        Graphics.drawRect(0, 0, UI.SCR.X, UI.SCR.Y, Color.new(0, 0, 0, 140))
        Font.ftPrint(BFONT, UI.SCR.X_MID, UI.SCR.Y_MID - 8, 8, UI.SCR.X, 16, "Saving...", UI.CCOL.YELLOW)
      end
      if UI.Transition ~= nil then
        local alpha = UI.Transition.Update()
        if alpha > 0 then
          Graphics.drawRect(0, 0, UI.SCR.X, UI.SCR.Y, Color.new(0, 0, 0, alpha))
        end
      end
      Screen.flip()
    end;
    WelcomeDraw = {
      Play = function (next_scene, show_boot_credits)
	        -- Boot splash fades in from black, then fades out into the next scene.
	        local function DrawBackground()
	          Screen.clear(Color.new(0, 0, 0))
	        end
        local function DrawTargetBackground(scene)
          Screen.clear(UI.SCR.BGCOL)
          if scene == UI.SCENES.MMAIN then
            if IMG.BGM ~= nil then
              Graphics.drawScaleImage(IMG.BGM, 0, 0, UI.SCR.X, UI.SCR.Y)
            elseif IMG.BKG ~= nil then
              Graphics.drawScaleImage(IMG.BKG, 0, 0, UI.SCR.X, UI.SCR.Y)
            end
          elseif scene == UI.SCENES.CREDITS or scene == UI.SCENES.MPROFILE then
            if IMG.BG ~= nil then
              Graphics.drawScaleImage(IMG.BG, 0, 0, UI.SCR.X, UI.SCR.Y)
            elseif IMG.BKG ~= nil then
              Graphics.drawScaleImage(IMG.BKG, 0, 0, UI.SCR.X, UI.SCR.Y)
            end
          else
            if IMG.BKG ~= nil then
              Graphics.drawScaleImage(IMG.BKG, 0, 0, UI.SCR.X, UI.SCR.Y)
            end
          end
        end
        local function DrawTargetScene(scene)
          if scene == nil then return end
          DrawTargetBackground(scene)
          if scene == UI.SCENES.MMAIN and UI.MainMenu ~= nil and UI.MainMenu.DrawOnly ~= nil then
            UI.MainMenu.DrawOnly()
          elseif scene == UI.SCENES.CREDITS and UI.Credits ~= nil and UI.Credits.DrawOnly ~= nil then
            UI.Credits.DrawOnly()
          end
        end

-- Boot audio (relative to current directory). Never fatal.
        local boot_sound_tried = false
        local boot_sound_loaded = nil

        local function TryBootSound()
          if boot_sound_tried then return end
          boot_sound_tried = true

          if UI.BOOT_SOUND == nil or UI.BOOT_SOUND.ENABLED ~= true then
            return
          end
          if type(Sound) ~= "table" or type(Sound.loadADPCM) ~= "function" then
            return
          end
-- Set volumes/formats defensively; some builds may ignore these.
          local function normalize_volume(value)
            if type(value) ~= "number" then
              return nil
            end
            if value <= 100 then
              return math.floor((value * 0x3fff / 100) + 0.5)
            end
            return value
          end

          pcall(function()
            if type(Sound.setVolume) == "function" then
              local volume = normalize_volume(UI.BOOT_SOUND.VOLUME)
              if volume ~= nil then
                Sound.setVolume(volume)
              end
            end
            if type(Sound.setADPCMVolume) == "function" then
              local adpcm_volume = normalize_volume(UI.BOOT_SOUND.ADPCM_VOLUME)
              if adpcm_volume ~= nil then
                Sound.setADPCMVolume(UI.BOOT_SOUND.CHANNEL or 0, adpcm_volume)
              end
            end
            if type(Sound.setFormat) == "function" then
              -- Common safe defaults; ADPCM playback may ignore this on some builds.
              Sound.setFormat(16, 44100, 2)
            end
          end)

          local ok_load, audio = pcall(Sound.loadADPCM, "embed:boot.adp")
          if not ok_load then
            return
          end
          if audio == nil or audio == 0 then
            return
          end
          boot_sound_loaded = audio

          local ok_play, play_err = pcall(function()
            Sound.playADPCM(UI.BOOT_SOUND.CHANNEL or 0, boot_sound_loaded)
          end)
          if not ok_play then
            if type(Sound.freeADPCM) == "function" then
              pcall(Sound.freeADPCM, boot_sound_loaded)
            end
            boot_sound_loaded = nil
            return
          end

          local sec = UI.BOOT_SOUND.SECONDS
          if type(sec) ~= "number" or sec < 0 then sec = 0 end
          local pad = UI.BOOT_SOUND.PAD_SECONDS
          if type(pad) ~= "number" or pad < 0 then pad = 0 end
        end
        local function DrawSplashCover(img, screen_w, screen_h, alpha)
          if img == nil then return end
          local img_w = Graphics.getImageWidth(img)
          local img_h = Graphics.getImageHeight(img)
          local scale = 1
          if img_w > 0 and img_h > 0 then
            local cover_scale = math.max(screen_w / img_w, screen_h / img_h)
            scale = cover_scale * 1.02
          end
          local draw_w = Round(img_w * scale)
          local draw_h = Round(img_h * scale)
          local x = Round((screen_w - draw_w) / 2)
          local y = Round((screen_h - draw_h) / 2)
          local tint = Color.new(128, 128, 128, alpha)
          Graphics.drawScaleImage(img, x, y, draw_w, draw_h, tint)
        end
        local function DrawSplashNative(img, x, y, alpha)
          if img == nil then return end
          local img_w = Graphics.getImageWidth(img)
          local img_h = Graphics.getImageHeight(img)
          if img_w <= 0 or img_h <= 0 then return end
          local tint = Color.new(128, 128, 128, alpha)
          Graphics.drawScaleImage(img, Round(x), Round(y), img_w, img_h, tint)
        end
        local function DrawSplashText(alpha)
          -- Requested: black text because splash image is white.
          local y0 = UI.SCR.Y_MID + 120
          Font.ftPrint(BFONT, UI.SCR.X_MID, y0 + 36,  8, UI.SCR.X, 16, "israpps.github.io",    Color.new(0, 0, 0, alpha))
        end
        local function DrawSplashLayered(alpha)
          local splash_alpha = alpha or 128
          local splash1 = IMG.SPLASH1
          local splash2 = IMG.SPLASH2
          local splash3 = IMG.SPLASH3
          local splash4 = IMG.SPLASH4
          local safe = UI.LAYOUT.SAFE or {}
          local margin_top = safe.T or 16
          local margin_bottom = safe.B or 16
          if splash1 ~= nil then DrawSplashCover(splash1, UI.SCR.X, UI.SCR.Y, splash_alpha) end
          if splash2 ~= nil then
            local w = Graphics.getImageWidth(splash2)
            local h = Graphics.getImageHeight(splash2)
            DrawSplashNative(splash2, (UI.SCR.X - w) / 2, (UI.SCR.Y - h) / 2, splash_alpha)
          end
          if splash3 ~= nil then
            local w = Graphics.getImageWidth(splash3)
            DrawSplashNative(splash3, (UI.SCR.X - w) / 2, margin_top, splash_alpha)
          end
          if splash4 ~= nil then
            local w = Graphics.getImageWidth(splash4)
            local h = Graphics.getImageHeight(splash4)
            DrawSplashNative(splash4, (UI.SCR.X - w) / 2, UI.SCR.Y - h - margin_bottom, splash_alpha)
          end
        end

        local FADE_IN_MS = 1400
        local FADE_OUT_MS = 1200

        local function Clamp01(value)
          if value < 0 then return 0 end
          if value > 1 then return 1 end
          return value
        end

        local function StepFade(drawFn, alphaFrom, alphaTo, durationMs)
          local timer = Timer.new()
          local last_ms = Timer.getTime(timer)
          local elapsed = 0
          local max_step = (UI.Transition and UI.Transition.max_step) or 33
          if durationMs <= 0 then
            drawFn()
            local alpha = Round(alphaTo)
            if alpha > 0 then
              Graphics.drawRect(0, 0, UI.SCR.X, UI.SCR.Y, Color.new(0, 0, 0, alpha))
            end
            Screen.flip()
            return
          end
          while true do
            local now_ms = Timer.getTime(timer)
            local dt = now_ms - last_ms
            last_ms = now_ms
            if dt < 0 then dt = 0 end
            if dt > max_step then dt = max_step end
            elapsed = elapsed + dt
            if elapsed > durationMs then elapsed = durationMs end
            local t = Clamp01(elapsed / durationMs)
            local e = EaseInOutCubic(t)
            local alpha = Round(alphaFrom + (alphaTo - alphaFrom) * e)
            drawFn()
            if alpha > 0 then
              Graphics.drawRect(0, 0, UI.SCR.X, UI.SCR.Y, Color.new(0, 0, 0, alpha))
            end
            Screen.flip()
            if elapsed >= durationMs then
              break
            end
          end
        end

        local function StepHoldFrames(drawFn, frames)
          if frames <= 0 then
            drawFn()
            Screen.flip()
            return
          end
          for _ = 1, frames do
            drawFn()
            Screen.flip()
          end
        end

        local function DrawSplash()
          DrawBackground()
          DrawSplashLayered(128)
          DrawSplashText(128)
        end

        local function DrawCredits()
          DrawTargetScene(UI.SCENES.CREDITS)
        end

        local function DrawMenu()
          DrawTargetScene(next_scene or UI.SCENES.MMAIN)
        end

        -- Start boot sound once; explicit holds must not be lengthened by audio duration.
        TryBootSound()
        local FPS = 60
        local SPLASH_HOLD_FRAMES = math.floor(4.0 * FPS + 0.5)
        local CREDITS_HOLD_FRAMES = math.floor(4.0 * FPS + 0.5)
        local INTRO_FADE_SCALE = 2.0
        local INTRO_FADE_IN_MS = math.floor(FADE_IN_MS * INTRO_FADE_SCALE + 0.5)
        local INTRO_FADE_OUT_MS = math.floor(FADE_OUT_MS * INTRO_FADE_SCALE + 0.5)

        StepFade(DrawSplash, 128, 0, INTRO_FADE_IN_MS)
        StepHoldFrames(DrawSplash, SPLASH_HOLD_FRAMES)
        StepFade(DrawSplash, 0, 128, INTRO_FADE_OUT_MS)

        StepFade(DrawCredits, 128, 0, INTRO_FADE_IN_MS)
        StepHoldFrames(DrawCredits, CREDITS_HOLD_FRAMES)
        StepFade(DrawCredits, 0, 128, INTRO_FADE_OUT_MS)

        StepFade(DrawMenu, 128, 0, FADE_IN_MS)
        DrawMenu()
        Screen.flip()

        -- Cleanup boot sound resource (safe if audio backend ignores it).
        if boot_sound_loaded ~= nil and type(Sound) == "table" and type(Sound.freeADPCM) == "function" then
          pcall(Sound.freeADPCM, boot_sound_loaded)
        end
      end

    };
    --- UI draw routine applied before drawing UI, add background and stuff you want rendered UNDER UI and text
    BottomDraw = {
      Play = function ()
	        Screen.clear(UI.SCR.BGCOL)
	        -- Main menu uses BGM.png; all other scenes use BKG.png.
	        if UI.CURSCENE == UI.SCENES.MMAIN then
	          if IMG.BGM ~= nil then
	            Graphics.drawScaleImage(IMG.BGM, 0, 0, UI.SCR.X, UI.SCR.Y)
	          elseif IMG.BKG ~= nil then
	            Graphics.drawScaleImage(IMG.BKG, 0, 0, UI.SCR.X, UI.SCR.Y)
	          end
	        elseif UI.CURSCENE == UI.SCENES.CREDITS or UI.CURSCENE == UI.SCENES.MPROFILE then
	          if IMG.BG ~= nil then
	            Graphics.drawScaleImage(IMG.BG, 0, 0, UI.SCR.X, UI.SCR.Y)
	          elseif IMG.BKG ~= nil then
	            Graphics.drawScaleImage(IMG.BKG, 0, 0, UI.SCR.X, UI.SCR.Y)
	          end
	        else
	          if IMG.BKG ~= nil then
	            Graphics.drawScaleImage(IMG.BKG, 0, 0, UI.SCR.X, UI.SCR.Y)
	          end
	        end
        -- Removed opaque overlay box on non-main scenes (was masking background).
      end;
    };
    Modal = {
      active = false;
      title = "";
      body = "";
      options = {"Confirm", "Cancel"};
      confirm_action = nil;
      cancel_action = nil;
      triangle_action = nil;
      ignore_until_release = false;
      OpenExit = function ()
        UI.Modal.active = true
        UI.Modal.title = "Exit"
        UI.Modal.body = "Return to OSDSYS?"
        UI.Modal.options = {"OSDSYS", "Cancel", "BOOT.ELF"}
        UI.Modal.confirm_action = UI.Modal.ConfirmExit
        UI.Modal.cancel_action = UI.Modal.Close
        UI.Modal.triangle_action = UI.Modal.LaunchBootElf
        UI.Modal.ignore_until_release = true
      end;
      OpenDKWDRV = function ()
        UI.Modal.active = true
        UI.Modal.title = "Disc (DKWDRV)"
        UI.Modal.body = "Launch DKWDRV?"
        UI.Modal.options = {"Yes", "Cancel"}
        UI.Modal.confirm_action = function ()
          local elf_path = "mc0:/PS1_DKWDRV/DKWDRV.ELF"
          UI.LAUNCHING = true
          System.loadELF(elf_path, 1, elf_path)
          return
        end
        UI.Modal.cancel_action = UI.Modal.Close
        UI.Modal.triangle_action = nil
        UI.Modal.ignore_until_release = true
      end;
      OpenDeviceLock = function (reason, active, target)
        local active_name = UI.device_lock_name(active)
        local target_name = UI.device_lock_name(target)
        UI.Modal.active = true
        UI.Modal.title = "Device drivers already loaded"
        if reason == "boot" then
          UI.Modal.body = ("Current boot device (%s) requires drivers already loaded.\nTo use %s, restart POPSLoader to reload drivers."):format(active_name, target_name)
        else
          UI.Modal.body = ("Drivers for %s are already loaded.\nTo use %s, restart POPSLoader to reload drivers."):format(active_name, target_name)
        end
        UI.Modal.options = {"Return", "Back"}
        UI.Modal.confirm_action = function ()
          UI.Modal.Close()
          UI.SceneChange(UI.SCENES.MMAIN)
        end
        UI.Modal.cancel_action = UI.Modal.Close
        UI.Modal.triangle_action = nil
        UI.Modal.ignore_until_release = true
      end;
      Close = function ()
        UI.Modal.active = false
        UI.Modal.confirm_action = nil
        UI.Modal.cancel_action = nil
        UI.Modal.triangle_action = nil
        UI.Modal.ignore_until_release = false
      end;
      ConfirmExit = function ()
        UI.LAUNCHING = true
        System.exitToBrowser()
      end;
      LaunchBootElf = function ()
        local elf_path = ResolveFirstExistingElf({
          "mc0:/BOOT/BOOT2.ELF",
          "mc0:/BOOT/BOOT.ELF",
          "mc1:/BOOT/BOOT2.ELF",
          "mc1:/BOOT/BOOT.ELF"
        })
        if elf_path == nil then
          UI.Notify("BOOT.ELF not found", 120)
          return
        end
        UI.LAUNCHING = true
        UI.Modal.Close()
        System.loadELFRebootIOP(elf_path, elf_path)
        return
      end;
      HandleInput = function ()
        if not UI.Modal.active then return end
        if UI.Modal.ignore_until_release then
          if UI.Pad.GPAD ~= nil and UI.Pad.GPAD == 0 then
            UI.Modal.ignore_until_release = false
          end
          return
        end
        if UI.Pad.Events.CONFIRM then
          if UI.Modal.confirm_action ~= nil then
            UI.Modal.confirm_action()
          else
            UI.Modal.Close()
          end
        elseif UI.Pad.Events.BACK then
          if UI.Modal.cancel_action ~= nil then
            UI.Modal.cancel_action()
          else
            UI.Modal.Close()
          end
        elseif UI.Pad.Events.EXIT then
          if UI.Modal.triangle_action ~= nil then
            UI.Modal.triangle_action()
          end
        end
      end;
      Draw = function ()
        if not UI.Modal.active then return end
        local box_w = 320
        local box_h = 140
        local box_x = UI.SCR.X_MID - (box_w / 2)
        local box_y = UI.SCR.Y_MID - (box_h / 2)
        Graphics.drawRect(0, 0, UI.SCR.X, UI.SCR.Y, Color.new(0, 0, 0, 120))
        Graphics.drawRect(box_x, box_y, box_w, box_h, Color.new(0, 0, 0, 200))
        Graphics.drawRect(box_x, box_y, box_w, 2, UI.CCOL.GREY)
        Graphics.drawRect(box_x, box_y + box_h - 2, box_w, 2, UI.CCOL.GREY)
        Font.ftPrint(BFONT, UI.SCR.X_MID, box_y + 10, 8, UI.SCR.X, 16, UI.Modal.title, UI.CCOL.YELLOW)
        Font.ftPrint(BFONT, UI.SCR.X_MID, box_y + 50, 8, UI.SCR.X, 16, UI.Modal.body, UI.CCOL.GREY)
        local confirm_label = UI.Modal.options[1] or "Confirm"
        local cancel_label = UI.Modal.options[2] or "Cancel"
        local triangle_label = UI.Modal.options[3]
        local hint = ("X: %s    O: %s"):format(confirm_label, cancel_label)
        if triangle_label ~= nil then
          hint = ("%s    Triangle: %s"):format(hint, triangle_label)
        end
        Font.ftPrint(BFONT, UI.SCR.X_MID, box_y + 95, 8, UI.SCR.X, 16, hint, UI.CCOL.GREY)
      end;
    };
    Transition = {
      active = false,
      phase = "out",
      target = nil,
      next_target = nil,
      allowSceneWrite = false,
      timer = nil,
      start = 0,
      elapsed = 0,
      last_time = nil,
      max_step = 33,
      duration_out = 1200,
      duration_in = 1400,
      Queue = function (target)
        if target == nil then return end
        if UI.Transition.active and UI.Transition.phase == "out" then
          UI.Transition.target = target
          return
        end
        if target ~= UI.CURSCENE then
          UI.Transition.next_target = target
        end
      end,
      Start = function (target)
        if UI.Transition.timer == nil then
          UI.Transition.timer = Timer.new()
        end
        UI.Transition.active = true
        UI.Transition.phase = "out"
        UI.Transition.target = target
        UI.Transition.next_target = nil
        UI.Transition.start = Timer.getTime(UI.Transition.timer)
        UI.Transition.elapsed = 0
        UI.Transition.last_time = UI.Transition.start
      end,
      Update = function ()
        if not UI.Transition.active then
          return 0
        end
        local now = Timer.getTime(UI.Transition.timer)
        local last = UI.Transition.last_time or now
        local delta = now - last
        if delta < 0 then delta = 0 end
        local max_step = UI.Transition.max_step or 33
        if delta > max_step then delta = max_step end
        UI.Transition.elapsed = (UI.Transition.elapsed or 0) + delta
        UI.Transition.last_time = now
        local elapsed = UI.Transition.elapsed or 0
        local duration = UI.Transition.phase == "out" and UI.Transition.duration_out or UI.Transition.duration_in
        if duration <= 0 then duration = 1 end
        local t = elapsed / duration
        if t > 1 then t = 1 end
        local e = EaseInOutCubic(t)
        local alpha
        if UI.Transition.phase == "out" then
          alpha = Round(128 * e)
        else
          alpha = Round(128 * (1 - e))
        end
        if t >= 1 then
          if UI.Transition.phase == "out" then
            local previous_scene = UI.CURSCENE
            if UI.OnSceneExit ~= nil then
              UI.OnSceneExit(previous_scene, UI.Transition.target)
            end
            UI.LASTSCENE = UI.CURSCENE
            UI.Transition.allowSceneWrite = true
            UI.CURSCENE = UI.Transition.target
            UI.Transition.allowSceneWrite = false
            if UI.OnSceneEnter ~= nil then
              UI.OnSceneEnter(previous_scene, UI.CURSCENE)
            end
            UI.Transition.phase = "in"
            UI.Transition.start = now
            UI.Transition.elapsed = 0
            UI.Transition.last_time = now
            alpha = 128
          else
            local queued = UI.Transition.next_target
            if queued ~= nil and queued ~= UI.CURSCENE then
              UI.Transition.next_target = nil
              UI.Transition.Start(queued)
              alpha = 0
            else
              UI.Transition.active = false
              UI.Transition.target = nil
              UI.Transition.next_target = nil
              alpha = 0
            end
          end
        end
        return alpha
      end
    };
    HandleGlobalInput = function (allow_exit)
      if UI.Modal.active then
        UI.Modal.HandleInput()
        for key, _ in pairs(UI.Pad.Events) do
          UI.Pad.Events[key] = false
        end
        return true
      end
      if UI.LAUNCHING then return false end
      if UI.Pad.Events.START and UI.CURSCENE ~= UI.SCENES.MPROFILE then
        UI.SyncSettingsSelectionFromRuntime()
        UI.ProfileDirty = false
        UI.BdmaDirty = false
        UI.SceneChange(UI.SCENES.MPROFILE)
        return true
      end
      if allow_exit == nil then allow_exit = true end
      if not allow_exit then return false end
      if UI.Pad.Events.EXIT then
        UI.Modal.OpenExit()
        return true
      end
      return false
    end;
    GameList = {
      MAXDRAW = 18;
      CURR = 1;
      STARTUP = 1;
      CoverLastIndex = nil;
      CoverPending = false;
      CoverPendingAt = 0;
      CoverIdleMs = 200;
      isArtEnabled = true;
      Reset = function ()
        UI.GameList.CURR = 1;
        UI.GameList.CoverLastIndex = nil
        UI.GameList.CoverPending = false
        UI.GameList.CoverPendingAt = 0
        UI.GameList.isArtEnabled = PLDR.ART_ENABLED ~= false
      end;
      Play = function()
        local layout = UI.LAYOUT
        UI.GameList.MAXDRAW = layout.LIST_MAX
        local titles = {
          [UI.SCENES.GUSBFAT] = "USB"
        }
        local scene_title = titles[UI.CURSCENE]
        if scene_title ~= nil then
          Font.ftPrint(LFONT, UI.SCR.X_MID, layout.TITLE_Y, 8, UI.SCR.X, 16, scene_title, UI.CCOL.GREY)
        end
        local placeholders = {
          [UI.SCENES.GBDMHDD] = "BDM HDD"
        }
        local placeholder_title = placeholders[UI.CURSCENE]
        if placeholder_title ~= nil then
          Font.ftPrint(LFONT, UI.SCR.X_MID, layout.TITLE_Y, 8, UI.SCR.X, 16, placeholder_title, UI.CCOL.GREY)
          Font.ftPrintMultiLineAligned(BFONT, UI.SCR.X_MID, UI.SCR.Y_MID, 20, UI.SCR.X, 32, "Not implemented yet", UI.CCOL.YELLOW)
          Input_GetEvent()
        if UI.HandleGlobalInput(false) then return end
          if UI.Pad.Events.EXIT then UI.SceneChange(UI.SCENES.CREDITS) end
          if UI.Pad.Events.BACK then UI.SceneChange(UI.SCENES.MMAIN) end
        if UI.Pad.Events.SQUARE then
          UI.GameList.isArtEnabled = not UI.GameList.isArtEnabled
          PLDR.ART_ENABLED = UI.GameList.isArtEnabled
          UI.GameList.CoverPending = false
          UI.GameList.CoverPendingAt = UI.Pad.CLK or 0
          if UI.CoverCache ~= nil then
            UI.CoverCache:UpdateSelection(nil)
          end
        end
          if UI.Pad.Events.CONFIRM then
            UI.Notif_queue.add("Not implemented yet")
          end
          local labels, order = UI.Footer.ResolveLegend({
            order = UI.Footer.order_with_start_r2,
            order_id = "start_r2",
            circle = UI.Footer.labels.circle_other,
            cross = UI.Footer.labels.cross_confirm,
            square = UI.GameList.isArtEnabled and "Cover Art: On" or "Cover Art: Off",
            start = UI.Footer.labels.start_profiles
          })
          UI.Footer.Draw(labels, order)
          return
        end
        local ammount = #PLDR.GAMES
        if UI.CURSCENE == UI.SCENES.GSMB then
          local slots = PLDR.GetMMCESlots()
          if #slots > 1 then
            Font.ftPrint(SFONT, layout.LIST_X, layout.LIST_Y - 20, 0, UI.SCR.X, 16, "Slot: "..PLDR.MMCE.PREFIX, UI.CCOL.GREY)
          end
        end
        if (UI.GameList.CURR > (UI.GameList.STARTUP+(UI.GameList.MAXDRAW-1))) then
          UI.GameList.STARTUP = (UI.GameList.CURR-UI.GameList.MAXDRAW+1)
        elseif (UI.GameList.CURR < UI.GameList.STARTUP) then
          UI.GameList.STARTUP = CLAMP(UI.GameList.CURR-1, 1, ammount)
        end
        for i = UI.GameList.STARTUP, ammount do
          if i >= (UI.GameList.STARTUP+UI.GameList.MAXDRAW) then break end
          local Y = layout.LIST_Y + ((i-UI.GameList.STARTUP) * layout.LIST_ROW_H)
          local display_name = PLDR.GAMES[i]
          local hdd_relpath = string.match(display_name or "", "^[^|]+|(.+)$")
          if hdd_relpath ~= nil then
            display_name = string.match(hdd_relpath, "([^/]+)$") or hdd_relpath
          end
	          local c = (i == UI.GameList.CURR) and UI.COLORS.LIST_SELECTED or UI.COLORS.LIST_UNSELECTED
	          Font.ftPrint(BFONT, layout.LIST_X, Y, 0, layout.LIST_W, 16, string.sub(display_name,1, -5), c)
        end
        local cover_img = nil
        if UI.CoverCache ~= nil then
          cover_img = UI.CoverCache.last_img
        end
        if layout.PREVIEW_W > 0 then
          local preview_img = nil
          local default_img = IMG["default"]
          local missing_img = IMG["MISSING"]
          local legacy_img = IMG["DISC"]
          if not UI.GameList.isArtEnabled then
            preview_img = default_img or missing_img or legacy_img
          elseif cover_img ~= nil then
            preview_img = cover_img
          else
            preview_img = missing_img or default_img or legacy_img
          end

          if preview_img ~= nil then
            Graphics.drawScaleImage(preview_img, layout.PREVIEW_X, layout.PREVIEW_Y, layout.PREVIEW_W, layout.PREVIEW_H)
          end

          local frame_img = IMG["frame"]
          if frame_img ~= nil then
            Graphics.drawScaleImage(frame_img, layout.PREVIEW_X - 2, layout.PREVIEW_Y - 2, layout.PREVIEW_W + 4, layout.PREVIEW_H + 4)
          else
            Graphics.drawRect(layout.PREVIEW_X - 2, layout.PREVIEW_Y - 2, layout.PREVIEW_W + 4, layout.PREVIEW_H + 4, UI.CCOL.GREY)
          end
        end
        if ammount <= 0 then
          Font.ftPrintMultiLineAligned(LFONT, UI.SCR.X_MID, UI.SCR.Y_MID, 20, UI.SCR.X, 32, "No games found", UI.CCOL.YELLOW)
          Font.ftPrintMultiLineAligned(LFONT, UI.SCR.X_MID+1, UI.SCR.Y_MID+1, 20, UI.SCR.X, 32, "No games found", UI.CCOL.TRANSP_BLACK)
        end
        Input_GetEvent()
        if UI.HandleGlobalInput(false) then return end
        if UI.Pad.Events.EXIT then UI.SceneChange(UI.SCENES.CREDITS) end
        if UI.Pad.Events.BACK then UI.SceneChange(UI.SCENES.MMAIN) end
        if UI.Pad.Events.SQUARE then
          UI.GameList.isArtEnabled = not UI.GameList.isArtEnabled
          PLDR.ART_ENABLED = UI.GameList.isArtEnabled
          UI.GameList.CoverPending = false
          UI.GameList.CoverPendingAt = UI.Pad.CLK or 0
          if UI.CoverCache ~= nil then
            UI.CoverCache:UpdateSelection(nil)
          end
        end
        if UI.Pad.Events.NAV_DOWN then UI.GameList.CURR = CLAMP(UI.GameList.CURR+1, 1, ammount) end
        if UI.Pad.Events.NAV_RIGHT then UI.GameList.CURR = CLAMP(UI.GameList.CURR+UI.GameList.MAXDRAW, 1, ammount) end
        if UI.Pad.Events.NAV_UP then UI.GameList.CURR = CLAMP(UI.GameList.CURR-1, 1, ammount) end
        if UI.Pad.Events.NAV_LEFT then UI.GameList.CURR = CLAMP(UI.GameList.CURR-UI.GameList.MAXDRAW, 1, ammount) end
        if UI.CoverCache ~= nil then
          local now = 0
          if UI.Pad.Timer ~= nil then
            now = Timer.getTime(UI.Pad.Timer)
          end
          local nav_event = UI.Pad.Events.NAV_DOWN or UI.Pad.Events.NAV_RIGHT or UI.Pad.Events.NAV_UP or UI.Pad.Events.NAV_LEFT
          if ammount <= 0 or not UI.GameList.isArtEnabled then
            UI.GameList.CoverLastIndex = nil
            UI.GameList.CoverPending = false
            UI.GameList.CoverPendingAt = now
            UI.CoverCache:UpdateSelection(nil)
          else
            if UI.GameList.CURR ~= UI.GameList.CoverLastIndex then
              UI.GameList.CoverLastIndex = UI.GameList.CURR
              UI.GameList.CoverPending = true
              UI.GameList.CoverPendingAt = now
              UI.CoverCache:UpdateSelection(nil)
            end
            if UI.GameList.CoverPending and not nav_event and (now - UI.GameList.CoverPendingAt) >= UI.GameList.CoverIdleMs then
              local entry = PLDR.GAMES[UI.GameList.CURR]
              local resolved_vcd_path = BuildListResolvedVcdPath(entry, PLDR.GAMEPATH)
              local cover_path = nil
              if resolved_vcd_path ~= nil then
                cover_path = StripExtension(resolved_vcd_path)..".png"
              end
              UI.CoverCache:UpdateSelection(cover_path)
              UI.GameList.CoverPending = false
            end
          end
        end
        if UI.Pad.Events.CONFIRM then
          if ammount <= 0 then
            UI.Notif_queue.add("No games found")
          else
            local popstarter_path = PLDR.POPSTARTER_PATH
            if type(PLDR.ResolvePopstarterPath) == "function" then
              popstarter_path = PLDR.ResolvePopstarterPath(PLDR.POPSTARTER_PATH)
            end
            local popstarter_ok = false
            if type(PLDR.PopstarterProbeWithEnsure) == "function" then
              popstarter_ok = PLDR.PopstarterProbeWithEnsure(popstarter_path)
            else
              popstarter_ok = doesFileExist(popstarter_path)
            end
            if not popstarter_ok then
              UI.Notif_queue.add("Cant find POPSTARTER ELF\n"..tostring(popstarter_path))
              return
            end
            local entry = PLDR.GAMES[UI.GameList.CURR]
            local root, rel = string.match(entry or "", "^([^|]+)|(.+)$")
            local vcd_full = BuildListResolvedVcdPath(entry, PLDR.GAMEPATH)
            if UI.CURSCENE ~= UI.SCENES.GHDD then -- only check if game can be found on USB and SMB
              if not doesFileExist(vcd_full) then
                UI.Notif_queue.add("Cant find Game\n"..vcd_full)
              end
            end
            local launch_path = PLDR.GAMEPATH
            if UI.CURSCENE == UI.SCENES.GHDD then
              launch_path = ""
            end
            if root ~= nil then
              PLDR.RunPOPStarterGame(root, rel, UI.CURSCENE)
            else
              PLDR.RunPOPStarterGame(launch_path, entry, UI.CURSCENE)
            end
          end
        end
        local cross_label = UI.Footer.labels.cross_launch
        if ammount <= 0 then
          cross_label = UI.Footer.labels.cross_confirm
        end
        local labels, order = UI.Footer.ResolveLegend({
          order = UI.Footer.order_with_start_r2,
          order_id = "start_r2",
          circle = UI.Footer.labels.circle_other,
          cross = cross_label,
          square = UI.GameList.isArtEnabled and "Cover Art: On" or "Cover Art: Off",
          start = UI.Footer.labels.start_profiles
        })
        UI.Footer.Draw(labels, order)
      end;
    };
    ProfileQuery = {
      lastopt = 1;
      curopt = 1;
      Play = function ()
        local layout = UI.LAYOUT
        local profcnt = #PLDR.PROFILES
        Font.ftPrint(LFONT, UI.SCR.X_MID, layout.TITLE_Y, 8, UI.SCR.X, 16, "Settings", UI.CCOL.GREY)
        local mode = UI.BdmaModes[UI.BdmaModeIndex]
        local left_icon  = IMG.left
        local right_icon = IMG.right
        local up_icon    = IMG.up
        local down_icon  = IMG.down
        local CX = UI.SCR.X_MID
        local H_ROW = 24
        local TITLE_TO_BLOCK = 36
        local BLOCK_GAP = 30
        local ROW_GAP = 6
        local BUTTON_GAP = 70
        local ICON_SPREAD = 120
        local ICON_SPREAD2 = 170
        local icon_scale = 0.55

        local function IconSize(icon)
          if icon == nil then return 0, 0 end
          local icon_w = math.floor(Graphics.getImageWidth(icon) * icon_scale + 0.5)
          local icon_h = math.floor(Graphics.getImageHeight(icon) * icon_scale + 0.5)
          return icon_w, icon_h
        end

        local function DrawCentered(text, row_y, color)
          Font.ftPrint(BFONT, CX, row_y, 8, UI.SCR.X, 16, text, color or UI.CCOL.GREY)
        end

        local function DrawIconOnRow(icon, center_x, row_y)
          if icon == nil then return end
          local icon_w, icon_h = IconSize(icon)
          local icon_x = math.floor(center_x - (icon_w / 2))
          local icon_y = row_y + math.floor((H_ROW - icon_h) / 2)
          Graphics.drawScaleImage(icon, icon_x, icon_y, icon_w, icon_h, UI.CCOL.GREY)
        end

        local mode_text = "<"..tostring(mode.label or "")..">"
        local profile_text = "POPStarter Profile: <Profile "..UI.ProfileQuery.curopt..">"
        local pop_path_label = "POPStarter Path:"
        local pop_path_value = "<"..tostring(PLDR.PROFILES[UI.ProfileQuery.curopt].ELF or "")..">"
        local dkwdrv_label = "DKWDRV Path:"
        local dkwdrv_value = "mc0:/PS1_DKWDRV/DKWDRV.ELF"

        local y = layout.TITLE_Y + TITLE_TO_BLOCK
        local footer_top_y = (layout.FOOTER_ICON_Y or (UI.SCR.Y - (layout.BTN_BAR_SAFE_BOTTOM or 56))) - 24
        local total_h = (7 * H_ROW) + (2 * BLOCK_GAP) + (4 * ROW_GAP) + BUTTON_GAP
        if (y + total_h) > footer_top_y then
          y = footer_top_y - total_h
        end
        if y < (layout.TITLE_Y + TITLE_TO_BLOCK) then
          y = layout.TITLE_Y + TITLE_TO_BLOCK
        end

        DrawCentered("BDMA:", y)
        y = y + H_ROW + ROW_GAP

        DrawIconOnRow(left_icon, CX - ICON_SPREAD, y)
        DrawIconOnRow(right_icon, CX + ICON_SPREAD, y)
        DrawCentered(mode_text, y)
        y = y + H_ROW
        y = y + BLOCK_GAP

        DrawCentered(profile_text, y)
        y = y + H_ROW + ROW_GAP

        DrawCentered(pop_path_label, y)
        DrawIconOnRow(up_icon, CX - ICON_SPREAD2, y)
        DrawIconOnRow(down_icon, CX + ICON_SPREAD2, y)
        y = y + H_ROW + ROW_GAP

        DrawCentered(pop_path_value, y, Color.new(128,128,128, 110))
        y = y + H_ROW
        y = y + BLOCK_GAP

        DrawCentered(dkwdrv_label, y)
        y = y + H_ROW + ROW_GAP
        DrawCentered(dkwdrv_value, y, Color.new(128,128,128, 110))
        y = y + H_ROW + BUTTON_GAP

        Input_GetEvent()
        if UI.HandleGlobalInput(false) then return end

        local function queue_exit(target_scene)
          UI.ShowSavingOverlay()
          PLDR.EnsurePopstarterDir()
          PLDR.SELECTED_PROFILE = UI.ProfileQuery.curopt
          PLDR.POPSTARTER_PATH = PLDR.PROFILES[UI.ProfileQuery.curopt].ELF
          PLDR.BDMA_MODE_KEY = UI.BdmaModes[UI.BdmaModeIndex].key
          UI.SavingActive = true
          local save_token = nil
          if type(PLDR.NextBdmaApplyToken) == "function" then
            save_token = PLDR.NextBdmaApplyToken()
          else
            PLDR._bdma_apply_seq = (tonumber(PLDR._bdma_apply_seq) or 0) + 1
            save_token = "bdma:"..tostring(PLDR._bdma_apply_seq)
          end
          local ok_run, result = xpcall(function()
            local saved = PLDR.SaveSettingsAtomic()
            local applied = true
            if UI.BdmaDirty then
              if type(PLDR.ApplyBdmaModeOnce) == "function" then
                applied = PLDR.ApplyBdmaModeOnce(PLDR.BDMA_MODE_KEY, save_token)
              else
                applied = PLDR.ApplyBdmaMode(PLDR.BDMA_MODE_KEY)
              end
            end
            return saved and applied
          end, function(e) return e end)
          UI.SavingActive = false
          if ok_run and result then
            UI.ProfileDirty = false
            UI.BdmaDirty = false
          else
            UI.Notif_queue.add("Failed to save settings")
          end
          UI.SceneChange(target_scene)
        end

        if UI.Pad.Events.EXIT then queue_exit(UI.SCENES.CREDITS) end
        if UI.Pad.Events.NAV_DOWN then
          local next_opt = CLAMP(UI.ProfileQuery.curopt+1, 1, profcnt)
          if next_opt ~= UI.ProfileQuery.curopt then
            UI.ProfileQuery.curopt = next_opt
            UI.ProfileDirty = true
          end
        end
        if UI.Pad.Events.NAV_UP then
          local next_opt = CLAMP(UI.ProfileQuery.curopt-1, 1, profcnt)
          if next_opt ~= UI.ProfileQuery.curopt then
            UI.ProfileQuery.curopt = next_opt
            UI.ProfileDirty = true
          end
        end
        if UI.Pad.Events.NAV_RIGHT then
          UI.BdmaModeIndex = UI.BdmaModeIndex + 1
          if UI.BdmaModeIndex > #UI.BdmaModes then UI.BdmaModeIndex = 1 end
          UI.BdmaDirty = true
        end
        if UI.Pad.Events.NAV_LEFT then
          UI.BdmaModeIndex = UI.BdmaModeIndex - 1
          if UI.BdmaModeIndex < 1 then UI.BdmaModeIndex = #UI.BdmaModes end
          UI.BdmaDirty = true
        end
        if UI.Pad.Events.BACK then queue_exit(UI.SCENES.MMAIN) end
        if UI.Pad.Events.START then
          local default_profile = tonumber(PLDR.DEFAULT_PROFILE) or 1
          local next_default = CLAMP(default_profile, 1, profcnt)
          if next_default ~= UI.ProfileQuery.curopt then
            UI.ProfileQuery.curopt = next_default
            UI.ProfileDirty = true
          end
          if UI.BdmaModeIndex ~= 1 then
            UI.BdmaModeIndex = 1
            UI.BdmaDirty = true
          end
          UI.Notif_queue.add("Profile defaults restored")
        end
        if UI.Pad.Events.CONFIRM then
          queue_exit(UI.SCENES.MMAIN)
        end
        local labels, order = UI.Footer.ResolveLegend({
          order = UI.Footer.order_with_start,
          order_id = "start",
          circle = UI.Footer.labels.circle_other,
          cross = UI.Footer.labels.cross_select,
          start = UI.Footer.labels.start_reset
        })
        UI.Footer.Draw(labels, order)
      end;
    };
    MainMenu = {
      OPT = 1;
      opts = {"MMCE", "MX4SIO", "HDD (exFAT)", "HDD (PFS)", "USB", "SMB (v1)", "Disc (DKWDRV)"};
      Carousel = {
        currentIndex = 1,
        targetIndex = 1,
        scrollPos = 1.0,
        animActive = false,
        animT = 0,
        animDir = 0,
        animDurSec = 0.55,
        slide = 0,
        allowOptWrite = false,
        timer = nil,
        last_ms = nil
      };
      DrawOnly = function ()
        UI.MainMenu._draw_only = true
        UI.MainMenu.Play()
        UI.MainMenu._draw_only = false
      end;
      Play = function ()
        local layout = UI.LAYOUT
        local profcnt = #UI.MainMenu.opts
	        -- Pages are no longer presented as "locked" in the UI.
        local icon_map = {
          ["MMCE"] = "MMCE",
          ["MX4SIO"] = "MX4SIO",
          ["HDD (exFAT)"] = "BDHDD",
          ["HDD (PFS)"] = "APAHDD",
          ["USB"] = "USB",
          ["SMB (v1)"] = "SMB",
          ["Disc (DKWDRV)"] = "DISC"
        }
        local icon_keys = {}
        for x = 1, #UI.MainMenu.opts do
          local opt = UI.MainMenu.opts[x]
          local key = icon_map[opt] or opt
          icon_keys[x] = key
        end
        local function WrapIndex(index, count)
          return ((index - 1) % count) + 1
        end
        local carousel = UI.MainMenu.Carousel
        if carousel.timer == nil then
          carousel.timer = Timer.new()
          carousel.last_ms = Timer.getTime(carousel.timer)
        end
        local now_ms = Timer.getTime(carousel.timer)
        local dt_ms = now_ms - (carousel.last_ms or now_ms)
        carousel.last_ms = now_ms
        if dt_ms < 0 then dt_ms = 0 end
        if not carousel.animActive then
          carousel.currentIndex = UI.MainMenu.OPT
          carousel.scrollPos = carousel.currentIndex
          carousel.slide = 0
        end
        if carousel.animActive then
          if carousel.currentIndex ~= UI.MainMenu.OPT then
          end
          local dt_sec = Clamp(dt_ms / 1000, 0, 1/30)
          carousel.animT = carousel.animT + dt_sec
          local duration = carousel.animDurSec
          if duration <= 0 then duration = 0.01 end
          local t = CLAMP(carousel.animT / duration, 0, 1)
          assert(type(EaseInOutCubic) == "function")
          local e = EaseInOutCubic(t)
          carousel.slide = carousel.animDir * e
          if t >= 1 then
            carousel.animActive = false
            carousel.currentIndex = carousel.targetIndex
            carousel.scrollPos = carousel.currentIndex
            carousel.animDir = 0
            carousel.slide = 0
            carousel.allowOptWrite = true
            UI.MainMenu.OPT = carousel.currentIndex
            carousel.allowOptWrite = false
          end
        end
        local center_x = layout.SAFE_X_MID or UI.SCR.X_MID
        local usable_top = layout.STATUS_Y + 24
        local usable_bottom = layout.FOOTER_ICON_Y - 24
        local center_y = Round((usable_top + usable_bottom) / 2)
	        if layout.CAROUSEL_Y_OFFSET ~= nil then
	          center_y = center_y + layout.CAROUSEL_Y_OFFSET
	        end
        local function Clamp(value, min_val, max_val)
          if value < min_val then return min_val end
          if value > max_val then return max_val end
          return value
        end
        local function ResolveIcon(key)
          return IMG[key] or IMG["MISSING"]
        end
        if not UI.MainMenu.icons_ready then
          for _, key in ipairs(icon_keys) do
            ResolveIcon(key)
          end
          UI.MainMenu.icons_ready = true
        end
        local function DrawIcon(index, x, y, color)
          local key = icon_keys[index]
          local icon = ResolveIcon(key)
          if icon == nil then return end
          local icon_w = Graphics.getImageWidth(icon)
          local icon_h = Graphics.getImageHeight(icon)
          local pos_x = Round(x - (icon_w / 2))
          local pos_y = Round(y - (icon_h / 2))
          Graphics.drawImage(icon, pos_x, pos_y, color)
        end
        local first_icon = ResolveIcon(icon_keys[1] or "MISSING")
        local base_icon_w = 0
        if first_icon ~= nil then
          base_icon_w = Graphics.getImageWidth(first_icon)
        end
        local slot_margin = 0
        local safe_w = (UI.SCR.X - UI.LAYOUT.SAFE.L - UI.LAYOUT.SAFE.R)
        -- Target: show 5 icons (-2..2) without clipping on overscan-heavy TVs.
        -- Use a tighter spacing than icon width so side icons remain visible.
        local ideal_spacing = math.floor(safe_w / 4.0)
        local min_spacing = 100
        local max_spacing = math.floor(safe_w / 3.5)
        local slot_spacing = ideal_spacing
        if slot_spacing < min_spacing then slot_spacing = min_spacing end
        if slot_spacing > max_spacing then slot_spacing = max_spacing end
        local base_sel = carousel.currentIndex
        local slide = carousel.slide or 0
        local scroll = base_sel + (carousel.animActive and slide or 0)
        local base_scroll = math.floor(scroll)
        local scroll_frac = scroll - base_scroll
        local center_label_idx = carousel.animActive and carousel.targetIndex or base_sel
        local top_y = layout.TITLE_Y
        Font.ftPrint(UI.FONT.LABEL, UI.SCR.X_MID, top_y, 8, UI.SCR.X, 16, UI.MainMenu.opts[center_label_idx], UI.COLORS.TEXT_PRIMARY)
        local status_y = top_y + 12
        if UI.boot_device ~= nil and UI.boot_device ~= DEVLOCK.NONE then
          Font.ftPrint(UI.FONT.STATUS, UI.SCR.X_MID, status_y, 8, UI.SCR.X, 16, "Booted from: "..UI.device_lock_name(UI.boot_device), UI.COLORS.TEXT_PRIMARY)
          status_y = status_y + 12
        end
        local function Lerp(a, b, t)
          return a + (b - a) * t
        end
        local function SlotAlpha(dist)
          if dist <= 1 then
            return Round(Lerp(128, 19, dist))
          end
          if dist <= 2 then
            return Round(Lerp(19, 6, dist - 1))
          end
          if dist <= 3 then
            return Round(Lerp(6, 0, dist - 2))
          end
          return 0
        end
        for k = -3, 3 do
          local idx = WrapIndex(base_scroll + k, profcnt)
          local x = center_x + slot_spacing * (k - scroll_frac)
          local y = center_y
          local dist = math.abs(k - scroll_frac)
          local alpha = SlotAlpha(dist)
          if alpha > 0 then
            local tint = Color.new(128, 128, 128, alpha)
            DrawIcon(idx, x, y, tint)
          end
        end
        local labels, order = UI.Footer.ResolveLegend({
          order = UI.Footer.order_with_start,
          order_id = "start",
          circle = UI.Footer.labels.circle_main,
          cross = UI.Footer.labels.cross_select,
          start = UI.Footer.labels.start_profiles
        })
        UI.Footer.Draw(labels, order)
        if UI.MainMenu._draw_only then return end
        Input_GetEvent()
        if UI.HandleGlobalInput(false) then return end
        if not carousel.animActive then
          if UI.Pad.Events.NAV_RIGHT then
            carousel.targetIndex = WrapIndex(carousel.currentIndex + 1, profcnt)
            carousel.animDir = 1
            carousel.animActive = true
            carousel.animT = 0
            carousel.slide = 0
          end
          if UI.Pad.Events.NAV_LEFT then
            carousel.targetIndex = WrapIndex(carousel.currentIndex - 1, profcnt)
            carousel.animDir = -1
            carousel.animActive = true
            carousel.animT = 0
            carousel.slide = 0
          end
        end
        if UI.Pad.Events.EXIT then UI.SceneChange(UI.SCENES.CREDITS) end
        if UI.Pad.Events.BACK then
          UI.Modal.OpenExit()
          return
        end
        if UI.Pad.Events.CONFIRM then
          if UI.MainMenu.OPT == 1 then
            if type(System) == "table" and type(System.initMMCE) == "function" then
              pcall(System.initMMCE)
            end
            local slots = PLDR.GetMMCESlots()
            if #slots < 1 then
              UI.Notif_queue.add("No MMCE device found (mmce0/mmce1).")
              PLDR.CleanupGameList()
              PLDR.GAMEPATH = ""
              UI.SceneChange(UI.SCENES.GSMB)
            else
              if PLDR.MMCE.PREFIX == nil then
                PLDR.SetMMCESlot(1)
              end
              local mmce_prefix = PLDR.MMCE.PREFIX or PLDR.SetMMCESlot(1)
              if mmce_prefix == nil then
                UI.Notif_queue.add("No MMCE device found (mmce0/mmce1).")
                return
              end
              PLDR.CleanupGameList()
              PLDR.GetPS1GameLists(mmce_prefix.."POPS/", true)
              UI.setDeviceLock(DEVLOCK.MMCE)
              UI.SceneChange(UI.SCENES.GSMB)
            end
          elseif UI.MainMenu.OPT == 2 then
            PLDR.CleanupGameList()
            PLDR.GAMEPATH = ""
            local mx4sio_root = PLDR.InitMX4SIOPopsRoot()
            if mx4sio_root == nil then
              UI.Notif_queue.add("No MX4SIO device found")
              return
            else
              PLDR.CleanupGameList()
              PLDR.GetPS1GameLists(mx4sio_root, true)
              UI.setDeviceLock(DEVLOCK.MX4SIO)
              UI.SceneChange(UI.SCENES.GMX4SIO)
            end
          elseif UI.MainMenu.OPT == 3 then
            UI.Notif_queue.add("Not Implemented Yet")
          elseif UI.MainMenu.OPT == 4 then
            PLDR.LoadHDDModules()
            if UI.LASTSCENE == UI.SCENES.GHDD then
            else
              PLDR.CleanupGameList()
            end
            local a, b, c = PLDR.CheckPOPStarterDEPS(UI.SCENES.GHDD)
            if PLDR.HDD.STATUS == 0 then
              if not a then UI.Notif_queue.add("ERROR: cannot access 'hdd0:__common' partition") end
              if not b then UI.Notif_queue.add("missing POPS file\nhdd0:__common/POPS/POPS.ELF") end
              if not c then UI.Notif_queue.add("missing POPS file\nhdd0:__common/POPS/IOPRP252.IMG") end
              PLDR.HDD.CheckAvailableHddPopsParts()
              PLDR.HDD.BuildGameList()
              if not PLDR.HDD.FOUNDANY then
                UI.Notif_queue.add("Could not find any '__.POPS' partitions")
              elseif #PLDR.GAMES < 1 then
                UI.Notif_queue.add("Could not find any games on 'hdd0:'")
              end
            else
              UI.Notif_queue.add("ERROR: Cant detect usable HDD ("..PLDR.HDD.STATUS..")")
            end
            UI.SceneChange(UI.SCENES.GHDD)
          elseif UI.MainMenu.OPT == 5 then
            if type(System) == "table" and type(System.ensureUsbMass) == "function" then
              System.ensureUsbMass()
            end
            if type(System) == "table" and type(System.sleep) == "function" then
              pcall(System.sleep, 1)
            end
            PLDR.CleanupGameList()
            PLDR.GAMEPATH = ""
            local snapshot = PLDR.RefreshMassStateSnapshot()
            PLDR.BuildMassGameListByType("usb", snapshot)
            if #PLDR.GAMES < 1 then
              if type(PLDR.RefreshMassBackendsBoundedOnce) == "function" then
                pcall(PLDR.RefreshMassBackendsBoundedOnce)
              end
              snapshot = PLDR.RefreshMassStateSnapshot()
              PLDR.BuildMassGameListByType("usb", snapshot)
            end
            UI.setDeviceLock(DEVLOCK.USB)
            UI.SceneChange(UI.SCENES.GUSBFAT)
          elseif UI.MainMenu.OPT == 6 then
            UI.Notif_queue.add("Not Implemented Yet")
          elseif UI.MainMenu.OPT == 7 then
            if type(System) == "table" and type(System.ensureCDFS) == "function" then
              System.ensureCDFS()
            end
            UI.Modal.OpenDKWDRV()
          end --because we still dont support SMB
        end
      end
    };
    Pad = {
      OLDPAD = 0;
      GPAD = 0;
      Timer = nil;
      Events = {
        NAV_UP = false,
        NAV_DOWN = false,
        NAV_LEFT = false,
        NAV_RIGHT = false,
        CONFIRM = false,
        BACK = false,
        EXIT = false,
        START = false,
        SELECT = false,
        SQUARE = false,
        R2 = false,
        ANY = false,
      };
      NavHeld = {};
      NavNeutral = {UP = true, DOWN = true, LEFT = true, RIGHT = true};
      Queue = {};
      DebugPadTimer = nil;
      DebugPadLast = 0;
      NavEventTimer = nil;
      NavEventLast = 0;
      NavEventCount = 0;
      LastActionEventMs = 0;
      Listen = function ()
        if UI.Pad.Timer == nil then
          UI.Pad.Timer = Timer.new()
          UI.Pad.CLK = Timer.getTime(UI.Pad.Timer)
        end
        local now = Timer.getTime(UI.Pad.Timer)
        UI.Pad.CLK = now
        UI.Pad.OLDPAD = UI.Pad.GPAD
        UI.Pad.GPAD = Pads.get()
        GPAD = UI.Pad.GPAD

        local pressed = UI.Pad.GPAD & ~UI.Pad.OLDPAD
        local released = ~UI.Pad.GPAD & UI.Pad.OLDPAD

        UI.Pad.Queue = {}
        UI.Pad.Events.NAV_UP = false
        UI.Pad.Events.NAV_DOWN = false
        UI.Pad.Events.NAV_LEFT = false
        UI.Pad.Events.NAV_RIGHT = false
        UI.Pad.Events.CONFIRM = false
        UI.Pad.Events.BACK = false
        UI.Pad.Events.EXIT = false
        UI.Pad.Events.START = false
        UI.Pad.Events.SELECT = false
        UI.Pad.Events.SQUARE = false
        UI.Pad.Events.R2 = false
        UI.Pad.Events.ANY = false

        local function emit(event)
          table.insert(UI.Pad.Queue, event)
          UI.Pad.Events[event] = true
          UI.Pad.Events.ANY = true
        end

        local function emit_nav(event)
          UI.Pad.NavEventCount = (UI.Pad.NavEventCount or 0) + 1
          emit(event)
        end

        local function emit_action(event)
          if (now - (UI.Pad.LastActionEventMs or 0)) < UI.InputConfig.MIN_ACTION_MS then
            return
          end
          UI.Pad.LastActionEventMs = now
          emit(event)
        end

        if (pressed & PAD_CROSS) ~= 0 then emit_action("CONFIRM") end
        if (pressed & PAD_CIRCLE) ~= 0 then emit_action("BACK") end
        if (pressed & PAD_TRIANGLE) ~= 0 then emit_action("EXIT") end
        if (pressed & PAD_START) ~= 0 then emit("START") end
        if (pressed & PAD_SELECT) ~= 0 then emit("SELECT") end
        if (pressed & PAD_SQUARE) ~= 0 then emit_action("SQUARE") end
        if (pressed & PAD_R2) ~= 0 then emit_action("R2") end

        local function resolve_nav(dir, is_down)
          local was_down = UI.Pad.NavHeld[dir] == true
          if not is_down then
            if was_down then
              UI.Pad.NavNeutral[dir] = true
            end
            UI.Pad.NavHeld[dir] = false
            return false
          end
          UI.Pad.NavHeld[dir] = true
          if not UI.Pad.NavNeutral[dir] then
            return false
          end
          UI.Pad.NavNeutral[dir] = false
          return true
        end

        if resolve_nav("UP", ((UI.Pad.GPAD & PAD_UP) ~= 0)) then emit_nav("NAV_UP") end
        if resolve_nav("DOWN", ((UI.Pad.GPAD & PAD_DOWN) ~= 0)) then emit_nav("NAV_DOWN") end
        if resolve_nav("LEFT", ((UI.Pad.GPAD & PAD_LEFT) ~= 0)) then emit_nav("NAV_LEFT") end
        if resolve_nav("RIGHT", ((UI.Pad.GPAD & PAD_RIGHT) ~= 0)) then emit_nav("NAV_RIGHT") end

        if UI.InputConfig.DEBUG_INPUT_LOG then
          if UI.Pad.DebugPadTimer == nil then
            UI.Pad.DebugPadTimer = Timer.new()
            UI.Pad.DebugPadLast = Timer.getTime(UI.Pad.DebugPadTimer)
          end
          local dbg_now = Timer.getTime(UI.Pad.DebugPadTimer)
          if (dbg_now - UI.Pad.DebugPadLast) >= 1000 then
            local up = (UI.Pad.GPAD & PAD_UP) ~= 0
            local down = (UI.Pad.GPAD & PAD_DOWN) ~= 0
            local cross = (UI.Pad.GPAD & PAD_CROSS) ~= 0
            local circle = (UI.Pad.GPAD & PAD_CIRCLE) ~= 0
            UI.Pad.DebugPadLast = dbg_now
          end
          if UI.Pad.NavEventTimer == nil then
            UI.Pad.NavEventTimer = Timer.new()
            UI.Pad.NavEventLast = Timer.getTime(UI.Pad.NavEventTimer)
            UI.Pad.NavEventCount = 0
          end
          local nav_now = Timer.getTime(UI.Pad.NavEventTimer)
          if (nav_now - UI.Pad.NavEventLast) >= 1000 then
            UI.Pad.NavEventCount = 0
            UI.Pad.NavEventLast = nav_now
          end
        end
      end;
    };
    Credits = {
      DrawOnly = function ()
        UI.Credits._draw_only = true
        UI.Credits.Play()
        UI.Credits._draw_only = false
      end;
      Play = function ()
        local layout = UI.LAYOUT
        local currcol = UI.CCOL.GREY
		
          Font.ftPrintMultiLineAligned(LFONT, UI.SCR.X_MID, layout.TITLE_Y, 20, UI.SCR.X, 40, "POPSLoader\nfor POPStarter", currcol)
          Font.ftPrintMultiLineAligned(BFONT, UI.SCR.X_MID, layout.TITLE_Y + 60, 20, UI.SCR.X, 40, "Code by El_isra", currcol)
          Font.ftPrintMultiLineAligned(BFONT, UI.SCR.X_MID, layout.TITLE_Y + 80, 20, UI.SCR.X, UI.SCR.Y, [[
Design by Berion
Scripts by Nuno6573 and Ripto
Based on Enceladus by Daniel Santos
Testing by P4NCHOL1NO, VizoR, and Community

Special Thanks To:
krHACKen for making POPStarter
uyjulian, fjtrujy, HWC, and others for always helping

This program is free and open source
If you bought it, you have been scammed

Compatibility problems? Visit:
youtube.com/@hugopocked6695
]], currcol)
        if UI.BUILD_INFO ~= nil and UI.BUILD_INFO.stamp ~= nil then
          local stamp_y = Round(layout.FOOTER_LABEL_Y - 18)
          Font.ftPrint(SFONT, layout.SAFE.L, stamp_y, 0, UI.SCR.X, 16, UI.BUILD_INFO.stamp, UI.CCOL.GREY)
        end

        if not UI.Credits._draw_only then
          Input_GetEvent()
          if UI.HandleGlobalInput(false) then return end
          if UI.Pad.Events.EXIT or UI.Pad.Events.BACK or UI.Pad.Events.ANY then
            UI.SceneChange(UI.SCENES.MMAIN)
          end
        end

      end
    };
  }
local function LoadBuildInfo()
  local candidates = {
    "BUILD_INFO.txt",
    "POPSLDR/BUILD_INFO.txt"
  }
  local info = {
    hash = nil,
    timestamp = nil,
    stamp = nil
  }
  for _, rel in ipairs(candidates) do
    local resolved = System.resolveAsset(rel) or rel
    local ok_open, fd = pcall(System.openFile, resolved, FREAD)
    if ok_open and type(fd) == "number" and fd >= 0 then
      local size = System.sizeFile(fd)
      local data = ""
      if type(size) == "number" and size > 0 then
        data = System.readFile(fd, size) or ""
      end
      System.closeFile(fd)
      if data ~= "" then
        local lines = {}
        for line in string.gmatch(data, "[^\r\n]+") do
          lines[#lines + 1] = line
        end
        info.hash = lines[1]
        info.timestamp = lines[2]
        break
      end
    end
  end
  if info.hash ~= nil and info.timestamp ~= nil then
    info.stamp = string.format("build %s %s", info.hash, info.timestamp)
  end
  return info
end
UI.BUILD_INFO = LoadBuildInfo()
if UI.FONT ~= nil then
  if UI.FONT.TITLE ~= nil then
    Font.ftSetCharSize(UI.FONT.TITLE, UI.FONT.TITLE_SIZE, UI.FONT.TITLE_SIZE)
  end
  if UI.FONT.LABEL ~= nil then
    Font.ftSetCharSize(UI.FONT.LABEL, UI.FONT.LABEL_SIZE, UI.FONT.LABEL_SIZE)
  end
end
_G.UI = UI
UI.GAME_SCENES = {
  [UI.SCENES.GUSBFAT] = true,
  [UI.SCENES.GSMB] = true,
  [UI.SCENES.GMX4SIO] = true,
  [UI.SCENES.GHDD] = true,
  [UI.SCENES.GBDMHDD] = true
}
function UI.IsGameScene(scene)
  return UI.GAME_SCENES[scene] == true
end
function UI.IsUsbScene(scene)
  return scene == UI.SCENES.GUSBFAT
end
function UI.OnSceneExit(previous_scene, next_scene)
  if UI.IsGameScene(previous_scene) and previous_scene ~= next_scene then
    if UI.CoverCache ~= nil and UI.CoverCache.Clear ~= nil then
      UI.CoverCache:Clear()
    end
  end
end
UI.RecalcLayout()
function UI.SyncSettingsSelectionFromRuntime()
  if type(PLDR.ReconcileBdmaModeWithEffectiveState) == "function" then
    PLDR.ReconcileBdmaModeWithEffectiveState()
  end
  local mode_key = PLDR.BDMA_MODE_KEY or "FAT32"
  for i = 1, #UI.BdmaModes do
    if UI.BdmaModes[i].key == mode_key then
      UI.BdmaModeIndex = i
      break
    end
  end
  local selected_profile = tonumber(PLDR.SELECTED_PROFILE) or tonumber(PLDR.DEFAULT_PROFILE) or 1
  UI.ProfileQuery.curopt = CLAMP(selected_profile, 1, #PLDR.PROFILES)
  UI.GameList.isArtEnabled = PLDR.ART_ENABLED ~= false
end
UI.SyncSettingsSelectionFromRuntime()
function Input_GetEvent()
  UI.Pad.Listen()
  if UI.Transition ~= nil and UI.Transition.active then
    for key, _ in pairs(UI.Pad.Events) do
      UI.Pad.Events[key] = false
    end
  end
  return UI.Pad.Events
end
do
  local menu = UI.MainMenu
  if menu ~= nil then
    menu._OPT = menu.OPT
    menu.OPT = nil
    setmetatable(menu, {
      __index = function (t, key)
        if key == "OPT" then
          return rawget(t, "_OPT")
        end
        return rawget(t, key)
      end,
      __newindex = function (t, key, value)
        if key == "OPT" then
          local carousel = t.Carousel
          if carousel ~= nil and not carousel.allowOptWrite then
            return
          end
          rawset(t, "_OPT", value)
          return
        end
        rawset(t, key, value)
      end
    })
  end
  UI._CURSCENE = UI.CURSCENE
  UI.CURSCENE = nil
  setmetatable(UI, {
    __index = function (t, key)
      if key == "CURSCENE" then
        return rawget(t, "_CURSCENE")
      end
      return rawget(t, key)
    end,
    __newindex = function (t, key, value)
      if key == "CURSCENE" then
        if UI.Transition == nil or not UI.Transition.allowSceneWrite then
          return
        end
        rawset(t, "_CURSCENE", value)
        return
      end
      rawset(t, key, value)
    end
  })
end
return UI
