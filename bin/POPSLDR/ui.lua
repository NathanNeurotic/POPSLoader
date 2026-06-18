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
local function IsDevicePath(path)
  return path ~= nil and string.match(path, "^[%a]+%d*:/") ~= nil
end
local function StripExtension(path)
  if path == nil then return nil end
  local stripped = string.match(path, "(.+)%.[^%.]+$")
  return stripped or path
end
local function BasenameWithoutExtension(path)
  if path == nil or path == "" then return "" end
  local basename = string.match(path, "([^/]+)$") or path
  local without_device = string.match(basename, "^[%a]+%d*:(.+)$")
  if without_device ~= nil and without_device ~= "" then
    basename = without_device
  end
  return StripExtension(basename) or basename
end
-- Strip a trailing POPS ".VCD" extension (any case) for game-list display,
-- and ONLY that extension. The previous code blanket-chopped the last 4
-- characters of every entry, which silently truncated titles that did NOT
-- end in .VCD (e.g. "Bomberman" -> "Bombe"). A generic last-extension strip
-- can't be used either: it would eat the tail of titles containing a dot
-- ("Mr. Driller" -> "Mr"). So match .VCD specifically.
-- Faded palette for hidden games shown in the "manage" view (Global Hide off).
-- The existing GREY renders brighter than LIST_UNSELECTED; these read as dimmer.
local LIST_HIDDEN_COLOR = Color.new(92, 94, 120, 70)
local LIST_HIDDEN_SELECTED_COLOR = Color.new(150, 152, 182, 110)
local function StripVcdExtension(name)
  local s = tostring(name or "")
  return (string.gsub(s, "%.[Vv][Cc][Dd]$", ""))
end

-- Horizontal marquee for the selected, overflowing game-list row. There is
-- no scissor/clip API for a pixel-smooth scroll, so this steps by whole
-- characters within the fixed column using the Font.ftWidth measurement
-- (C fntCalcDimensions binding). Continuous via a "label .. gap .. label"
-- scroll buffer; cosmetic; resets when the selection changes.
local MARQUEE_HOLD_FRAMES = 36   -- pause showing the head before scrolling
local MARQUEE_STEP_FRAMES = 6    -- frames per one-character advance
local function FitFromLeft(font, text, max_w)
  local s = tostring(text or "")
  -- Trim from the right until the run fits the column. ftWidth is exact for
  -- the proportional font; only runs for the single focused row.
  while #s > 0 and Font.ftWidth(font, s) > max_w do
    s = string.sub(s, 1, -2)
  end
  return s
end
local function MarqueeLabel(font, label, max_w, tick)
  if type(Font.ftWidth) ~= "function" then return label end
  if Font.ftWidth(font, label) <= max_w then
    return label
  end
  local sep = "    "
  local scroll = label..sep..label
  local cycle = string.len(label) + string.len(sep)
  local start_char = 1
  if tick > MARQUEE_HOLD_FRAMES then
    start_char = (math.floor((tick - MARQUEE_HOLD_FRAMES) / MARQUEE_STEP_FRAMES) % cycle) + 1
  end
  return FitFromLeft(font, string.sub(scroll, start_char), max_w)
end
local function ResolveSelectedVcdPath(entry, game_path)
  if entry == nil or entry == "" then
    return nil
  end

  local root, rel = string.match(entry, "^([^|]+)|(.+)$")
  if root ~= nil and rel ~= nil then
    if IsDevicePath(root) then
      if type(JoinPath) == "function" then
        return JoinPath(root, rel)
      end
      if string.sub(root, -1) == "/" then
        return root..rel
      end
      return root.."/"..rel
    end
    if IsDevicePath(rel) then
      return rel
    end
    if IsDevicePath(game_path) then
      if type(JoinPath) == "function" then
        return JoinPath(game_path, rel)
      end
      if string.sub(game_path, -1) == "/" then
        return game_path..rel
      end
      return game_path.."/"..rel
    end
    return rel
  end

  if IsDevicePath(entry) then
    return entry
  end
  if IsDevicePath(game_path) then
    if type(JoinPath) == "function" then
      return JoinPath(game_path, entry)
    end
    if string.sub(game_path, -1) == "/" then
      return game_path..entry
    end
    return game_path.."/"..entry
  end
  return entry
end
local function ExtractHddArtBasename(entry)
  local candidate = tostring(entry or "")
  if candidate == "" then
    return ""
  end
  local relpath = string.match(candidate, "^[^|]+|(.+)$")
  if relpath ~= nil and relpath ~= "" then
    candidate = relpath
  end
  return BasenameWithoutExtension(candidate)
end
local function BuildCoverCandidates(vcd_path, use_hdd_common_art, entry)
  if use_hdd_common_art then
    local basename = ExtractHddArtBasename(entry)
    if basename == "" then
      basename = BasenameWithoutExtension(vcd_path)
    end
    if basename == "" then
      return {}
    end
    if type(PLDR) == "table" and type(PLDR.ResolveHddPartitionReadablePath) == "function" then
      local resolved = PLDR.ResolveHddPartitionReadablePath("hdd0:__common", "POPS/ART/"..basename..".png")
      if resolved ~= nil then
        return { resolved }
      end
      return {}
    end
    return {}
  end
  if vcd_path == nil or vcd_path == "" then
    return {}
  end
  local base = StripExtension(vcd_path)
  return {
    base..".png"
  }
end
-- Read a game's "<name>.txt" details sidecar. Bounded so a stray huge file can't
-- stall the snappy cover-load path it rides on.
local function ReadGameDetailsText(path)
  if path == nil or path == "" then return nil end
  if type(System) ~= "table" or type(System.openFile) ~= "function" then return nil end
  local ok_open, fd = pcall(System.openFile, path, FREAD)
  if not ok_open or type(fd) ~= "number" or fd < 0 then return nil end
  local data = nil
  -- pcall the size/read/close (not just open): a valid-but-unreadable fd can
  -- throw, and this runs inside the un-pcall'd game-list render frame -- degrade
  -- to "no details" instead of erroring the whole frame (matches system.lua).
  local ok_sz, size = pcall(System.sizeFile, fd)
  if ok_sz and type(size) == "number" and size > 0 then
    if size > 8192 then size = 8192 end
    local ok_rd, rd = pcall(System.readFile, fd, size)
    if ok_rd then data = rd end
  end
  pcall(System.closeFile, fd)
  if type(data) == "string" and data ~= "" then return data end
  return nil
