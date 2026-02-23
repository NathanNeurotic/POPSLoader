--[[
  ___  ___  ___  ___ _                 _         
 | _ \/ _ \| _ \/ __| |   ___  __ _ __| |___ _ _ 
 |  _/ (_) |  _/\__ \ |__/ _ \/ _` / _` / -_) '_|
 |_|  \___/|_|  |___/____\___/\__,_\__,_\___|_|  
  Licensed under GNU General public license v3.0
--]]

LOG("Registering POPSLoader UI")
local DEVLOCK = { NONE = 0, USB = 1, MMCE = 2, MX4SIO = 3 }
local UI
local IMG = rawget(_G, "IMG")
if type(IMG) ~= "table" then
  error("IMG not initialized before ui.lua")
end
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
local function GuardTrace()
  if debug ~= nil and debug.traceback ~= nil then
    return debug.traceback("TRACE", 2)
  end
  return "TRACE unavailable"
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
local function ResolveAssetSafe(path)
  if path == nil then return nil end
  if type(System) == "table" and type(System.resolveAsset) == "function" then
    local ok, resolved = pcall(System.resolveAsset, path)
    if ok and type(resolved) == "string" and resolved ~= "" then
      return resolved
    end
  end
  return path
end
local function EnsureDirPath(path)
  if path == nil or path == "" then return nil end
  if type(EnsureTrailingSlash) == "function" then
    return EnsureTrailingSlash(path)
  end
  if string.sub(path, -1) ~= "/" then
    return path.."/"
  end
  return path
end
local function AddUniquePath(list, seen, path)
  if path == nil or path == "" then return end
  if seen[path] == true then return end
  seen[path] = true
  table.insert(list, path)
end
local function JoinPathSimple(base, rel)
  if base == nil or base == "" then return rel end
  if rel == nil or rel == "" then return base end
  return EnsureDirPath(base)..rel
end
local BOOT_ASSET_BASE_DIR = APP_DIR
if type(System) == "table" and type(System.getAppDir) == "function" then
  local ok, app_dir = pcall(System.getAppDir)
  if ok and type(app_dir) == "string" and app_dir ~= "" then
    BOOT_ASSET_BASE_DIR = app_dir
  end
end
BOOT_ASSET_BASE_DIR = EnsureDirPath(BOOT_ASSET_BASE_DIR)
local function ResolveBootSoundCandidates(name)
  local candidates = {}
  local seen = {}
  local rels = {
    name,
    "POPSLDR/"..name
  }
  for _, rel in ipairs(rels) do
    AddUniquePath(candidates, seen, ResolveAssetSafe(rel))
  end
  if BOOT_ASSET_BASE_DIR ~= nil then
    for _, rel in ipairs(rels) do
      local full = JoinPathSimple(BOOT_ASSET_BASE_DIR, rel)
      AddUniquePath(candidates, seen, ResolveAssetSafe(full))
    end
  end
  return candidates
end
local function ExtractGameRelPath(entry)
  if entry == nil then return nil end
  local relpath = string.match(entry, "^[^|]+|(.+)$")
  return relpath or entry
end
local function ParseHddGameEntry(entry)
  if entry == nil then return nil, nil end
  local partition, relpath = string.match(entry, "^([^|]+)|(.+)$")
  return partition, relpath
end
local function ParseMassGameEntry(entry)
  if entry == nil then return nil, nil end
  local prefix, relpath = string.match(entry, "^(mass%d*:/)|(.+)$")
  return prefix, relpath
end
local function StripExtension(path)
  if path == nil then return nil end
  local stripped = string.match(path, "(.+)%.[^%.]+$")
  return stripped or path
end
local function BuildCoverCandidates(entry, game_path, device_scene)
  -- TODO: verify cover art naming/layout. For now, assume sidecar image next to the VCD.
  local relpath = ExtractGameRelPath(entry)
  local mass_prefix, mass_relpath = ParseMassGameEntry(entry)
  if mass_relpath ~= nil then
    relpath = mass_relpath
  end
  if relpath == nil or relpath == "" then return {}, nil end
  local hdd_partition_label, hdd_relpath = ParseHddGameEntry(entry)
  if hdd_partition_label ~= nil and hdd_relpath ~= nil then
    relpath = hdd_relpath
  end
  local fullpath = relpath
  local cover_root = game_path
  if mass_prefix ~= nil then
    cover_root = mass_prefix
  end
  if type(JoinPath) == "function" then
    fullpath = JoinPath(cover_root or "", relpath)
  elseif cover_root ~= nil and cover_root ~= "" then
    if string.sub(cover_root, -1) == "/" then
      fullpath = cover_root..relpath
    else
      fullpath = cover_root.."/"..relpath
    end
  end
  local base = StripExtension(fullpath)
  local mount_partition = nil
  if hdd_partition_label ~= nil then
    mount_partition = "hdd0:"..hdd_partition_label
  elseif device_scene ~= nil and PLDR ~= nil and PLDR.HDD ~= nil and PLDR.HDD.GAMEPARTS ~= nil then
    mount_partition = PLDR.HDD.GAMEPARTS[entry]
  end
  return {
    base..".png"
  }, mount_partition