end
-- Word-wrap a details blurb into an ARRAY of lines, PRESERVING the source's own
-- line breaks: split on newlines first, then greedily wrap each line to max_chars;
-- a blank source line stays a blank line (paragraph spacing). Returns ALL lines
-- (no clipping) -- the list view windows/scrolls this. A trailing newline in the
-- .txt is stripped so it doesn't reserve a phantom blank line at the end.
local function WrapGameDetailsLines(text, max_chars)
  local out = {}
  if type(text) ~= "string" then return out end
  text = string.gsub(text, "%s+$", "")
  if text == "" then return out end
  max_chars = tonumber(max_chars) or 30
  if max_chars < 8 then max_chars = 8 end
  -- Iterate source line-by-line (strip a trailing CR); the appended "\n" makes
  -- gmatch yield the final line too. Authored line breaks survive this way.
  for src in string.gmatch(text .. "\n", "([^\n]*)\n") do
    src = string.gsub(src, "\r$", "")
    if string.match(src, "%S") == nil then
      out[#out + 1] = ""
    else
      local cur = ""
      for word in string.gmatch(src, "%S+") do
        if cur == "" then
          cur = word
        elseif (#cur + 1 + #word) <= max_chars then
          cur = cur .. " " .. word
        else
          out[#out + 1] = cur
          cur = word
        end
      end
      if cur ~= "" then out[#out + 1] = cur end
    end
  end
  return out
end
local CoverCache = {
  max = 3,
  entries = {},
  order = {},
  failed = {},
  last_key = nil,
  last_img = nil,
  last_desc = nil,
  desc_scroll = 0
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
  self.last_desc = nil
  self.desc_scroll = 0
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
function CoverCache:UpdateSelection(vcd_path, use_hdd_common_art, entry)
  local key_source = vcd_path
  if use_hdd_common_art == true then
    key_source = entry or vcd_path
  end
  local key = tostring(use_hdd_common_art == true).."|"..tostring(key_source or "")
  if self.last_key == key then
    return self.last_img
  end
  self.last_key = key
  self.last_img = nil
  self.last_desc = nil
  self.desc_scroll = 0  -- new selection -> start its description at the top
  if (use_hdd_common_art ~= true) and (vcd_path == nil or vcd_path == "") then
    return nil
  end
  local candidates = BuildCoverCandidates(vcd_path, use_hdd_common_art == true, entry)
  -- Game details: read "<cover-base>.txt" next to the cover art, but only when the
  -- feature is on (otherwise this read is skipped so navigation stays snappy).
  -- Stored raw; the list view word-wraps it under the cover.
  if type(PLDR) == "table" and PLDR.SHOW_DETAILS == true and candidates[1] ~= nil then
    local desc_path = string.gsub(candidates[1], "%.png$", ".txt")
    if desc_path ~= candidates[1] then
      self.last_desc = ReadGameDetailsText(desc_path)
    end
  end
  for i = 1, #candidates do
    local img = self:GetOrLoad(candidates[i])
    if img ~= nil then
      self.last_img = img
      return img
    end
  end
  return nil
end

local VIDEO_STANDARD_AUTO = (type(PLDR) == "table" and PLDR.VIDEO_STANDARD_AUTO) or "AUTO"
local VIDEO_STANDARD_NTSC = (type(PLDR) == "table" and PLDR.VIDEO_STANDARD_NTSC) or "NTSC"
local VIDEO_STANDARD_PAL = (type(PLDR) == "table" and PLDR.VIDEO_STANDARD_PAL) or "PAL"
local CONSOLE_REGION_MODE = (type(PLDR) == "table" and PLDR.CONSOLE_REGION_MODE) or NTSC
-- Force the FIRST video apply (at boot) to re-issue Screen.setMode even when UI.SCR
-- already matches the request, so gsKit (re)centers the raster. Without it the boot
-- image sat top-aligned with a bottom bar on PAL until the user re-picked a mode.
local VIDEO_BOOT_APPLIED = false

local function ResolveVideoSpecForKey(key)
  if type(PLDR) == "table" and type(PLDR.GetVideoStandardSpec) == "function" then
    return PLDR.GetVideoStandardSpec(key)
  end
  if tostring(key or "") == VIDEO_STANDARD_PAL then
    -- PAL-native 512 so the UI fills the PAL screen (matches BuildVideoStandardSpec).
    return { key = VIDEO_STANDARD_PAL, mode = PAL, width = 640, height = 512, fps = 50 }
  end
  return { key = VIDEO_STANDARD_NTSC, mode = NTSC, width = 640, height = 448, fps = 60 }
end

local function WrapText(text, limit)
  limit = tonumber(limit) or 38
  if limit < 4 then limit = 4 end

  local function push_wrapped_token(out, token)
    token = tostring(token or "")
    while #token > limit do
      table.insert(out, string.sub(token, 1, limit))
      token = string.sub(token, limit + 1)
    end
    if token ~= "" then
      table.insert(out, token)
    end
  end

  local function wrap_paragraph(paragraph, out)
    paragraph = tostring(paragraph or "")
    if paragraph == "" then
      table.insert(out, "")
      return
    end

    local current_line = ""
    for word in paragraph:gmatch("%S+") do
      if #word > limit then
        if current_line ~= "" then
          table.insert(out, current_line)
          current_line = ""
        end
        push_wrapped_token(out, word)
      elseif current_line == "" then
        current_line = word
      elseif #current_line + 1 + #word <= limit then
        current_line = current_line .. " " .. word
      else
        table.insert(out, current_line)
        current_line = word
      end
    end

    if current_line ~= "" then
      table.insert(out, current_line)
    end
  end

  local wrapped = {}
  text = tostring(text or "")
  local start = 1
  while true do
    local pos = string.find(text, "\n", start, true)
    if not pos then
      wrap_paragraph(string.sub(text, start), wrapped)
      break
    end
    wrap_paragraph(string.sub(text, start, pos - 1), wrapped)
    start = pos + 1
  end

  return wrapped
end

local INITIAL_VIDEO_SPEC = ResolveVideoSpecForKey((type(PLDR) == "table" and PLDR.VIDEO_STANDARD) or VIDEO_STANDARD_AUTO)
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
    boot_device = DEVLOCK.NONE;
    boot_device_label = nil;
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
    CoverPreviewEnabled = true;
    device_lock_name = function (lock)
      if lock == DEVLOCK.USB then return "USB" end
      if lock == DEVLOCK.MMCE then return "MMCE" end
      if lock == DEVLOCK.MX4SIO then return "MX4SIO" end
      return "None"
    end;
    IsHideToggleScene = function (scene)
      return scene == UI.SCENES.MMAIN
        or scene == UI.SCENES.GUSBFAT
        or scene == UI.SCENES.GSMB
        or scene == UI.SCENES.GMX4SIO
        or scene == UI.SCENES.GHDD
        or scene == UI.SCENES.GBDMHDD
    end;
    ShouldHideAuxText = function (scene)
      return UI.HideTextMode and UI.IsHideToggleScene(scene or UI.CURSCENE)
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
    -- Force the game-list cover preview to (re)load for the focused game whenever a
    -- scene is entered (called from the transition apply once CURSCENE flips). The
    -- per-frame cover load only fires on a selection CHANGE (CURR ~= CoverLastIndex),
    -- so re-entering a list where the entry selection equals the last-loaded index
    -- (commonly index 1) otherwise never loaded the first game's art until you
    -- scrolled away and back. Clearing the trigger here makes the current selection's
    -- cover load on every entry. Touches only the cover-trigger state (not CURR), and
    -- is inert outside game lists since only GameList.Play reads it.
    OnSceneEnter = function (prev_scene, scene)
      if type(UI.GameList) == "table" then
        UI.GameList.CoverLastIndex = nil
        UI.GameList.CoverPending = false
        UI.GameList.CoverPendingAt = 0
        -- Entering a device game-list from a non-list scene (carousel/menu): open at
        -- the top instead of inheriting the previously-viewed device's (clamped)
        -- cursor -- UI.GameList.CURR is a single global index shared across pages.
        -- Gated to carousel->list entry, so R1 in-place rescan and the -page /
        -- Boot-Page auto-enter (which set CURR deliberately, or want the top anyway)
        -- are untouched. UI.IsGameScene(nil) is false, so a first/unknown prev is fine.
        if UI.IsGameScene(scene) and not UI.IsGameScene(prev_scene) then
          UI.GameList.CURR = 1
          UI.GameList.STARTUP = 1
        end
      end
    end;
    --- Color Constants
    CCOL = {
      GREY = Color.new(128,128,128,128);
      YELLOW = Color.new(80, 170, 255, 128);
      RED = Color.new(128,0,0);
      TRANSP_BLACK = Color.new(0,0,0,40);
      MODAL_BACKDROP = Color.new(0,0,0,48);
      LOADING_BACKDROP = Color.new(0,0,0,64);
    };
    COLORS = {
	      TEXT_PRIMARY = Color.new(140, 200, 255, 128);
	      -- Softer indigo list palette to match the current concept art.
	      LIST_SELECTED = Color.new(188, 192, 232, 128);
	      LIST_UNSELECTED = Color.new(62, 66, 166, 128);
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
	      X = tonumber(INITIAL_VIDEO_SPEC.width) or 640;
	      X_MID = (tonumber(INITIAL_VIDEO_SPEC.width) or 640) / 2;
	      Y = tonumber(INITIAL_VIDEO_SPEC.height) or 448;
	      Y_MID = (tonumber(INITIAL_VIDEO_SPEC.height) or 448) / 2;
	      VMODE = INITIAL_VIDEO_SPEC.mode or NTSC;
	      BGCOL = Color.new(20, 30, 80);
	    };
    LAYOUT = {
      SAFE = {L = 40, R = 40, T = 24, B = 28};
      BTN_BAR_SAFE_BOTTOM = 56;
      ICON_SPACING = 120;
      LIST_ROW_H = 20;
      PREVIEW_W = 256;
      PREVIEW_H = 256;
      COVER_W = 232;
      COVER_H = 232;
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
      local preview_w = 256
      local preview_h = 256
      UI.LAYOUT.PREVIEW_W = preview_w
      UI.LAYOUT.PREVIEW_H = preview_h
      UI.LAYOUT.COVER_W = 232
      UI.LAYOUT.COVER_H = 232
      UI.LAYOUT.PREVIEW_X = Round(UI.SCR.X - safe.R - preview_w)
      UI.LAYOUT.PREVIEW_Y = Round(UI.SCR.Y_MID - (preview_h / 2))
      UI.LAYOUT.FOOTER_ICON_Y = Round(UI.SCR.Y - UI.LAYOUT.BTN_BAR_SAFE_BOTTOM)
      UI.LAYOUT.FOOTER_LABEL_Y = Round(UI.LAYOUT.FOOTER_ICON_Y + UI.LAYOUT.FOOTER_LABEL_Y_OFFSET)
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
	    VideoStandardModes = {
	      {
	        key = VIDEO_STANDARD_AUTO,
	        label = "Auto (console region)",
	        fps = (CONSOLE_REGION_MODE == PAL) and 50 or 60,
	        mode = CONSOLE_REGION_MODE,
	        width = 640,
	        height = (CONSOLE_REGION_MODE == PAL) and 512 or 448
	      },
	      {
	        key = VIDEO_STANDARD_NTSC,
	        label = "NTSC (60Hz, 480i/240p)",
	        fps = 60,
	        mode = NTSC,
	        width = 640,
	        height = 448
	      },
	      {
	        key = VIDEO_STANDARD_PAL,
	        label = "PAL (50Hz, 576i/288p)",
	        fps = 50,
	        mode = PAL,
	        width = 640,
	        height = 512
	      }
	    };
	    BdmaModeIndex = 1;
	    VideoStandardIndex = 1;
	    BdmaDirty = false;
	    VideoStandardDirty = false;
	    ProfileDirty = false;
	    PopPathDirty = false;
	    PopPathProfileDefaultDirty = false;
	    DkwdrvDirty = false;
    PopstarterPathDraft = nil;
    DkwdrvPathDraft = nil;
    KeyboardLayoutDraft = nil;
    HideTextMode = false;
    SettingsReturnScene = nil;
    SettingsEntryHideTextMode = false;
    SettingsEntryKeyboardLayout = nil;
    SettingsFocus = 1;
    SavingActive = false;
    SavingMessage = "Saving...";
    SavingAnimTick = 0;
    SavingProgress = nil;
    SetHideTextMode = function (enabled, notify)
      local next_state = (enabled == true)
      UI.HideTextMode = next_state
      if notify == true then
        if next_state then
          UI.Notif_queue.add("UI text hidden", "ok")
        else
          UI.Notif_queue.add("UI text shown", "ok")
        end
      end
      return next_state
    end;
    ToggleHideTextMode = function (notify)
      return UI.SetHideTextMode(not UI.HideTextMode, notify)
    end;
    GetSettingsReturnScene = function ()
      local scene = UI.SettingsReturnScene or UI.LASTSCENE or UI.SCENES.MMAIN
      if scene == nil or scene == UI.SCENES.MPROFILE then
        scene = UI.SCENES.MMAIN
      end
      return scene
    end;
    ShowSavingOverlay = function (msg, progress)
      UI.SavingMessage = tostring(msg or "Saving...")
      UI.SavingActive = true
      UI.SavingAnimTick = (tonumber(UI.SavingAnimTick) or 0) + 1
      if type(progress) == "number" then
        UI.SavingProgress = Clamp(progress, 0, 1)
      else
        UI.SavingProgress = nil
      end
      UI.flip()
    end;
    HideSavingOverlay = function ()
      UI.SavingActive = false
      UI.SavingMessage = "Saving..."
      UI.SavingProgress = nil
    end;
    RunBusyTask = function (initial_message, worker, failure_message)
      UI.ShowSavingOverlay(initial_message or "Working...", 0.05)
      local function report(message, progress)
        UI.ShowSavingOverlay(message or initial_message or "Working...", progress)
      end
      local ok, a, b, c, d = pcall(worker, report)
      UI.HideSavingOverlay()
      if not ok then
        -- DIAGNOSTIC: surface the SWALLOWED worker error (`a`). Without it,
        -- "Failed to load HDD" et al. show no cause -- exactly why provato/Nuno's
        -- real HDD failure was invisible (the thrown error, with its file:line,
        -- was captured here and discarded). Truncate so the toast stays readable.
        local err_detail = tostring(a)
        if #err_detail > 160 then err_detail = string.sub(err_detail, 1, 160).."..." end
        UI.Notif_queue.add(tostring(failure_message or "Operation failed").."\n"..err_detail, "error")
        return false, a
      end
      return true, a, b, c, d
    end;
	    MakeBusyProgressReporter = function (report, message, start_progress, end_progress)
	      local label = tostring(message or "Working...")
	      local progress_a = tonumber(start_progress) or 0
	      local progress_b = tonumber(end_progress) or progress_a
	      local last_ratio = -1
      local last_ms = -1000
      local function now_ms()
        if UI.Pad ~= nil and UI.Pad.Timer ~= nil then
          return tonumber(Timer.getTime(UI.Pad.Timer)) or 0
        end
        return 0
      end
	      return function (ratio)
	        local next_ratio = Clamp(tonumber(ratio) or 0, 0, 1)
	        local next_progress = progress_a + ((progress_b - progress_a) * next_ratio)
	        local current_ms = now_ms()
	        if next_ratio < 1 then
	          local ratio_delta = next_ratio - last_ratio
	          if current_ms > 0 and last_ms >= 0 then
	            if ratio_delta < 0.0025 and (current_ms - last_ms) < 20 then
	              return
	            end
	          elseif last_ratio >= 0 and ratio_delta < 0.0025 then
	            return
	          end
	        end
	        last_ratio = next_ratio
        last_ms = current_ms
        -- Report only the OVERALL progress (the overlay draws one %+bar from it).
        -- The label deliberately carries NO per-phase % -- showing both the phase
        -- count and the overall bar was two different numbers at once (#498).
        report(label, next_progress)
      end
    end;
    --- Notifications queue handler
    --- Content-sized toast: wraps long text and long path-like tokens, separates head/body, supports
    --- severity ("info" / "warn" / "error" / "ok") and stacks up to MAX toasts.
    --- Backward compatible: existing UI.Notif_queue.add(string) call sites still work.
    Notif_queue = {
      msg   = {};
      MAX   = 2;
      LIMIT = 60;   -- chars per wrapped line at BFONT inside the safe area
      LINE  = 18;
      PADX  = 10;
      PADY  = 8;
      GAP   = 4;    -- vertical gap between stacked toasts
      ALFA  = 0x80; -- legacy field, kept for any external readers
      display = function ()
        local q = UI.Notif_queue
        if #q.msg < 1 then return end
        local safe   = UI.LAYOUT.SAFE
        local box_x  = safe.L
        local box_w  = UI.SCR.X - safe.L - safe.R
        local y      = safe.T
        local function sev_color(sev, a)
          if sev == "error" then return Color.new(255, 130, 130, a) end
          if sev == "warn"  then return Color.new(255, 200,  90, a) end
          if sev == "ok"    then return Color.new(120, 230, 170, a) end
          return Color.new(140, 200, 255, a) -- info / default
        end
        for i = 1, #q.msg do
          local t = q.msg[i]
          local alfa = math.floor(t.alfa or 0x90)
          if alfa < 1 then alfa = 1 end
          local head_lines = WrapText(t.head or "", q.LIMIT)
          local body_lines = WrapText(t.body or "", q.LIMIT)
          local total = #head_lines + #body_lines
          if total < 1 then total = 1 end
          local box_h = (total * q.LINE) + (q.PADY * 2)
          Graphics.drawRect(box_x, y, box_w, box_h, Color.new(0, 0, 0, math.min(alfa, 0xA0)))
          Graphics.drawRect(box_x, y, 2,     box_h, sev_color(t.sev, alfa))
          local ty = y + q.PADY
          for hi = 1, #head_lines do
            Font.ftPrint(BFONT, box_x + q.PADX, ty, 0, box_w - q.PADX*2, q.LINE,
                         head_lines[hi], sev_color(t.sev, alfa))
            ty = ty + q.LINE
          end
          for bi = 1, #body_lines do
            Font.ftPrint(BFONT, box_x + q.PADX, ty, 0, box_w - q.PADX*2, q.LINE,
                         body_lines[bi], Color.new(180, 200, 230, alfa))
            ty = ty + q.LINE
          end
          t.alfa = (t.alfa or 0x90) - ((#q.msg > 1) and 1.4 or 0.8)
          y = y + box_h + q.GAP
        end
        local n = 1
        while n <= #q.msg do
          if (q.msg[n].alfa or 0) < 1 then table.remove(q.msg, n) else n = n + 1 end
        end
      end;
      add = function (notif, sev)
        local q = UI.Notif_queue
        local text = tostring(notif or "")
        local head, body
        local nl = string.find(text, "\n", 1, true)
        if nl then
          head = string.sub(text, 1, nl - 1)
          body = string.sub(text, nl + 1)
        else
          head = text
          body = ""
        end
        table.insert(q.msg, { head = head, body = body, sev = sev or "info", alfa = 0xC8 })
        while #q.msg > q.MAX do table.remove(q.msg, 1) end
      end;
    };
    Notify = function (msg, _ms, sev)
      UI.Notif_queue.add(msg, sev)
    end;
    Footer = {
      order = {"triangle", "circle", "cross", "square"};
      order_with_r2 = {"triangle", "circle", "cross", "square"};
	      order_with_start = {"triangle", "circle", "cross", "start"};
	      order_with_start_r2 = {"triangle", "circle", "cross", "square", "start"};
	      order_settings = {"circle", "cross", "square", "start", "select"};
	      order_settings_save = {"circle", "cross", "start", "select"};
	      order_keyboard = {"circle", "cross", "square", "start"};
	      labels = {
	        triangle = "Credits",
	        circle_main = "Exit",
	        circle_other = "Back",
	        start_profiles = "Settings",
	        start_reset = "Reset Defaults",
	        select_toggle = "Toggle UI",
	        square_backspace = "Backspace",
	        cross_confirm = "Confirm",
	        cross_enter = "Enter",
	        cross_select = "Select",
	        cross_launch = "Launch"
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
          start = start_label,
          select = select_label
        }
        if square_label ~= nil then
          labels.square = square_label
        end
        UI.Footer.legend_cache[key] = {labels = labels, order = order}
        return labels, order
      end;
      Draw = function (labels, order)
        if UI.ShouldHideAuxText(UI.CURSCENE) then
          return
        end
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
      if UI.SavingActive then
        Screen.clear(UI.SCR.BGCOL or Color.new(20, 30, 80))
        if type(IMG) == "table" and type(Graphics) == "table" and type(Graphics.drawScaleImage) == "function" then
          local cached_bg = rawget(IMG, "BG") or rawget(IMG, "BGM") or rawget(IMG, "BKG")
          if cached_bg ~= nil then
            pcall(Graphics.drawScaleImage, cached_bg, 0, 0, UI.SCR.X, UI.SCR.Y)
          end
        end
      end
      UI.Notif_queue.display()
      UI.Modal.Draw()
      if UI.SavingActive then
        local tick = math.floor((tonumber(UI.SavingAnimTick) or 0))
        local tick_ms = tick * 200
        if UI.Pad ~= nil and UI.Pad.Timer ~= nil then
          tick_ms = math.floor(Timer.getTime(UI.Pad.Timer))
          tick = math.floor(tick_ms / 200)
        end
        local dots = {"", ".", "..", "..."}
        local spinners = {"|", "/", "-", "\\"}
        local dot_suffix = dots[(tick % #dots) + 1]
        local spinner = spinners[(tick % #spinners) + 1]
        local box_w = 320
        local box_h = 110
        local box_x = UI.SCR.X_MID - (box_w / 2)
        local box_y = UI.SCR.Y_MID - (box_h / 2)
        local bar_x = box_x + 20
        local bar_y = box_y + 64
        local bar_w = box_w - 40
        local bar_h = 14
        Graphics.drawRect(0, 0, UI.SCR.X, UI.SCR.Y, UI.CCOL.LOADING_BACKDROP or Color.new(0, 0, 0, 64))
        Graphics.drawRect(box_x, box_y, box_w, box_h, Color.new(0, 0, 0, 210))
	        Graphics.drawRect(box_x, box_y, box_w, 2, UI.CCOL.GREY)
	        Graphics.drawRect(box_x, box_y + box_h - 2, box_w, 2, UI.CCOL.GREY)
	        Graphics.drawRect(bar_x, bar_y, bar_w, bar_h, Color.new(24, 34, 68, 128))
	        Graphics.drawRect(bar_x + 1, bar_y + 1, bar_w - 2, bar_h - 2, Color.new(10, 14, 26, 128))
	        local pulse_w = math.max(12, math.floor((bar_w - 4) * 0.08))
	        local pulse_travel = math.max(0, (bar_w - 4) - pulse_w)
	        local pulse_offset = 0
	        if pulse_travel > 0 then
	          pulse_offset = math.floor((tick_ms / 60) % (pulse_travel + 1))
	        end
	        Graphics.drawRect(bar_x + 2 + pulse_offset, bar_y + 3, pulse_w, bar_h - 6, Color.new(120, 190, 255, 36))
	        if type(UI.SavingProgress) == "number" then
	          local fill_w = math.floor((bar_w - 4) * UI.SavingProgress + 0.5)
	          if fill_w > 0 then
	            Graphics.drawRect(bar_x + 2, bar_y + 2, fill_w, bar_h - 4, Color.new(110, 190, 255, 120))
	            local shimmer_w = math.max(14, math.floor((bar_w - 4) * 0.12))
	            local shimmer_travel = math.max(0, fill_w - shimmer_w)
	            local shimmer_offset = 0
	            if shimmer_travel > 0 then
	              shimmer_offset = math.floor((tick_ms / 45) % (shimmer_travel + 1))
	            end
	            Graphics.drawRect(bar_x + 2 + shimmer_offset, bar_y + 2, math.min(shimmer_w, fill_w), bar_h - 4, Color.new(210, 235, 255, 48))
	          end
	        else
          local marquee_w = math.max(42, math.floor((bar_w - 4) * 0.26))
          local travel = math.max(0, (bar_w - 4) - marquee_w)
          local offset = 0
          if travel > 0 then
            offset = math.floor((tick_ms / 80) % (travel + 1))
          end
          Graphics.drawRect(bar_x + 2 + offset, bar_y + 2, marquee_w, bar_h - 4, Color.new(110, 190, 255, 96))
        end
        Font.ftPrint(BFONT, UI.SCR.X_MID, box_y + 20, 8, UI.SCR.X, 16, tostring(UI.SavingMessage or "Saving/Applying...")..dot_suffix, UI.CCOL.YELLOW)
        if type(UI.SavingProgress) == "number" then
          Font.ftPrint(SFONT, UI.SCR.X_MID, box_y + 84, 8, UI.SCR.X, 16, tostring(math.floor(UI.SavingProgress * 100 + 0.5)).."%  "..spinner, UI.CCOL.GREY)
        else
          Font.ftPrint(SFONT, UI.SCR.X_MID, box_y + 84, 8, UI.SCR.X, 16, "Working "..spinner, UI.CCOL.GREY)
        end
      end
      if UI.Transition ~= nil then
        local alpha = UI.Transition.Update()
        if alpha > 0 then
          local overlay = UI.Transition.GetOverlayImage()
          if overlay ~= nil then
            Graphics.drawScaleImage(overlay, 0, 0, UI.SCR.X, UI.SCR.Y, Color.new(128, 128, 128, alpha))
          else
            Graphics.drawRect(0, 0, UI.SCR.X, UI.SCR.Y, Color.new(0, 0, 0, alpha))
          end
        end
      end
      Screen.flip()
    end;
    WelcomeDraw = {
      Play = function (next_scene, show_boot_credits, boot_init_fn)
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
        local FPS = UI.GetDisplayRefreshHz()
        local SPLASH_HOLD_FRAMES = math.floor(4.0 * FPS + 0.5)
        local CREDITS_HOLD_FRAMES = math.floor(4.0 * FPS + 0.5)
        local INTRO_FADE_SCALE = 2.0
        local INTRO_FADE_IN_MS = math.floor(FADE_IN_MS * INTRO_FADE_SCALE + 0.5)
        local INTRO_FADE_OUT_MS = math.floor(FADE_OUT_MS * INTRO_FADE_SCALE + 0.5)

        StepFade(DrawSplash, 128, 0, INTRO_FADE_IN_MS)
        -- Run the heavy boot init (settings load + device bring-up + boot-page
        -- selection) HERE, with the splash already painted: the synchronous work
        -- freezes on THIS splash frame instead of behind a black screen, so the
        -- splash COVERS what used to be the boot black-out (the device settle
        -- retries, the #494 USB sidecar wait, etc.). The hold/credits/menu below
        -- then resume and read the now-ready state. (boot_init_fn never returns on
        -- a -game auto-launch -- the splash just showed briefly before the launch.)
        if type(boot_init_fn) == "function" then boot_init_fn() end
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
          local configured_path = tostring((PLDR and PLDR.DKWDRV_PATH) or "mc0:/PS1_DKWDRV/DKWDRV.ELF")
          local elf_path = configured_path
          -- For a custom HDD path, resolve through POPSTARTER's slot-tolerant
          -- HDD resolver FIRST. POPSLoader mounts the user partition on
          -- whatever pfs slot is free (commonly pfs1:), so a config that names
          -- a specific slot -- or omits/mismatches it -- must be remapped to
          -- the LIVE mount. ResolveHddReadablePath resolves an HDD path by
          -- partition NAME + relpath to the actual mounted, readable pfsN:/..
          -- path (and records the mount), so any slot (or slot-less) custom
          -- HDD DKWDRV path works, exactly like POPSTARTER custom HDD paths.
          -- (Previously HDD DKWDRV had to be pfs1: -- Nuno 2026-06-04.)
          -- Non-HDD paths (mc0:/, mass:/, mmce:/ ...) keep the existing
          -- first-existing-candidate resolution below.
          local lower_cfg = string.lower(configured_path)
          local cfg_is_hdd = string.find(lower_cfg, "^hdd%d:") ~= nil
            or string.find(lower_cfg, "^pfs%d*:/") ~= nil
            or string.find(lower_cfg, "^ata%d*:") ~= nil
            or string.find(lower_cfg, "^apa%d*:") ~= nil
          if cfg_is_hdd and type(PLDR) == "table" and type(PLDR.ResolveHddReadablePath) == "function" then
            local ok, resolved = pcall(PLDR.ResolveHddReadablePath, configured_path)
            if ok and type(resolved) == "string" and resolved ~= "" then
              elf_path = resolved
            end
          end
          if (elf_path == nil or elf_path == configured_path)
            and type(PLDR) == "table" and type(PLDR.ResolveFirstExistingPath) == "function" then
            local fallback = PLDR.ResolveFirstExistingPath(configured_path)
            if fallback ~= nil then
              elf_path = fallback
            end
          end
          -- Live-pfs-slot scan fallback. The partition may already be mounted
          -- on a pfs slot (e.g. you browsed to DKWDRV.ELF, which mounts the
          -- partition on pfs1: and holds it). Name-based resolution above then
          -- can't reuse that mount -- a fresh mount of the same partition
          -- collides (pfs won't double-mount), so only a path whose slot hint
          -- already matches the live mount resolves. That is why a custom HDD
          -- path previously had to say pfs1: (Nuno 2026-06-04). Here we instead
          -- probe the live pfs slots for the file's relpath DIRECTLY (read-only,
          -- no mounting) and use whichever slot actually has it. This makes any
          -- slot, or a slot-less path, resolve to the live mount. The resulting
          -- pfsN:/.. path flows through the same confirmed case-(2) launch.
          if cfg_is_hdd and (elf_path == nil or not SafeDoesFileExist(elf_path))
            and type(PLDR) == "table" and type(PLDR.ParseHddExecMountAndRelpath) == "function" then
            local ok, _part, relpath = pcall(PLDR.ParseHddExecMountAndRelpath, configured_path)
            if ok and type(relpath) == "string" and relpath ~= "" then
              for slot = 0, 3 do
                local probe = "pfs"..tostring(slot)..":/"..relpath
                if SafeDoesFileExist(probe) then
                  elf_path = probe
                  break
                end
              end
            end
          end
          if elf_path == nil or not SafeDoesFileExist(elf_path) then
            UI.Modal.Close()
            UI.Notif_queue.add("No DKWDRV found at this path\n"..configured_path, "error")
            return
          end
          UI.LAUNCHING = true
          UI.Modal.Close()
          local previous_cwd = nil
          if type(PLDR) == "table" and type(PLDR.SetLaunchWorkingDirectory) == "function" then
            previous_cwd = PLDR.SetLaunchWorkingDirectory(elf_path)
          end
          -- Where DKWDRV.ELF itself lives (memory card vs HDD partition).
          local lower_elf = string.lower(tostring(elf_path or ""))
          local is_hdd_path = string.find(lower_elf, "^hdd%d:") ~= nil
            or string.find(lower_elf, "^pfs%d*:/") ~= nil
            or string.find(lower_elf, "^ata%d*:") ~= nil
            or string.find(lower_elf, "^apa%d*:") ~= nil
          -- Whether POPSLoader ITSELF was booted from HDD this session
          -- (independent of where DKWDRV.ELF lives).
          local hdd_loaded = type(PLDR) == "table" and type(PLDR.HDD) == "table"
            and tonumber(PLDR.HDD.LOADSTATE or 0) ~= 0
          --
          -- Launch routing. Three cases:
          --
          --  (1) MC / non-HDD DKWDRV, POPSLoader booted from HDD
          --      (Nuno 2026-05-31 "hangs on pic"). etc/boot.lua left pfs1:
          --      mounted; the reboot_iop=1 SifIopReset hangs on that held
          --      mount (ps2sdk #425, same root cause as U-10). Mirror the
          --      U-10 LaunchBootElf fix: cold prep (unmount the boot pfs1:,
          --      clear keep mask) + reboot_iop=0 (no in-process reset). This
          --      is safe here precisely because DKWDRV is NOT on HDD, so no
          --      HDD partition needs to survive the prep.
          --
          --  (2) HDD-resident DKWDRV (hdd?:/ pfs?:/ ata?:/ apa?:/), ANY boot
          --      source. Routed through the partition-aware games path
          --      (loadELFWithPartition -> ExecuteHddBackedViaEmbeddedLoader),
          --      which mounts the partition + uses the BRAM child loader. The
          --      prior plain loadELF route went to a direct ExecPS2 that
          --      cannot mount an HDD partition (black screen on custom HDD
          --      paths). Cold prep is NOT applied (it would unmount the very
          --      partition DKWDRV launches from). nil-fallback to the prior
          --      behavior if no partition context can be built.
          --
          --  (3) MC / non-HDD DKWDRV, POPSLoader NOT booted from HDD.
          --      UNCHANGED: reboot_iop=1, full IOP reset (safe -- no pfs1:
          --      is held when not HDD-booted). This is the confirmed-working
          --      MC DKWDRV path (QA 2026-05-26).
          local rc
          if hdd_loaded and not is_hdd_path then
            -- Case (1): MC DKWDRV from HDD-booted POPSLoader (MERGED FIX,
            -- PR #485). Cold prep clears the held boot pfs1:, reboot_iop=0.
            if type(PLDR) == "table" and type(PLDR.PrepareForColdExternalELFLaunch) == "function" then
              pcall(PLDR.PrepareForColdExternalELFLaunch)
            elseif type(PLDR) == "table" and type(PLDR.PrepareForExternalELFLaunch) == "function" then
              pcall(PLDR.PrepareForExternalELFLaunch, elf_path)
            end
            rc = System.loadELF(elf_path, 0, elf_path)
          elseif is_hdd_path then
            -- Case (2): HDD-resident DKWDRV (custom HDD path, e.g.
            -- hdd0:__common:pfs1:/APPS/PS1_DKWDRV/DKWDRV.ELF, or +OPL, etc).
            -- Normalize the launch EXACTLY like POPSTARTER's HDD custom-path
            -- flow (the proven-working reference -- D-10 passes hardware):
            --   1. partition context  -> "hdd0:PART:"   (BuildHddPartitionContext)
            --   2. slot-less exec path -> "pfs:/REL"     (BuildPartitionScopedExecPath)
            --   3. COLD prep (PrepareForColdExternalELFLaunch) -> unmount ALL
            --      pfs slots so the partition the browser left mounted/held
            --      (on whatever pfsN:) is freed.
            --   4. loadELFWithPartition(pfs:/REL, 1, hdd0:PART:, argv0) ->
            --      ExecuteHddBackedViaEmbeddedLoader mounts PART FRESH on pfs0:
            --      BY NAME and hands off via the BRAM child loader.
            -- This is slot-agnostic on purpose: we never assume which pfsN:
            -- the browser used, because cold prep frees everything and the C
            -- side re-mounts by partition name. The earlier attempt passed the
            -- raw composite path + kept the held mount, so the C-side fresh
            -- pfs0: mount collided (pfs won't double-mount a partition) and
            -- returned -1 before the child loader (Nuno HW 2026-06-04).
            -- nil-fallback: if no partition context / normalized path can be
            -- built, fall back to prior plain behavior (no worse than today).
            local partition_context = nil
            if type(PLDR) == "table" and type(PLDR.BuildHddPartitionContext) == "function" then
              local ok, ctx = pcall(PLDR.BuildHddPartitionContext, elf_path)
              if ok then partition_context = ctx end
            end
            local exec_path_norm = nil
            if type(PLDR) == "table" and type(PLDR.BuildPartitionScopedExecPath) == "function" then
              local ok, p = pcall(PLDR.BuildPartitionScopedExecPath, elf_path)
              if ok and type(p) == "string" and p ~= "" then exec_path_norm = p end
            end
            if partition_context ~= nil and partition_context ~= ""
              and exec_path_norm ~= nil
              and type(System.loadELFWithPartition) == "function" then
              -- COLD prep: unmount all slots so PART is free to re-mount fresh.
              if type(PLDR) == "table" and type(PLDR.PrepareForColdExternalELFLaunch) == "function" then
                pcall(PLDR.PrepareForColdExternalELFLaunch)
              elseif type(PLDR) == "table" and type(PLDR.PrepareForExternalELFLaunch) == "function" then
                pcall(PLDR.PrepareForExternalELFLaunch, elf_path)
              end
              -- reboot_iop=1 selects the partition API; the hdd-backed early
              -- return reaches ExecuteHddBackedViaEmbeddedLoader (child loader
              -- owns IOP state), NOT the in-process SifIopReset block. argv0 =
              -- original path (matches the MC DKWDRV convention, #485).
              rc = System.loadELFWithPartition(exec_path_norm, 1, partition_context, elf_path)
            else
              if type(PLDR) == "table" and type(PLDR.PrepareForExternalELFLaunch) == "function" then
                pcall(PLDR.PrepareForExternalELFLaunch, elf_path)
              end
              rc = System.loadELF(elf_path, 0, elf_path)
            end
          else
            -- Case (3): MC / non-HDD DKWDRV, POPSLoader NOT booted from HDD.
            -- UNCHANGED, confirmed-working (QA 2026-05-26): reboot_iop=1.
            if type(PLDR) == "table" and type(PLDR.PrepareForExternalELFLaunch) == "function" then
              pcall(PLDR.PrepareForExternalELFLaunch, elf_path)
            end
            rc = System.loadELF(elf_path, 1, elf_path)
          end
          if type(PLDR) == "table" and type(PLDR.RestoreWorkingDirectory) == "function" then
            pcall(PLDR.RestoreWorkingDirectory, previous_cwd)
          end
          UI.LAUNCHING = false
          UI.Notify("DKWDRV failed to launch\nreturn code: "..tostring(rc), 150, "error")
          return
        end
        UI.Modal.cancel_action = UI.Modal.Close
        UI.Modal.triangle_action = nil
        UI.Modal.ignore_until_release = true
      end;
      OpenSaveSettings = function (on_save, on_discard)
        UI.Modal.active = true
        UI.Modal.title = "Save Settings"
        UI.Modal.body = "Save your changes before leaving?"
        UI.Modal.options = {"Save", "Cancel", "Don't Save"}
        UI.Modal.confirm_action = function ()
          UI.Modal.Close()
          if type(on_save) == "function" then on_save() end
        end
        UI.Modal.cancel_action = function ()
          UI.Modal.Close()
        end
        UI.Modal.triangle_action = function ()
          UI.Modal.Close()
          if type(on_discard) == "function" then on_discard() end
        end
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
        UI.Modal.Close()
        if type(PLDR) == "table" and type(PLDR.PrepareForExternalELFLaunch) == "function" then
          pcall(PLDR.PrepareForExternalELFLaunch, nil)
        end
        System.exitToBrowser()
      end;
      LaunchBootElf = function ()
        local elf_path = ResolveFirstExistingElf({
          "mc0:/BOOT/BOOT.ELF",
          "mc1:/BOOT/BOOT.ELF"
        })
        if elf_path == nil then
          UI.Notify("BOOT.ELF not found\nchecked mc0:/BOOT and mc1:/BOOT", 120, "error")
          return
        end
        UI.LAUNCHING = true
        UI.Modal.Close()
        local reboot_iop = 0
        local hdd_loaded = type(PLDR) == "table" and type(PLDR.HDD) == "table" and tonumber(PLDR.HDD.LOADSTATE or 0) ~= 0
        if hdd_loaded and type(PLDR) == "table" and type(PLDR.PrepareForColdExternalELFLaunch) == "function" then
          pcall(PLDR.PrepareForColdExternalELFLaunch)
        elseif type(PLDR) == "table" and type(PLDR.PrepareForExternalELFLaunch) == "function" then
          pcall(PLDR.PrepareForExternalELFLaunch, elf_path)
        end
        -- reboot_iop stays 0 for BOOT.ELF, including the HDD-boot case.
        -- (hdd_loaded is still used above to pick the cold pfs teardown.)
        --
        -- 2026-05-30: regression resolved by diffing against a build that
        -- WORKED (Nuno's, on official Enceladus). That build launched
        -- everything with reboot_iop=0 -- no IOP reset, embedded child-loader
        -- handoff -- and it worked from an HDD boot. The reboot=1 path forces
        -- SifIopReset("", 0), a soft reset that cannot reboot a HDD-dirtied
        -- IOP (dev9/atad/pfs/fileXio still loaded) -> SifIopSync spins -> the
        -- black screen testers saw (hardware froze at the reset/sync stage).
        -- The prior assumption that BOOT.ELF needs a clean-IOP reset after HDD
        -- use was wrong: PrepareForColdExternalELFLaunch() above already
        -- unmounts every pfs slot (the only HDD state that matters here), so
        -- the no-reset path is both correct and sufficient. PR #450/#451's
        -- reboot=1 attempts were chasing the wrong mechanism.
        local rc = System.loadELF(elf_path, reboot_iop)
        UI.LAUNCHING = false
        UI.Notify("BOOT.ELF failed to launch\nreturn code: "..tostring(rc), 150, "error")
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
        local body_lines = WrapText(UI.Modal.body or "", 38)
        local line_spacing = 16
        local confirm_label = UI.Modal.options[1] or "Confirm"
        local cancel_label = UI.Modal.options[2] or "Cancel"
        local triangle_label = UI.Modal.options[3]
        local extra_footer_h = (triangle_label ~= nil) and 16 or 0
        local box_w = 320
        local box_h = 140 + (math.max(1, #body_lines) - 1) * line_spacing + extra_footer_h
        local box_x = math.floor(UI.SCR.X_MID - (box_w / 2))
        local box_y = math.floor(UI.SCR.Y_MID - (box_h / 2))
        Graphics.drawRect(0, 0, UI.SCR.X, UI.SCR.Y, UI.CCOL.MODAL_BACKDROP)
        Graphics.drawRect(box_x, box_y, box_w, box_h, Color.new(0, 0, 0, 200))
        Graphics.drawRect(box_x, box_y, box_w, 2, UI.CCOL.GREY)
        Graphics.drawRect(box_x, box_y + box_h - 2, box_w, 2, UI.CCOL.GREY)
        Font.ftPrint(BFONT, UI.SCR.X_MID, box_y + 10, 8, UI.SCR.X, 16, UI.Modal.title, UI.CCOL.YELLOW)
        for i, line in ipairs(body_lines) do
          Font.ftPrint(BFONT, UI.SCR.X_MID, box_y + 50 + (i - 1) * line_spacing, 8, UI.SCR.X, 16, line, UI.CCOL.GREY)
        end
        local hint1 = ("X: %s    O: %s"):format(confirm_label, cancel_label)
        if triangle_label ~= nil then
          local hint2 = ("Triangle: %s"):format(triangle_label)
          Font.ftPrint(BFONT, UI.SCR.X_MID, box_y + box_h - 60, 8, UI.SCR.X, 16, hint1, UI.CCOL.GREY)
          Font.ftPrint(BFONT, UI.SCR.X_MID, box_y + box_h - 45, 8, UI.SCR.X, 16, hint2, UI.CCOL.GREY)
        else
          Font.ftPrint(BFONT, UI.SCR.X_MID, box_y + box_h - 45, 8, UI.SCR.X, 16, hint1, UI.CCOL.GREY)
        end
      end;
    };
    PathEditor = {
      active = false;
      title = "";
      value = "";
      on_confirm = nil;
      row = 1;
      col = 1;
      upper = false;
      cursor = 0;
      max_len = 120;
      pressed_row = 0;
      pressed_col = 0;
      pressed_until = 0;
      layout_key = "QWERTY";
      layout_order = {"QWERTY", "ABC", "DVORAK"};
      layouts = {
        ABC = {
          {"a","b","c","d","e","f","g","h","i","j"},
          {"k","l","m","n","o","p","q","r","s","t"},
          {"u","v","w","x","y","z","0","1","2","3"},
          {"4","5","6","7","8","9",":","/",".","_"},
          {"-","?","!","&","\\","'","(",")",",",";","+"},
          {"=","[","]","SPACE","DEL","CLR"},
          {"BACK","DONE"}
        },
        QWERTY = {
          {"q","w","e","r","t","y","u","i","o","p"},
          {"a","s","d","f","g","h","j","k","l",";"},
          {"z","x","c","v","b","n","m",",",".","/"},
          {"0","1","2","3","4","5","6","7","8","9",":","_"},
          {"-","?","!","&","\\","'","(",")","+","=","[","]"},
          {"SPACE","DEL","CLR"},
          {"BACK","DONE"}
        },
        DVORAK = {
          {"'",";",",",".","p","y","f","g","c","r","l"},
          {"a","o","e","u","i","d","h","t","n","s"},
          {"q","j","k","x","b","m","w","v","z","/"},
          {"0","1","2","3","4","5","6","7","8","9",":","_"},
          {"-","?","!","&","\\","(",")","+","=","[","]"},
          {"SPACE","DEL","CLR"},
          {"BACK","DONE"}
        }
      };
      _NormalizeLayout = function (layout)
        if type(PLDR) == "table" and type(PLDR.NormalizeKeyboardLayout) == "function" then
          return PLDR.NormalizeKeyboardLayout(layout)
        end
        local key = string.upper(tostring(layout or ""))
        if key == "ABC" or key == "DVORAK" then
          return key
        end
        return "QWERTY"
      end;
      _CurrentRows = function ()
        local layout_key = UI.PathEditor._NormalizeLayout(UI.PathEditor.layout_key)
        local rows = UI.PathEditor.layouts[layout_key]
        if rows == nil then
          rows = UI.PathEditor.layouts.ABC
        end
        return rows
      end;
      Open = function (title, initial, on_confirm)
        UI.PathEditor.active = true
        UI.PathEditor.title = tostring(title or "Edit Path")
        UI.PathEditor.value = tostring(initial or "")
        UI.PathEditor.on_confirm = on_confirm
        UI.PathEditor.row = 1
        UI.PathEditor.col = 1
        UI.PathEditor.upper = false
        UI.PathEditor.cursor = string.len(UI.PathEditor.value or "")
        UI.PathEditor.pressed_row = 0
        UI.PathEditor.pressed_col = 0
        UI.PathEditor.pressed_until = 0
        UI.PathEditor.layout_key = UI.PathEditor._NormalizeLayout(UI.KeyboardLayoutDraft or (type(PLDR) == "table" and PLDR.KEYBOARD_LAYOUT) or "QWERTY")
      end;
      Close = function ()
        UI.PathEditor.active = false
        UI.PathEditor.title = ""
        UI.PathEditor.on_confirm = nil
        UI.PathEditor.cursor = 0
        UI.PathEditor.pressed_row = 0
        UI.PathEditor.pressed_col = 0
        UI.PathEditor.pressed_until = 0
      end;
      _NowMs = function ()
        if UI.Pad ~= nil and UI.Pad.Timer ~= nil then
          return tonumber(Timer.getTime(UI.Pad.Timer)) or 0
        end
        return 0
      end;
      _RowSize = function (row)
        if row == 0 then
          return #UI.PathEditor.layout_order
        end
        local rows = UI.PathEditor._CurrentRows()
        local r = rows[row]
        if r == nil then return 0 end
        return #r
      end;
      _ValueLength = function ()
        return string.len(tostring(UI.PathEditor.value or ""))
      end;
      _ClampCursor = function ()
        local length = UI.PathEditor._ValueLength()
        if UI.PathEditor.cursor < 0 then
          UI.PathEditor.cursor = 0
        elseif UI.PathEditor.cursor > length then
          UI.PathEditor.cursor = length
        end
      end;
      _MoveCursor = function (delta)
        UI.PathEditor.cursor = (tonumber(UI.PathEditor.cursor) or 0) + (tonumber(delta) or 0)
        UI.PathEditor._ClampCursor()
      end;
      _CurrentKey = function ()
        if UI.PathEditor.row == 0 then
          return UI.PathEditor.layout_order[UI.PathEditor.col]
        end
        local rows = UI.PathEditor._CurrentRows()
        local row = rows[UI.PathEditor.row]
        if row == nil then return nil end
        return row[UI.PathEditor.col]
      end;
      _KeyWidth = function (key)
        if key == "SPACE" then return 92 end
        if key == "BACK" or key == "DONE" then return 84 end
        if key == "DEL" or key == "CLR" then return 54 end
        return 38
      end;
      _LayoutButtonWidth = function (layout_key)
        if layout_key == "QWERTY" then return 94 end
        if layout_key == "DVORAK" then return 88 end
        return 62
      end;
      _DisplayKey = function (key)
        if key == nil then return "" end
        if key == "SPACE" then return "SPACE" end
        if UI.PathEditor.upper and string.match(key, "^[a-z]$") then
          return string.upper(key)
        end
        return key
      end;
      _SetLayout = function (layout_key)
        local normalized = UI.PathEditor._NormalizeLayout(layout_key)
        UI.PathEditor.layout_key = normalized
        UI.KeyboardLayoutDraft = normalized
        UI.ProfileDirty = true
        local row_size = UI.PathEditor._RowSize(UI.PathEditor.row)
        if row_size > 0 then
          UI.PathEditor.col = CLAMP(UI.PathEditor.col, 1, row_size)
        else
          UI.PathEditor.row = 1
          UI.PathEditor.col = 1
        end
        return normalized
      end;
      _BuildVisibleValue = function (max_chars)
        local raw = tostring(UI.PathEditor.value or "")
        local limit = math.max(8, tonumber(max_chars) or 48)
        UI.PathEditor._ClampCursor()
        local cursor = tonumber(UI.PathEditor.cursor) or 0
        local length = string.len(raw)
        local start_idx = 1
        if length > limit then
          start_idx = cursor - math.floor(limit / 2) + 1
          if start_idx < 1 then
            start_idx = 1
          end
          local max_start = math.max(1, length - limit + 1)
          if start_idx > max_start then
            start_idx = max_start
          end
        end
        local end_idx = math.min(length, start_idx + limit - 1)
        local shown = string.sub(raw, start_idx, end_idx)
        local rel_cursor = cursor - (start_idx - 1)
        if rel_cursor < 0 then rel_cursor = 0 end
        if rel_cursor > string.len(shown) then
          rel_cursor = string.len(shown)
        end
        local blink_on = (math.floor(UI.PathEditor._NowMs() / 300) % 2) == 0
        local cursor_marker = blink_on and "|" or " "
        shown = string.sub(shown, 1, rel_cursor)..cursor_marker..string.sub(shown, rel_cursor + 1)
        if start_idx > 1 then
          shown = "..."..shown
        end
        if end_idx < length then
          shown = shown.."..."
        end
        return shown
      end;
      _InsertText = function (ch)
        local val = UI.PathEditor.value or ""
        local insert = tostring(ch or "")
        if insert == "" then
          return
        end
        if (string.len(val) + string.len(insert)) > UI.PathEditor.max_len then
          return
        end
        UI.PathEditor._ClampCursor()
        local cursor = tonumber(UI.PathEditor.cursor) or 0
        local left = string.sub(val, 1, cursor)
        local right = string.sub(val, cursor + 1)
        UI.PathEditor.value = left..insert..right
        UI.PathEditor.cursor = cursor + string.len(insert)
      end;
      _DeleteChar = function ()
        local val = UI.PathEditor.value or ""
        UI.PathEditor._ClampCursor()
        local cursor = tonumber(UI.PathEditor.cursor) or 0
        if cursor <= 0 or val == "" then
          return
        end
        UI.PathEditor.value = string.sub(val, 1, cursor - 1)..string.sub(val, cursor + 1)
        UI.PathEditor.cursor = cursor - 1
      end;
      _FlashCurrentKey = function ()
        UI.PathEditor.pressed_row = UI.PathEditor.row
        UI.PathEditor.pressed_col = UI.PathEditor.col
        UI.PathEditor.pressed_until = UI.PathEditor._NowMs() + 160
      end;
      _FlashKey = function (target_key)
        for c = 1, #UI.PathEditor.layout_order do
          if UI.PathEditor.layout_order[c] == target_key then
            UI.PathEditor.pressed_row = 0
            UI.PathEditor.pressed_col = c
            UI.PathEditor.pressed_until = UI.PathEditor._NowMs() + 160
            return
          end
        end
        local rows = UI.PathEditor._CurrentRows()
        for r = 1, #rows do
          local row = rows[r]
          for c = 1, #row do
            if row[c] == target_key then
              UI.PathEditor.pressed_row = r
              UI.PathEditor.pressed_col = c
              UI.PathEditor.pressed_until = UI.PathEditor._NowMs() + 160
              return
            end
          end
        end
      end;
      _IsPressed = function (row, col)
        return UI.PathEditor.pressed_row == row
          and UI.PathEditor.pressed_col == col
          and UI.PathEditor._NowMs() <= (tonumber(UI.PathEditor.pressed_until) or 0)
      end;
      HandleInput = function ()
        if not UI.PathEditor.active then return end
        if UI.Pad.Events.BACK then
          UI.PathEditor.Close()
          return
        end
        if UI.Pad.Events.L1 then
          UI.PathEditor._MoveCursor(-1)
        end
        if UI.Pad.Events.R1 then
          UI.PathEditor._MoveCursor(1)
        end
        if UI.Pad.Events.R2 then
          UI.PathEditor.upper = not UI.PathEditor.upper
        end
        if UI.Pad.Events.SQUARE then
          UI.PathEditor._DeleteChar()
          UI.PathEditor._FlashKey("DEL")
        end

        local rows = UI.PathEditor._CurrentRows()
        local max_rows = #rows
        if UI.Pad.Events.NAV_UP then
          UI.PathEditor.row = CLAMP(UI.PathEditor.row - 1, 0, max_rows)
          local row_size = UI.PathEditor._RowSize(UI.PathEditor.row)
          UI.PathEditor.col = CLAMP(UI.PathEditor.col, 1, row_size)
        end
        if UI.Pad.Events.NAV_DOWN then
          UI.PathEditor.row = CLAMP(UI.PathEditor.row + 1, 0, max_rows)
          local row_size = UI.PathEditor._RowSize(UI.PathEditor.row)
          UI.PathEditor.col = CLAMP(UI.PathEditor.col, 1, row_size)
        end
        if UI.Pad.Events.NAV_LEFT then
          UI.PathEditor.col = UI.PathEditor.col - 1
          if UI.PathEditor.col < 1 then
            UI.PathEditor.col = UI.PathEditor._RowSize(UI.PathEditor.row)
          end
        end
        if UI.Pad.Events.NAV_RIGHT then
          UI.PathEditor.col = UI.PathEditor.col + 1
          local row_size = UI.PathEditor._RowSize(UI.PathEditor.row)
          if UI.PathEditor.col > row_size then
            UI.PathEditor.col = 1
          end
        end

        local function confirm_value()
          local cb = UI.PathEditor.on_confirm
          local val = tostring(UI.PathEditor.value or "")
          UI.PathEditor.Close()
          if cb ~= nil then
            cb(val)
          end
        end

        if UI.Pad.Events.START then
          confirm_value()
          return
        end

        if UI.Pad.Events.CONFIRM then
          UI.PathEditor._FlashCurrentKey()
          local key = UI.PathEditor._CurrentKey()
          if UI.PathEditor.row == 0 then
            UI.PathEditor._SetLayout(key)
            return
          elseif key == "SPACE" then
            UI.PathEditor._InsertText(" ")
          elseif key == "DEL" then
            UI.PathEditor._DeleteChar()
          elseif key == "CLR" then
            UI.PathEditor.value = ""
            UI.PathEditor.cursor = 0
          elseif key == "DONE" then
            confirm_value()
            return
          elseif key == "BACK" then
            UI.PathEditor.Close()
            return
          elseif key ~= nil and key ~= "" then
            local out = key
            if UI.PathEditor.upper and string.match(out, "^[a-z]$") then
              out = string.upper(out)
            end
            UI.PathEditor._InsertText(out)
          end
        end
      end;
      Draw = function ()
        if not UI.PathEditor.active then return end
        local box_w = math.min(UI.SCR.X - 48, 560)
        local box_h = math.min(UI.SCR.Y - 32, 352)
        local box_x = math.floor((UI.SCR.X - box_w) / 2)
        local box_y = math.floor((UI.SCR.Y - box_h) / 2)
        local input_x = box_x + 18
        local input_y = box_y + 30
        local input_w = box_w - 36
        local input_h = 34
        Graphics.drawRect(0, 0, UI.SCR.X, UI.SCR.Y, Color.new(6, 10, 20, 224))
        Graphics.drawRect(box_x, box_y, box_w, box_h, Color.new(6, 10, 20, 224))
        Graphics.drawRect(input_x, input_y, input_w, input_h, Color.new(18, 28, 56, 128))
        Graphics.drawRect(input_x + 1, input_y + 1, input_w - 2, input_h - 2, Color.new(4, 6, 14, 128))

        Font.ftPrint(BFONT, UI.SCR.X_MID, box_y + 8, 8, UI.SCR.X, 16, UI.PathEditor.title, UI.CCOL.YELLOW)
        Font.ftPrint(SFONT, input_x + 10, input_y + 10, 0, input_w - 20, 16, UI.PathEditor._BuildVisibleValue(46), Color.new(150, 205, 255, 128))
        local mode_label = UI.PathEditor.upper and "Case: UPPER  (R2)" or "Case: lower  (R2)"
        local info_label = mode_label.."   Cursor: L1 / R1"
        Font.ftPrint(SFONT, input_x + 2, input_y + input_h + 10, 0, input_w - 4, 16, info_label, UI.CCOL.GREY)

        local key_h = 24
        local key_gap = 6
        local layout_h = 22
        local layout_gap = 8
        local layout_y = input_y + input_h + 30
        local layout_w = 0
        for i = 1, #UI.PathEditor.layout_order do
          layout_w = layout_w + UI.PathEditor._LayoutButtonWidth(UI.PathEditor.layout_order[i])
          if i < #UI.PathEditor.layout_order then
            layout_w = layout_w + layout_gap
          end
        end
        local layout_x = math.floor(box_x + ((box_w - layout_w) / 2))
        local layout_cursor_x = layout_x
        for i = 1, #UI.PathEditor.layout_order do
          local layout_key = UI.PathEditor.layout_order[i]
          local button_w = UI.PathEditor._LayoutButtonWidth(layout_key)
          local selected = (UI.PathEditor.row == 0 and UI.PathEditor.col == i)
          local active = (UI.PathEditor.layout_key == layout_key)
          local pressed = UI.PathEditor._IsPressed(0, i)
          local border = Color.new(40, 68, 110, 128)
          local fill = Color.new(10, 16, 30, 128)
          local text_color = UI.CCOL.GREY
          if active then
            border = Color.new(70, 126, 190, 128)
            fill = Color.new(22, 44, 74, 128)
            text_color = Color.new(168, 212, 255, 128)
          end
          if selected then
            border = Color.new(90, 170, 255, 128)
            fill = Color.new(30, 64, 118, 128)
            text_color = Color.new(180, 220, 255, 128)
          end
          if pressed then
            border = Color.new(120, 210, 255, 128)
            fill = Color.new(54, 118, 180, 128)
            text_color = Color.new(200, 230, 255, 128)
          end
          Graphics.drawRect(layout_cursor_x, layout_y, button_w, layout_h, border)
          Graphics.drawRect(layout_cursor_x + 1, layout_y + 1, button_w - 2, layout_h - 2, fill)
          Font.ftPrint(SFONT, Round(layout_cursor_x + (button_w / 2)), layout_y + 3, 8, button_w, 16, layout_key, text_color)
          layout_cursor_x = layout_cursor_x + button_w + layout_gap
        end

        local start_y = layout_y + layout_h + 8
        local rows = UI.PathEditor._CurrentRows()
        for r = 1, #rows do
          local row = rows[r]
          local row_w = 0
          for c = 1, #row do
            row_w = row_w + UI.PathEditor._KeyWidth(row[c])
            if c < #row then
              row_w = row_w + key_gap
            end
          end
          local row_x = math.floor(box_x + ((box_w - row_w) / 2))
          local cursor_x = row_x
          for c = 1, #row do
            local key = row[c]
            local key_w = UI.PathEditor._KeyWidth(key)
            local x = cursor_x
            local y = start_y + ((r - 1) * (key_h + key_gap))
            local text_y = y + 3
            local text_x = Round(x + (key_w / 2))
            local text_w = key_w
            local selected = (UI.PathEditor.row == r and UI.PathEditor.col == c)
            local pressed = UI.PathEditor._IsPressed(r, c)
            local border = Color.new(32, 54, 90, 128)
            local fill = Color.new(14, 20, 38, 128)
            local text_color = UI.CCOL.GREY
            if pressed then
              border = Color.new(120, 210, 255, 128)
              fill = Color.new(54, 118, 180, 128)
              text_color = Color.new(200, 230, 255, 128)
            elseif selected then
              border = Color.new(90, 170, 255, 128)
              fill = Color.new(30, 64, 118, 128)
              text_color = Color.new(180, 220, 255, 128)
            end
            Graphics.drawRect(x, y, key_w, key_h, border)
            Graphics.drawRect(x + 1, y + 1, key_w - 2, key_h - 2, fill)
            Graphics.drawRect(x + 1, y + 1, key_w - 2, 1, Color.new(70, 100, 150, 96))
            Font.ftPrint(SFONT, text_x, text_y, 8, text_w, 16, UI.PathEditor._DisplayKey(key), text_color)
            cursor_x = x + key_w + key_gap
          end
        end
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
      overlay_img = nil,
      overlay_resolved = false,
      GetOverlayImage = function ()
        if not UI.Transition.overlay_resolved then
          if type(IMG) == "table" and IMG.BG ~= nil then
            UI.Transition.overlay_img = IMG.BG
          end
          UI.Transition.overlay_resolved = true
        end
        return UI.Transition.overlay_img
      end,
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
        local overlay = UI.Transition.GetOverlayImage()
        local max_alpha = (overlay ~= nil) and 255 or 128
        local alpha
        if UI.Transition.phase == "out" then
          alpha = Round(max_alpha * e)
        else
          alpha = Round(max_alpha * (1 - e))
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
            alpha = max_alpha
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
      if UI.Pad.Events.SELECT then
        if UI.IsHideToggleScene(UI.CURSCENE) or UI.CURSCENE == UI.SCENES.MPROFILE then
          UI.ToggleHideTextMode(true)
          return true
        end
      end
      if UI.Pad.Events.START and UI.CURSCENE ~= UI.SCENES.MPROFILE then
        UI.SettingsReturnScene = UI.CURSCENE
        UI.SettingsEntryHideTextMode = (UI.HideTextMode == true)
        UI.SyncSettingsSelectionFromRuntime()
        if UI.SyncSettingsDraftFromRuntime ~= nil then
          UI.SyncSettingsDraftFromRuntime()
        end
        UI.ProfileDirty = false
        UI.BdmaDirty = false
        UI.VideoStandardDirty = false
        UI.BootPageModes = {
          {key = "Carousel", label = "Carousel (default)"},
          {key = "MX4SIO",   label = "MX4SIO"},
          {key = "USB",      label = "USB"},
          {key = "MMCE",     label = "MMCE"},
          {key = "HDD",      label = "HDD (PFS)"},
        }
        UI.BootPageIndex = 1
        for i = 1, #UI.BootPageModes do
          if UI.BootPageModes[i].key == tostring((type(PLDR) == "table" and PLDR.BOOT_PAGE) or "Carousel") then
            UI.BootPageIndex = i
            break
          end
        end
        UI.SettingsEntryBootPageIndex = UI.BootPageIndex
        -- Carousel device-visibility draft ({KEY=true} set of hidden devices) +
        -- entry snapshot for the dirty check.
        UI.DeviceHiddenDraft = {}
        UI.SettingsEntryHiddenSet = {}
        if type(PLDR) == "table" then
          for token in string.gmatch(string.upper(tostring(PLDR.HIDDEN_DEVICES or "")), "[^,%s]+") do
            UI.DeviceHiddenDraft[token] = true
            UI.SettingsEntryHiddenSet[token] = true
          end
        end
        UI.SettingsEntryHiddenDevices = (type(PLDR) == "table" and type(PLDR.NormalizeHiddenDevices) == "function") and PLDR.NormalizeHiddenDevices(UI.DeviceHiddenDraft) or ""
        UI.MultiDiscCollapse = (type(PLDR) == "table" and PLDR.COLLAPSE_MULTIDISC == true)
        UI.SettingsEntryMultiDiscCollapse = UI.MultiDiscCollapse
        UI.GlobalHide = (type(PLDR) == "table" and PLDR.GLOBAL_HIDE == true)
        UI.SettingsEntryGlobalHide = UI.GlobalHide
        UI.ShowDetails = (type(PLDR) == "table" and PLDR.SHOW_DETAILS == true)
        UI.SettingsEntryShowDetails = UI.ShowDetails
        UI.SettingsEntryKeyboardLayout = tostring(UI.KeyboardLayoutDraft or (type(PLDR) == "table" and PLDR.KEYBOARD_LAYOUT) or "QWERTY")
        UI.SettingsFocus = 1
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
      DetailsTotal = 0;       -- wrapped lines in the current description (0 = none)
      DetailsVisible = 0;     -- how many of them fit on screen this frame
      DescScrollAt = 0;       -- last right-stick scroll step (ms, for rate-limit)
      Reset = function ()
        UI.GameList.CURR = 1;
        UI.GameList.CoverLastIndex = nil
        UI.GameList.CoverPending = false
        UI.GameList.CoverPendingAt = 0
        UI.GameList.DetailsTotal = 0
        UI.GameList.DetailsVisible = 0
        UI.GameList.DescScrollAt = 0
      end;
      Play = function()
        local layout = UI.LAYOUT
        UI.GameList.MAXDRAW = layout.LIST_MAX
        local titles = {
          [UI.SCENES.GUSBFAT] = "USB"
        }
        local scene_title = titles[UI.CURSCENE]
        if scene_title ~= nil and not UI.ShouldHideAuxText(UI.CURSCENE) then
          Font.ftPrint(LFONT, UI.SCR.X_MID, layout.TITLE_Y, 8, UI.SCR.X, 16, scene_title, UI.CCOL.GREY)
        end
        local placeholders = {
          [UI.SCENES.GBDMHDD] = "BDM HDD"
        }
        local placeholder_title = placeholders[UI.CURSCENE]
        if placeholder_title ~= nil then
          if not UI.ShouldHideAuxText(UI.CURSCENE) then
            Font.ftPrint(LFONT, UI.SCR.X_MID, layout.TITLE_Y, 8, UI.SCR.X, 16, placeholder_title, UI.CCOL.GREY)
            Font.ftPrintMultiLineAligned(BFONT, UI.SCR.X_MID, UI.SCR.Y_MID, 20, UI.SCR.X, 32, "Not implemented yet", UI.CCOL.YELLOW)
          end
          Input_GetEvent()
        if UI.HandleGlobalInput(false) then return end
          if UI.Pad.Events.EXIT then UI.SceneChange(UI.SCENES.CREDITS) end
          if UI.Pad.Events.BACK then UI.SceneChange(UI.SCENES.MMAIN) end
          if UI.Pad.Events.CONFIRM then
            UI.Notif_queue.add("This backend isn't implemented yet", "warn")
          end
          local labels, order = UI.Footer.ResolveLegend({
            order = UI.Footer.order_with_start_r2,
            order_id = "start_r2",
            circle = UI.Footer.labels.circle_other,
            cross = UI.Footer.labels.cross_confirm,
            square = "Cover Art",
            start = UI.Footer.labels.start_profiles
          })
          UI.Footer.Draw(labels, order)
          return
        end
        local ammount = #PLDR.GAMES
        if ammount <= 0 then
          UI.GameList.CURR = 1
          UI.GameList.STARTUP = 1
        else
          UI.GameList.CURR = CLAMP(UI.GameList.CURR, 1, ammount)
          UI.GameList.STARTUP = CLAMP(UI.GameList.STARTUP, 1, ammount)
        end
        if UI.CURSCENE == UI.SCENES.GSMB then
          local slots = PLDR.GetMMCESlots()
          if #slots > 1 and not UI.ShouldHideAuxText(UI.CURSCENE) then
            Font.ftPrint(SFONT, layout.LIST_X, layout.LIST_Y - 20, 0, UI.SCR.X, 16, "Slot: "..PLDR.MMCE.PREFIX, UI.CCOL.GREY)
          end
        end
        if (UI.GameList.CURR > (UI.GameList.STARTUP+(UI.GameList.MAXDRAW-1))) then
          UI.GameList.STARTUP = (UI.GameList.CURR-UI.GameList.MAXDRAW+1)
        elseif (UI.GameList.CURR < UI.GameList.STARTUP) then
          UI.GameList.STARTUP = CLAMP(UI.GameList.CURR-1, 1, ammount)
        end
        -- Advance the marquee clock for the focused row; reset on selection change.
        if UI.GameList.MarqueeSel ~= UI.GameList.CURR then
          UI.GameList.MarqueeSel = UI.GameList.CURR
          UI.GameList.MarqueeTick = 0
        else
          UI.GameList.MarqueeTick = (UI.GameList.MarqueeTick or 0) + 1
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
          if PLDR.IsGameHidden and PLDR.IsGameHidden(PLDR.GAMES[i]) then
            c = (i == UI.GameList.CURR) and LIST_HIDDEN_SELECTED_COLOR or LIST_HIDDEN_COLOR
          end
          local label = StripVcdExtension(display_name)
          -- Only the focused row scrolls (OPL-style); others clip as before.
          if i == UI.GameList.CURR then
            label = MarqueeLabel(BFONT, label, layout.LIST_W, UI.GameList.MarqueeTick or 0)
          end
	          Font.ftPrint(BFONT, layout.LIST_X, Y, 0, layout.LIST_W, 16, label, c)
        end
        local cover_enabled = UI.CoverPreviewEnabled ~= false
        local cover_img = nil
        if UI.CoverCache ~= nil then
          cover_img = UI.CoverCache.last_img
        end
        if layout.PREVIEW_W > 0 then
          local preview_x = layout.PREVIEW_X
          local preview_y = layout.PREVIEW_Y
          local preview_w = layout.PREVIEW_W
          local preview_h = layout.PREVIEW_H
          local preview_img = nil
          local preview_is_live_cover = false
          if cover_enabled then
            if cover_img ~= nil then
              preview_img = cover_img
              preview_is_live_cover = true
            else
              preview_img = IMG.missing
            end
          else
            preview_img = IMG.default or IMG.missing
          end
          local draw_x = preview_x
          local draw_y = preview_y
          local draw_w = preview_w
          local draw_h = preview_h
          -- Pixel-aspect-correct the cover + frame, and compute their on-screen size
          -- UP FRONT (independent of Y) so the per-game description can sit directly
          -- under the REAL artwork. The PS2 stretches the whole 640xY framebuffer to
          -- one 4:3 frame, so a fixed pixel-square shows tall on NTSC (Y=448) and
          -- wide on PAL (Y=512) (#496); size from the source aspect * (480/SCR.Y),
          -- fit inside the COVER_W box, and keep the top/right anchor.
          local cover_w, cover_h = nil, nil
          if preview_img ~= nil and preview_is_live_cover then
            local box = math.min(layout.COVER_W or 232, draw_w, draw_h)
            local iw = Graphics.getImageWidth(preview_img)
            local ih = Graphics.getImageHeight(preview_img)
            if type(iw) ~= "number" or iw <= 0 then iw = 1 end
            if type(ih) ~= "number" or ih <= 0 then ih = 1 end
            local ratio = (iw / ih) * (480 / (UI.SCR.Y or 448))
            if ratio >= 1 then
              cover_w = box
              cover_h = Round(box / ratio)
            else
              cover_h = box
              cover_w = Round(box * ratio)
            end
            if cover_w > draw_w then cover_w = draw_w end
            if cover_h > draw_h then cover_h = draw_h end
          end
          -- frame.png is the decorative border (256x256), same aspect correction so
          -- it stays square on BOTH standards instead of warping per video mode.
          local frame_w, frame_h = nil, nil
          if IMG.frame ~= nil then
            local fiw = Graphics.getImageWidth(IMG.frame)
            local fih = Graphics.getImageHeight(IMG.frame)
            if type(fiw) ~= "number" or fiw <= 0 then fiw = 1 end
            if type(fih) ~= "number" or fih <= 0 then fih = 1 end
            local fratio = (fiw / fih) * (480 / (UI.SCR.Y or 448))
            if fratio >= 1 then
              frame_w = draw_w
              frame_h = Round(draw_w / fratio)
            else
              frame_h = draw_h
              frame_w = Round(draw_h * fratio)
            end
            if frame_w > draw_w then frame_w = draw_w end
            if frame_h > draw_h then frame_h = draw_h end
          end
          -- Visible art height = the taller of the cover/frame (both top-anchored);
          -- a missing/disabled cover falls back to the full placeholder box.
          local art_h = 0
          if cover_h ~= nil and cover_h > art_h then art_h = cover_h end
          if frame_h ~= nil and frame_h > art_h then art_h = frame_h end
          if not preview_is_live_cover and draw_h > art_h then art_h = draw_h end
          if art_h <= 0 then art_h = draw_h end
          -- Per-game details: when the feature is on AND a "<name>.txt" was found,
          -- wrap it, place it DIRECTLY under the artwork, and lift the [art + gap +
          -- text] group so it CENTERS in the content area (top safe margin .. above
          -- the button bar) -- biased up so it doesn't feel bottom-heavy, and with no
          -- dead gap between art and text. A blurb taller than fits is windowed and
          -- SCROLLS with the right analog stick (input section). The art never moves
          -- DOWN from its normal spot; the line budget clears the footer icons.
          local details_lines, details_y, details_first = nil, nil, 1
          local details_line_h, details_gap = 14, 8
          local details_h, details_visible, details_total = 0, 0, 0
          UI.GameList.DetailsTotal = 0
          UI.GameList.DetailsVisible = 0
          if cover_enabled and type(PLDR) == "table" and PLDR.SHOW_DETAILS == true
             and UI.CoverCache ~= nil and type(UI.CoverCache.last_desc) == "string"
             and UI.CoverCache.last_desc ~= "" then
            local footer_y = layout.FOOTER_ICON_Y or (UI.SCR.Y - 56)
            local bottom_limit = footer_y - 24  -- clear the centered footer icons
            local top_margin = ((layout.SAFE and layout.SAFE.T) or 24) + 8
            local avail = bottom_limit - top_margin
            local cap = math.floor((avail - art_h - details_gap) / details_line_h)
            if cap < 1 then cap = 1 end
            local all_lines = WrapGameDetailsLines(UI.CoverCache.last_desc, 30)
            details_total = #all_lines
            if details_total > 0 then
              details_visible = details_total
              if details_visible > cap then details_visible = cap end
              details_h = details_visible * details_line_h
              -- clamp the persisted scroll offset to the current line count
              local max_off = details_total - details_visible
              if max_off < 0 then max_off = 0 end
              local off = UI.CoverCache.desc_scroll or 0
              if off < 0 then off = 0 end
              if off > max_off then off = max_off end
              UI.CoverCache.desc_scroll = off
              details_first = off + 1
              details_lines = all_lines
              UI.GameList.DetailsTotal = details_total
              UI.GameList.DetailsVisible = details_visible
              local group_h = art_h + details_gap + details_h
              local group_top = Round(top_margin + (avail - group_h) / 2)
              if group_top < top_margin then group_top = top_margin end
              if group_top > draw_y then group_top = draw_y end  -- only lift up, never down
              -- Belt-and-suspenders: never let the group bottom cross into the button
              -- bar, even on an unusually short screen where the art nearly fills the
              -- content band (unreachable on real PS2 video modes; keeps the footer
              -- icons clear if one ever exists). Prioritizes footer clearance.
              if group_top + group_h > bottom_limit then group_top = bottom_limit - group_h end
              draw_y = group_top
              details_y = draw_y + art_h + details_gap
            end
          end
          -- Draw the cover/placeholder at the (possibly lifted) draw_y.
          if preview_img ~= nil then
            if preview_is_live_cover and cover_w ~= nil and cover_h ~= nil then
              local cover_x = draw_x + (draw_w - cover_w)
              Graphics.drawScaleImage(preview_img, cover_x, draw_y, cover_w, cover_h)
            else
              Graphics.drawScaleImage(preview_img, draw_x, draw_y, draw_w, draw_h)
            end
          end
          if IMG.frame ~= nil and frame_w ~= nil and frame_h ~= nil then
            local frame_x = draw_x + (draw_w - frame_w)
            Graphics.drawScaleImage(IMG.frame, frame_x, draw_y, frame_w, frame_h)
          end
          -- Paint the description: window the visible slice from the scroll offset,
          -- with a "..." affordance when there's more above/below (font-safe, same
          -- idiom as the old truncation). draw_y/details_y already include the lift.
          if details_lines ~= nil and details_y ~= nil and details_visible > 0 then
            local buf = {}
            for k = details_first, details_first + details_visible - 1 do
              buf[#buf + 1] = details_lines[k] or ""
            end
            if details_first > 1 and #buf > 0 then
              local L = buf[1] or ""
              if #L > 27 then L = string.sub(L, 1, 27) end
              buf[1] = "..." .. L
            end
            if (details_first + details_visible - 1) < details_total and #buf > 0 then
              local L = buf[#buf] or ""
              if #L > 27 then L = string.sub(L, 1, 27) end
              buf[#buf] = L .. "..."
            end
            Font.ftPrintMultiLineAligned(SFONT, draw_x + Round(draw_w / 2), details_y, details_line_h, draw_w, details_h, table.concat(buf, "\n"), UI.CCOL.GREY)
          end
        end
        if ammount <= 0 then
          if not UI.ShouldHideAuxText(UI.CURSCENE) then
            Font.ftPrintMultiLineAligned(LFONT, UI.SCR.X_MID, UI.SCR.Y_MID, 20, UI.SCR.X, 32, "No games found", UI.CCOL.YELLOW)
            Font.ftPrintMultiLineAligned(LFONT, UI.SCR.X_MID+1, UI.SCR.Y_MID+1, 20, UI.SCR.X, 32, "No games found", UI.CCOL.TRANSP_BLACK)
          end
        end
        Input_GetEvent()
        if UI.HandleGlobalInput(false) then return end
        if UI.Pad.Events.EXIT then UI.SceneChange(UI.SCENES.CREDITS) end
        if UI.Pad.Events.BACK then UI.SceneChange(UI.SCENES.MMAIN) end
        if ammount > 0 then
          if UI.Pad.Events.NAV_DOWN then UI.GameList.CURR = CLAMP(UI.GameList.CURR+1, 1, ammount) end
          if UI.Pad.Events.NAV_RIGHT then UI.GameList.CURR = CLAMP(UI.GameList.CURR+UI.GameList.MAXDRAW, 1, ammount) end
          if UI.Pad.Events.NAV_UP then UI.GameList.CURR = CLAMP(UI.GameList.CURR-1, 1, ammount) end
          if UI.Pad.Events.NAV_LEFT then UI.GameList.CURR = CLAMP(UI.GameList.CURR-UI.GameList.MAXDRAW, 1, ammount) end
          -- L1 bounces between the top and bottom -- the page-at-a-time d-pad is
          -- slow on big libraries (1000+ games). At the top it jumps to the bottom;
          -- anywhere else it jumps to the top -- so repeated presses ping-pong. The
          -- cursor position itself is the state (no toggle to drift out of sync),
          -- and this leaves R1 free for the per-page rescan. (#499)
          if UI.Pad.Events.L1 then
            if UI.GameList.CURR == 1 then
              UI.GameList.CURR = ammount
            else
              UI.GameList.CURR = 1
            end
          end
          -- Right analog stick scrolls a description that's too long to fully fit
          -- under the cover (when game details are on). The stick is otherwise
          -- unused here (R3 is the click, separate), so this is a free, discoverable
          -- "read the rest" gesture. Rate-limited so a held stick scrolls steadily
          -- (~1 line / 90ms) instead of flying line-by-line every frame. DetailsTotal
          -- / DetailsVisible were set by the render block just above this frame.
          if UI.CoverCache ~= nil and (UI.GameList.DetailsTotal or 0) > (UI.GameList.DetailsVisible or 0)
             and type(Pads) == "table" and type(Pads.getRightStick) == "function" then
            local ok_rs, _, rv = pcall(Pads.getRightStick)
            if ok_rs and type(rv) == "number" and math.abs(rv) > 48 then
              local now = 0
              if UI.Pad.Timer ~= nil then now = Timer.getTime(UI.Pad.Timer) end
              if (now - (UI.GameList.DescScrollAt or 0)) >= 90 then
                local off = UI.CoverCache.desc_scroll or 0
                if rv > 0 then off = off + 1 else off = off - 1 end
                local max_off = (UI.GameList.DetailsTotal or 0) - (UI.GameList.DetailsVisible or 0)
                if off < 0 then off = 0 end
                if off > max_off then off = max_off end
                UI.CoverCache.desc_scroll = off
                UI.GameList.DescScrollAt = now
              end
            end
          end
        end
        if UI.Pad.Events.SQUARE then
          UI.CoverPreviewEnabled = not UI.CoverPreviewEnabled
          local now = 0
          if UI.Pad.Timer ~= nil then
            now = Timer.getTime(UI.Pad.Timer)
          end
          if UI.CoverPreviewEnabled then
            UI.GameList.CoverLastIndex = nil
            UI.GameList.CoverPending = true
            UI.GameList.CoverPendingAt = now - UI.GameList.CoverIdleMs
            UI.Notif_queue.add("Cover Art enabled", "ok")
          else
            if UI.CoverCache ~= nil then
              UI.CoverCache:UpdateSelection(nil)
            end
            UI.GameList.CoverPending = false
            UI.Notif_queue.add("Cover Art disabled", "ok")
          end
        end
        if UI.CoverCache ~= nil then
          local now = 0
          if UI.Pad.Timer ~= nil then
            now = Timer.getTime(UI.Pad.Timer)
          end
          local nav_event = UI.Pad.Events.NAV_DOWN or UI.Pad.Events.NAV_RIGHT or UI.Pad.Events.NAV_UP or UI.Pad.Events.NAV_LEFT
          if UI.CoverPreviewEnabled == false then
            UI.GameList.CoverPending = false
            UI.GameList.CoverPendingAt = now
            UI.CoverCache:UpdateSelection(nil)
          elseif ammount <= 0 then
            UI.GameList.CoverLastIndex = nil
            UI.GameList.CoverPending = false
            UI.GameList.CoverPendingAt = now
            UI.CoverCache:UpdateSelection(nil)
          else
            if UI.GameList.CURR ~= UI.GameList.CoverLastIndex then
              UI.GameList.CoverLastIndex = UI.GameList.CURR
              UI.GameList.CoverPending = true
              UI.GameList.CoverPendingAt = now
            end
            if UI.GameList.CoverPending and not nav_event and (now - UI.GameList.CoverPendingAt) >= UI.GameList.CoverIdleMs then
              local entry = PLDR.GAMES[UI.GameList.CURR]
              local vcd_path = ResolveSelectedVcdPath(entry, PLDR.GAMEPATH)
              UI.CoverCache:UpdateSelection(vcd_path, UI.CURSCENE == UI.SCENES.GHDD, entry)
              UI.GameList.CoverPending = false
            end
          end
        end
        local function LaunchSelectedGame(launch_options)
          if ammount <= 0 then
            UI.Notif_queue.add("No games found on this device", "warn")
            return
          end
          local configured_popstarter_path = tostring(PLDR.POPSTARTER_PATH or "")
          if type(PLDR.GetEffectiveConfiguredPopstarterPath) == "function" then
            configured_popstarter_path = tostring(PLDR.GetEffectiveConfiguredPopstarterPath(PLDR.POPSTARTER_PATH, PLDR.SELECTED_PROFILE) or configured_popstarter_path)
          end
          local popstarter_path = configured_popstarter_path
          if type(PLDR.ResolvePopstarterPath) == "function" then
            popstarter_path = PLDR.ResolvePopstarterPath(configured_popstarter_path)
          end
          local popstarter_ok = false
          if type(PLDR.PopstarterProbeWithEnsure) == "function" then
            popstarter_ok = PLDR.PopstarterProbeWithEnsure(popstarter_path)
          else
            popstarter_ok = doesFileExist(popstarter_path)
          end
          if not popstarter_ok then
            local message = "No POPSTARTER found at this path\n"..configured_popstarter_path
            if configured_popstarter_path ~= tostring(popstarter_path) then
              message = message.."\nResolved: "..tostring(popstarter_path)
            end
            UI.Notif_queue.add(message, "error")
            return
          end
          if type(launch_options) == "table" and launch_options.hdd_selector_mode == "full_hdd_pfs0" then
            local lowered_popstarter = string.lower(tostring(popstarter_path or ""))
            if string.match(lowered_popstarter, "^hdd%d:") == nil and string.match(lowered_popstarter, "^pfs%d*:/") == nil then
              UI.Notif_queue.add("HDD Alt mode needs POPSTARTER on HDD", "warn")
              return
            end
          end
          local entry = PLDR.GAMES[UI.GameList.CURR]
          if entry == nil then
            UI.Notif_queue.add("Couldn't read that game selection", "error")
            return
          end
          local root, rel = string.match(entry or "", "^([^|]+)|(.+)$")
          local vcd_full = ResolveSelectedVcdPath(entry, PLDR.GAMEPATH)
          if UI.CURSCENE ~= UI.SCENES.GHDD then -- only check if game can be found on USB and SMB
            if not doesFileExist(vcd_full) then
              UI.Notif_queue.add("Game file missing\n"..vcd_full, "error")
            end
          end
          local launch_path = PLDR.GAMEPATH
          if UI.CURSCENE == UI.SCENES.GHDD then
            launch_path = ""
          end
          if UI.CURSCENE == UI.SCENES.GHDD then
            PLDR.RunPOPStarterGame(launch_path, entry, UI.CURSCENE, launch_options)
          elseif root ~= nil then
            PLDR.RunPOPStarterGame(root, rel, UI.CURSCENE, launch_options)
          else
            PLDR.RunPOPStarterGame(launch_path, entry, UI.CURSCENE, launch_options)
          end
        end
        if UI.Pad.Events.CONFIRM then
          LaunchSelectedGame(nil)
        elseif UI.Pad.Events.R2 and UI.CURSCENE == UI.SCENES.GHDD then
          LaunchSelectedGame({ hdd_selector_mode = "full_hdd_pfs0" })
        elseif UI.Pad.Events.R1 and UI.CURSCENE == UI.SCENES.GHDD then
          UI.RunBusyTask("Refreshing HDD list...", function (report)
            local partition_progress = UI.MakeBusyProgressReporter(report, "Rescanning HDD partitions...", 0.10, 0.55)
            local game_progress = UI.MakeBusyProgressReporter(report, "Rebuilding HDD game list...", 0.55, 0.95)
            report("Refreshing HDD list...", 0.05)
            PLDR.HDD.EnsureGameList(partition_progress, game_progress, true)
            report("Done", 1.0)
          end, "Failed to refresh HDD list")
          UI.GameList.CURR = 1
          UI.GameList.CoverLastIndex = nil
          UI.GameList.CoverPending = false
          if #PLDR.GAMES < 1 then
            UI.Notif_queue.add("HDD list refreshed (no games found)", "warn")
          else
            UI.Notif_queue.add("HDD list refreshed", "ok")
          end
        elseif UI.Pad.Events.R1 and (UI.CURSCENE == UI.SCENES.GSMB
               or UI.CURSCENE == UI.SCENES.GMX4SIO
               or UI.CURSCENE == UI.SCENES.GUSBFAT) then
          -- R1 re-runs the SAME scan entering the page does, in place: re-detect
          -- the device and rebuild the list -- for hotplugging a card/drive or a
          -- config change without leaving the page. These devices keep no
          -- persistent cache (unlike HDD), so it's simply a fresh live scan.
          local rescan_scene = UI.CURSCENE
          UI.RunBusyTask("Refreshing list...", function (report)
            local scan = UI.MakeBusyProgressReporter(report, "Scanning games...", 0.30, 0.95)
            if rescan_scene == UI.SCENES.GSMB then
              report("Detecting MMCE device...", 0.16)
              if type(PLDR.DetectMMCESlot) == "function" then pcall(PLDR.DetectMMCESlot, true) end
              local mmce_prefix = (type(PLDR.MMCE) == "table" and PLDR.MMCE.PREFIX) or nil
              if mmce_prefix == nil and type(PLDR.SetMMCESlot) == "function" then
                mmce_prefix = PLDR.SetMMCESlot(1)
              end
              PLDR.CleanupGameList()
              if type(mmce_prefix) == "string" and mmce_prefix ~= "" and doesFolderExist(mmce_prefix.."POPS/") then
                report("Scanning MMCE games...", 0.30)
                PLDR.GetPS1GameLists(mmce_prefix.."POPS/", true, scan)
              end
            elseif rescan_scene == UI.SCENES.GMX4SIO then
              report("Refreshing mass backends...", 0.16)
              if type(PLDR.RefreshMassBackends) == "function" then pcall(PLDR.RefreshMassBackends) end
              if type(PLDR.SetMx4sioAutoEnterPending) == "function" then PLDR.SetMx4sioAutoEnterPending(true) end
              local mx4sio_root = PLDR.InitMX4SIOPopsRoot()
              if type(PLDR.SetMx4sioAutoEnterPending) == "function" then PLDR.SetMx4sioAutoEnterPending(false) end
              PLDR.CleanupGameList()
              if type(mx4sio_root) == "string" and mx4sio_root ~= "" then
                report("Scanning MX4SIO games...", 0.30)
                PLDR.GetPS1GameLists(mx4sio_root, true, scan)
              end
            else
              report("Initializing USB backend...", 0.16)
              if type(System) == "table" and type(System.ensureUsbMass) == "function" then pcall(System.ensureUsbMass) end
              if type(PLDR.RefreshMassBackends) == "function" then pcall(PLDR.RefreshMassBackends) end
              PLDR.CleanupGameList()
              report("Building USB game list...", 0.30)
              PLDR.BuildMassGameListByType("usb", nil, scan)
            end
            report("Done", 1.0)
          end, "Failed to refresh list")
          UI.GameList.CURR = 1
          UI.GameList.CoverLastIndex = nil
          UI.GameList.CoverPending = false
          if #PLDR.GAMES < 1 then
            UI.Notif_queue.add("List refreshed (no games found)", "warn")
          else
            UI.Notif_queue.add("List refreshed", "ok")
          end
        end
        if UI.Pad.Events.L3 and ammount > 0 then
          if PLDR.GLOBAL_HIDE then
            UI.Notif_queue.add("[Global Hide ON]\nTurn 'Hidden games' off in Settings to manage", "warn")
          elseif UI.CURSCENE == UI.SCENES.GHDD then
            local entry = PLDR.GAMES[UI.GameList.CURR]
            local was_hidden = PLDR.IsGameHidden(entry)
            local ok, reason = PLDR.SetHddGameHidden(entry, not was_hidden)
            if ok then
              UI.Notif_queue.add(was_hidden and "Game shown" or "Game hidden", "ok")
            else
              UI.Notif_queue.add("Couldn't write .hide to the HDD ("..tostring(reason or "")..").\nYou can still add a \"<game>.hide\" next to the .VCD from a PC.", "warn")
            end
          else
            local entry = PLDR.GAMES[UI.GameList.CURR]
            local vcd_path = ResolveSelectedVcdPath(entry, PLDR.GAMEPATH)
            local was_hidden = PLDR.IsGameHidden(entry)
            local ok, reason = PLDR.SetGameHidden(entry, vcd_path, not was_hidden)
            if ok then
              UI.Notif_queue.add(was_hidden and "Game shown" or "Game hidden", "ok")
            else
              UI.Notif_queue.add("Couldn't update hidden state ("..tostring(reason)..")", "error")
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
          square = "Cover Art",
          start = UI.Footer.labels.start_profiles,
          R2 = UI.CURSCENE == UI.SCENES.GHDD and ammount > 0 and "HDD Alt" or nil
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

        -- OPL-style focused-list Settings page.
        --
        -- Layout: title -> stack of items (section headers, cycle rows, path
        -- rows, action rows). A single highlight bar follows the focused row.
        -- Section headers are non-selectable separators. The footer just shows
        -- "Back / Select / Reset / Hide" -- the whole interaction is
        -- D-pad-driven so the previous one-button-per-field hotkey grid is
        -- gone (Square/L1/R1/Left/Right/Up/Down were each tied to a single
        -- widget; that has been replaced with a single focused cursor).
        --
        -- Bindings:
        --   D-pad Up/Down: move focus, skipping section headers and spacers.
        --   D-pad Left/Right: cycle the focused value (cycle items only).
        --   X (CONFIRM): activate focused item -- cycles a cycle row,
        --                opens the path editor for a path row, or fires the
        --                action for an action row.
        --   O (BACK): discard staged edits and return to the previous scene.
        --   Start (Reset Defaults): keep the legacy "Reset Defaults" shortcut.
        --   Select: hide-text toggle (global; handled outside this block).
        --
        -- Persistence: every field still routes through the same draft
        -- variables and PLDR.CommitSettingsChanges contract used by the
        -- previous Settings page, so S-01..S-09 and U-01..U-11 paths in
        -- QA_REGRESSION_MATRIX.md continue to apply unchanged.

        local safe = layout.SAFE or {L = 40, R = 40}

        local accent_color    = (UI.COLORS and UI.COLORS.TEXT_PRIMARY) or UI.CCOL.YELLOW
        local label_color     = UI.CCOL.GREY
        local muted_color     = Color.new(128, 128, 128, 110)
        local highlight_color = Color.new(50, 80, 160, 110)
        local separator_color = Color.new(140, 200, 255, 60)

        local TITLE_GAP = 22
        local SECTION_GAP_BEFORE = 10
        local SECTION_HEADER_H = 22
        local SPACER_H = 12
        local ROW_H = 22

        local SAFE_LEFT  = safe.L + 12
        local SAFE_RIGHT = UI.SCR.X - safe.R - 12
        local LABEL_X = safe.L + 28
        local LABEL_W = 240
        local VALUE_X = LABEL_X + LABEL_W + 24
        local VALUE_W = SAFE_RIGHT - VALUE_X - 12
        if VALUE_W < 80 then VALUE_W = 80 end

        local function TruncateMiddle(text, max_chars)
          local raw = tostring(text or "")
          if string.len(raw) <= max_chars then
            return raw
          end
          local keep_left = math.floor((max_chars - 3) / 2)
          local keep_right = (max_chars - 3) - keep_left
          return string.sub(raw, 1, keep_left).."..."..string.sub(raw, -keep_right)
        end

        local function CycleIndex(current, delta, count)
          if type(count) ~= "number" or count <= 0 then return current end
          local n = ((current - 1 + delta) % count) + 1
          return n
        end

        -- Session helpers (kept compatible with the previous Settings Play
        -- so external state machines using them stay correct).
        local function clear_settings_session()
          UI.SettingsReturnScene = nil
          UI.SettingsEntryHideTextMode = false
          UI.SettingsEntryKeyboardLayout = nil
          UI.SettingsFocus = 1
        end

        local function restore_settings_session()
          UI.SyncSettingsSelectionFromRuntime()
          UI.SyncSettingsDraftFromRuntime()
          UI.SetHideTextMode(UI.SettingsEntryHideTextMode == true, false)
          UI.ProfileDirty = false
          UI.BdmaDirty = false
          UI.PopPathDirty = false
          UI.PopPathProfileDefaultDirty = false
          UI.DkwdrvDirty = false
          UI.VideoStandardDirty = false
        end

        local function discard_settings_and_return()
          restore_settings_session()
          local return_scene = UI.GetSettingsReturnScene()
          clear_settings_session()
          UI.SceneChange(return_scene)
        end

        local function queue_exit(target_scene, allow_fallback_exit)
          UI.ShowSavingOverlay("Saving/Applying...", 0.08)
          local stage_progress = {
            prepare = 0.18,
            save = 0.42,
            apply_bdma = 0.76,
            finalize = 0.96
          }
          local function report_stage(stage, message)
            UI.ShowSavingOverlay(message or "Saving/Applying...", stage_progress[stage])
          end
          local save_token = nil
          if type(PLDR.NextBdmaApplyToken) == "function" then
            save_token = PLDR.NextBdmaApplyToken()
          else
            PLDR._bdma_apply_seq = (tonumber(PLDR._bdma_apply_seq) or 0) + 1
            save_token = "bdma:"..tostring(PLDR._bdma_apply_seq)
          end
          local profile_index = CLAMP(UI.ProfileQuery.curopt, 1, #PLDR.PROFILES)
          local pop_path = tostring(UI.PopstarterPathDraft or PLDR.POPSTARTER_PATH or "")
          local popstarter_mode = nil
          if UI.PopPathDirty == true then
            popstarter_mode = "CUSTOM"
          elseif UI.PopPathProfileDefaultDirty == true then
            popstarter_mode = "PROFILE_DEFAULT"
          elseif type(PLDR.GetEffectiveConfiguredPopstarterPath) == "function" then
            pop_path = tostring(PLDR.GetEffectiveConfiguredPopstarterPath(pop_path, profile_index) or pop_path)
          end
          local dkwdrv_path = tostring(UI.DkwdrvPathDraft or PLDR.DKWDRV_PATH or PLDR.DKWDRV_DEFAULT_PATH or "mc0:/PS1_DKWDRV/DKWDRV.ELF")
          local mode_entry = UI.BdmaModes[UI.BdmaModeIndex] or UI.BdmaModes[1]
          local mode_key = mode_entry and mode_entry.key or "FAT32"
          local video_entry = UI.VideoStandardModes[UI.VideoStandardIndex] or UI.VideoStandardModes[1]
          local video_key = video_entry and video_entry.key or VIDEO_STANDARD_NTSC
          local boot_page_entry = UI.BootPageModes[UI.BootPageIndex] or UI.BootPageModes[1]
          local boot_page_key = boot_page_entry and boot_page_entry.key or "Carousel"
          local multidisc_collapse_val = UI.MultiDiscCollapse == true
          local global_hide_val = UI.GlobalHide == true
          local show_details_val = UI.ShowDetails == true
          local video_live_before = nil
          if type(Screen) == "table" and type(Screen.getMode) == "function" then
            local okb, mb = pcall(Screen.getMode)
            if okb and type(mb) == "table" then video_live_before = mb.mode end
          end
          local video_standard_before = (type(PLDR) == "table") and PLDR.VIDEO_STANDARD or nil
          local ok_run, result, reason = xpcall(function()
            if type(PLDR.CommitSettingsChanges) == "function" then
              return PLDR.CommitSettingsChanges({
                profile = profile_index,
                popstarter_path = pop_path,
                popstarter_mode = popstarter_mode,
                dkwdrv_path = dkwdrv_path,
                bdma_mode = mode_key,
                video_standard = video_key,
                keyboard_layout = UI.KeyboardLayoutDraft or (type(PLDR) == "table" and PLDR.KEYBOARD_LAYOUT) or "QWERTY",
                boot_page = boot_page_key,
                hidden_devices = UI.DeviceHiddenDraft,
                multidisc_collapse = multidisc_collapse_val,
                global_hide = global_hide_val,
                show_details = show_details_val,
                hide_text = UI.HideTextMode == true,
                prev_hide_text = UI.SettingsEntryHideTextMode == true,
                apply_bdma = UI.BdmaDirty,
                bdma_token = save_token,
                on_stage = report_stage
              })
            end

            PLDR.SELECTED_PROFILE = profile_index
            if popstarter_mode ~= nil then
              PLDR.POPSTARTER_SELECTION_MODE = popstarter_mode
            end
            PLDR.POPSTARTER_PATH = pop_path
            PLDR.DKWDRV_PATH = dkwdrv_path
            PLDR.BDMA_MODE_KEY = mode_key
            PLDR.VIDEO_STANDARD = video_key
            if type(PLDR) == "table" and type(PLDR.NormalizeKeyboardLayout) == "function" then
              PLDR.KEYBOARD_LAYOUT = PLDR.NormalizeKeyboardLayout(UI.KeyboardLayoutDraft or PLDR.KEYBOARD_LAYOUT or "QWERTY")
            else
              PLDR.KEYBOARD_LAYOUT = UI.KeyboardLayoutDraft or PLDR.KEYBOARD_LAYOUT or "QWERTY"
            end
            PLDR.BOOT_PAGE = boot_page_key
            if type(UI.DeviceHiddenDraft) == "table" and type(PLDR.NormalizeHiddenDevices) == "function" then
              PLDR.HIDDEN_DEVICES = PLDR.NormalizeHiddenDevices(UI.DeviceHiddenDraft)
            end
            PLDR.COLLAPSE_MULTIDISC = multidisc_collapse_val
            PLDR.GLOBAL_HIDE = global_hide_val
            PLDR.SHOW_DETAILS = show_details_val
            if type(PLDR.ApplyVideoStandardRuntime) == "function" then
              PLDR.ApplyVideoStandardRuntime(video_key)
            end
            report_stage("save", "Saving settings")
            local saved = PLDR.SaveSettingsAtomic()
            local applied = true
            if saved and UI.BdmaDirty then
              report_stage("apply_bdma", "Applying BDMA mode")
              applied = PLDR.ApplyBdmaMode(mode_key)
            end
            if not saved then
              return false, "save_failed"
            end
            if not applied then
              return false, "bdma_apply_failed"
            end
            return true, nil
          end, function(e) return e end)
          UI.HideSavingOverlay()
          if ok_run and result == true then
            UI.ProfileDirty = false
            UI.BdmaDirty = false
            UI.PopPathDirty = false
            UI.PopPathProfileDefaultDirty = false
            UI.DkwdrvDirty = false
            UI.VideoStandardDirty = false
            clear_settings_session()
            -- HDD-write probe (TEST): on an HDD boot, report whether a __.POPS
            -- partition accepts a scoped write -- tells us if settings/.hide can
            -- live on the HDD. Settings already saved (to mc0: on HDD); this only
            -- reports. (nil return = not an HDD boot -> no toast.)
            if type(PLDR.ProbeHddSettingsWrite) == "function" then
              local hdd_w_ok, hdd_w_info = PLDR.ProbeHddSettingsWrite()
              if hdd_w_ok == true then
                UI.Notif_queue.add("HDD partition "..tostring(hdd_w_info).." is WRITABLE -- settings can live on HDD", "ok")
              elseif hdd_w_ok == false then
                UI.Notif_queue.add("HDD write test FAILED ("..tostring(hdd_w_info)..")\nsettings stay on the memory card", "warn")
              end
            end
            -- Display-change safety: if the GS mode actually switched, confirm it
            -- in the new mode and auto-revert if the user can't (invisible mode).
            if video_live_before ~= nil and type(Screen) == "table" and type(Screen.getMode) == "function" then
              local oka, ma = pcall(Screen.getMode)
              local video_live_after = (oka and type(ma) == "table") and ma.mode or nil
              if video_live_after ~= nil and video_live_after ~= video_live_before then
                local kept = true
                if type(UI.RunVideoModeConfirm) == "function" then
                  -- pcall: if the confirm modal itself errors, fall to REVERT
                  -- (back to the known-good mode) rather than crash the scene.
                  local ok_confirm, confirm_res = pcall(UI.RunVideoModeConfirm, 15)
                  kept = (ok_confirm == true) and (confirm_res == true)
                end
                if not kept and video_standard_before ~= nil then
                  PLDR.VIDEO_STANDARD = video_standard_before
                  if type(PLDR.ApplyVideoStandardRuntime) == "function" then
                    PLDR.ApplyVideoStandardRuntime(video_standard_before)
                  end
                  pcall(PLDR.SaveSettingsAtomic)
                  UI.Notif_queue.add("Display reverted -- new mode wasn't confirmed", "warn")
                end
              end
            end
            UI.SceneChange(target_scene)
          else
            if reason == "bdma_apply_failed" then
              UI.Notif_queue.add("BDMA mode change didn't apply\nsettings weren't saved", "error")
              UI.SyncSettingsSelectionFromRuntime()
              UI.SyncSettingsDraftFromRuntime()
            elseif reason == "save_failed" then
              UI.Notif_queue.add("Couldn't save settings\n"..tostring(PLDR.SETTINGS_PATH or "mc0:/POPSTARTER/.pldrs").." may be read-only"..((type(BOOT_MX4SIO_PROBE_RESULT) == "string" and BOOT_MX4SIO_PROBE_RESULT ~= "") and "\nmx4sio probe: "..BOOT_MX4SIO_PROBE_RESULT or ""), "error")
              UI.SyncSettingsSelectionFromRuntime()
              UI.SyncSettingsDraftFromRuntime()
            else
              UI.Notif_queue.add("Couldn't save settings\n"..tostring(PLDR.SETTINGS_PATH or "mc0:/POPSTARTER/.pldrs").." may be read-only"..((type(BOOT_MX4SIO_PROBE_RESULT) == "string" and BOOT_MX4SIO_PROBE_RESULT ~= "") and "\nmx4sio probe: "..BOOT_MX4SIO_PROBE_RESULT or ""), "error")
              UI.SyncSettingsSelectionFromRuntime()
              UI.SyncSettingsDraftFromRuntime()
            end
            if allow_fallback_exit == true then
              UI.ProfileDirty = false
              UI.BdmaDirty = false
              UI.PopPathDirty = false
              UI.PopPathProfileDefaultDirty = false
              UI.DkwdrvDirty = false
              UI.VideoStandardDirty = false
              clear_settings_session()
              UI.SceneChange(target_scene)
            end
          end
        end

        -- Field-specific helpers (used by item callbacks below).
        local function CycleProfile(delta)
          local next_opt = CycleIndex(UI.ProfileQuery.curopt, delta, profcnt)
          if next_opt ~= UI.ProfileQuery.curopt then
            UI.ProfileQuery.curopt = next_opt
            if not UI.PopPathDirty then
              local profile = PLDR.PROFILES[UI.ProfileQuery.curopt]
              UI.PopstarterPathDraft = tostring((profile and profile.ELF) or UI.PopstarterPathDraft or "")
              UI.PopPathProfileDefaultDirty = true
            end
            UI.ProfileDirty = true
          end
        end

        local keyboard_layouts = (UI.PathEditor and UI.PathEditor.layout_order) or {"QWERTY", "ABC", "DVORAK"}
        local function CurrentKeyboardLayoutIndex()
          local key = string.upper(tostring(UI.KeyboardLayoutDraft or "QWERTY"))
          for i = 1, #keyboard_layouts do
            if string.upper(tostring(keyboard_layouts[i])) == key then return i end
          end
          return 1
        end
        local function CycleKeyboardLayout(delta)
          local n = #keyboard_layouts
          if n <= 0 then return end
          local idx = CycleIndex(CurrentKeyboardLayoutIndex(), delta, n)
          UI.KeyboardLayoutDraft = keyboard_layouts[idx]
        end

        local function ResetDefaults()
          local default_profile = tonumber(PLDR.DEFAULT_PROFILE) or 1
          local next_default = CLAMP(default_profile, 1, profcnt)
          if next_default ~= UI.ProfileQuery.curopt then
            UI.ProfileQuery.curopt = next_default
            UI.ProfileDirty = true
          end
          local default_entry = PLDR.PROFILES[next_default]
          if default_entry ~= nil then
            UI.PopstarterPathDraft = tostring(default_entry.ELF or UI.PopstarterPathDraft or "")
            UI.PopPathDirty = false
            UI.PopPathProfileDefaultDirty = true
            UI.ProfileDirty = true
          end
          local default_dkw = tostring(PLDR.DKWDRV_DEFAULT_PATH or "mc0:/PS1_DKWDRV/DKWDRV.ELF")
          if UI.DkwdrvPathDraft ~= default_dkw then
            UI.DkwdrvPathDraft = default_dkw
            UI.DkwdrvDirty = true
            UI.ProfileDirty = true
          end
          if UI.BdmaModeIndex ~= 1 then
            UI.BdmaModeIndex = 1
            UI.BdmaDirty = true
          end
          if (UI.BootPageIndex or 1) ~= 1 then
            UI.BootPageIndex = 1
            UI.ProfileDirty = true
          end
          if UI.MultiDiscCollapse == true then
            UI.MultiDiscCollapse = false
            UI.ProfileDirty = true
          end
          if UI.GlobalHide == true then
            UI.GlobalHide = false
            UI.ProfileDirty = true
          end
          if UI.ShowDetails == true then
            UI.ShowDetails = false
            UI.ProfileDirty = true
          end
          local default_video_key = VIDEO_STANDARD_AUTO
          local default_video_index = 1
          for i = 1, #UI.VideoStandardModes do
            if UI.VideoStandardModes[i].key == default_video_key then
              default_video_index = i
              break
            end
          end
          if UI.VideoStandardIndex ~= default_video_index then
            UI.VideoStandardIndex = default_video_index
            UI.VideoStandardDirty = true
          end
          if UI.HideTextMode then
            UI.SetHideTextMode(false, false)
            UI.ProfileDirty = true
          end
          local default_keyboard_layout = "QWERTY"
          if type(PLDR) == "table" and type(PLDR.NormalizeKeyboardLayout) == "function" then
            default_keyboard_layout = PLDR.NormalizeKeyboardLayout(default_keyboard_layout)
          end
          if tostring(UI.KeyboardLayoutDraft or "") ~= tostring(default_keyboard_layout) then
            UI.KeyboardLayoutDraft = default_keyboard_layout
            UI.ProfileDirty = true
          end
          UI.Notif_queue.add("Profile defaults restored", "ok")
        end

        local function OpenPopstarterPathEditor()
          UI.PathEditor.Open("Edit POPStarter Path", UI.PopstarterPathDraft or "", function(path)
            UI.PopstarterPathDraft = tostring(path or "")
            UI.PopPathDirty = true
            UI.PopPathProfileDefaultDirty = false
            UI.ProfileDirty = true
          end)
        end

        local function OpenDkwdrvPathEditor()
          UI.PathEditor.Open("Edit DKWDRV Path", UI.DkwdrvPathDraft or "", function(path)
            UI.DkwdrvPathDraft = tostring(path or "")
            UI.DkwdrvDirty = true
            UI.ProfileDirty = true
          end)
        end

        local function KeyboardLayoutDirty()
          local current = string.upper(tostring(UI.KeyboardLayoutDraft or "QWERTY"))
          local entry = string.upper(tostring(UI.SettingsEntryKeyboardLayout or current))
          return current ~= entry
        end

        local function HideTextDirty()
          return (UI.HideTextMode == true) ~= (UI.SettingsEntryHideTextMode == true)
        end

        -- Build the items list. Sections and spacers are non-selectable
        -- markers; cycle/path/action items respond to focus + activation.
        local items = {}
        local function AddSection(label)
          table.insert(items, { kind = "section", label = label })
        end
        local function AddSpacer()
          table.insert(items, { kind = "spacer" })
        end
        local function AddCycle(label, get_value, prev_fn, next_fn, dirty_fn)
          table.insert(items, {
            kind = "cycle",
            label = label,
            value = get_value,
            prev = prev_fn,
            next = next_fn,
            dirty = dirty_fn
          })
        end
        local function AddInfo(label, get_value)
          -- Read-only status row (not focusable -- see IsSelectable). Surfaces
          -- live runtime state next to the relevant setting.
          table.insert(items, { kind = "info", label = label, value = get_value })
        end
        local function AddPath(label, get_value, open_fn, dirty_fn)
          table.insert(items, {
            kind = "path",
            label = label,
            value = get_value,
            open = open_fn,
            dirty = dirty_fn
          })
        end
        local function AddAction(label, activate_fn, accent)
          table.insert(items, {
            kind = "action",
            label = label,
            activate = activate_fn,
            accent = accent == true
          })
        end

        AddSection("Storage")
        local function CycleBdma(dir)
          local next_idx = CycleIndex(UI.BdmaModeIndex, dir, #UI.BdmaModes)
          local next_key = (UI.BdmaModes[next_idx] or {}).key
          -- BDMA/SMB modules must live in mc:/POPSTARTER. Can't ENABLE BDMA while that
          -- folder is disabled -- make the user turn it back on first.
          if next_key ~= nil and next_key ~= "FAT32" and PLDR.POPSTARTER_MC_FOLDER == false then
            UI.Notif_queue.add("Enable the POPSTARTER Folder first\n(BDMA / SMB modules must live on the memory card)", "warn")
            return
          end
          UI.BdmaModeIndex = next_idx
          UI.BdmaDirty = true
        end
        AddCycle(
          "BDMA Mode",
          function() return tostring((UI.BdmaModes[UI.BdmaModeIndex] or UI.BdmaModes[1] or {}).label or "") end,
          function() CycleBdma(-1) end,
          function() CycleBdma(1) end,
          function() return UI.BdmaDirty == true end
        )

        AddSection("Display")
        AddCycle(
          "Video Standard",
          function() return tostring((UI.VideoStandardModes[UI.VideoStandardIndex] or UI.VideoStandardModes[1] or {}).label or "") end,
          function()
            UI.VideoStandardIndex = CycleIndex(UI.VideoStandardIndex, -1, #UI.VideoStandardModes)
            UI.VideoStandardDirty = true
            UI.ProfileDirty = true
          end,
          function()
            UI.VideoStandardIndex = CycleIndex(UI.VideoStandardIndex,  1, #UI.VideoStandardModes)
            UI.VideoStandardDirty = true
            UI.ProfileDirty = true
          end,
          function() return UI.VideoStandardDirty == true end
        )
        -- Read-only: what the GS is ACTUALLY outputting right now, so a
        -- PAL-console user who selects NTSC can see whether the hardware
        -- really switched -- no -debug / launch args needed (GitHub #495).
        AddInfo(
          "Actual output",
          function()
            if type(Screen) ~= "table" or type(Screen.getMode) ~= "function" then
              return "(unknown)"
            end
            local ok, m = pcall(Screen.getMode)
            if not ok or type(m) ~= "table" or type(m.mode) ~= "number" then
              return "(unknown)"
            end
            local name = (m.mode == PAL) and "PAL"
              or (m.mode == NTSC) and "NTSC"
              or ("mode "..tostring(m.mode))
            return name.." "..tostring(UI.SCR.X or "?").."x"..tostring(UI.SCR.Y or "?")
          end
        )
        AddCycle(
          "Hide UI Text",
          function() return UI.HideTextMode and "Hidden" or "Visible" end,
          function() UI.SetHideTextMode(not UI.HideTextMode, false) end,
          function() UI.SetHideTextMode(not UI.HideTextMode, false) end,
          HideTextDirty
        )

        AddSection("Startup")
        AddCycle(
          "Boot Page",
          function() return tostring((UI.BootPageModes[UI.BootPageIndex] or UI.BootPageModes[1] or {}).label or "") end,
          function() UI.BootPageIndex = CycleIndex(UI.BootPageIndex, -1, #UI.BootPageModes) end,
          function() UI.BootPageIndex = CycleIndex(UI.BootPageIndex,  1, #UI.BootPageModes) end,
          function() return (UI.BootPageIndex or 1) ~= (UI.SettingsEntryBootPageIndex or 1) end
        )

        -- Carousel device visibility checklist: a Shown/Hidden row per main-menu
        -- device. Toggling hides/shows it on the carousel (all shown by default).
        AddSection("Carousel Devices")
        if type(PLDR) == "table" and type(PLDR.CAROUSEL_DEVICE_KEYS) == "table" then
          local function ToggleDevice(dkey)
            if type(UI.DeviceHiddenDraft) ~= "table" then UI.DeviceHiddenDraft = {} end
            if UI.DeviceHiddenDraft[dkey] then
              UI.DeviceHiddenDraft[dkey] = nil
            else
              local visible = 0
              for di = 1, #PLDR.CAROUSEL_DEVICE_KEYS do
                if not UI.DeviceHiddenDraft[PLDR.CAROUSEL_DEVICE_KEYS[di]] then visible = visible + 1 end
              end
              if visible <= 1 then
                UI.Notif_queue.add("At least one device must stay on the carousel", "warn")
                return
              end
              UI.DeviceHiddenDraft[dkey] = true
            end
            UI.ProfileDirty = true
          end
          for di = 1, #PLDR.CAROUSEL_DEVICE_KEYS do
            local dkey = PLDR.CAROUSEL_DEVICE_KEYS[di]
            local dlabel = (type(UI.MainMenu) == "table" and type(UI.MainMenu.opts) == "table" and UI.MainMenu.opts[di]) or dkey
            AddCycle(
              dlabel,
              function() return (type(UI.DeviceHiddenDraft) == "table" and UI.DeviceHiddenDraft[dkey]) and "Hidden" or "Shown" end,
              function() ToggleDevice(dkey) end,
              function() ToggleDevice(dkey) end,
              function()
                local d = (type(UI.DeviceHiddenDraft) == "table" and UI.DeviceHiddenDraft[dkey]) and true or false
                local e = (type(UI.SettingsEntryHiddenSet) == "table" and UI.SettingsEntryHiddenSet[dkey]) and true or false
                return d ~= e
              end
            )
          end
        end

        AddSection("Game List")
        AddCycle(
          "Multi-disc games",
          function() return UI.MultiDiscCollapse and "First disc only" or "Show all discs" end,
          function() UI.MultiDiscCollapse = not UI.MultiDiscCollapse end,
          function() UI.MultiDiscCollapse = not UI.MultiDiscCollapse end,
          function() return (UI.MultiDiscCollapse == true) ~= (UI.SettingsEntryMultiDiscCollapse == true) end
        )
        AddCycle(
          "Hidden games",
          function() return UI.GlobalHide and "Hidden" or "Visible (manage)" end,
          function() UI.GlobalHide = not UI.GlobalHide end,
          function() UI.GlobalHide = not UI.GlobalHide end,
          function() return (UI.GlobalHide == true) ~= (UI.SettingsEntryGlobalHide == true) end
        )
        AddCycle(
          "Game details",
          function() return UI.ShowDetails and "Shown" or "Hidden" end,
          function() UI.ShowDetails = not UI.ShowDetails end,
          function() UI.ShowDetails = not UI.ShowDetails end,
          function() return (UI.ShowDetails == true) ~= (UI.SettingsEntryShowDetails == true) end
        )

        AddSection("POPSTARTER")
        AddCycle(
          "Profile",
          function() return "Profile "..tostring(UI.ProfileQuery.curopt) end,
          function() CycleProfile(-1) end,
          function() CycleProfile( 1) end,
          function() return UI.ProfileDirty == true end
        )
        AddPath(
          "POPSTARTER Path",
          function() return TruncateMiddle(UI.PopstarterPathDraft or PLDR.POPSTARTER_PATH or "", 40) end,
          OpenPopstarterPathEditor,
          function() return UI.PopPathDirty == true or UI.PopPathProfileDefaultDirty == true end
        )
        AddPath(
          "DKWDRV Path",
          function() return TruncateMiddle(UI.DkwdrvPathDraft or PLDR.DKWDRV_PATH or PLDR.DKWDRV_DEFAULT_PATH or "mc0:/PS1_DKWDRV/DKWDRV.ELF", 40) end,
          OpenDkwdrvPathEditor,
          function() return UI.DkwdrvDirty == true end
        )
        AddCycle(
          "Keyboard Layout",
          function() return string.upper(tostring(UI.KeyboardLayoutDraft or "QWERTY")) end,
          function() CycleKeyboardLayout(-1) end,
          function() CycleKeyboardLayout( 1) end,
          KeyboardLayoutDirty
        )

        local function HasUnsavedChanges()
          return UI.ProfileDirty == true
            or UI.BdmaDirty == true
            or UI.PopPathDirty == true
            or UI.PopPathProfileDefaultDirty == true
            or UI.DkwdrvDirty == true
            or UI.VideoStandardDirty == true
            or HideTextDirty()
            or KeyboardLayoutDirty()
        end

        local function ToggleMcFolder()
          if PLDR.POPSTARTER_MC_FOLDER == false then
            PLDR.POPSTARTER_MC_FOLDER = true
            pcall(PLDR.EnsurePopstarterDir)
            pcall(PLDR.SaveSettingsAtomic)
            UI.Notif_queue.add("POPSTARTER folder restored on the memory card\n(set a BDMA mode to re-add the exFAT/SMB modules)", "ok")
            return
          end
          -- Only allowed while BDMA is off (FAT32/None): the BDMA + SMB modules live
          -- in this folder, so it can't be deleted while BDMA still needs it.
          local bdma_draft = (UI.BdmaModes[UI.BdmaModeIndex] or {}).key
          if (bdma_draft ~= nil and bdma_draft ~= "FAT32")
             or (PLDR.BDMA_MODE_KEY ~= nil and PLDR.BDMA_MODE_KEY ~= "FAT32") then
            UI.Notif_queue.add("Can't disable while BDMA is enabled\nSet BDMA Mode to FAT32 (None) first", "warn")
            return
          end
          local confirmed = UI.RunConfirm({
            "Delete the POPSTARTER folder from the memory card?",
            "",
            "This removes the POPSTARTER pack -- including the",
            "BDMA and SMB modules -- from mc0: / mc1:. They won't",
            "return until you turn this back On (or re-add them",
            "manually). Your POPSLoader settings are kept.",
          })
          if confirmed then
            PLDR.POPSTARTER_MC_FOLDER = false
            pcall(PLDR.SaveSettingsAtomic)
            pcall(PLDR.RemovePopstarterMcFolder)
            UI.Notif_queue.add("POPSTARTER folder deleted from the memory card", "warn")
          end
        end

        AddSpacer()
        AddAction("Save Changes",      function() queue_exit(UI.SCENES.MMAIN, true) end, true)
        AddAction("Reset Defaults",    function() ResetDefaults() end, false)
        AddAction("Discard & Exit",    function() discard_settings_and_return() end, false)
        AddSpacer()
        AddSection("Memory Card")
        AddCycle(
          "POPSTARTER Folder",
          function() return (PLDR.POPSTARTER_MC_FOLDER == false) and "Off (deleted)" or "On (default)" end,
          function() ToggleMcFolder() end,
          function() ToggleMcFolder() end,
          function() return false end
        )

        -- Focus normalization: clamp + skip non-selectable rows.
        local function IsSelectable(idx)
          local it = items[idx]
          return it ~= nil and it.kind ~= "section" and it.kind ~= "spacer"
            and it.kind ~= "info"
        end
        if type(UI.SettingsFocus) ~= "number" or UI.SettingsFocus < 1 or UI.SettingsFocus > #items then
          UI.SettingsFocus = 1
        end
        if not IsSelectable(UI.SettingsFocus) then
          for i = 1, #items do
            if IsSelectable(i) then UI.SettingsFocus = i; break end
          end
        end
        local function MoveFocus(delta)
          local n = #items
          if n == 0 then return end
          local cur = UI.SettingsFocus
          for _ = 1, n do
            cur = cur + delta
            if cur < 1 then cur = n
            elseif cur > n then cur = 1
            end
            if IsSelectable(cur) then
              UI.SettingsFocus = cur
              return
            end
          end
        end

        -- Compute total content height for top-Y placement.
        local total_h = 0
        for i = 1, #items do
          local it = items[i]
          if it.kind == "section" then
            total_h = total_h + SECTION_HEADER_H + (i > 1 and SECTION_GAP_BEFORE or 0)
          elseif it.kind == "spacer" then
            total_h = total_h + SPACER_H
          else
            total_h = total_h + ROW_H
          end
        end
        local footer_top_y = (layout.FOOTER_ICON_Y or (UI.SCR.Y - (layout.BTN_BAR_SAFE_BOTTOM or 56))) - 18
        local top_y = layout.TITLE_Y + TITLE_GAP
        if (top_y + total_h) > footer_top_y then
          top_y = footer_top_y - total_h
        end
        if top_y < (layout.TITLE_Y + TITLE_GAP) then
          top_y = layout.TITLE_Y + TITLE_GAP
        end

        -- Draw
        local function DrawHighlight(row_y)
          Graphics.drawRect(SAFE_LEFT, row_y - 2, SAFE_RIGHT - SAFE_LEFT, ROW_H, highlight_color)
        end

        local function DrawSection(label, row_y)
          Font.ftPrint(BFONT, LABEL_X, row_y, 0, UI.SCR.X, 16, label, accent_color)
          Graphics.drawRect(SAFE_LEFT, row_y + SECTION_HEADER_H - 4, SAFE_RIGHT - SAFE_LEFT, 1, separator_color)
        end

        local function DrawRow(it, row_y, focused)
          if focused and it.kind ~= "action" then
            DrawHighlight(row_y)
          end
          local label_text_color = focused and accent_color or label_color
          if it.kind == "action" then
            -- Action items are centered, accent-tinted when focused.
            local color = focused and accent_color or (it.accent and accent_color or label_color)
            if focused then DrawHighlight(row_y) end
            Font.ftPrint(BFONT, UI.SCR.X_MID, row_y, 8, UI.SCR.X, 16, it.label, color)
            return
          end
          Font.ftPrint(BFONT, LABEL_X, row_y, 0, LABEL_W, 16, it.label, label_text_color)
          local value_text = it.value and tostring(it.value() or "") or ""
          local dirty = (it.dirty and it.dirty()) == true
          local value_text_color
          if dirty then
            value_text_color = accent_color
          elseif it.kind == "path" or it.kind == "info" then
            value_text_color = muted_color
          else
            value_text_color = label_color
          end
          Font.ftPrint(BFONT, VALUE_X, row_y, 0, VALUE_W, 16, value_text, value_text_color)
          if focused and it.kind == "cycle" then
            -- Small left/right arrow chevrons hint at D-pad cycling.
            Font.ftPrint(BFONT, VALUE_X - 14, row_y, 0, 12, 16, "<", accent_color)
            Font.ftPrint(BFONT, SAFE_RIGHT - 8, row_y, 0, 12, 16, ">", accent_color)
          end
        end

        -- Focus-following scroll viewport. The page previously placed a fixed
        -- top-Y and, when the item stack was taller than the title->footer
        -- area, simply OVERFLOWED off-screen -- lower rows (Show Devices
        -- checkboxes, the Save/Reset/Discard actions) became unreachable.
        -- Precompute each item's content offset (variable row heights), then
        -- scroll only when needed so the focused row stays visible. When the
        -- content fits, item_off + base_y == the original y exactly, so the
        -- non-overflowing layout is unchanged.
        local view_top = layout.TITLE_Y + TITLE_GAP
        local view_h = footer_top_y - view_top
        local item_off = {}
        local item_h = {}
        do
          local acc = 0
          for i = 1, #items do
            local it = items[i]
            if it.kind == "section" and i > 1 then acc = acc + SECTION_GAP_BEFORE end
            item_off[i] = acc
            if it.kind == "section" then item_h[i] = SECTION_HEADER_H
            elseif it.kind == "spacer" then item_h[i] = SPACER_H
            else item_h[i] = ROW_H end
            acc = acc + item_h[i]
          end
        end
        local scrolling = total_h > view_h
        local scroll = 0
        local base_y = top_y
        if scrolling then
          base_y = view_top
          scroll = UI.SettingsScroll or 0
          local f = UI.SettingsFocus
          local f_off = item_off[f] or 0
          local f_h = item_h[f] or ROW_H
          if f_off < scroll then
            scroll = f_off
          elseif (f_off + f_h) > (scroll + view_h) then
            scroll = f_off + f_h - view_h
          end
          local max_scroll = total_h - view_h
          if scroll < 0 then scroll = 0 end
          if scroll > max_scroll then scroll = max_scroll end
          UI.SettingsScroll = scroll
        else
          UI.SettingsScroll = 0
        end

        for i = 1, #items do
          local it = items[i]
          local row_y = base_y + item_off[i] - scroll
          -- When scrolling, draw only fully-visible rows so nothing paints
          -- over the title or footer; when it fits, draw everything (original).
          local show = (not scrolling)
            or (row_y >= view_top and (row_y + item_h[i]) <= (footer_top_y + 1))
          if show then
            if it.kind == "section" then
              DrawSection(it.label, row_y)
            elseif it.kind == "spacer" then
              -- nothing to draw
            else
              DrawRow(it, row_y, UI.SettingsFocus == i)
            end
          end
        end

        -- Minimal scrollbar so "there's more below/above" is discoverable.
        if scrolling and total_h > 0 then
          local track_x = SAFE_RIGHT + 4
          local thumb_h = math.max(16, math.floor(view_h * view_h / total_h))
          local max_scroll = total_h - view_h
          local t = (max_scroll > 0) and (scroll / max_scroll) or 0
          local thumb_y = view_top + math.floor((view_h - thumb_h) * t)
          Graphics.drawRect(track_x, view_top, 2, view_h, separator_color)
          Graphics.drawRect(track_x, thumb_y, 2, thumb_h, accent_color)
        end

        Input_GetEvent()
        if UI.PathEditor.active then
          UI.PathEditor.HandleInput()
          UI.PathEditor.Draw()
          local labels, order = UI.Footer.ResolveLegend({
            order = UI.Footer.order_keyboard,
            order_id = "keyboard",
            circle = UI.Footer.labels.circle_other,
            cross = UI.Footer.labels.cross_confirm,
            square = UI.Footer.labels.square_backspace,
            start = "Save",
          })
          UI.Footer.Draw(labels, order)
          return
        end
        if UI.HandleGlobalInput(false) then return end

        if UI.Pad.Events.NAV_UP   then MoveFocus(-1) end
        if UI.Pad.Events.NAV_DOWN then MoveFocus( 1) end

        local focused_item = items[UI.SettingsFocus]
        if focused_item ~= nil then
          if UI.Pad.Events.NAV_LEFT then
            if focused_item.kind == "cycle" and focused_item.prev then focused_item.prev() end
          end
          if UI.Pad.Events.NAV_RIGHT then
            if focused_item.kind == "cycle" and focused_item.next then focused_item.next() end
          end
          if UI.Pad.Events.CONFIRM then
            if focused_item.kind == "cycle" and focused_item.next then
              focused_item.next()
            elseif focused_item.kind == "path" and focused_item.open then
              focused_item.open()
            elseif focused_item.kind == "action" and focused_item.activate then
              focused_item.activate()
              return
            end
          end
        end

        if UI.Pad.Events.BACK then
          if HasUnsavedChanges() then
            local return_scene = UI.GetSettingsReturnScene()
            UI.Modal.OpenSaveSettings(
              function() queue_exit(return_scene, true) end,
              function() discard_settings_and_return() end
            )
          else
            discard_settings_and_return()
          end
          return
        end
        if UI.Pad.Events.START then
          ResetDefaults()
        end

        local labels, order = UI.Footer.ResolveLegend({
          order = UI.Footer.order_settings_save,
          order_id = "settings_focus",
          circle = UI.Footer.labels.circle_other,
          cross = UI.Footer.labels.cross_select,
          start = UI.Footer.labels.start_reset,
          select = UI.Footer.labels.select_toggle
        })
        UI.Footer.Draw(labels, order)
      end;
    };
    MainMenu = {
      OPT = 1;
      opts = {"MMCE", "MX4SIO", "HDD (exFAT)", "HDD (PFS)", "USB", "i.Link", "SMB (v1)", "Disc (DKWDRV)"};
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
	          ["i.Link"] = "ILINK",
	          ["Disc (DKWDRV)"] = "DISC"
        }
        local icon_keys = {}
        for x = 1, #UI.MainMenu.opts do
          local opt = UI.MainMenu.opts[x]
          local key = icon_map[opt] or opt
          icon_keys[x] = key
        end
        -- Carousel device visibility: drive nav + render over the VISIBLE subset
        -- of opts so hidden devices are skipped with no gaps. With nothing hidden
        -- this is the identity list (behavior unchanged). visible_seq[pos] = real
        -- opts index; pos_of[real] = its position in the visible sequence.
        local visible_seq = {}
        local pos_of = {}
        for x = 1, #UI.MainMenu.opts do
          local dkey = (type(PLDR) == "table" and type(PLDR.CAROUSEL_DEVICE_KEYS) == "table") and PLDR.CAROUSEL_DEVICE_KEYS[x] or nil
          local is_hidden = (type(PLDR) == "table" and type(PLDR.IsDeviceHidden) == "function" and PLDR.IsDeviceHidden(dkey)) == true
          if not is_hidden then
            visible_seq[#visible_seq + 1] = x
            pos_of[x] = #visible_seq
          end
        end
        if #visible_seq == 0 then
          for x = 1, #UI.MainMenu.opts do visible_seq[x] = x; pos_of[x] = x end
        end
        profcnt = #visible_seq
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
          local sync_pos = pos_of[UI.MainMenu.OPT]
          if sync_pos == nil then
            -- OPT points at a now-hidden device -- snap to the first visible one
            -- and cancel any pending auto-enter so we don't enter the wrong device.
            sync_pos = 1
            carousel.allowOptWrite = true
            UI.MainMenu.OPT = visible_seq[1]
            carousel.allowOptWrite = false
            UI.MainMenu.PendingAutoEnter = false
          end
          carousel.currentIndex = sync_pos
          carousel.scrollPos = sync_pos
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
            UI.MainMenu.OPT = visible_seq[carousel.currentIndex] or visible_seq[1]
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
          return IMG[key] or IMG["missing"]
        end
        if not UI.MainMenu.icons_ready then
          for _, key in ipairs(icon_keys) do
            ResolveIcon(key)
          end
          UI.MainMenu.icons_ready = true
        end
        local function DrawIcon(index, x, y, color)
          local real = visible_seq[index]
          if real == nil then return end
          local key = icon_keys[real]
          local icon = ResolveIcon(key)
          if icon == nil then return end
          local icon_w = Graphics.getImageWidth(icon)
          local icon_h = Graphics.getImageHeight(icon)
          local pos_x = Round(x - (icon_w / 2))
          local pos_y = Round(y - (icon_h / 2))
          Graphics.drawImage(icon, pos_x, pos_y, color)
        end
        local first_icon = ResolveIcon(icon_keys[1] or "missing")
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
        if not UI.ShouldHideAuxText(UI.CURSCENE) then
          Font.ftPrint(UI.FONT.LABEL, UI.SCR.X_MID, top_y, 8, UI.SCR.X, 16, UI.MainMenu.opts[visible_seq[center_label_idx] or visible_seq[1]], UI.COLORS.TEXT_PRIMARY)
        end
        local status_y = top_y + 12
        local boot_label = UI.boot_device_label
        if (boot_label == nil or boot_label == "") and UI.boot_device ~= nil and UI.boot_device ~= DEVLOCK.NONE then
          boot_label = UI.device_lock_name(UI.boot_device)
        end
        if boot_label ~= nil and boot_label ~= "" and not UI.ShouldHideAuxText(UI.CURSCENE) then
          Font.ftPrint(UI.FONT.STATUS, UI.SCR.X_MID, status_y, 8, UI.SCR.X, 16, "Booted from: "..tostring(boot_label), UI.COLORS.TEXT_PRIMARY)
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
        -- One-shot auto-enter for -page/-mode without -game: open the device's
        -- game list directly instead of only pre-positioning the carousel
        -- (CosmicScale 2026-06-12: "-page=hdd highlights HDD but doesn't open
        -- the list"). Set by the launch-arg block in system.lua. Fire only once
        -- the carousel has settled on the launch-arg page (OPT is final) by
        -- synthesizing a single CONFIRM, which the dispatch below turns into the
        -- normal device-entry (load + SceneChange). This runs past the
        -- _draw_only return above, so it never fires during the welcome splash.
        if UI.MainMenu.PendingAutoEnter and not carousel.animActive then
          UI.MainMenu.PendingAutoEnter = false
          UI.Pad.Events.CONFIRM = true
        end
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
	            local ok = UI.RunBusyTask("Loading MMCE...", function (report)
              local scan_progress = UI.MakeBusyProgressReporter(report, "Scanning MMCE games...", 0.48, 0.88)
	              report("Detecting MMCE device...", 0.18)
	              if type(PLDR.DetectMMCESlot) == "function" then
	                pcall(PLDR.DetectMMCESlot, true)
	              end
              local slots = PLDR.GetMMCESlots()
              if #slots < 1 then
                UI.Notif_queue.add("No MMCE device detected\nchecked mmce0: and mmce1:", "warn")
                PLDR.CleanupGameList()
                PLDR.GAMEPATH = ""
                UI.SceneChange(UI.SCENES.GSMB)
                return
              end
              report("Preparing MMCE list...", 0.42)
              if PLDR.MMCE.PREFIX == nil then
                PLDR.SetMMCESlot(1)
              end
              local mmce_prefix = PLDR.MMCE.PREFIX or PLDR.SetMMCESlot(1)
              if mmce_prefix == nil then
                UI.Notif_queue.add("No MMCE device detected\nchecked mmce0: and mmce1:", "warn")
                return
              end
	              PLDR.CleanupGameList()
	              local mmce_pops = mmce_prefix.."POPS/"
	              if doesFolderExist(mmce_pops) then
	                report("Scanning MMCE games...", 0.48)
	                PLDR.GetPS1GameLists(mmce_pops, true, scan_progress)
	              else
	                UI.Notif_queue.add("MMCE has no POPS folder\nexpected mmce0:/POPS/", "warn")
	              end
              report("Opening MMCE list...", 1.0)
              UI.SceneChange(UI.SCENES.GSMB)
            end, "Failed to load MMCE")
            if not ok then return end
	          elseif UI.MainMenu.OPT == 2 then
	            local ok = UI.RunBusyTask("Loading MX4SIO...", function (report)
              local scan_progress = UI.MakeBusyProgressReporter(report, "Scanning MX4SIO games...", 0.48, 0.9)
	              report("Refreshing mass backends...", 0.18)
	              PLDR.CleanupGameList()
	              PLDR.GAMEPATH = ""
              -- MX4SIO crash-marker: its probe lives in a vendored IOP driver
              -- that can BLOCK with no card. Mark "pending" before the probe;
              -- if we hang in there the marker survives, and the next boot's
              -- Boot-Page auto-enter skips MX4SIO (see system.lua). Cleared as
              -- soon as the probe returns -- it returns on a no-card result, just
              -- never on a hang -- so only a genuine stall leaves it set.
              if type(PLDR.SetMx4sioAutoEnterPending) == "function" then
                PLDR.SetMx4sioAutoEnterPending(true)
              end
              if type(PLDR.RefreshMassBackends) == "function" then
                pcall(PLDR.RefreshMassBackends)
              end
              report("Locating MX4SIO POPS folder...", 0.42)
              local mx4sio_root = PLDR.InitMX4SIOPopsRoot()
              if type(PLDR.SetMx4sioAutoEnterPending) == "function" then
                PLDR.SetMx4sioAutoEnterPending(false)
              end
              if mx4sio_root == nil then
                UI.Notif_queue.add("No MX4SIO device detected", "warn")
                return
	              end
	              report("Scanning MX4SIO games...", 0.48)
	              PLDR.CleanupGameList()
	              PLDR.GetPS1GameLists(mx4sio_root, true, scan_progress)
	              report("Opening MX4SIO list...", 1.0)
	              UI.SceneChange(UI.SCENES.GMX4SIO)
            end, "Failed to load MX4SIO")
            if not ok then return end
          elseif UI.MainMenu.OPT == 3 then
            UI.Notif_queue.add("This backend isn't implemented yet", "warn")
	          elseif UI.MainMenu.OPT == 4 then
	            local ok = UI.RunBusyTask("Loading HDD...", function (report)
              local partition_progress = UI.MakeBusyProgressReporter(report, "Scanning HDD partitions...", 0.42, 0.66)
              local game_progress = UI.MakeBusyProgressReporter(report, "Building HDD game list...", 0.68, 0.92)
	              report("Loading HDD modules...", 0.14)
	              PLDR.LoadHDDModules()
	              if UI.LASTSCENE ~= UI.SCENES.GHDD then
                PLDR.CleanupGameList()
              end
              if PLDR.HDD.STATUS == 0 then
	                report("Scanning HDD partitions...", 0.42)
	                local hdd_list_src = PLDR.HDD.EnsureGameList(partition_progress, game_progress, false)
	                if (hdd_list_src == "disk" or hdd_list_src == "memo") and not PLDR.HDD._hinted then
	                  PLDR.HDD._hinted = true
	                  UI.Notif_queue.add("HDD list loaded from cache (R1 rescans)", "ok")
	                end
	                if not PLDR.HDD.FOUNDANY then
	                  UI.Notif_queue.add("No '__.POPS' partitions on hdd0:\nformat one with __.POPS / __.POPS0...9", "warn")
	                elseif #PLDR.GAMES < 1 then
                  UI.Notif_queue.add("No games found on hdd0:\n(__.POPS partitions are empty)", "warn")
                end
              else
                UI.Notif_queue.add("HDD not usable\nstatus: "..PLDR.HDD.STATUS, "error")
              end
              report("Opening HDD list...", 1.0)
              UI.SceneChange(UI.SCENES.GHDD)
            end, "Failed to load HDD")
            if not ok then return end
	          elseif UI.MainMenu.OPT == 5 then
	            local ok = UI.RunBusyTask("Loading USB...", function (report)
              local build_progress = UI.MakeBusyProgressReporter(report, "Building USB game list...", 0.44, 0.88)
              local retry_progress = UI.MakeBusyProgressReporter(report, "Retrying USB scan...", 0.9, 0.97)
	              report("Initializing USB backend...", 0.16)
	              if type(System) == "table" and type(System.ensureUsbMass) == "function" then
	                System.ensureUsbMass()
              end
              if type(PLDR.RefreshMassBackends) == "function" then
                pcall(PLDR.RefreshMassBackends)
              end
              report("Checking USB roots...", 0.38)
              PLDR.CleanupGameList()
              PLDR.GAMEPATH = ""
              local usb_roots = PLDR.GetRootsByType("usb")
              if usb_roots == nil or #usb_roots < 1 then
                if type(System) == "table" and type(System.ensureUsbMass) == "function" then
                  System.ensureUsbMass()
                end
                if type(PLDR.RefreshMassBackends) == "function" then
                  pcall(PLDR.RefreshMassBackends)
                end
                usb_roots = PLDR.GetRootsByType("usb")
              end
	              if usb_roots == nil or #usb_roots < 1 then
	                UI.Notif_queue.add("No USB backend detected\nreseat the drive and try again", "warn")
	              end
	              report("Building USB game list...", 0.44)
	              local games = PLDR.BuildMassGameListByType("usb", nil, build_progress)
	              if (games == nil or #games < 1) and usb_roots ~= nil and #usb_roots > 0 then
	                report("Retrying USB scan...", 0.9)
	                if type(System) == "table" and type(System.ensureUsbMass) == "function" then
	                  System.ensureUsbMass()
                end
	                if type(PLDR.RefreshMassBackends) == "function" then
	                  pcall(PLDR.RefreshMassBackends)
	                end
	                games = PLDR.BuildMassGameListByType("usb", nil, retry_progress)
	              end
	              report("Opening USB list...", 1.0)
              UI.SceneChange(UI.SCENES.GUSBFAT)
            end, "Failed to load USB")
            if not ok then return end
	          elseif UI.MainMenu.OPT == 6 then
	            UI.Notif_queue.add("This backend isn't implemented yet", "warn")
	          elseif UI.MainMenu.OPT == 7 then
	            UI.Notif_queue.add("This backend isn't implemented yet", "warn")
	          elseif UI.MainMenu.OPT == 8 then
	            if type(System) == "table" and type(System.ensureCDFS) == "function" then
	              System.ensureCDFS()
	            end
	            UI.Modal.OpenDKWDRV()
	          end
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
        L1 = false,
        R1 = false,
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
        UI.Pad.Events.L1 = false
        UI.Pad.Events.R1 = false
        UI.Pad.Events.R2 = false
        UI.Pad.Events.L2 = false
        UI.Pad.Events.L3 = false
        UI.Pad.Events.R3 = false
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
        if (pressed & PAD_L1) ~= 0 then emit_action("L1") end
        if (pressed & PAD_R1) ~= 0 then emit_action("R1") end
        if (pressed & PAD_R2) ~= 0 then emit_action("R2") end
        if (pressed & PAD_L2) ~= 0 then emit_action("L2") end
        if (pressed & PAD_L3) ~= 0 then emit_action("L3") end
        if (pressed & PAD_R3) ~= 0 then emit_action("R3") end

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
Scripts by nuno6573 and Ripto
Based on Enceladus by Daniel Santos
Testing by P4NCHOL1NO, VizoR, provato,
nuno6573, oldman63, and Community

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
function UI.GetDisplayRefreshHz()
  local mode = UI.VideoStandardModes[UI.VideoStandardIndex] or UI.VideoStandardModes[1]
  if mode ~= nil and type(mode.fps) == "number" and mode.fps > 0 then
    return mode.fps
  end
  return 60
end
function UI.ApplyVideoStandardFromRuntime(video_standard)
  local requested = tostring(video_standard or (PLDR and PLDR.VIDEO_STANDARD) or VIDEO_STANDARD_NTSC)
  local selected = UI.VideoStandardModes[1]
  local selected_index = 1
  for i = 1, #UI.VideoStandardModes do
    if tostring(UI.VideoStandardModes[i].key or "") == requested then
      selected = UI.VideoStandardModes[i]
      selected_index = i
      break
    end
  end
  local req_mode = selected.mode or NTSC
  local req_width = tonumber(selected.width) or 640
  local req_height = tonumber(selected.height) or 448
  UI.VideoStandardIndex = selected_index
  UI.VideoStandardDirty = false
  -- Decide whether to switch from the LIVE GS mode, not UI.SCR.VMODE. The GS
  -- boots in the console's BIOS region, so on a PAL console the live mode is PAL
  -- even though VMODE was seeded NTSC from the setting -- trusting that software
  -- belief is the bug where "NTSC set" still displayed PAL. Only skip the switch
  -- when the real GS already matches the request.
  local live_mode = nil
  if type(Screen) == "table" and type(Screen.getMode) == "function" then
    local ok_live, live = pcall(Screen.getMode)
    if ok_live and type(live) == "table" and type(live.mode) == "number" then
      live_mode = live.mode
    end
  end
  if VIDEO_BOOT_APPLIED and UI.SCR.VMODE == req_mode and live_mode == req_mode
     and UI.SCR.X == req_width and UI.SCR.Y == req_height then
    return
  end
  VIDEO_BOOT_APPLIED = true
  UI.SCR.VMODE = req_mode
  UI.SCR.X = req_width
  UI.SCR.Y = req_height
  UI.RecalcLayout()
  if type(Screen) == "table" and type(Screen.setMode) == "function" then
    pcall(Screen.setMode, UI.SCR.VMODE, UI.SCR.X, UI.SCR.Y, CT24, INTERLACED, FIELD)
    -- Readback (GitHub #495): did the GS actually flip to the requested mode?
    -- NTSC=2, PAL=3. gsKit's init_screen calls SetGsCrt every time, so the CRTC
    -- SHOULD re-latch -- this confirms it on hardware. got==req but a PAL TV
    -- still showing PAL = the display won't lock to forced NTSC (no code fix);
    -- got~=req = the re-latch genuinely failed. Always recorded (cheap); only
    -- SHOWN under -debug, via PLDR.SurfaceLaunchArgsDebug.
    local got_mode = -1
    if type(Screen.getMode) == "function" then
      local ok_rb, rb = pcall(Screen.getMode)
      if ok_rb and type(rb) == "table" and type(rb.mode) == "number" then
        got_mode = rb.mode
      end
    end
    local free_vram = -1
    if type(Screen.getFreeVRAM) == "function" then
      local ok_v, v = pcall(Screen.getFreeVRAM)
      if ok_v and type(v) == "number" then free_vram = v end
    end
    UI.VIDEO_READBACK = string.format("req=%d got=%d free=%d %dx%d",
      req_mode, got_mode, free_vram, UI.SCR.X, UI.SCR.Y)
  end
end
-- Generic blocking yes/no confirm (X = Yes, O = No). `lines` = array of text lines.
-- Frame-paced + button-release-gated like RunVideoModeConfirm; defaults to NO on a
-- ~30s timeout so a destructive prompt can never auto-confirm itself.
function UI.RunConfirm(lines)
  if type(Screen) ~= "table" or type(Screen.flip) ~= "function"
     or type(Pads) ~= "table" or type(Pads.get) ~= "function" then
    return false
  end
  if type(lines) ~= "table" then lines = { tostring(lines or "") } end
  local settle = 0
  while settle < 30 do
    local okp, gp = pcall(Pads.get)
    if settle >= 8 and okp and type(gp) == "number" and (gp & (PAD_CROSS | PAD_CIRCLE)) == 0 then break end
    Screen.flip()
    settle = settle + 1
  end
  local f, total = 0, 30 * 60
  while f < total do
    Screen.clear(UI.SCR.BGCOL or Color.new(20, 30, 80))
    local y = UI.SCR.Y_MID - (#lines * 11) - 24
    for i = 1, #lines do
      Font.ftPrint(SFONT, UI.SCR.X_MID, y, 8, UI.SCR.X, 16, tostring(lines[i] or ""), UI.CCOL.GREY)
      y = y + 22
    end
    Font.ftPrint(BFONT, UI.SCR.X_MID, y + 16, 8, UI.SCR.X, 24, "X = Yes      O = No", UI.CCOL.YELLOW)
    Screen.flip()
    f = f + 1
    local okp, gp = pcall(Pads.get)
    if okp and type(gp) == "number" then
      if (gp & PAD_CROSS) ~= 0 then return true end
      if (gp & PAD_CIRCLE) ~= 0 then return false end
    end
  end
  return false
end

-- Display-change safety net: after a video-mode switch, confirm it IN THE NEW
-- mode and auto-revert if the user can't confirm (e.g. the new mode shows nothing
-- on their display). Mirrors OPL's "keep this video mode?" prompt. Blocking; uses
-- the same draw+flip+pad-poll pattern as the boot splash. Returns true = keep.
function UI.RunVideoModeConfirm(seconds)
  if type(Screen) ~= "table" or type(Screen.flip) ~= "function"
     or type(Pads) ~= "table" or type(Pads.get) ~= "function" then
    return true
  end
  -- Frame-paced (count Screen.flip), NOT clock()-paced. clock()/vsync is unstable
  -- for a moment right after Screen.setMode, which made the old Timer-based countdown
  -- jump (14 -> 2) and auto-revert in 1-3s on PAL CRTs (provato). Counting flips is
  -- immune to that, and Screen.flip's vsync provides the pacing.
  local FPS = 60
  local total_frames = (tonumber(seconds) or 15) * FPS
  -- Let the freshly-switched GS settle (>= ~0.5s), AND wait for the Save X/O to
  -- release so a still-held button isn't read as an instant confirm/revert.
  local settle = 0
  while settle < 90 do
    local okp, gp = pcall(Pads.get)
    if settle >= 30 and okp and type(gp) == "number" and (gp & (PAD_CROSS | PAD_CIRCLE)) == 0 then break end
    Screen.flip()
    settle = settle + 1
  end
  local f = 0
  while f < total_frames do
    local remaining = math.max(0, math.ceil((total_frames - f) / FPS))
    Screen.clear(UI.SCR.BGCOL or Color.new(20, 30, 80))
    Font.ftPrint(LFONT, UI.SCR.X_MID, UI.SCR.Y_MID - 70, 8, UI.SCR.X, 32, "Keep this display mode?", UI.CCOL.YELLOW)
    Font.ftPrint(BFONT, UI.SCR.X_MID, UI.SCR.Y_MID, 8, UI.SCR.X, 24, "X = Keep      O = Revert", UI.CCOL.GREY)
    Font.ftPrint(SFONT, UI.SCR.X_MID, UI.SCR.Y_MID + 54, 8, UI.SCR.X, 16, "Reverting in "..tostring(remaining).."s if not confirmed", UI.CCOL.GREY)
    Screen.flip()
    f = f + 1
    local okp, gp = pcall(Pads.get)
    if okp and type(gp) == "number" then
      if (gp & PAD_CROSS) ~= 0 then return true end
      if (gp & PAD_CIRCLE) ~= 0 then return false end
    end
  end
  return false
end
function UI.SyncSettingsDraftFromRuntime()
  if type(PLDR) == "table" and type(PLDR.GetEffectiveConfiguredPopstarterPath) == "function" then
    UI.PopstarterPathDraft = tostring(PLDR.GetEffectiveConfiguredPopstarterPath(PLDR.POPSTARTER_PATH, PLDR.SELECTED_PROFILE) or "")
  else
    UI.PopstarterPathDraft = tostring(PLDR.POPSTARTER_PATH or "")
  end
  UI.DkwdrvPathDraft = tostring(PLDR.DKWDRV_PATH or PLDR.DKWDRV_DEFAULT_PATH or "mc0:/PS1_DKWDRV/DKWDRV.ELF")
  if type(PLDR) == "table" and type(PLDR.NormalizeKeyboardLayout) == "function" then
    UI.KeyboardLayoutDraft = PLDR.NormalizeKeyboardLayout(PLDR.KEYBOARD_LAYOUT)
  else
    UI.KeyboardLayoutDraft = tostring(PLDR.KEYBOARD_LAYOUT or "QWERTY")
  end
  UI.PopPathDirty = false
  UI.PopPathProfileDefaultDirty = false
  UI.DkwdrvDirty = false
  UI.VideoStandardDirty = false
end
function UI.SyncSettingsSelectionFromRuntime()
  if type(PLDR.ReconcileBdmaModeWithEffectiveState) == "function" then
    PLDR.ReconcileBdmaModeWithEffectiveState()
  end
  local mode_key = PLDR.BDMA_MODE_KEY or "FAT32"
  UI.BdmaModeIndex = 1
  for i = 1, #UI.BdmaModes do
    if UI.BdmaModes[i].key == mode_key then
      UI.BdmaModeIndex = i
      break
    end
  end
  if type(UI.ApplyVideoStandardFromRuntime) == "function" then
    UI.ApplyVideoStandardFromRuntime(PLDR.VIDEO_STANDARD)
  end
  local selected_profile = tonumber(PLDR.SELECTED_PROFILE) or tonumber(PLDR.DEFAULT_PROFILE) or 1
  UI.ProfileQuery.curopt = CLAMP(selected_profile, 1, #PLDR.PROFILES)
end
UI.SyncSettingsDraftFromRuntime()
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