end
local CoverCache = {
  max = 3,
  entries = {},
  order = {},
  failed = {},
  last_key = nil,
  last_img = nil,
  last_missing = false
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
  self.last_missing = false
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
  if path == nil or path == "" then return nil, false end
  local cached = self.entries[path]
  if cached ~= nil then
    return cached, false
  end
  local failed_reason = self.failed[path]
  if failed_reason ~= nil then
    return nil, failed_reason == "missing"
  end
  if not SafeDoesFileExist(path) then
    self.failed[path] = "missing"
    return nil, true
  end
  if type(Graphics) ~= "table" or type(Graphics.loadImage) ~= "function" then
    self.failed[path] = "load"
    return nil, false
  end
  local img = Graphics.loadImage(path)
  if img == nil then
    self.failed[path] = "load"
    return nil, false
  end
  if type(Graphics.setImageFilters) == "function" then
    Graphics.setImageFilters(img, LINEAR)
  end
  self.entries[path] = img
  table.insert(self.order, path)
  self:EvictIfNeeded()
  return img, false
end
function CoverCache:UpdateSelection(entry, game_path, device_scene)
  local key = tostring(entry or "")
  if game_path ~= nil then
    key = key.."@"..tostring(game_path)
  end
  if device_scene ~= nil then
    key = key.."#"..tostring(device_scene)
  end
  if self.last_key == key then
    return self.last_img, self.last_missing
  end
  self.last_key = key
  self.last_img = nil
  self.last_missing = false
  if entry == nil or entry == "" then
    return nil, false
  end
  local candidates, mount_partition = BuildCoverCandidates(entry, game_path, device_scene)
  local mount_ok = true
  if mount_partition ~= nil and type(HDD) == "table" then
    mount_ok = false
    if type(HDD.UMountPartition) == "function" then
      pcall(HDD.UMountPartition, 0)
    end
    if type(HDD.MountPartition) == "function" then
      local ok, result = pcall(HDD.MountPartition, mount_partition, 0, FIO_MT_RDONLY)
      mount_ok = ok and result == true
    end
  end
  local all_missing = true
  local checked_any = false
  for i = 1, #candidates do
    if not mount_ok then
      break
    end
    local img, missing = self:GetOrLoad(candidates[i])
    checked_any = true
    if img ~= nil then
      self.last_img = img
      if mount_partition ~= nil and type(HDD) == "table" and type(HDD.UMountPartition) == "function" then
        pcall(HDD.UMountPartition, 0)
      end
      return img, false
    end
    if not missing then
      all_missing = false
    end
  end
  if mount_partition ~= nil and mount_ok and type(HDD) == "table" and type(HDD.UMountPartition) == "function" then
    pcall(HDD.UMountPartition, 0)
  end
  if checked_any and all_missing then
    self.last_missing = true
    return nil, true
  end
  return nil, false
end
UI = {
    LASTSCENE = 5;
    SCENES = {
      GUSB = 1,
      GMMCE = 3,
      GMX4SIO = 4,
      GHDD = 5,
      GAPAHDD = 5,
      GBDMHDD = 6,
      MMAIN = 8,
      MPROFILE = 9,
      CREDITS = 10
    };
    LAUNCHING = false;
    HideUI = (PLDR ~= nil and PLDR.SETTINGS ~= nil and PLDR.SETTINGS.hide_ui == true);
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
      return true
    end;
    ShouldHideUI = function ()
      if not UI.HideUI then return false end
      if UI.CURSCENE == UI.SCENES.MPROFILE or UI.CURSCENE == UI.SCENES.CREDITS then
        return false
      end
      return true
    end;
    setDeviceLock = function (target)
      return
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
      LIST_SELECTED = Color.new(90, 175, 255, 128);
      LIST_UNSELECTED = Color.new(20, 45, 100, 128);
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
	      -- Raised/tighter footer to avoid overscan and allow icon reflections to overlap slightly.
	      CAROUSEL_Y_OFFSET = 36;
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
      MIN_ACTION_MS = 90;
    };
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
        LOG(NOTIF)
        table.insert(UI.Notif_queue.msg, NOTIF)
      end;
      msg = {};
    };
    Footer = {
      order = {"triangle", "circle", "cross", "square"};
      order_with_r2 = {"triangle", "circle", "cross", "square"};
      order_with_start = {"triangle", "circle", "cross", "start"};
      order_with_start_r2 = {"triangle", "circle", "cross", "square", "start"};
      order_with_start_select = {"triangle", "circle", "cross", "select", "start"};
      order_with_start_select_square = {"triangle", "circle", "cross", "square", "select", "start"};
      order_with_start_select_r2 = {"triangle", "circle", "cross", "R2", "select", "start"};
      labels = {
        triangle = "Credits",
        circle_main = "Exit",
        circle_other = "Back",
        start_profiles = "Settings",
        start_reset = "Reset Defaults",
        cross_confirm = "Confirm",
        cross_enter = "Enter",
        cross_select = "Select",
        cross_launch = "Launch",
        R2 = "Edit DKWDRV"
      };
      legend_cache = {};
      LegendKey = function (order_id, circle_label, cross_label, start_label, square_label, select_label, r2_label)
        return table.concat({
          tostring(order_id or ""),
          tostring(circle_label or ""),
          tostring(cross_label or ""),
          tostring(start_label or ""),
          tostring(square_label or ""),
          tostring(select_label or ""),
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
        local select_label = opts.select
        local r2_label = opts.R2
        local key = UI.Footer.LegendKey(order_id, circle_label, cross_label, start_label, square_label, select_label, r2_label)
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
        if select_label ~= nil then
          labels.select = select_label
        end
        if r2_label ~= nil then
          labels.R2 = r2_label
        end
        UI.Footer.legend_cache[key] = {labels = labels, order = order}
        return labels, order
      end;
      Draw = function (labels, order)
        local safe = UI.LAYOUT.SAFE
        local entries = order or UI.Footer.order
        local count = #entries
        local bar_height = 0
        for i = 1, count do
          local key = entries[i]
          local icon = IMG[key]
          if icon ~= nil then
            local h = Graphics.getImageHeight(icon)
            if h ~= nil and h > bar_height then
              bar_height = h
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
            if w ~= nil and w > max_w then
              max_w = w
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
            Graphics.drawImage(icon, x - (w / 2), y - (h / 2), UI.CCOL.GREY)
          end
          local label = labels and labels[key] or nil
          if label ~= nil then
            Font.ftPrint(SFONT, x, labelY, 8, UI.LAYOUT.FOOTER_LABEL_W, 16, label, UI.CCOL.GREY)
          end
        end
      end;
    };
    TextEntry = {
      active = false,
      title = "",
      value = "",
      default_value = nil,
      confirm_action = nil,
      cancel_action = nil,
      row = 1,
      col = 1,
      max_len = 128,
      caps = false,
      keys = {
        {"a","b","c","d","e","f","g","h","i","j"},
        {"k","l","m","n","o","p","q","r","s","t"},
        {"u","v","w","x","y","z","0","1","2","3"},
        {"4","5","6","7","8","9",":","/","_","-"},
        {".","DEF","DEL","CLR","OK"}
      },
      Open = function (title, initial, confirm_action, cancel_action, default_value)
        UI.TextEntry.active = true
        UI.TextEntry.title = title or "Edit"
        UI.TextEntry.value = initial or ""
        UI.TextEntry.confirm_action = confirm_action
        UI.TextEntry.cancel_action = cancel_action
        UI.TextEntry.default_value = default_value
        UI.TextEntry.row = 1
        UI.TextEntry.col = 1
      end;
      Close = function ()
        UI.TextEntry.active = false
        UI.TextEntry.confirm_action = nil
        UI.TextEntry.cancel_action = nil
      end;
      Append = function (char)
        if char == nil then return end
        if #UI.TextEntry.value >= UI.TextEntry.max_len then
          return
        end
        UI.TextEntry.value = UI.TextEntry.value..char
      end;
      Backspace = function ()
        if #UI.TextEntry.value > 0 then
          UI.TextEntry.value = string.sub(UI.TextEntry.value, 1, -2)
        end
      end;
      HandleInput = function ()
        if not UI.TextEntry.active then return end
        local keys = UI.TextEntry.keys
        local row = UI.TextEntry.row
        local col = UI.TextEntry.col
        if UI.Pad.Events.NAV_UP then
          row = row - 1
        elseif UI.Pad.Events.NAV_DOWN then
          row = row + 1
        elseif UI.Pad.Events.NAV_LEFT then
          col = col - 1
        elseif UI.Pad.Events.NAV_RIGHT then
          col = col + 1
        end
        if row < 1 then row = 1 end
        if row > #keys then row = #keys end
        local row_keys = keys[row]
        if col < 1 then col = 1 end
        if col > #row_keys then col = #row_keys end
        UI.TextEntry.row = row
        UI.TextEntry.col = col
        if UI.Pad.Events.SQUARE then
          UI.TextEntry.caps = not UI.TextEntry.caps
          return
        end
        if UI.Pad.Events.EXIT then
          UI.TextEntry.Backspace()
          return
        end
        if UI.Pad.Events.BACK then
          if UI.TextEntry.cancel_action ~= nil then
            UI.TextEntry.cancel_action()
          end
          UI.TextEntry.Close()
          return
        end
        if UI.Pad.Events.START then
          if UI.TextEntry.confirm_action ~= nil then
            UI.TextEntry.confirm_action(UI.TextEntry.value)
          end
          UI.TextEntry.Close()
          return
        end
        if UI.Pad.Events.CONFIRM then
          local key = keys[row][col]
          if key == "OK" then
            if UI.TextEntry.confirm_action ~= nil then
              UI.TextEntry.confirm_action(UI.TextEntry.value)
            end
            UI.TextEntry.Close()
          elseif key == "DEL" then
            UI.TextEntry.Backspace()
          elseif key == "CLR" then
            UI.TextEntry.value = ""
          elseif key == "DEF" then
            if UI.TextEntry.default_value ~= nil then
              UI.TextEntry.value = UI.TextEntry.default_value
            end
          else
            local ch = key
            if type(ch) == "string" and #ch == 1 and string.match(ch, "%a") then
              if UI.TextEntry.caps then
                ch = string.upper(ch)
              else
                ch = string.lower(ch)
              end
            end
            UI.TextEntry.Append(ch)
          end
        end
      end;
      Draw = function ()
        if not UI.TextEntry.active then return end
        local box_w = 520
        local box_h = 260
        local box_x = UI.SCR.X_MID - (box_w / 2)
        local box_y = UI.SCR.Y_MID - (box_h / 2)
        Graphics.drawRect(0, 0, UI.SCR.X, UI.SCR.Y, Color.new(0, 0, 0, 120))
        Graphics.drawRect(box_x, box_y, box_w, box_h, Color.new(0, 0, 0, 200))
        Graphics.drawRect(box_x, box_y, box_w, 2, UI.CCOL.GREY)
        Graphics.drawRect(box_x, box_y + box_h - 2, box_w, 2, UI.CCOL.GREY)
        Font.ftPrint(BFONT, UI.SCR.X_MID, box_y + 10, 8, UI.SCR.X, 16, UI.TextEntry.title, UI.CCOL.YELLOW)
        local value = UI.TextEntry.value
        if #value > 58 then
          value = "..."..string.sub(value, -55)
        end
        Font.ftPrint(SFONT, UI.SCR.X_MID, box_y + 36, 8, UI.SCR.X, 16, value, UI.CCOL.GREY)
        local keys = UI.TextEntry.keys
        local start_x = box_x + 24
        local start_y = box_y + 70
        local cell_w = 44
        local cell_h = 28
        for r = 1, #keys do
          local row = keys[r]
          for c = 1, #row do
            local x = start_x + (c - 1) * cell_w
            local y = start_y + (r - 1) * cell_h
            if r == UI.TextEntry.row and c == UI.TextEntry.col then
              Graphics.drawRect(x - 2, y - 2, cell_w - 4, cell_h - 4, UI.CCOL.GREY)
            end
            local display_key = row[c]
            if type(display_key) == "string" and #display_key == 1 and string.match(display_key, "%a") then
              if UI.TextEntry.caps then
                display_key = string.upper(display_key)
              else
                display_key = string.lower(display_key)
              end
            end
            Font.ftPrint(SFONT, x + (cell_w / 2), y + 4, 8, cell_w, 16, display_key, UI.CCOL.GREY)
          end
        end
        local hint = "X: Enter  O: Cancel  Start: OK  Triangle: Backspace  Square: Aa"
        Font.ftPrint(SFONT, UI.SCR.X_MID, box_y + box_h - 24, 8, UI.SCR.X, 16, hint, UI.CCOL.GREY)
      end;
    };
    --- wrapper for Screen.flip(), here you add UI draws that renders on top of everything (for example, error notifications)
    flip = function (notif)
      UI.Notif_queue.display()
      UI.TextEntry.Draw()
      UI.Modal.Draw()
      if UI.Transition ~= nil then
        local alpha = UI.Transition.Update()
        if alpha > 0 then
          Graphics.drawRect(0, 0, UI.SCR.X, UI.SCR.Y, Color.new(0, 0, 0, alpha))
        end
      end
      Screen.flip()
    end;
    WelcomeDraw = {
      Play = function (next_scene)
	        -- Boot splash fades in from black, then fades out into the next scene.
	        local function DrawBackground()
	          Screen.clear(Color.new(0, 0, 0))
	        end
        local function DrawTargetBackground(scene)
          Screen.clear(UI.SCR.BGCOL)
          local bg = nil
          if scene == UI.SCENES.MMAIN then
            bg = IMG.BGM or IMG.BKG
          elseif scene == UI.SCENES.MPROFILE or scene == UI.SCENES.CREDITS then
            bg = IMG.BG or IMG.BKG
          else
            bg = IMG.BKG
          end
          if bg ~= nil then
            Graphics.drawScaleImage(bg, 0, 0, UI.SCR.X, UI.SCR.Y, Color.new(128, 128, 128, 128))
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

-- Boot audio (stable APP_DIR-derived lookup). Never fatal.
        local boot_sound_loaded = nil
        local boot_sound_hold_frames = nil

        local function TryBootSound()
          if UI.BOOT_SOUND == nil then
            return
          end
          UI.BOOT_SOUND.STATE = UI.BOOT_SOUND.STATE or {
            attempted = false,
            path_resolved = false
          }
          if UI.BOOT_SOUND.STATE.attempted then return end
          UI.BOOT_SOUND.STATE.attempted = true

          if UI.BOOT_SOUND.ENABLED ~= true then
            LOG("BOOT SOUND: disabled")
            UI.BOOT_SOUND.STATE.path_resolved = true
            return
          end
          if type(Sound) ~= "table" or type(Sound.loadADPCM) ~= "function" then
            LOG("BOOT SOUND: Sound API not available")
            UI.BOOT_SOUND.STATE.path_resolved = true
            return
          end

          local primary = UI.BOOT_SOUND.PATH or "boot.adp"
          local names = { primary }
          if primary ~= "boot.adpcm" then
            table.insert(names, "boot.adpcm")
          end

          local found = nil
          local requested = nil
          for _, rel in ipairs(names) do
            requested = rel
            local candidates = ResolveBootSoundCandidates(rel)
            UI.BOOT_SOUND.STATE.path_resolved = true
            for _, p in ipairs(candidates) do
              if SafeDoesFileExist(p) then
                found = p
                break
              end
            end
            if found ~= nil then break end
          end

          if found == nil and requested ~= nil then
            -- Last resort: try HostFS prefix in PCSX2 setups.
            local host_p = "host:" .. requested
            if SafeDoesFileExist(host_p) then found = host_p end
          end

          if found == nil then
            -- Embedded-first fallback: allow logical asset key even when no filesystem path exists.
            found = primary
          end

          LOGF("BOOT SOUND: using '%s'", tostring(found))

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

          LOGF("BOOT SOUND: loading '%s'", tostring(found))
          local ok_load, audio = pcall(Sound.loadADPCM, found)
          if not ok_load then
            LOGF("BOOT SOUND: load threw for '%s': %s", tostring(found), tostring(audio))
            return
          end
          if audio == nil or audio == 0 then
            LOGF("BOOT SOUND: load failed for '%s'", tostring(found))
            return
          end
          boot_sound_loaded = audio
          LOGF("BOOT SOUND: loaded handle=%s", tostring(boot_sound_loaded))

          local ok_play, play_err = pcall(function()
            Sound.playADPCM(UI.BOOT_SOUND.CHANNEL or 0, boot_sound_loaded)
          end)
          if not ok_play then
            LOGF("BOOT SOUND: play failed for '%s': %s", tostring(found), tostring(play_err))
            if type(Sound.freeADPCM) == "function" then
              pcall(Sound.freeADPCM, boot_sound_loaded)
            end
            boot_sound_loaded = nil
            return
          end
          LOGF("BOOT SOUND: play started on channel %s", tostring(UI.BOOT_SOUND.CHANNEL or 0))

          local sec = UI.BOOT_SOUND.SECONDS
          if type(sec) ~= "number" or sec < 0 then sec = 0 end
          local pad = UI.BOOT_SOUND.PAD_SECONDS
          if type(pad) ~= "number" or pad < 0 then pad = 0 end
          boot_sound_hold_frames = math.floor(((sec + pad) * 60) + 0.5)
          LOGF("BOOT SOUND: hold frames=%s", tostring(boot_sound_hold_frames))
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

local function DrawSplashFit(img, x, y, draw_w, draw_h, alpha)
  if img == nil then return end
  local tint = Color.new(128, 128, 128, alpha)
  Graphics.drawScaleImage(img, x, y, draw_w, draw_h, tint)
end

local function DrawSplash(alpha)
  -- Standard splash: single logical asset IMG/PSL.png, non-fatal fallback to solid color.
  if IMG.PSL ~= nil then
    DrawSplashCover(IMG.PSL, UI.SCR.X, UI.SCR.Y, alpha)
    return
  end
  Screen.clear(Color.new(0, 0, 0))
end
        local fade_in_frames = 120
        local fade_out_frames = 60

        -- Start boot sound once (timing remains fixed to splash/credits durations).
        TryBootSound()
        local splash_seconds = 8.0
        local credits_seconds = 7.0
        local splash_frames = math.floor((splash_seconds * 60) + 0.5)
        local credits_frames = math.floor((credits_seconds * 60) + 0.5)
        if fade_in_frames > splash_frames then
          fade_in_frames = splash_frames
        end
        if fade_out_frames > splash_frames - fade_in_frames then
          fade_out_frames = splash_frames - fade_in_frames
        end
        if fade_out_frames < 0 then fade_out_frames = 0 end
        local splash_hold_frames = splash_frames - fade_in_frames - fade_out_frames
        if splash_hold_frames < 0 then splash_hold_frames = 0 end
        local credits_fade_in_frames = fade_in_frames
        local credits_fade_out_frames = fade_out_frames
        if credits_fade_in_frames > credits_frames then
          credits_fade_in_frames = credits_frames
        end
        if credits_fade_out_frames > credits_frames - credits_fade_in_frames then
          credits_fade_out_frames = credits_frames - credits_fade_in_frames
        end
        if credits_fade_out_frames < 0 then credits_fade_out_frames = 0 end
        local credits_hold_frames = credits_frames - credits_fade_in_frames - credits_fade_out_frames
        if credits_hold_frames < 0 then credits_hold_frames = 0 end

        -- Splash: slow fade in -> hold -> fade out to black.
        for i = 1, fade_in_frames do
          local alpha = Round(128 * (i / fade_in_frames))
          DrawBackground()
          DrawSplash(alpha)
          Screen.flip()
        end
        for _ = 1, splash_hold_frames do
          DrawBackground()
          DrawSplash(128)
          Screen.flip()
        end
        if fade_out_frames > 0 then
          for i = 1, fade_out_frames do
            local alpha = Round(128 * (i / fade_out_frames))
            DrawBackground()
            DrawSplash(128)
            Graphics.drawRect(0, 0, UI.SCR.X, UI.SCR.Y, Color.new(0, 0, 0, alpha))
            Screen.flip()
          end
        end

        -- Credits: fade in from black -> hold -> fade out to black.
        for i = 1, credits_fade_in_frames do
          local alpha = Round(128 * (1 - (i / credits_fade_in_frames)))
          DrawTargetScene(UI.SCENES.CREDITS)
          Graphics.drawRect(0, 0, UI.SCR.X, UI.SCR.Y, Color.new(0, 0, 0, alpha))
          Screen.flip()
        end
        for _ = 1, credits_hold_frames do
          DrawTargetScene(UI.SCENES.CREDITS)
          Screen.flip()
        end
        if credits_fade_out_frames > 0 then
          for i = 1, credits_fade_out_frames do
            local alpha = Round(128 * (i / credits_fade_out_frames))
            DrawTargetScene(UI.SCENES.CREDITS)
            Graphics.drawRect(0, 0, UI.SCR.X, UI.SCR.Y, Color.new(0, 0, 0, alpha))
            Screen.flip()
          end
        end

        local final_scene = UI.SCENES.MMAIN
        -- Main menu: fade in from black.
        for i = 1, fade_in_frames do
          local alpha = Round(128 * (1 - (i / fade_in_frames)))
          DrawTargetScene(final_scene)
          Graphics.drawRect(0, 0, UI.SCR.X, UI.SCR.Y, Color.new(0, 0, 0, alpha))
          Screen.flip()
        end
        DrawTargetScene(final_scene)
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
        local bg = nil
        if UI.CURSCENE == UI.SCENES.MMAIN then
          bg = IMG.BGM or IMG.BKG
        elseif UI.CURSCENE == UI.SCENES.MPROFILE or UI.CURSCENE == UI.SCENES.CREDITS then
          bg = IMG.BG or IMG.BKG
        else
          bg = IMG.BKG
        end
        if bg ~= nil then
          local alpha = 128
          Graphics.drawScaleImage(bg, 0, 0, UI.SCR.X, UI.SCR.Y, Color.new(128, 128, 128, alpha))
          UI._BG_LOG_FRAMES = (UI._BG_LOG_FRAMES or 0) + 1
          if (UI._BG_LOG_FRAMES % 60) == 0 then
            LOGF("DRAWBG handle=%s alpha=%s", tostring(bg), tostring(alpha))
          end
        end
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
      ResolveElfPath = function (candidates)
        if type(candidates) ~= "table" then
          return nil
        end
        if type(doesFileExist) == "function" then
          for _, path in ipairs(candidates) do
            local okcall, exists = pcall(doesFileExist, path)
            if okcall and exists == true then
              return path
            end
          end
        end
        if type(System) == "table" and type(System.openFile) == "function" then
          for _, path in ipairs(candidates) do
            local okfd, fd = pcall(System.openFile, path, FREAD)
            if okfd and type(fd) == "number" and fd >= 0 then
              if type(System.closeFile) == "function" then
                pcall(System.closeFile, fd)
              end
              return path
            end
          end
        end
        return nil
      end;
      OpenExit = function ()
        LOG("Exit requested")
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
        LOG("DKWDRV requested")
        UI.Modal.active = true
        UI.Modal.title = "DKWDRV"
        UI.Modal.body = "Leave and Launch DKWDRV?"
        UI.Modal.options = {"Confirm", "Cancel"}
        UI.Modal.confirm_action = UI.Modal.LaunchDKWDRV
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
          LOG("Device lock prompt choice: RETURN")
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
        LOG("Exit confirmed")
        UI.LAUNCHING = true
        System.exitToBrowser()
      end;
      LaunchBootElf = function ()
        LOG("Exit triangle: BOOT2/BOOT.ELF requested")
        local candidates = {
          "mc0:/BOOT/BOOT2.ELF",
          "mc0:/BOOT/BOOT.ELF",
          "mc1:/BOOT/BOOT2.ELF",
          "mc1:/BOOT/BOOT.ELF"
        }
        local boot_path = UI.Modal.ResolveElfPath(candidates)
        if boot_path == nil then
          if UI.Notif_queue ~= nil and type(UI.Notif_queue.add) == "function" then
            UI.Notif_queue.add("mc?:/BOOT/BOOT2.ELF or BOOT.ELF not found")
          end
          return
        end
        if type(System) == "table" and type(System.loadELF) == "function" then
          UI.LAUNCHING = true
          UI.Modal.Close()
          local ok, rc = pcall(System.loadELF, boot_path, 1, boot_path)
          if ok ~= true then
            UI.LAUNCHING = false
            if UI.Notif_queue ~= nil and type(UI.Notif_queue.add) == "function" then
              UI.Notif_queue.add("BOOT ELF launch error")
            end
            return
          end
          if type(rc) == "number" and rc < 0 then
            UI.LAUNCHING = false
            if UI.Notif_queue ~= nil and type(UI.Notif_queue.add) == "function" then
              UI.Notif_queue.add(("BOOT ELF launch failed: %d"):format(rc))
            end
            return
          end
        end
      end;
      LaunchDKWDRV = function ()
        LOG("DKWDRV launch confirmed")
        local configured = nil
        local default_path = (PLDR ~= nil and PLDR.DEFAULT_DKWDRV_PATH) or "mc0:/PS1_DKWDRV/DKWDRV.ELF"
        if PLDR ~= nil and PLDR.SETTINGS ~= nil then
          configured = PLDR.SETTINGS.dkwdrv_path
        end
        if configured == nil or configured == "" then
          configured = default_path
        end
        local candidates = { configured }
        local dkw_path = UI.Modal.ResolveElfPath(candidates)
        if dkw_path == nil then
          if UI.Notif_queue ~= nil and type(UI.Notif_queue.add) == "function" then
            UI.Notif_queue.add("DKWDRV not found")
          end
          UI.Modal.Close()
          return
        end
        if type(System) == "table" and type(System.loadELF) == "function" then
          UI.LAUNCHING = true

          -- Important: Some environments return from loadELF on failure, leaving the UI black
          -- because UI.LAUNCHING stays true. Also, using an extra argv forces the ExecPS2 path
          -- in the C binding, which tends to be more robust for certain homebrew.
          local ok, rc = pcall(System.loadELF, dkw_path, 1, dkw_path)
          if ok and rc == nil then
            return
          end
          if (not ok) or (type(rc) == "number" and rc < 0) then
            UI.LAUNCHING = false
            if UI.Notif_queue ~= nil and type(UI.Notif_queue.add) == "function" then
              UI.Notif_queue.add("DKWDRV launch failed"..(type(rc) == "number" and (": "..tostring(rc)) or ""))
            end
            UI.Modal.Close()
          end
        end
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
      duration_out = 140,
      duration_in = 120,
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
        local alpha
        if UI.Transition.phase == "out" then
          alpha = Round(128 * t)
        else
          alpha = Round(128 * (1 - t))
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
      if UI.TextEntry ~= nil and UI.TextEntry.active then
        UI.TextEntry.HandleInput()
        for key, _ in pairs(UI.Pad.Events) do
          UI.Pad.Events[key] = false
        end
        return true
      end
      if UI.Modal.active then
        UI.Modal.HandleInput()
        for key, _ in pairs(UI.Pad.Events) do
          UI.Pad.Events[key] = false
        end
        return true
      end
      if UI.LAUNCHING then return false end
      if UI.Pad.Events.SELECT then
        UI.HideUI = not UI.HideUI
        if PLDR ~= nil and PLDR.SETTINGS ~= nil then
          PLDR.SETTINGS.hide_ui = UI.HideUI
          if PLDR.SaveSettings ~= nil then
            PLDR.SaveSettings()
          end
        end
        return true
      end
      if UI.Pad.Events.START and UI.CURSCENE ~= UI.SCENES.MPROFILE then
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
      SHOW_COVER = (PLDR ~= nil and PLDR.SETTINGS ~= nil and PLDR.SETTINGS.show_cover ~= false);
      LAST_SQUARE_DOWN = false;
      Reset = function ()
        UI.GameList.CURR = 1;
      end;
      Play = function()
        local layout = UI.LAYOUT
        local hide_ui = UI.ShouldHideUI()
        UI.GameList.MAXDRAW = layout.LIST_MAX
        local titles = {
          [UI.SCENES.GUSB] = "USB",
          [UI.SCENES.GMX4SIO] = "MX4SIO"
        }
        local scene_title = titles[UI.CURSCENE]
        if scene_title ~= nil and not hide_ui then
          Font.ftPrint(LFONT, UI.SCR.X_MID, layout.TITLE_Y, 8, UI.SCR.X, 16, scene_title, UI.CCOL.GREY)
        end
        local placeholders = {
          [UI.SCENES.GBDMHDD] = "BDM HDD"
        }
        local placeholder_title = placeholders[UI.CURSCENE]
        if placeholder_title ~= nil then
          if not hide_ui then
            Font.ftPrint(LFONT, UI.SCR.X_MID, layout.TITLE_Y, 8, UI.SCR.X, 16, placeholder_title, UI.CCOL.GREY)
            Font.ftPrintMultiLineAligned(BFONT, UI.SCR.X_MID, UI.SCR.Y_MID, 20, UI.SCR.X, 32, "Not implemented yet", UI.CCOL.YELLOW)
          end
          Input_GetEvent()
        if UI.HandleGlobalInput(false) then return end
          if UI.Pad.Events.EXIT then UI.SceneChange(UI.SCENES.CREDITS) end
          if UI.Pad.Events.BACK then UI.SceneChange(UI.SCENES.MMAIN) end
          if UI.Pad.Events.CONFIRM then
            UI.Notif_queue.add("Not implemented yet")
          end
          if not hide_ui then
            local labels, order = UI.Footer.ResolveLegend({
              order = UI.Footer.order_with_start_select_square,
              order_id = "start_select_square",
              circle = UI.Footer.labels.circle_other,
              cross = UI.Footer.labels.cross_confirm,
              square = "Cover Art",
              select = "Hide UI",
              start = UI.Footer.labels.start_profiles
            })
            UI.Footer.Draw(labels, order)
          end
          return
        end
        local ammount = #PLDR.GAMES
        if UI.CURSCENE == UI.SCENES.GMMCE and not hide_ui then
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
          local _, mass_relpath = ParseMassGameEntry(display_name)
          local relpath = ExtractGameRelPath(display_name)
          if mass_relpath ~= nil then
            relpath = mass_relpath
          end
          if relpath ~= nil then
            display_name = string.match(relpath, "([^/]+)$") or relpath
          end
	          local c = (i == UI.GameList.CURR) and UI.COLORS.LIST_SELECTED or UI.COLORS.LIST_UNSELECTED
	          Font.ftPrint(BFONT, layout.LIST_X, Y, 0, layout.LIST_W, 16, string.sub(display_name,1, -5), c)
        end
        if UI.GameList.SHOW_COVER then
          local cover_img = nil
          local cover_missing = false
          if UI.CoverCache ~= nil then
            if ammount > 0 then
              cover_img, cover_missing = UI.CoverCache:UpdateSelection(PLDR.GAMES[UI.GameList.CURR], PLDR.GAMEPATH, UI.CURSCENE)
            else
              UI.CoverCache:UpdateSelection(nil, PLDR.GAMEPATH, UI.CURSCENE)
            end
          end
          if layout.PREVIEW_W > 0 then
            local preview_img = cover_img
            if preview_img == nil and cover_missing then
              preview_img = IMG.MISSING
            end
            if preview_img ~= nil then
              Graphics.drawScaleImage(preview_img, layout.PREVIEW_X, layout.PREVIEW_Y, layout.PREVIEW_W, layout.PREVIEW_H)
            end
          end
        end
        if ammount <= 0 and not hide_ui then
          Font.ftPrintMultiLineAligned(LFONT, UI.SCR.X_MID, UI.SCR.Y_MID, 20, UI.SCR.X, 32, "No games found", UI.CCOL.YELLOW)
          Font.ftPrintMultiLineAligned(LFONT, UI.SCR.X_MID+1, UI.SCR.Y_MID+1, 20, UI.SCR.X, 32, "No games found", UI.CCOL.TRANSP_BLACK)
        end
        Input_GetEvent()
        if UI.HandleGlobalInput(false) then return end
        if UI.Pad.Events.EXIT then
          UI.ProfileQuery.bdma_mode = nil
          UI.SceneChange(UI.SCENES.CREDITS)
        end
        if UI.Pad.Events.BACK then UI.SceneChange(UI.SCENES.MMAIN) end
        if UI.Pad.Events.NAV_DOWN then UI.GameList.CURR = CLAMP(UI.GameList.CURR+1, 1, ammount) end
        if UI.Pad.Events.NAV_RIGHT then UI.GameList.CURR = CLAMP(UI.GameList.CURR+UI.GameList.MAXDRAW, 1, ammount) end
        if UI.Pad.Events.NAV_UP then UI.GameList.CURR = CLAMP(UI.GameList.CURR-1, 1, ammount) end
        if UI.Pad.Events.NAV_LEFT then UI.GameList.CURR = CLAMP(UI.GameList.CURR-UI.GameList.MAXDRAW, 1, ammount) end
        if (UI.IsUsbScene(UI.CURSCENE) or UI.IsMx4sioScene(UI.CURSCENE)) and UI.Pad.Events.R2 then
          if UI.RefreshCurrentMassScene(UI.CURSCENE) then
            UI.Notif_queue.add("Device list refreshed")
            ammount = #PLDR.GAMES
          end
          return
        end
        local square_down = false
        if UI.Pad.GPAD ~= nil and PAD_SQUARE ~= nil then
          square_down = (UI.Pad.GPAD & PAD_SQUARE) ~= 0
        end
        if square_down and not UI.GameList.LAST_SQUARE_DOWN then
          UI.GameList.SHOW_COVER = not UI.GameList.SHOW_COVER
          if PLDR ~= nil and PLDR.SETTINGS ~= nil then
            PLDR.SETTINGS.show_cover = UI.GameList.SHOW_COVER
            if PLDR.SaveSettings ~= nil then
              PLDR.SaveSettings()
            end
          end
        end
        UI.GameList.LAST_SQUARE_DOWN = square_down
        if UI.Pad.Events.CONFIRM then
          if ammount <= 0 then
            UI.Notif_queue.add("No games found")
          elseif not doesFileExist(PLDR.POPSTARTER_PATH) then
            UI.Notif_queue.add("Cant find POPSTARTER ELF\n"..PLDR.POPSTARTER_PATH)
          else
            if UI.CURSCENE ~= UI.SCENES.GHDD then -- only check if game can be found on USB and SMB
              local selected_entry = PLDR.GAMES[UI.GameList.CURR]
              local mass_prefix, mass_relpath = ParseMassGameEntry(selected_entry)
              local selected_relpath = mass_relpath or selected_entry
              local selected_root = PLDR.GAMEPATH
              if mass_prefix ~= nil then
                selected_root = mass_prefix
              end
              if not doesFileExist(selected_root .. selected_relpath) then
                UI.Notif_queue.add("Cant find Game\n"..selected_root .. selected_relpath)
              end
            end
            local launch_path = PLDR.GAMEPATH
            if UI.CURSCENE == UI.SCENES.GHDD then
              launch_path = ""
            end
            PLDR.RunPOPStarterGame(launch_path, PLDR.GAMES[UI.GameList.CURR], UI.CURSCENE)
          end
        end
        local cross_label = UI.Footer.labels.cross_launch
        if ammount <= 0 then
          cross_label = UI.Footer.labels.cross_confirm
        end
        if not hide_ui then
          local footer_order = UI.Footer.order_with_start_select_square
          local footer_id = "start_select_square"
          local footer_square = "Cover Art"
          local footer_r2 = nil
          if UI.IsUsbScene(UI.CURSCENE) or UI.IsMx4sioScene(UI.CURSCENE) then
            footer_order = UI.Footer.order_with_start_select_r2
            footer_id = "start_select_r2_refresh"
            footer_square = nil
            footer_r2 = "Refresh"
          end
          local labels, order = UI.Footer.ResolveLegend({
            order = footer_order,
            order_id = footer_id,
            circle = UI.Footer.labels.circle_other,
            cross = cross_label,
            square = footer_square,
            R2 = footer_r2,
            select = "Hide UI",
            start = UI.Footer.labels.start_profiles
          })
          UI.Footer.Draw(labels, order)
        end
      end;
    };
    ProfileQuery = {
      lastopt = 1;
      curopt = 1;
      Play = function ()
        local layout = UI.LAYOUT
        local profiles = (PLDR ~= nil and type(PLDR.PROFILES) == "table") and PLDR.PROFILES or {}
        local profcnt = #profiles
        local function GetSelectedProfile()
          if profcnt < 1 then
            return { DESC = "No POPStarter profiles available", ELF = "" }
          end
          UI.ProfileQuery.curopt = CLAMP(tonumber(UI.ProfileQuery.curopt) or 1, 1, profcnt)
          return profiles[UI.ProfileQuery.curopt] or { DESC = "Invalid profile entry", ELF = "" }
        end
        local selected_profile = GetSelectedProfile()
        local hide_ui = UI.ShouldHideUI()
        if UI.ProfileQuery.bdma_mode == nil then
          if PLDR.GetBDMAMode ~= nil then
            UI.ProfileQuery.bdma_mode = PLDR.GetBDMAMode()
          else
            UI.ProfileQuery.bdma_mode = 1
          end
        end
        local bdma_mode = UI.ProfileQuery.bdma_mode
        local bdma_label = "USBFAT32(None)"
        if PLDR.GetBDMAModeText ~= nil then
          bdma_label = PLDR.GetBDMAModeText(bdma_mode)
        end
        local dkwdrv_path = (PLDR ~= nil and PLDR.SETTINGS ~= nil and PLDR.SETTINGS.dkwdrv_path) or (PLDR and PLDR.DEFAULT_DKWDRV_PATH) or "mc0:/PS1_DKWDRV/DKWDRV.ELF"
        local popstarter_path = (System ~= nil and System.GetPOPStarterElfPath ~= nil and System.GetPOPStarterElfPath()) or (PLDR and PLDR.POPSTARTER_PATH) or ""
        local dkwdrv_label = dkwdrv_path
        if #dkwdrv_label > 52 then
          dkwdrv_label = "..."..string.sub(dkwdrv_label, -49)
        end
        local popstarter_label = popstarter_path
        if #popstarter_label > 52 then
          popstarter_label = "..."..string.sub(popstarter_label, -49)
        end
        if not hide_ui then
          Font.ftPrint(LFONT, UI.SCR.X_MID, layout.TITLE_Y, 8, UI.SCR.X, 16, "Settings", UI.CCOL.GREY)
          local function DrawCenteredIcon(icon, x, y)
            if icon == nil then return end
            local w = Graphics.getImageWidth(icon) or 0
            local h = Graphics.getImageHeight(icon) or 0
            Graphics.drawImage(icon, x - (w / 2), y - (h / 2), UI.CCOL.GREY)
          end
          local function DrawIconPair(left_key, right_key, y, offset)
            local left_icon = IMG[left_key]
            local right_icon = IMG[right_key]
            local center_x = UI.SCR.X_MID
            local icon_offset = offset or 36
            DrawCenteredIcon(left_icon, center_x - icon_offset, y)
            DrawCenteredIcon(right_icon, center_x + icon_offset, y)
          end
          local info_y = layout.TITLE_Y + 52
          local bdma_icons_y = info_y
          DrawIconPair("left", "right", bdma_icons_y, 36)
          local bdma_y = bdma_icons_y + 24
          Font.ftPrint(BFONT, UI.SCR.X_MID, bdma_y, 8, UI.SCR.X, 16, "BDMA MODE:", UI.CCOL.GREY)
          local bdma_value_y = bdma_y + 18
          Font.ftPrint(BFONT, UI.SCR.X_MID, bdma_value_y, 8, UI.SCR.X, 16, bdma_label, UI.CCOL.GREY)
          local dkwdrv_icon_y = bdma_value_y + 42
          DrawCenteredIcon(IMG.R2, UI.SCR.X_MID, dkwdrv_icon_y)
          local dkwdrv_title_y = dkwdrv_icon_y + 24
          Font.ftPrint(BFONT, UI.SCR.X_MID, dkwdrv_title_y, 8, UI.SCR.X, 16, "DKWDRV PATH:", UI.CCOL.GREY)
          local dkwdrv_path_y = dkwdrv_title_y + 18
          Font.ftPrint(BFONT, UI.SCR.X_MID, dkwdrv_path_y, 8, UI.SCR.X, 16, dkwdrv_label, UI.CCOL.GREY)
          local popstarter_icon_y = dkwdrv_path_y + 42
          DrawCenteredIcon(IMG.R2, UI.SCR.X_MID, popstarter_icon_y)
          local popstarter_title_y = popstarter_icon_y + 24
          Font.ftPrint(BFONT, UI.SCR.X_MID, popstarter_title_y, 8, UI.SCR.X, 16, "POPSTARTER PATH:", UI.CCOL.GREY)
          local popstarter_path_y = popstarter_title_y + 18
          Font.ftPrint(BFONT, UI.SCR.X_MID, popstarter_path_y, 8, UI.SCR.X, 16, popstarter_label, UI.CCOL.GREY)
          local profile_icons_y = popstarter_path_y + 42
          DrawIconPair("up", "down", profile_icons_y, 36)
          local profile_title_y = profile_icons_y + 24
          Font.ftPrint(BFONT, UI.SCR.X_MID, profile_title_y, 8, UI.SCR.X, 16, "POPStarter Mode:", UI.CCOL.GREY)
          local profile_desc_y = profile_title_y + 18
          Font.ftPrint(BFONT, UI.SCR.X_MID, profile_desc_y, 8, UI.SCR.X, 16, selected_profile.DESC or "", UI.CCOL.GREY)
          local profile_path_y = profile_desc_y + 18
          Font.ftPrint(BFONT, UI.SCR.X_MID, profile_path_y, 8, UI.SCR.X, 16, selected_profile.ELF or "", Color.new(128,128,128, 110))
        end
        Input_GetEvent()
        if UI.HandleGlobalInput(false) then return end
        if UI.Pad.Events.EXIT then
          UI.ProfileQuery.bdma_mode = nil
          UI.SceneChange(UI.SCENES.CREDITS)
        end
        if UI.Pad.Events.NAV_DOWN then UI.ProfileQuery.curopt = CLAMP(UI.ProfileQuery.curopt+1, 1, profcnt) end
        if UI.Pad.Events.NAV_UP then UI.ProfileQuery.curopt = CLAMP(UI.ProfileQuery.curopt-1, 1, profcnt) end
        selected_profile = GetSelectedProfile()
        if UI.Pad.Events.NAV_LEFT or UI.Pad.Events.NAV_RIGHT then
          local count = 4
          if PLDR.GetBDMAModeCount ~= nil then
            count = PLDR.GetBDMAModeCount()
          end
          local mode = UI.ProfileQuery.bdma_mode or 1
          if UI.Pad.Events.NAV_LEFT then
            mode = CYCLE_CLAMP(mode - 1, 1, count)
          else
            mode = CYCLE_CLAMP(mode + 1, 1, count)
          end
          UI.ProfileQuery.bdma_mode = mode
        end
        if UI.Pad.Events.BACK then
          UI.ProfileQuery.bdma_mode = nil
          UI.SceneChange(UI.SCENES.MMAIN)
        end
        if UI.Pad.Events.START then
          local default_profile = tonumber(PLDR.DEFAULT_PROFILE) or 1
          UI.ProfileQuery.curopt = CLAMP(default_profile, 1, profcnt)
          local profile = GetSelectedProfile()
          if profile ~= nil then
            PLDR.POPSTARTER_PATH = profile.ELF
          end
          if PLDR.SETTINGS ~= nil then
            PLDR.SETTINGS.profile_index = UI.ProfileQuery.curopt
            PLDR.SETTINGS.dkwdrv_path = PLDR.DEFAULT_DKWDRV_PATH or "mc0:/PS1_DKWDRV/DKWDRV.ELF"
          end
          if PLDR.GetBDMAMode ~= nil then
            UI.ProfileQuery.bdma_mode = PLDR.GetBDMAMode()
          end
          if PLDR.SaveSettings ~= nil then
            PLDR.SaveSettings()
          end
          UI.Notif_queue.add("Profile defaults restored")
        end
        if UI.Pad.Events.R2 then
          UI.TextEntry.Open("Edit POPStarter Path", popstarter_path, function (new_value)
            if PLDR ~= nil and PLDR.SETTINGS ~= nil then
              PLDR.SETTINGS.popstarter_path = new_value
              local resolved = new_value
              if System ~= nil and System.GetPOPStarterElfPath ~= nil then
                resolved = System.GetPOPStarterElfPath()
              end
              if PLDR.PROFILES ~= nil and PLDR.PROFILES[1] ~= nil then
                PLDR.PROFILES[1].ELF = resolved
              end
              PLDR.POPSTARTER_PATH = resolved
              if PLDR.SaveSettings ~= nil then
                PLDR.SaveSettings()
              end
              if UI.Notif_queue ~= nil and UI.Notif_queue.add ~= nil then
                UI.Notif_queue.add("POPStarter path saved")
              end
            end
          end, nil, (PLDR and PLDR.SETTINGS and PLDR.SETTINGS.popstarter_path) or JoinPath(APP_DIR or System.currentDirectory(), "POPSTARTER.ELF"))
        end
        if UI.Pad.Events.SQUARE then
          UI.TextEntry.Open("Edit DKWDRV Path", dkwdrv_path, function (new_value)
            if PLDR ~= nil and PLDR.SETTINGS ~= nil then
              PLDR.SETTINGS.dkwdrv_path = new_value
              if PLDR.SaveSettings ~= nil then
                PLDR.SaveSettings()
              end
              if UI.Notif_queue ~= nil and UI.Notif_queue.add ~= nil then
                UI.Notif_queue.add("DKWDRV path saved")
              end
            end
          end, nil, PLDR and PLDR.DEFAULT_DKWDRV_PATH or "mc0:/PS1_DKWDRV/DKWDRV.ELF")
        end
        if UI.Pad.Events.CONFIRM then
          if PLDR.SetBDMAMode ~= nil then
            PLDR.SetBDMAMode(UI.ProfileQuery.bdma_mode)
          end
          if PLDR.ApplyBDMAMode ~= nil then
            PLDR.ApplyBDMAMode()
          end
          if PLDR.SETTINGS ~= nil then
            PLDR.SETTINGS.profile_index = UI.ProfileQuery.curopt
          end
          if PLDR.SaveSettings ~= nil then
            PLDR.SaveSettings()
          end
          local confirm_profile = GetSelectedProfile()
          if type(confirm_profile.ELF) ~= "string" or confirm_profile.ELF == "" or not doesFileExist(confirm_profile.ELF) then
            UI.Notif_queue.add("POPStarter ELF missing")
          else
            PLDR.POPSTARTER_PATH = confirm_profile.ELF
            UI.ProfileQuery.bdma_mode = nil
            UI.SceneChange(UI.SCENES.MMAIN)
          end
        end
        if not hide_ui then
          local labels, order = UI.Footer.ResolveLegend({
            order = UI.Footer.order_with_start_select_r2,
            order_id = "start_select_r2",
            circle = UI.Footer.labels.circle_other,
            cross = UI.Footer.labels.cross_select,
            select = "Hide UI",
            R2 = UI.Footer.labels.R2,
            start = UI.Footer.labels.start_reset
          })
          UI.Footer.Draw(labels, order)
        end
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
        local hide_ui = UI.ShouldHideUI()
        local function ResolveActiveBDMALabel()
          if PLDR == nil then
            return "NONE"
          end
          if PLDR.GetBDMADetectedLabel ~= nil then
            return PLDR.GetBDMADetectedLabel()
          end
          if PLDR.GetBDMAModeText == nil then
            return "NONE"
          end
          local mode = nil
          if PLDR.GetBDMAMode ~= nil then
            mode = PLDR.GetBDMAMode()
          end
          local raw = PLDR.GetBDMAModeText(mode)
          if type(raw) ~= "string" then
            return "NONE"
          end
          local upper = string.upper(raw)
          if string.find(upper, "USBEXFAT", 1, true) then
            return "USBEXFAT"
          end
          if string.find(upper, "MX4SIO", 1, true) then
            return "MX4SIO"
          end
          if string.find(upper, "MMCE", 1, true) then
            return "MMCE"
          end
          return "NONE"
        end
        local top_label_y = layout.STATUS_Y + 16
        if not hide_ui then
          local title_y = layout.TITLE_Y
          local status_y = title_y + 16
          top_label_y = status_y + 16
          Font.ftPrint(UI.FONT.TITLE, UI.SCR.X_MID, title_y, 8, UI.SCR.X, 16, "POPSLOADER", UI.COLORS.TEXT_PRIMARY)
          Font.ftPrint(UI.FONT.STATUS, UI.SCR.X_MID, status_y, 8, UI.SCR.X, 16, "ACTIVE BDMA: "..ResolveActiveBDMALabel(), UI.COLORS.TEXT_PRIMARY)
        end
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
            LOG("SNAP BUG: currentIndex changed during anim")
            LOG(GuardTrace())
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
        local center_label_x = center_x
        local center_label_y = Round(top_label_y)
        local center_label_idx = carousel.animActive and carousel.targetIndex or base_sel
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
        if not hide_ui then
          Font.ftPrint(UI.FONT.LABEL, Round(center_label_x), center_label_y, 8, UI.SCR.X, 16, UI.MainMenu.opts[center_label_idx], UI.COLORS.TEXT_PRIMARY)
        end
        if not hide_ui then
          local select_label = "Hide UI"
          local labels, order = UI.Footer.ResolveLegend({
            order = UI.Footer.order_with_start_select,
            order_id = "start_select",
            circle = UI.Footer.labels.circle_main,
            cross = UI.Footer.labels.cross_select,
            select = select_label,
            start = UI.Footer.labels.start_profiles
          })
          UI.Footer.Draw(labels, order)
        end
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
            local slots = PLDR.GetMMCESlots()
            if #slots < 1 then
              UI.Notif_queue.add("No MMCE device found (mmce0/mmce1).")
              PLDR.CleanupGameList()
              PLDR.GAMEPATH = ""
              UI.SceneChange(UI.SCENES.GMMCE)
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
              UI.SceneChange(UI.SCENES.GMMCE)
            end
          elseif UI.MainMenu.OPT == 2 then
            UI.setDeviceLock(DEVLOCK.MX4SIO)
            UI.SceneChange(UI.SCENES.GMX4SIO)
          elseif UI.MainMenu.OPT == 3 then
            UI.Notif_queue.add("Not Implemented Yet")
          elseif UI.MainMenu.OPT == 4 then
            PLDR.LoadHDDModules()
            if UI.LASTSCENE == UI.SCENES.GHDD then
              LOG("skipping cache cleanup")
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
            if not UI.RefreshMassDevicePage("USB") then
              return
            end
            UI.setDeviceLock(DEVLOCK.USB)
            UI.SceneChange(UI.SCENES.GUSB)
          elseif UI.MainMenu.OPT == 6 then
            UI.Notif_queue.add("Not Implemented Yet")
          elseif UI.MainMenu.OPT == 7 then
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
        R2 = false,
        ANY = false,
      };
      NavHeld = {};
      NavNeutral = {UP = true, DOWN = true, LEFT = true, RIGHT = true};
      Queue = {};
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
        UI.Pad.Events.SQUARE = false
        UI.Pad.Events.START = false
        UI.Pad.Events.SELECT = false
        UI.Pad.Events.R2 = false
        UI.Pad.Events.ANY = false

        local function emit(event)
          table.insert(UI.Pad.Queue, event)
          UI.Pad.Events[event] = true
          UI.Pad.Events.ANY = true
        end

        local function emit_nav(event)
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
        if (pressed & PAD_SQUARE) ~= 0 then emit_action("SQUARE") end
        if (pressed & PAD_START) ~= 0 then emit("START") end
        if (pressed & PAD_SELECT) ~= 0 then emit("SELECT") end
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
        local hide_ui = false

        if not hide_ui then
          Font.ftPrintMultiLineAligned(LFONT, UI.SCR.X_MID, layout.TITLE_Y, 20, UI.SCR.X, 40, "POPSLoader\nfor POPStarter", currcol)
          Font.ftPrintMultiLineAligned(BFONT, UI.SCR.X_MID, layout.TITLE_Y + 60, 20, UI.SCR.X, 40, "Code by El_isra", currcol)
          Font.ftPrintMultiLineAligned(BFONT, UI.SCR.X_MID, layout.TITLE_Y + 80, 20, UI.SCR.X, UI.SCR.Y, [[
Design by Berion
Scripts by Nuno6573 and Ripto
Testing by P4NCHOL1NO
Based on Enceladus by Daniel Santos

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
  [UI.SCENES.GUSB] = true,
  [UI.SCENES.GMMCE] = true,
  [UI.SCENES.GMX4SIO] = true,
  [UI.SCENES.GHDD] = true,
  [UI.SCENES.GBDMHDD] = true
}
function UI.IsGameScene(scene)
  return UI.GAME_SCENES[scene] == true
end
function UI.IsUsbScene(scene)
  return scene == UI.SCENES.GUSB
end
function UI.IsMx4sioScene(scene)
  return scene == UI.SCENES.GMX4SIO
end

function UI.RefreshMassDevicePage(device_kind)
  if PLDR == nil then
    UI.Notif_queue.add("Mass routing helper unavailable")
    return false
  end

  if device_kind == "USB" and type(PLDR.RefreshMassSlots) == "function" then
    local state = PLDR.MASS_ENUM
    if type(state) == "table" and not state.usb_init_refresh_done then
      PLDR.RefreshMassSlots("usb-stack-init")
      state.usb_init_refresh_done = true
    end
  end

  PLDR.CleanupGameList()

  if device_kind == "MX4SIO" then
    local host_boot = type(APP_DIR) == "string" and string.match(string.lower(APP_DIR), "^host:") ~= nil
    if host_boot then
      if PLDR.MX4SIO ~= nil then
        PLDR.MX4SIO.READY = false
        PLDR.MX4SIO.MASSINDX = nil
        PLDR.MX4SIO.ROOT = nil
      end
      UI.Notif_queue.add("MX4SIO unavailable on host boot")
      return false
    end

    LOG("Initializing MX4SIO...")
    local hint = nil
    if PLDR.MX4SIO ~= nil then
      hint = PLDR.MX4SIO.PREFIX_HINT
    end
    local ok, ready, root = pcall(System.initMX4SIO, hint)
    if not ok or not ready or type(root) ~= "string" or root == "" then
      if PLDR.MX4SIO ~= nil then
        PLDR.MX4SIO.READY = false
        PLDR.MX4SIO.MASSINDX = nil
        PLDR.MX4SIO.ROOT = nil
      end
      UI.Notif_queue.add("MX4SIO init failed (searched mass0..mass9)")
      return false
    end

    if PLDR.MX4SIO ~= nil and PLDR.MX4SIO.READY and type(PLDR.MX4SIO.ROOT) == "string" and PLDR.MX4SIO.ROOT ~= "" then
      PLDR.GetPS1GameLists(PLDR.MX4SIO.ROOT.."POPS/", true)
      UI.GameList.Reset()
      return true
    end

    local boot_is_mx4sio = (PLDR ~= nil and PLDR.BOOT_DEVICE_KIND == "MX4SIO")
    local scene_is_mx4sio = UI.IsMx4sioScene(UI.CURSCENE)
    local enum_has_mx4sio = false
    if PLDR ~= nil and type(PLDR.HasClassifiedMassSlot) == "function" then
      enum_has_mx4sio = PLDR.HasClassifiedMassSlot("MX4SIO")
    end

    if not boot_is_mx4sio and not (scene_is_mx4sio and enum_has_mx4sio) then
      if PLDR.MX4SIO ~= nil then
        PLDR.MX4SIO.READY = false
        PLDR.MX4SIO.MASSINDX = nil
        PLDR.MX4SIO.ROOT = nil
      end
      UI.Notif_queue.add("MX4SIO not detected (searched mass0..mass9)")
      return false
    end

    local mass_idx = string.match(root, "^mass(%d+):/?$")
    if mass_idx ~= nil then
      mass_idx = tonumber(mass_idx)
    end

    if PLDR.MX4SIO ~= nil then
      PLDR.MX4SIO.READY = true
      PLDR.MX4SIO.MASSINDX = mass_idx
      PLDR.MX4SIO.ROOT = root
    end
    PLDR.GetPS1GameLists(root.."POPS/", true)
    UI.GameList.Reset()
    return true
  end

  if type(PLDR.EnumerateMassSlots) ~= "function" or type(PLDR.RouteMassSlotsForPage) ~= "function" then
    UI.Notif_queue.add("Mass routing helper unavailable")
    return false
  end

  local slots = nil
  if type(PLDR.GetMassSlotsCached) == "function" then
    slots = PLDR.GetMassSlotsCached() or {}
  else
    slots = PLDR.EnumerateMassSlots(9) or {}
  end
  local routed = PLDR.RouteMassSlotsForPage(device_kind, slots) or {}

  if routed[1] == nil then
    if device_kind ~= "MX4SIO" then
      if PLDR.USB ~= nil then
        PLDR.USB.MASSINDX = nil
        PLDR.USB.ROOT = "mass:/"
      end
      UI.Notif_queue.add("No USB slot routed for USB page")
    end
    return false
  end

  if PLDR.USB ~= nil then
    PLDR.USB.MASSINDX = routed[1].source_slot
    PLDR.USB.ROOT = routed[1].source_prefix
  end

  local found_any = false
  for i = 1, #routed do
    local source_prefix = routed[i] and routed[i].source_prefix
    if type(source_prefix) == "string" and source_prefix ~= "" then
      local list = PLDR.GetPS1GameLists(source_prefix.."POPS/", true)
      if type(list) == "table" and #list > 0 then
        found_any = true
      end
    end
  end

  if type(PLDR.DedupeAndSortMassGames) == "function" then
    PLDR.GAMES = PLDR.DedupeAndSortMassGames(PLDR.GAMES)
  end

  UI.GameList.Reset()
  return found_any or (#PLDR.GAMES > 0)
end

function UI.RefreshCurrentMassScene(scene)
  local current = scene or UI.CURSCENE
  if UI.IsMx4sioScene(current) then
    return UI.RefreshMassDevicePage("MX4SIO")
  end
  if UI.IsUsbScene(current) then
    return UI.RefreshMassDevicePage("USB")
  end
  return false
end
function UI.OnSceneEnter(previous_scene, next_scene)
  if UI.BOOT_SOUND ~= nil and UI.BOOT_SOUND.STATE ~= nil and UI.BOOT_SOUND.STATE.path_resolved ~= true then
    return
  end
  if UI.IsUsbScene(next_scene) then
    if PLDR ~= nil and type(PLDR.RefreshMassSlots) == "function" then
      PLDR.RefreshMassSlots("scene-enter-usb")
    end
    UI.RefreshCurrentMassScene(next_scene)
  elseif UI.IsMx4sioScene(next_scene) then
    if PLDR ~= nil and type(PLDR.RefreshMassSlots) == "function" then
      PLDR.RefreshMassSlots("scene-enter-mx4sio")
    end
    UI.RefreshCurrentMassScene(next_scene)
  end
end

function UI.OnSceneExit(previous_scene, next_scene)
  if UI.IsGameScene(previous_scene) and previous_scene ~= next_scene then
    if UI.CoverCache ~= nil and UI.CoverCache.Clear ~= nil then
      UI.CoverCache:Clear()
    end
  end
end
UI.RecalcLayout()
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
            LOG("ERROR: state change blocked while animationActive (OPT write)")
            LOG(GuardTrace())
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
          LOG("ERROR: scene change blocked outside transition midpoint")
          LOG(GuardTrace())
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
