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
    local okfd, fd = pcall(System.openFile, path, FREAD)
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
-- PS2 alpha is 0-128 (128 = fully opaque), and alpha is the right lever because it
-- moves the row strictly toward whatever is behind it; changing RGB would help on a
-- dark backdrop and hurt on a light one.
--
-- SECOND tuning pass. sAGA asked for this once (#536, which set 34/80 from a much
-- stronger shade) and again on 2026-07-28 after testing RR74: "the names of the
-- hidden games need to be made even fainter (even fainter)". Unselected drops
-- 34 -> 20, i.e. ~41% less opaque again and about 16% of full; selected drops
-- 80 -> 68, a smaller step on purpose.
--
-- The asymmetry is deliberate and is the constraint to respect if this is tuned a
-- THIRD time: the unselected rows are the clutter being complained about, but the
-- SELECTED hidden row is how you find a game in order to press L3 and un-hide it.
-- Drive that one too low and the manage view stops being usable at all -- so take
-- any further reduction out of the unselected value first.
local LIST_HIDDEN_COLOR = Color.new(80, 82, 104, 20)
local LIST_HIDDEN_SELECTED_COLOR = Color.new(132, 134, 162, 68)
local function StripVcdExtension(name)
  local s = tostring(name or "")
  return (string.gsub(s, "%.[Vv][Cc][Dd]$", ""))
end
-- Remove a Redump/No-Intro disc marker -- "(Disc N)", "[Disc N]", "(Disk N)", "(CD N)",
-- "(Disc N of M)" -- from an ALREADY-extension-stripped display name. DISPLAY/lookup only;
-- the launch path keeps the full marked name. Mirrors the BRACKETED-ONLY grammar of
-- system.lua IsSecondaryDisc (a bare "... Disc N" suffix is deliberately NOT touched --
-- that was a 19-false-positive trap). The whole bracket group is consumed so "(Disc 1 of
-- 2)" and a mid-name "(Disc 1) (Leon)" both clean up; leftover/edge spaces are tidied.
local function StripDiscMarker(name)
  local s = tostring(name or "")
  s = string.gsub(s, "[%(%[]%s*[Dd][Ii][Ss][CcKk]%s*%d+[^%)%]]*[%)%]]", " ")
  s = string.gsub(s, "[%(%[]%s*[Cc][Dd]%s*%d+[^%)%]]*[%)%]]", " ")
  s = string.gsub(s, "%s+", " ")
  s = string.gsub(s, "^%s+", "")
  s = string.gsub(s, "%s+$", "")
  return s
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
  local partition, relpath = string.match(candidate, "^([^|]+)|(.+)$")
  -- Partition-installed game: art + details .txt are named after the game (the
  -- partition name minus its 3-char prefix, matching POPStarter's own
  -- __common/POPS/<name> asset convention), never "IMAGE0".
  if relpath ~= nil and type(PLDR) == "table" and type(PLDR.IsPartitionInstalledHddEntry) == "function"
     and PLDR.IsPartitionInstalledHddEntry(partition, relpath) then
    return string.sub(partition, 4)
  end
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
      -- EXACT game filename ONLY (maintainer directive, EXP71): APA/Partition art
      -- lives ONLY at hdd0:__common/POPS/ART/<gamefilename>_COV.png. No
      -- disc-marker-stripped family name, no legacy variants -- a stripped
      -- candidate could shadow the exact per-disc art, and every extra probe is
      -- a full dir walk on a big ART folder. Fast hit, or graceful skip. The
      -- resolver existence-confirms the file.
      local rc = PLDR.ResolveHddPartitionReadablePath("hdd0:__common", "POPS/ART/"..basename.."_COV.png")
      if rc ~= nil then return { rc } end
      return {}
    end
    return {}
  end
  if vcd_path == nil or vcd_path == "" then
    return {}
  end
  local base = StripExtension(vcd_path)
  -- ONE directory, EXACT filename (maintainer directive, EXP71): art is read
  -- ONLY from <device>:/ART/<gamefilename>_COV.png (APA/PFS:
  -- hdd0:__common/POPS/ART/<gamefilename>_COV.png, branch above). The
  -- 2026-07-23 additive legacy families and the disc-marker-stripped family
  -- name are all gone: every extra candidate is a full dir-chain walk on a
  -- large ART folder, and the stripped name could shadow exact per-disc art.
  -- Fast hit, or graceful skip (the memo + placeholder path handles absence);
  -- probes stay bounded single fopens off the render thread.
  local dir, name = string.match(base, "^(.*/)([^/]+)$")
  if dir == nil then dir, name = "", base end
  -- %w+ accepts letters and digits in any order and still stops at the colon
  -- (mx4sio0: has a digit in the NAME; the old %a+%d*: matched nothing there).
  local devroot = string.match(dir, "^(%w+:/)")
  local artdir = (devroot or dir).."ART/"
  -- EXACT game filename ONLY (maintainer directive, EXP71): <device>:/ART/
  -- <gamefilename>_COV.png. The disc-marker-stripped family name is GONE --
  -- tried first, it could shadow the exact per-disc art.
  return { artdir..name.."_COV.png" }
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
  pending = nil,     -- EXP49: in-flight async cover load {key,candidates,idx,token,started}
  token = 0,         -- EXP49: request id, so a late result for an old selection is dropped
  last_key = nil,
  last_img = nil,
  last_desc = nil,
  last_desc_lines = nil,
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
  self.pending = nil     -- EXP49: abandon any in-flight load; its result will be dropped as stale
  self.last_key = nil
  self.last_img = nil
  self.last_desc = nil
  self.last_desc_lines = nil
  self.desc_scroll = 0
end
-- EXP33: scene-exit cleanup that FREES decoded covers (memory) but KEEPS the
-- negative-miss memo (self.failed). Re-entering the same device then skips the
-- re-probe of covers already known absent -- each miss is a full FAT dir-chain
-- walk on SD-over-SIO2 / USB 1.1, which is the "exit and re-enter MX4SIO stalls"
-- report. self.failed is keyed by full path, so a different device (or an R1
-- refresh, which calls the full Clear) never collides. last_img is freed here,
-- so it MUST be dropped, not kept.
function CoverCache:ReleaseTextures()
  local free_ok = type(Graphics) == "table" and type(Graphics.freeImage) == "function"
  for key, img in pairs(self.entries) do
    if free_ok then pcall(Graphics.freeImage, img) end
    self.entries[key] = nil
  end
  self.order = {}
  self.last_key = nil
  self.last_img = nil
  self.last_desc = nil
  self.last_desc_lines = nil
  self.desc_scroll = 0
  -- self.failed intentionally preserved: it reflects on-disk state keyed by absolute
  -- path, so re-entering the SAME device skips re-probing covers already known absent;
  -- a different device uses different paths (no collision) and R1 does a full Clear.
end
-- EXP35: the EXP34 dir-listing existence cache (CoverCache:ListDirSet / :DirHas,
-- backed by self.dir_listing) was REMOVED -- it ran System.listDirectory
-- (opendir/readdir) on the cover folder, which on the MX4SIO bdmfs_fatfs backend
-- correlated with a per-navigation lag ending in "not enough memory" (2026-07-22).
-- Cover existence is a single bounded Graphics.loadImage (fopen) again; genuine
-- absences are memoized in self.failed (decode failures stay retryable -- EXP59).
-- See CoverCache:MemoizeMiss / :GetOrLoad.
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
-- EXP59 (OPL parity): only GENUINE ABSENCE is memoized. OPL distinguishes
-- ERR_BAD_FILE (memoized) from decode/IO errors (retried next visit); we used
-- to memoize ANY nil, so one transient failure (a busy cover worker, EE-RAM
-- pressure mid-decode, an IOP RPC hiccup on slow media) became a cover that
-- silently never appeared until R1. A present-but-undecodable file stays
-- retryable; a truly absent file stays memoized (its re-probe is a full FAT
-- dir-chain walk on SD-over-SIO2 / USB 1.1 -- that stall protection stands).
function CoverCache:MemoizeMiss(path)
  local ok, exists = pcall(doesFileExist, path)
  if ok and exists == true then return end
  self.failed[path] = true
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
  if type(Graphics) ~= "table" or type(Graphics.loadImage) ~= "function" then
    self.failed[path] = true
    return nil
  end
  -- EXP49: the dir_present folder gate is GONE. It was added (EXP37) to dodge the
  -- MX4SIO stutter and never could: it only short-circuits when the ART folder is
  -- ABSENT, and the folder very much exists -- it is shared with OPL. OPL itself has
  -- no folder-exists check, no readdir and no stat on this path; it does one open()
  -- per game, exactly like the line below. With loads now off the render thread
  -- (CoverCache:Pump / Poll) an absent folder costs nothing visible either, so the
  -- gate has no remaining job. Same reason the EXP34/44/46 directory listings are
  -- gone: probe COUNT was never the problem.
  --
  -- This synchronous path now runs ONLY as the fallback for builds/devices where the
  -- async worker is unavailable. The game list never reaches it.
  local img = Graphics.loadImage(path)
  if img == nil then
    self:MemoizeMiss(path)
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
  self.last_desc_lines = nil
  self.desc_scroll = 0  -- new selection -> start its description at the top
  if (use_hdd_common_art ~= true) and (vcd_path == nil or vcd_path == "") then
    return nil
  end
  local candidates = BuildCoverCandidates(vcd_path, use_hdd_common_art == true, entry)
  -- Game details: read "<cover-base>.txt" next to the cover art, but only when the
  -- feature is on (otherwise this read is skipped so navigation stays snappy).
  -- Stored raw; the list view word-wraps it under the cover.
  -- EXP54: the details .txt is NO LONGER read here. This was the last blocking card
  -- read left on the RENDER thread, and it is why EXP53 changed nothing: EXP49/53
  -- moved the COVER off the thread but left this one on it, so the frame still
  -- stalled on a slow miss into the same big ART/ folder -- 1-2 opens per newly
  -- selected title. Confirmed by the field report: totally static screen, scrolling
  -- text stopped (render blocked, not just input), on exactly the two devices with a
  -- large ART/ folder (MX4SIO, USB) and never on ATA/APA/SMB.
  --
  -- It now rides the cover: the .txt is only read once a cover has actually LOADED
  -- (see Pump), which means the file is known to exist in that folder and the read is
  -- a cheap hit rather than a full-directory miss. If a game has no cover, its .txt
  -- is not read at all -- so a card with no art (the reported case) does ZERO reads
  -- per navigation instead of two slow ones.
  -- (EXP73: self.pending_desc was dropped here -- write-only since EXP72 deleted its
  -- only reader, the EXP54 in-Pump read.)
  -- Mass devices: compute the details-.txt path for the WORKER-side companion
  -- read (EXP72, sAGA: details never showed without a cover). NO io here --
  -- T35's zero-blocking-IO invariant: the resident cover worker opens the file
  -- on its own thread (Graphics.coverLoadTextPath + coverLoadText), even when
  -- there is no cover to load at all (a text-only job below). Exact game
  -- filename only (EXP71 rule); misses memoize in self.failed.
  self.pending_desc_path = nil
  if use_hdd_common_art ~= true and type(PLDR) == "table"
     and PLDR.SHOW_DETAILS == true and self.last_desc == nil
     and type(Graphics) == "table" and type(Graphics.coverLoadTextPath) == "function" then
    local base = StripExtension(vcd_path or "")
    local dir, name = string.match(base, "^(.*/)([^/]+)$")
    if dir == nil then dir, name = "", base end
    local devroot = string.match(dir, "^(%w+:/)")
    if devroot ~= nil and name ~= "" then
      local dp = devroot.."ART/"..name..".txt"
      if not self.failed[dp] then
        self.pending_desc_path = dp
      end
    end
  end
  -- HDD/PFS quirk: BuildCoverCandidates' HDD branch only returns candidates the
  -- partition resolver EXISTENCE-CONFIRMED, so with no cover .png the list is
  -- EMPTY -- which used to also skip the .txt (a Game.txt without a Game.png
  -- showed details on every removable device but not on HDD) and starve the
  -- missing-cover caption. Resolve the .txt independently here.
  if use_hdd_common_art == true and type(PLDR) == "table"
     and PLDR.SHOW_DETAILS == true and self.last_desc == nil
     and type(PLDR.ResolveHddPartitionReadablePath) == "function" then
    local hdd_base = ExtractHddArtBasename(entry)
    if hdd_base ~= "" then
      local hdd_names = {}
      local hdd_stripped = StripDiscMarker(hdd_base)
      if hdd_stripped ~= "" and hdd_stripped ~= hdd_base then hdd_names[1] = hdd_stripped end
      hdd_names[#hdd_names + 1] = hdd_base
      for ni = 1, #hdd_names do
        local ok_txt, txt_path = pcall(PLDR.ResolveHddPartitionReadablePath, "hdd0:__common", "POPS/ART/"..hdd_names[ni]..".txt")
        if ok_txt and type(txt_path) == "string" and txt_path ~= "" then
          local d = ReadGameDetailsText(txt_path)
          if d ~= nil then
            self.last_desc = d
            self.last_desc_lines = nil
            break
          end
        end
      end
    end
  end
  -- Anything already decoded, or already known absent, is answered with ZERO I/O.
  local first_unknown = nil
  local cached_img = nil
  for i = 1, #candidates do
    local p = candidates[i]
    local cached = self.entries[p]
    if cached ~= nil then
      cached_img = cached
      break
    end
    if not self.failed[p] and first_unknown == nil then
      first_unknown = i
    end
  end
  if cached_img ~= nil then
    self.last_img = cached_img
    -- EXP73: a CACHED cover used to return straight from here, before any details
    -- job was issued, so a game whose art was already decoded could never show its
    -- .txt -- and revisiting a game was the common case. The sidecar still has to
    -- be fetched; it just has no cover to ride on.
    self:BeginTextOnlyLoad(key)
    return cached_img
  end
  if first_unknown == nil then
    -- every cover candidate is a known miss. The DETAILS text may still exist:
    -- give the worker a text-only job (empty image path) so cover-less games
    -- show their description without any render-thread io (EXP72).
    self:BeginTextOnlyLoad(key)
    return nil   -- nothing to do for the cover itself
  end
  -- EXP49: hand the unknown candidate to the worker and RETURN IMMEDIATELY. The list
  -- keeps drawing the placeholder; CoverCache:Pump adopts the texture when it lands.
  -- This is the whole fix: the probe itself is unchanged (one open per game, same as
  -- OPL) -- it simply stops happening on the thread that draws. A miss into a large
  -- shared ART/ folder still costs ~0.3-0.6s on MX4SIO, but nothing waits for it now.
  self:BeginLoad(key, candidates, first_unknown)
  return nil
end

-- Kick an async load for candidates[idx] of `key`. Falls back to the old synchronous
-- load only when the worker is unavailable (older core), so behaviour degrades rather
-- than breaks.
function CoverCache:BeginLoad(key, candidates, idx)
  local path = candidates[idx]
  if path == nil then return end
  -- EXP53: drain an UNCOLLECTED result before requesting. Pump only runs on the
  -- game-list scene, so leaving the page mid-load (START, a launch, a back-out)
  -- leaves the worker slot finished-but-unread; without this every later request is
  -- refused and covers silently stop for the rest of the session. EXP51 did exactly
  -- this in C and that build would not boot, so it is done HERE and the C stays
  -- byte-identical to EXP49, which did boot. Polling is free and side-effect-free.
  if self.pending == nil and type(Graphics) == "table"
     and type(Graphics.coverLoadPoll) == "function" then
    local ok_d, _, orphan = pcall(Graphics.coverLoadPoll)
    if ok_d and orphan ~= nil and type(Graphics.freeImage) == "function" then
      pcall(Graphics.freeImage, orphan)
    end
  end
  if type(Graphics) ~= "table" or type(Graphics.coverLoadBegin) ~= "function" then
    local img = self:GetOrLoad(path)
    if img ~= nil and self.last_key == key then self.last_img = img end
    return
  end
  self.token = (self.token or 0) + 1
  local dp = self.pending_desc_path
  self.pending_desc_path = nil
  self.pending = { key = key, candidates = candidates, idx = idx, token = self.token, desc_path = dp }
  -- EXP73: ALWAYS set the companion text path here, clearing it with "" when this
  -- game has none. EXP72 set it only in the text-only and the worker-refused-retry
  -- branches, so this -- the path EVERY first-time cover load takes -- asked the
  -- worker for no text at all, and games with BOTH a cover and a .txt lost details
  -- they used to show (the EXP54 read was deleted in the same commit). Clearing on
  -- the no-details case matters just as much: a path left over from a refused job
  -- otherwise rides the next game's cover job and shows the WRONG game's blurb.
  if type(Graphics.coverLoadTextPath) == "function" then
    pcall(Graphics.coverLoadTextPath, dp or "")
  end
  local ok, accepted = pcall(Graphics.coverLoadBegin, path, self.token)
  if not ok or accepted ~= true then
    -- Worker busy (or refused): Pump retries on a later frame. Never block here.
    self.pending.started = false
  else
    self.pending.started = true
  end
end

-- EXP73: issue a TEXT-ONLY worker job (empty image path) for a pending details
-- sidecar -- the case where there is no cover load to carry it.
--
-- EXP72 fired this job but never set self.pending, and CoverCache:Pump early-returns
-- on a nil pending, so the job was never polled: the worker DID read the file and the
-- bytes were dropped on the floor. That is the reported bug ("Game Details does not
-- appear on the game list"). It also left the C slot finished-but-unread, which
-- refuses every later request until something else drains it.
function CoverCache:BeginTextOnlyLoad(key)
  local dp = self.pending_desc_path
  self.pending_desc_path = nil
  if dp == nil then return end
  if type(Graphics) ~= "table" or type(Graphics.coverLoadBegin) ~= "function"
     or type(Graphics.coverLoadTextPath) ~= "function" then
    return
  end
  -- Drain an uncollected result first, for EXP53's reason: a finished-but-unread
  -- job occupies the slot and every request is refused while it sits there.
  if type(Graphics.coverLoadPoll) == "function" then
    local ok_d, _, orphan = pcall(Graphics.coverLoadPoll)
    if ok_d and orphan ~= nil and type(Graphics.freeImage) == "function" then
      pcall(Graphics.freeImage, orphan)
    end
  end
  self.token = (self.token or 0) + 1
  self.pending = { key = key, candidates = {}, idx = 0, token = self.token,
                   text_only = true, desc_path = dp }
  pcall(Graphics.coverLoadTextPath, dp)
  local ok, accepted = pcall(Graphics.coverLoadBegin, "", self.token)
  self.pending.started = (ok and accepted == true)
end

-- Drain the worker's companion-text channel for a COMPLETED job.
--
-- Must run on every completed job, whatever the cover outcome: the C channel is
-- consumed on read (luagraphics.cpp lua_coverloadtext), so a value left sitting
-- there is picked up by the NEXT game. A stale result is drained and DISCARDED --
-- the same rule T30 pins for textures: never show one game's data on another's row.
function CoverCache:CollectPendingText(p, stale)
  if type(Graphics) ~= "table" or type(Graphics.coverLoadText) ~= "function" then return end
  local ok, dtxt = pcall(Graphics.coverLoadText)   -- consume unconditionally
  if not ok then return end
  local dp = p.desc_path
  if dp == nil or stale then return end
  if type(dtxt) == "string" and dtxt ~= "" then
    if self.last_desc == nil then
      self.last_desc = dtxt
      self.last_desc_lines = nil
    end
  elseif dtxt == false then
    -- false is the worker's "open/read failed" -- treat as absent so a cover-less
    -- game without a sidecar stops re-requesting it on every visit.
    self.failed[dp] = true
  end
end

-- Called once per game-list frame. Adopts a finished load, advances to the next
-- candidate on a miss, and retries a request the worker was too busy to accept.
-- Does no filesystem work of its own and never blocks.
-- EXP58: settle the cover worker before handing the machine to another ELF.
-- The worker can be mid-fopen when a launch happens, which leaves an IOP RPC
-- outstanding across the SifIopReset the launch performs -- exactly the
-- "polluted parent" state src/main.cpp:607 has to defend against at BOOT, except
-- self-inflicted. DKWDRV is the sensitive case (maintainer: "its environment gets
-- poisoned and its unable to do anything"), because it wants a clean IOP.
--
-- BOUNDED: a cover probe into a large ART/ folder can take ~0.5s, so wait up to
-- ~2s and then give up rather than risk hanging a launch. Any texture that lands
-- is freed -- we are leaving the scene, nothing will draw it.
function CoverCache:Quiesce()
  self.pending = nil
  if type(Graphics) ~= "table" or type(Graphics.coverLoadPoll) ~= "function" then return end
  for _ = 1, 120 do
    local ok, token, ptr = pcall(Graphics.coverLoadPoll)
    if not ok then return end
    if token ~= nil then
      if ptr ~= nil and type(Graphics.freeImage) == "function" then
        pcall(Graphics.freeImage, ptr)
      end
      return   -- consumed; the slot is idle again
    end
    if type(Screen) == "table" and type(Screen.waitVblankStart) == "function" then
      pcall(Screen.waitVblankStart)
    end
  end
end

function CoverCache:Pump()
  local p = self.pending
  if p == nil then return end
  if type(Graphics) ~= "table" or type(Graphics.coverLoadPoll) ~= "function" then
    self.pending = nil
    return
  end
  -- EXP73: a text-only job carries no cover candidate; its image path is "".
  local ipath = (p.text_only == true) and "" or p.candidates[p.idx]
  if p.started ~= true then
    -- EXP57: BOUNDED retry. This used to retry forever, so a request that could never
    -- start left the loader pending permanently -- sAGA reported the "Loading ART..."
    -- line stuck on screen, and after EXP56 removed that line the same state simply
    -- went silent and covers stopped appearing for the rest of the session. The cause
    -- is that coverLoadBegin creates a NEW EE thread per request (luagraphics.cpp:117,
    -- OPL uses one long-lived worker instead), so a failed CreateThread refuses every
    -- later call. Give up after ~1s and treat it as a miss: worst case one cover does
    -- not appear, never a wedged loader. The proper fix is a single persistent worker.
    p.retries = (p.retries or 0) + 1
    if p.retries > 60 then
      -- Give up on THIS request, but do NOT memoize: a worker that never
      -- accepted is transient by definition (thread creation / busy worker),
      -- so the next selection visit must be allowed to re-try (EXP59).
      self.pending = nil
      return
    end
    -- EXP73: our begin was refused, so any DONE result in the slot belongs to an
    -- ABANDONED job -- drain it, or it refuses this retry too and every retry after
    -- it (the "covers stop for the rest of the session" state EXP57 could only bound).
    local ok_d, _, orphan = pcall(Graphics.coverLoadPoll)
    if ok_d and orphan ~= nil and type(Graphics.freeImage) == "function" then
      pcall(Graphics.freeImage, orphan)
    end
    -- Re-arm from the JOB's own desc_path, not self.pending_desc_path (already
    -- consumed when the job was created), and clear when this job carries none.
    if type(Graphics.coverLoadTextPath) == "function" then
      pcall(Graphics.coverLoadTextPath, p.desc_path or "")
    end
    local ok, accepted = pcall(Graphics.coverLoadBegin, ipath, p.token)
    p.started = (ok and accepted == true)
    return
  end
  local ok, token, ptr = pcall(Graphics.coverLoadPoll)
  if not ok or token == nil then return end   -- still working
  local stale = (token ~= p.token) or (self.last_key ~= p.key)
  -- EXP73: collect the sidecar on EVERY completed job -- cover hit, cover miss and
  -- text-only alike. EXP72 collected it only inside the `ptr ~= nil` arm, so a
  -- cover-less game (the reported case) never got its .txt; and it ran the collect
  -- TWICE on a hit, the second read always hitting an already-consumed channel.
  self:CollectPendingText(p, stale)
  if ptr ~= nil then
    if stale then
      -- The selection moved on while this was loading: drop it rather than show or
      -- cache art for a game that is no longer selected.
      if type(Graphics.freeImage) == "function" then pcall(Graphics.freeImage, ptr) end
    else
      if type(Graphics.setImageFilters) == "function" then
        pcall(Graphics.setImageFilters, ptr, LINEAR)
      end
      self.entries[ipath] = ptr
      table.insert(self.order, ipath)
      self:EvictIfNeeded()
      self.last_img = ptr
    end
    self.pending = nil
    return
  end
  if p.text_only == true then
    -- No cover was requested: nothing to memoize as absent, nothing to advance to.
    self.pending = nil
    return
  end
  -- Miss: memoize ONLY when the file is genuinely absent (EXP59, OPL parity --
  -- a decode failure on a present file stays retryable), then try the next candidate.
  self:MemoizeMiss(ipath)
  if stale then self.pending = nil; return end
  local nxt = nil
  for i = p.idx + 1, #p.candidates do
    if not self.failed[p.candidates[i]] then nxt = i; break end
  end
  if nxt == nil then
    self.pending = nil
  else
    self:BeginLoad(p.key, p.candidates, nxt)
  end
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
      GSMBNET = 7,
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
        or scene == UI.SCENES.GSMBNET
    end;
    ShouldHideAuxText = function (scene)
      return UI.HideTextMode and UI.IsHideToggleScene(scene or UI.CURSCENE)
    end;
    -- Region-native confirm mapping (R3Z3N review): Japanese-ROM consoles
    -- (rom0:ROMVER byte 5 == 'J' -> PLDR.CONFIRM_CIRCLE, probed at boot in
    -- system.lua) use CIRCLE = confirm / CROSS = cancel; everywhere else the
    -- reverse. Scenes consume abstract CONFIRM/BACK events, so the pad map in
    -- UI.Pad.Listen plus these glyph helpers are the ONLY swap points: footer
    -- icons, modal hints and blocking prompts all route through them.
    ConfirmSwapped = function ()
      return type(PLDR) == "table" and PLDR.CONFIRM_CIRCLE == true
    end;
    ConfirmGlyphKey = function ()  -- footer/IMG key of the CONFIRM button
      return UI.ConfirmSwapped() and "circle" or "cross"
    end;
    BackGlyphKey = function ()
      return UI.ConfirmSwapped() and "cross" or "circle"
    end;
    ConfirmGlyphLetter = function ()  -- text hints ("X: Confirm" style)
      return UI.ConfirmSwapped() and "O" or "X"
    end;
    BackGlyphLetter = function ()
      return UI.ConfirmSwapped() and "X" or "O"
    end;
    ConfirmPadMask = function ()  -- raw Pads.get bitmask of CONFIRM
      return UI.ConfirmSwapped() and PAD_CIRCLE or PAD_CROSS
    end;
    BackPadMask = function ()
      return UI.ConfirmSwapped() and PAD_CROSS or PAD_CIRCLE
    end;
    -- "X = Yes      O = No"-style line for the blocking prompts, composed from
    -- word-level i18n keys so the glyph letters can swap per region.
    PadHintPair = function (confirm_word, back_word)
      return UI.ConfirmGlyphLetter().." = "..PLDR.L(confirm_word)
        .."      "..UI.BackGlyphLetter().." = "..PLDR.L(back_word)
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
        UI.GameList.CoverPendingFrames = 0
        -- Entering a device game-list from a non-list scene (carousel/menu): open at
        -- the top instead of inheriting the previously-viewed device's (clamped)
        -- cursor -- UI.GameList.CURR is a single global index shared across pages.
        -- Gated to carousel->list entry, so R1 in-place rescan and the -page /
        -- Boot-Page auto-enter (which set CURR deliberately, or want the top anyway)
        -- are untouched. Overlays opened FROM a list that return to it -- Credits AND
        -- Settings (MPROFILE) -- are exempted so they keep your scroll position.
        -- UI.IsGameScene(nil) is false, so a first/unknown prev is fine.
        if UI.IsGameScene(scene) and not UI.IsGameScene(prev_scene)
           and prev_scene ~= UI.SCENES.CREDITS and prev_scene ~= UI.SCENES.MPROFILE then
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
      -- Expand the list 3px MORE on each side (oldman63 #501 r4): left margin 40 -> 18
      -- and the gap before the cover 3 -> 0, so the list now runs FLUSH to the opaque
      -- 256-wide frame box (SCR.X - safe.R - 256) on the right and 18px from the screen
      -- edge on the left. NB: both are past CRT action-safe now -- the left characters
      -- and the right edge butting the cover frame want a hardware eyeball. Cover unmoved.
      UI.LAYOUT.LIST_X = Round(safe.L - 22)
      UI.LAYOUT.LIST_Y = Round(safe.T + 16)
      UI.LAYOUT.LIST_W = (UI.SCR.X - safe.R - 256) - UI.LAYOUT.LIST_X
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
      DEBUG_INPUT_LOG = false;
    };
	    BdmaModes = {
	      { key = "FAT32", label = "FAT32-USB (None)" },
	      { key = "USBEXFAT", label = "exFAT-USB" },
	      { key = "MX4SIO", label = "MX4SIO" },
	      { key = "MMCE", label = "MMCE" },
	      { key = "ATA", label = "exFAT-HDD (ata)" }
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
	    DkwdrvDirty = false;
    PopstarterPathDraft = nil;
    DkwdrvPathDraft = nil;
    KeyboardLayoutDraft = nil;
    SmbDraft = nil;
    SmbDirty = false;
    SmbModulesDraft = false;
    SmbModulesDirty = false;
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
    -- EXP42: applies the "Cover art" setting (PLDR.COVER_ART) to the LIVE game list.
    -- Turning it on re-arms the deferred cover load (the settle counter runs on the next
    -- list frame); turning it off drops the current selection's decoded image so the box
    -- falls back to the plain jewel-case placeholder immediately. Carries the exact side
    -- effects the old Square handler had, so behaviour is unchanged: only the trigger
    -- moved to Settings. Callable from the settings loader before the list scene exists,
    -- so both GameList and the cover cache are optional here.
    SetCoverPreview = function (enabled)
      local next_state = (enabled ~= false)
      UI.CoverPreviewEnabled = next_state
      if type(UI.GameList) == "table" then
        if next_state then
          UI.GameList.CoverLastIndex = nil
          UI.GameList.CoverPending = true
          UI.GameList.CoverPendingFrames = 9999  -- re-enabled: load on the next settled frame
        else
          UI.GameList.CoverPending = false
        end
      end
      if not next_state and UI.CoverCache ~= nil then
        UI.CoverCache:UpdateSelection(nil)
      end
      return next_state
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
    -- EXP32: the SIO2 "Device conflict / Restart" dialog is GONE. mmceman and
    -- mx4sio_bd coexist on freesio2 (EXP31), exactly as OPL/RiptOPL run them
    -- concurrently with no exclusion -- there is no conflict left to dialog
    -- about. (The -page= self-exec plumbing in luasystem.cpp stays: launch
    -- args use it independently.)
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
        -- Pre-translate the title: add-time L runs on the CONCATENATED string, so
        -- the 8 existing "Failed to load ..." translations never matched (oldman63).
        UI.Notif_queue.add(PLDR.L(tostring(failure_message or "Operation failed")).."\n"..err_detail, "error")
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
          -- Timer.getTime is MICROSECONDS; divide so the `< 20` throttle below
          -- really means 20 ms. Raw µs made the throttle never suppress, so every
          -- per-file progress callback repainted + vsync'd (~1 frame PER FILE on a
          -- big scan -- roughly 8-10 s of pure overlay overhead per 500 games).
          return (tonumber(Timer.getTime(UI.Pad.Timer)) or 0) / 1000
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
        -- Localize static toasts (dynamic/unlisted text falls through to English).
        local text = PLDR.L(tostring(notif or ""))
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
      -- Legend orders use the semantic tokens "confirm"/"back" (resolved to the
      -- region-native cross/circle glyph in ResolveLegend). Confirm always sits
      -- FAR LEFT, back/exit at the right edge -- R3Z3N review.
      --
      -- DELIBERATELY SHORT (R3Z3N review round 3, seconded by Berion: "I would
      -- drop credits, settings and game art buttons in games list"; main menu is
      -- exactly "select, settings, exit"). The footer advertises the PRIMARY
      -- action plus the way out, nothing else. The dropped bindings still WORK
      -- where they worked before (Square still toggles cover art on a game list,
      -- START still opens Settings) -- only the legend clutter is gone. Credits
      -- moved into Settings entirely, so the Triangle binding is gone with it.
      order = {"confirm", "square", "back"};
      order_with_start = {"confirm", "start", "back"};
      order_with_start_r2 = {"confirm", "back"};
      order_settings_save = {"confirm", "start", "back"};
      order_keyboard = {"confirm", "square", "start", "back"};
	      -- No `triangle` (Credits) or `select_toggle` (Hide Text) entries: neither
	      -- appears in any order above anymore. Credits moved into Settings and the
	      -- Settings page no longer hijacks Select. ResolveLegend/Draw tolerate a
	      -- nil label, so an order that names a glyph with no label just draws the
	      -- glyph -- but nothing does.
	      labels = {
	        circle_main = "Exit",
	        circle_other = "Back",
	        start_profiles = "Settings",
	        start_menu = "Menu",
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
        -- Callers still pass labels by SEMANTIC role: opts.circle = the
        -- back/cancel action, opts.cross = the confirm action. Which physical
        -- glyph carries each role follows the region-native mapping (constant
        -- for the whole session, so the cache stays valid).
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
        local confirm_key = UI.ConfirmGlyphKey()
        local back_key = UI.BackGlyphKey()
        local labels = {
          triangle = UI.Footer.labels.triangle,
          [back_key] = circle_label,
          [confirm_key] = cross_label,
          start = start_label,
          select = select_label
        }
        if square_label ~= nil then
          labels.square = square_label
        end
        -- Translate the semantic order tokens to the physical glyph keys the
        -- Draw loop indexes IMG[] with.
        local physical = {}
        for i = 1, #order do
          local entry = order[i]
          if entry == "confirm" then entry = confirm_key
          elseif entry == "back" then entry = back_key end
          physical[i] = entry
        end
        UI.Footer.legend_cache[key] = {labels = labels, order = physical}
        return labels, physical
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
            Font.ftPrint(SFONT, x, labelY, 8, UI.LAYOUT.FOOTER_LABEL_W, 16, PLDR.L(label), UI.CCOL.GREY)
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
        -- Animation clock for the bar marquee (ms). The spinner + animated title
        -- dots were removed: the title is center-aligned, so a changing-width dot
        -- string re-centered it every 200ms (the tester's "flickers for no reason"),
        -- and the messages already end in "..." so the dots were redundant churn.
        local tick_ms = (math.floor((tonumber(UI.SavingAnimTick) or 0))) * 200
        if UI.Pad ~= nil and UI.Pad.Timer ~= nil then
          -- /1000: Timer.getTime is MICROSECONDS; the marquee divisor math below
          -- assumes ms (raw µs would wrap the whole bar ~60x/sec = flicker). The
          -- marquee branch is only reachable with a nil progress (latent today).
          tick_ms = math.floor(Timer.getTime(UI.Pad.Timer) / 1000)
        end
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
	        -- (Removed the always-on pulse sweep: it slid across the whole bar
	        -- independent of progress, reading as a detached/glitchy highlight.)
	        if type(UI.SavingProgress) == "number" then
	          local fill_w = math.floor((bar_w - 4) * UI.SavingProgress + 0.5)
	          if fill_w > 0 then
	            -- Determinate: a single clean fill, no moving shimmer overlay.
	            Graphics.drawRect(bar_x + 2, bar_y + 2, fill_w, bar_h - 4, Color.new(110, 190, 255, 120))
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
        Font.ftPrint(BFONT, UI.SCR.X_MID, box_y + 20, 8, UI.SCR.X, 16, PLDR.L(tostring(UI.SavingMessage or "Saving/Applying...")), UI.CCOL.YELLOW)
        if type(UI.SavingProgress) == "number" then
          Font.ftPrint(SFONT, UI.SCR.X_MID, box_y + 84, 8, UI.SCR.X, 16, tostring(math.floor(UI.SavingProgress * 100 + 0.5)).."%", UI.CCOL.GREY)
        else
          Font.ftPrint(SFONT, UI.SCR.X_MID, box_y + 84, 8, UI.SCR.X, 16, PLDR.L("Working..."), UI.CCOL.GREY)
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

          if UI.BOOT_SOUND == nil or UI.BOOT_SOUND.ENABLED ~= true
             or (type(PLDR) == "table" and PLDR.BOOT_SOUND == false) then
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
          -- Frame-paced: this loop runs one Screen.flip per iteration. The old
          -- Timer.getTime() delta (microseconds) was always clamped to max_step, so
          -- advancing a fixed step per frame reproduces the exact prior pacing with no
          -- wall clock. (durationMs is "ms" only by this same step scale.)
          local elapsed = 0
          local step = (UI.Transition and UI.Transition.max_step) or 33
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
            elapsed = elapsed + step
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
      -- List-menu mode: when menu_items is set the modal is a small vertical
      -- chooser (Up/Down + Confirm) instead of the X/O/Triangle button prompt.
      menu_items = nil;
      menu_index = 1;
      -- One place builds every "X: Confirm    O: Cancel" hint line so the
      -- glyph letters stay consistent across modals AND follow the
      -- region-native confirm mapping (confirm always listed first).
      ButtonHint = function (confirm_label, cancel_label)
        return ("%s: %s    %s: %s"):format(
          UI.ConfirmGlyphLetter(), confirm_label,
          UI.BackGlyphLetter(), cancel_label)
      end;
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
          -- cwd / app-dir fallback, DEFAULT PATH ONLY (an explicit custom path is
          -- never shadowed): the default is mc-only, so a DKWDRV.ELF sitting next
          -- to POPSLOADER.ELF on USB/exFAT/MMCE was never found -- unlike
          -- POPSTARTER, whose ladder probes the launcher's own folder. Also
          -- probes the mc1: twin of the mc0: default for slot-2-only consoles.
          if (elf_path == nil or not SafeDoesFileExist(elf_path))
            and configured_path == tostring((type(PLDR) == "table" and PLDR.DKWDRV_DEFAULT_PATH) or "") then
            local probes = {}
            if string.match(string.lower(configured_path), "^mc0:") ~= nil then
              probes[#probes + 1] = "mc1:"..string.sub(configured_path, 5)
            end
            local cwd = nil
            pcall(function() cwd = System.currentDirectory() end)
            if type(cwd) == "string" and cwd ~= "" then
              if string.sub(cwd, -1) ~= "/" then cwd = cwd.."/" end
              probes[#probes + 1] = cwd.."DKWDRV.ELF"
              probes[#probes + 1] = cwd.."PS1_DKWDRV/DKWDRV.ELF"
            end
            for pi = 1, #probes do
              if SafeDoesFileExist(probes[pi]) then
                elf_path = probes[pi]
                break
              end
            end
          end
          if elf_path == nil or not SafeDoesFileExist(elf_path) then
            UI.Modal.Close()
            UI.Notif_queue.add(PLDR.L("No DKWDRV found at this path").."\n"..configured_path, "error")
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
          UI.Notify(PLDR.L("DKWDRV failed to launch").."\n"..PLDR.L("return code:").." "..tostring(rc), 150, "error")
          return
        end
        UI.Modal.cancel_action = UI.Modal.Close
        UI.Modal.triangle_action = nil
        UI.Modal.ignore_until_release = true
      end;
      -- (OpenSaveSettings, the old X-Save/O-Cancel/Triangle-Don't-Save leave
      -- prompt, was removed: Back and START now open the identical
      -- OpenSettingsMenu chooser -- R3Z3N review round 3, "they should be the
      -- same".)
      -- The settings page's Save/Reset/Discard actions live behind START
      -- (R3Z3N review: inline list rows for them sat oddly above Memory Card
      -- and made reaching them a scroll chore).
      OpenSettingsMenu = function (on_save, on_reset, on_discard)
        UI.Modal.active = true
        UI.Modal.title = "Settings"
        UI.Modal.body = ""
        UI.Modal.menu_items = {
          { label = "Save Changes",   action = on_save },
          { label = "Reset Defaults", action = on_reset },
          { label = "Discard & Exit", action = on_discard },
        }
        UI.Modal.menu_index = 1
        UI.Modal.confirm_action = nil
        UI.Modal.cancel_action = UI.Modal.Close
        UI.Modal.triangle_action = nil
        UI.Modal.ignore_until_release = true
      end;
      Close = function ()
        UI.Modal.active = false
        UI.Modal.confirm_action = nil
        UI.Modal.cancel_action = nil
        UI.Modal.triangle_action = nil
        UI.Modal.menu_items = nil
        UI.Modal.menu_index = 1
        UI.Modal.ignore_until_release = false
      end;
      ConfirmExit = function ()
        UI.LAUNCHING = true
        UI.Modal.Close()
        -- On an HDD boot, tear the pfs mounts down cold (same pattern as the
        -- BOOT.ELF arm): exitToBrowser is a bare ExecOSD with no unmount, and a
        -- settings save may have left the boot partition RW-mounted -- handing
        -- OSDSYS a still-RW journal-less PFS mount is an unclean-unmount
        -- corruption vector for the partition holding POPSLoader itself.
        local hdd_loaded = type(PLDR) == "table" and type(PLDR.HDD) == "table"
          and tonumber(PLDR.HDD.LOADSTATE or 0) ~= 0
        if hdd_loaded and type(PLDR.PrepareForColdExternalELFLaunch) == "function" then
          pcall(PLDR.PrepareForColdExternalELFLaunch)
        elseif type(PLDR) == "table" and type(PLDR.PrepareForExternalELFLaunch) == "function" then
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
        UI.Notify(PLDR.L("BOOT.ELF failed to launch").."\n"..PLDR.L("return code:").." "..tostring(rc), 150, "error")
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
        if UI.Modal.menu_items ~= nil then
          local n = #UI.Modal.menu_items
          if n > 0 then
            if UI.Pad.Events.NAV_UP then
              UI.Modal.menu_index = ((UI.Modal.menu_index - 2) % n) + 1
            end
            if UI.Pad.Events.NAV_DOWN then
              UI.Modal.menu_index = (UI.Modal.menu_index % n) + 1
            end
          end
          if UI.Pad.Events.CONFIRM then
            local entry = UI.Modal.menu_items[UI.Modal.menu_index]
            UI.Modal.Close()
            if entry ~= nil and type(entry.action) == "function" then
              entry.action()
            end
          elseif UI.Pad.Events.BACK then
            UI.Modal.Close()
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
        if UI.Modal.menu_items ~= nil then
          local n = #UI.Modal.menu_items
          local row_h = 22
          local box_w = 320
          local box_h = 96 + n * row_h
          local box_x = math.floor(UI.SCR.X_MID - (box_w / 2))
          local box_y = math.floor(UI.SCR.Y_MID - (box_h / 2))
          Graphics.drawRect(0, 0, UI.SCR.X, UI.SCR.Y, UI.CCOL.MODAL_BACKDROP)
          Graphics.drawRect(box_x, box_y, box_w, box_h, Color.new(0, 0, 0, 200))
          Graphics.drawRect(box_x, box_y, box_w, 2, UI.CCOL.GREY)
          Graphics.drawRect(box_x, box_y + box_h - 2, box_w, 2, UI.CCOL.GREY)
          Font.ftPrint(BFONT, UI.SCR.X_MID, box_y + 10, 8, UI.SCR.X, 16, PLDR.L(UI.Modal.title), UI.CCOL.YELLOW)
          local accent = (UI.COLORS and UI.COLORS.TEXT_PRIMARY) or UI.CCOL.YELLOW
          for i = 1, n do
            local row_y = box_y + 44 + (i - 1) * row_h
            local selected = (i == UI.Modal.menu_index)
            if selected then
              Graphics.drawRect(box_x + 16, row_y - 2, box_w - 32, row_h - 2, Color.new(50, 80, 160, 110))
            end
            Font.ftPrint(BFONT, UI.SCR.X_MID, row_y, 8, UI.SCR.X, 16, PLDR.L(UI.Modal.menu_items[i].label), selected and accent or UI.CCOL.GREY)
          end
          local hint = UI.Modal.ButtonHint(PLDR.L("Confirm"), PLDR.L("Cancel"))
          Font.ftPrint(BFONT, UI.SCR.X_MID, box_y + box_h - 26, 8, UI.SCR.X, 16, hint, UI.CCOL.GREY)
          return
        end
        local body_lines = WrapText(PLDR.L(UI.Modal.body or ""), 38)
        local line_spacing = 16
        local confirm_label = PLDR.L(UI.Modal.options[1] or "Confirm")
        local cancel_label = PLDR.L(UI.Modal.options[2] or "Cancel")
        local triangle_label = UI.Modal.options[3] and PLDR.L(UI.Modal.options[3]) or nil
        local extra_footer_h = (triangle_label ~= nil) and 16 or 0
        local box_w = 320
        local box_h = 140 + (math.max(1, #body_lines) - 1) * line_spacing + extra_footer_h
        local box_x = math.floor(UI.SCR.X_MID - (box_w / 2))
        local box_y = math.floor(UI.SCR.Y_MID - (box_h / 2))
        Graphics.drawRect(0, 0, UI.SCR.X, UI.SCR.Y, UI.CCOL.MODAL_BACKDROP)
        Graphics.drawRect(box_x, box_y, box_w, box_h, Color.new(0, 0, 0, 200))
        Graphics.drawRect(box_x, box_y, box_w, 2, UI.CCOL.GREY)
        Graphics.drawRect(box_x, box_y + box_h - 2, box_w, 2, UI.CCOL.GREY)
        Font.ftPrint(BFONT, UI.SCR.X_MID, box_y + 10, 8, UI.SCR.X, 16, PLDR.L(UI.Modal.title), UI.CCOL.YELLOW)
        for i, line in ipairs(body_lines) do
          Font.ftPrint(BFONT, UI.SCR.X_MID, box_y + 50 + (i - 1) * line_spacing, 8, UI.SCR.X, 16, line, UI.CCOL.GREY)
        end
        local hint1 = UI.Modal.ButtonHint(confirm_label, cancel_label)
        if triangle_label ~= nil then
          local hint2 = ("%s: %s"):format(PLDR.L("Triangle"), triangle_label)
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
      -- Cycled by the Settings -> Startup -> Keyboard Layout row. The keyboard
      -- itself no longer hosts a layout strip: it duplicated that setting and
      -- ate a nav row (R3Z3N review, r3configurator model).
      layout_order = {"QWERTY", "DVORAK", "ABC", "AZERTY", "QWERTZ", "ABNT"};
      -- Every layout: number row FIRST (r3configurator model -- R3Z3N review),
      -- then the letter rows, then symbols, then the action rows.
      layouts = {
        -- AZERTY (French): letters in the AZERTY arrangement; digits/symbols kept
        -- consistent with QWERTY so path/credential entry is unchanged.
        AZERTY = {
          {"0","1","2","3","4","5","6","7","8","9",":","_"},
          {"a","z","e","r","t","y","u","i","o","p"},
          {"q","s","d","f","g","h","j","k","l","m"},
          {"w","x","c","v","b","n",",",";",".","/"},
          {"-","?","!","&","\\","'","(",")","+","=","[","]"},
          {"SPACE","DEL","CLR"},
          {"BACK","DONE"}
        },
        -- QWERTZ (German): QWERTY with Y and Z swapped.
        QWERTZ = {
          {"0","1","2","3","4","5","6","7","8","9",":","_"},
          {"q","w","e","r","t","z","u","i","o","p"},
          {"a","s","d","f","g","h","j","k","l",";"},
          {"y","x","c","v","b","n","m",",",".","/"},
          {"-","?","!","&","\\","'","(",")","+","=","[","]"},
          {"SPACE","DEL","CLR"},
          {"BACK","DONE"}
        },
        -- ABNT (Brazilian Portuguese): the alphanumeric portion is QWERTY; the
        -- distinguishing ABNT keys (c-cedilla, accents) are non-ASCII and the OSK
        -- is single-char ASCII (see SHIFT_MAP note), so they are intentionally absent.
        ABNT = {
          {"0","1","2","3","4","5","6","7","8","9",":","_"},
          {"q","w","e","r","t","y","u","i","o","p"},
          {"a","s","d","f","g","h","j","k","l",";"},
          {"z","x","c","v","b","n","m",",",".","/"},
          {"-","?","!","&","\\","'","(",")","+","=","[","]"},
          {"SPACE","DEL","CLR"},
          {"BACK","DONE"}
        },
        ABC = {
          {"0","1","2","3","4","5","6","7","8","9"},
          {"a","b","c","d","e","f","g","h","i","j"},
          {"k","l","m","n","o","p","q","r","s","t"},
          {"u","v","w","x","y","z",":","/",".","_"},
          {"-","?","!","&","\\","'","(",")",",",";","+"},
          {"=","[","]","SPACE","DEL","CLR"},
          {"BACK","DONE"}
        },
        QWERTY = {
          {"0","1","2","3","4","5","6","7","8","9",":","_"},
          {"q","w","e","r","t","y","u","i","o","p"},
          {"a","s","d","f","g","h","j","k","l",";"},
          {"z","x","c","v","b","n","m",",",".","/"},
          {"-","?","!","&","\\","'","(",")","+","=","[","]"},
          {"SPACE","DEL","CLR"},
          {"BACK","DONE"}
        },
        DVORAK = {
          {"0","1","2","3","4","5","6","7","8","9",":","_"},
          {"'",";",",",".","p","y","f","g","c","r","l"},
          {"a","o","e","u","i","d","h","t","n","s"},
          {"q","j","k","x","b","m","w","v","z","/"},
          {"-","?","!","&","\\","(",")","+","=","[","]"},
          {"SPACE","DEL","CLR"},
          {"BACK","DONE"}
        }
      };
      -- R2/UPPER mode on non-letter keys: digits and brackets shift to the symbols
      -- the layouts can't otherwise produce (@ # $ % ^ * " < > | { } ~ `). Without
      -- these, common SMB credentials (an @ in a username, a $ hidden-share suffix,
      -- most password symbols) were IMPOSSIBLE to type -- "right settings" that
      -- could never be entered. Keys stay single-char, so key widths, navigation,
      -- and _InsertText need no changes.
      SHIFT_MAP = {
        ["0"] = "@", ["1"] = "#", ["2"] = "$", ["3"] = "%", ["4"] = "^",
        ["5"] = "*", ["6"] = "\"", ["7"] = "<", ["8"] = ">", ["9"] = "|",
        ["["] = "{", ["]"] = "}", ["-"] = "~", ["="] = "`",
      };
      _NormalizeLayout = function (layout)
        if type(PLDR) == "table" and type(PLDR.NormalizeKeyboardLayout) == "function" then
          return PLDR.NormalizeKeyboardLayout(layout)
        end
        local key = string.upper(tostring(layout or ""))
        if key == "ABC" or key == "DVORAK" or key == "AZERTY" or key == "QWERTZ" or key == "ABNT" then
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
        -- Start UPPERCASE with the cursor on the first LETTER row (row 2 --
        -- row 1 is the number row), i.e. Q on QWERTY: r3configurator model,
        -- R3Z3N review.
        UI.PathEditor.row = 2
        UI.PathEditor.col = 1
        UI.PathEditor.upper = true
        UI.PathEditor.cursor = string.len(UI.PathEditor.value or "")
        UI.PathEditor.pressed_row = 0
        UI.PathEditor.pressed_col = 0
        UI.PathEditor.pressed_until = 0
        UI.PathEditor.initial = UI.PathEditor.value   -- for the circle discard-confirm
        UI.PathEditor.discard_until = 0
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
        UI.PathEditor.initial = nil
        UI.PathEditor.discard_until = 0
      end;
      _NowMs = function ()
        -- Timer.getTime() is raw clock() ticks = MICROSECONDS on PS2 (CLOCKS_PER_SEC=1e6),
        -- but every _NowMs caller (caret blink /300, key-flash +160, _IsPressed compare)
        -- was authored in MILLISECONDS. Divide once here so the whole PathEditor is
        -- unit-correct: the 160 "ms" key-flash now actually survives to the next frame
        -- (it was expiring 160 us later, so the pressed-key highlight never showed) and
        -- the caret blinks ~300 ms instead of ~1000x too fast.
        if UI.Pad ~= nil and UI.Pad.Timer ~= nil then
          return (tonumber(Timer.getTime(UI.Pad.Timer)) or 0) / 1000
        end
        return 0
      end;
      _RowSize = function (row)
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
      _DisplayKey = function (key)
        if key == nil then return "" end
        -- The word-keys (SPACE/BACK/DONE) are user-facing labels, so translate them
        -- for DISPLAY while the raw key string stays the input-logic identifier
        -- (sAGA #538: BACK/DONE could not be translated). Single-character keys are
        -- never translated. Falls back to the English word if untranslated.
        if key == "SPACE" or key == "BACK" or key == "DONE" or key == "DEL" or key == "CLR" then
          if type(PLDR) == "table" and type(PLDR.L) == "function" then
            return PLDR.L(key)
          end
          return key
        end
        if UI.PathEditor.upper then
          if string.match(key, "^[a-z]$") then
            return string.upper(key)
          end
          local shifted = UI.PathEditor.SHIFT_MAP[key]
          if shifted ~= nil then return shifted end
        end
        return key
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
        if UI.PathEditor.pressed_row ~= row or UI.PathEditor.pressed_col ~= col then
          return false
        end
        if UI.PathEditor._NowMs() <= (tonumber(UI.PathEditor.pressed_until) or 0) then
          return true
        end
        -- Holding CONFIRM keeps the key visually pressed for the whole hold:
        -- the fixed 160 ms stamp alone read as a timed blip that ended while
        -- the button was still down (R3Z3N review). Only while the cursor is
        -- still on the flashed key, so navigating away drops the highlight.
        return UI.PathEditor.row == row and UI.PathEditor.col == col
          and UI.Pad ~= nil and type(UI.Pad.GPAD) == "number"
          and (UI.Pad.GPAD & UI.ConfirmPadMask()) ~= 0
      end;
      HandleInput = function ()
        if not UI.PathEditor.active then return end
        if UI.Pad.Events.BACK then
          -- Circle with UNSAVED typing asks for a second circle press (within
          -- ~1.5 s) before discarding -- one reflexive press used to silently
          -- throw away a whole typed credential (Square/backspace is one button
          -- over). Untouched fields keep the single-press close.
          local edited = (UI.PathEditor.initial ~= nil)
            and (UI.PathEditor.value ~= UI.PathEditor.initial)
          if not edited or UI.PathEditor._NowMs() < (UI.PathEditor.discard_until or 0) then
            UI.PathEditor.Close()
          else
            UI.PathEditor.discard_until = UI.PathEditor._NowMs() + 1500
            if type(UI.Notif_queue) == "table" then
              -- Name whichever physical button is BACK on this console.
              local msg = UI.ConfirmSwapped()
                and "Press CROSS again to discard what you typed"
                or "Press CIRCLE again to discard what you typed"
              UI.Notif_queue.add(msg, "warn")
            end
          end
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
          UI.PathEditor.row = CLAMP(UI.PathEditor.row - 1, 1, max_rows)
          local row_size = UI.PathEditor._RowSize(UI.PathEditor.row)
          UI.PathEditor.col = CLAMP(UI.PathEditor.col, 1, row_size)
        end
        if UI.Pad.Events.NAV_DOWN then
          UI.PathEditor.row = CLAMP(UI.PathEditor.row + 1, 1, max_rows)
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
          if key == "SPACE" then
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
            if UI.PathEditor.upper then
              if string.match(out, "^[a-z]$") then
                out = string.upper(out)
              elseif UI.PathEditor.SHIFT_MAP[out] ~= nil then
                out = UI.PathEditor.SHIFT_MAP[out]
              end
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

        Font.ftPrint(BFONT, UI.SCR.X_MID, box_y + 8, 8, UI.SCR.X, 16, PLDR.L(UI.PathEditor.title), UI.CCOL.YELLOW)
        Font.ftPrint(SFONT, input_x + 10, input_y + 10, 0, input_w - 20, 16, UI.PathEditor._BuildVisibleValue(46), Color.new(150, 205, 255, 128))
        -- The label names the state R2 SWITCHES TO, not the current one
        -- (R3Z3N: "tell people what you would change to, not what you are on").
        local mode_label = UI.PathEditor.upper and PLDR.L("Case/Symbols: lower  (R2)") or PLDR.L("Case/Symbols: UPPER  (R2)")
        local info_label = mode_label.."   "..PLDR.L("Cursor: L1 / R1")
        Font.ftPrint(SFONT, input_x + 2, input_y + input_h + 10, 0, input_w - 4, 16, info_label, UI.CCOL.GREY)

        local key_h = 24
        local key_gap = 6
        -- (The in-keyboard layout strip is gone -- the Settings page's Keyboard
        -- Layout row is the one chooser. The grid starts where the strip sat.)
        local start_y = input_y + input_h + 30
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
      elapsed = 0,
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
        UI.Transition.active = true
        UI.Transition.phase = "out"
        UI.Transition.target = target
        UI.Transition.next_target = nil
        UI.Transition.elapsed = 0
      end,
      Update = function ()
        if not UI.Transition.active then
          return 0
        end
        -- Frame-paced: Update runs once per render frame. The old Timer.getTime() delta
        -- (microseconds) was always clamped to max_step, so advancing a fixed max_step
        -- per frame reproduces the exact prior pacing with no wall clock.
        UI.Transition.elapsed = (UI.Transition.elapsed or 0) + (UI.Transition.max_step or 33)
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
            UI.Transition.elapsed = 0
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
      -- Select toggles Hide-Text on the scenes it actually helps (the carousel
      -- and the game lists, where it clears the view for cover art). NOT on the
      -- Settings page: hiding the text of the page you are reading is nonsense
      -- (R3Z3N review round 3, "get rid of hid text here"). Settings still
      -- exposes it as the Display > Hide UI Text row.
      if UI.Pad.Events.SELECT then
        if UI.IsHideToggleScene(UI.CURSCENE) then
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
        -- Entry snapshots so per-row dirty indicators + the BDMA/Video dirty flags
        -- compare against the state at entry (cycle-away-and-back = clean) instead
        -- of set-on-touch.
        UI.SettingsEntryBdmaModeIndex = UI.BdmaModeIndex or 1
        UI.SettingsEntryVideoStandardIndex = UI.VideoStandardIndex or 1
        UI.BootPageModes = {
          {key = "Carousel", label = "Carousel (default)"},
          {key = "MX4SIO",   label = "MX4SIO"},
          {key = "USB",      label = "USB"},
          {key = "MMCE",     label = "MMCE"},
          {key = "HDD",      label = "HDD (PFS)"},
          {key = "EXFAT",    label = "HDD (exFAT)"},
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
        -- If an R3 reveal was active, restore the real persisted setting before the
        -- Settings page reads it (reveal only transiently cleared GLOBAL_HIDE).
        -- Flag a rebuild for the RETURN path: the list still shows the revealed
        -- hidden games, and going back without a rescan left it contradicting the
        -- restored GLOBAL_HIDE (L3 then said "press R3 to reveal" while the games
        -- were visibly on screen).
        if PLDR._GLOBAL_HIDE_SAVED ~= nil then
          PLDR.GLOBAL_HIDE = (PLDR._GLOBAL_HIDE_SAVED == true)
          PLDR._GLOBAL_HIDE_SAVED = nil
          UI.RevealHidden = false
          UI.PendingHideRebuild = true
        end
        UI.GlobalHide = (type(PLDR) == "table" and PLDR.GLOBAL_HIDE == true)
        UI.SettingsEntryGlobalHide = UI.GlobalHide
        -- Game-details draft as a 4-way value: off | left | center | right. Derived
        -- from the on/off (PLDR.SHOW_DETAILS) + the alignment (PLDR.DETAILS_ALIGN).
        local _da = (type(PLDR) == "table" and PLDR.DETAILS_ALIGN) or "left"
        if _da ~= "center" and _da ~= "right" then _da = "left" end
        UI.DetailsAlign = ((type(PLDR) == "table" and PLDR.SHOW_DETAILS == true) and _da) or "off"
        UI.SettingsEntryDetailsAlign = UI.DetailsAlign
        UI.HddFs = (type(PLDR) == "table" and type(PLDR.NormalizeHddFs) == "function")
    and PLDR.NormalizeHddFs(PLDR.HDD_FS) or "PFS"
        UI.SettingsEntryHddFs = UI.HddFs
        local _al = (type(PLDR) == "table" and PLDR.ART_LOCATION) or "pops_art"
        if _al ~= "pops" and _al ~= "art" then _al = "pops_art" end
        UI.ArtLocation = _al
        UI.SettingsEntryArtLocation = UI.ArtLocation
        UI.CoverArt = (type(PLDR) == "table" and PLDR.COVER_ART ~= false)
        UI.SettingsEntryCoverArt = UI.CoverArt
        UI.GameListCache = (type(PLDR) == "table" and PLDR.GAMELIST_CACHE == true)
        UI.SettingsEntryGameListCache = UI.GameListCache
        UI.BootSound = (type(PLDR) == "table" and PLDR.BOOT_SOUND ~= false)
        UI.SettingsEntryBootSound = UI.BootSound
        UI.BdmaAdaptive = (type(PLDR) == "table" and PLDR.BDMA_ADAPTIVE == true)
        UI.SettingsEntryBdmaAdaptive = UI.BdmaAdaptive
        UI.Overscan = math.floor(tonumber(type(PLDR) == "table" and PLDR.OVERSCAN or 0) or 0)
        UI.SettingsEntryOverscan = UI.Overscan
        UI.SettingsEntryKeyboardLayout = tostring(UI.KeyboardLayoutDraft or (type(PLDR) == "table" and PLDR.KEYBOARD_LAYOUT) or "QWERTY")
        UI.SettingsEntryLanguage = tostring(UI.LanguageDraft or (type(PLDR) == "table" and PLDR.LANGUAGE) or "EN")
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
      CoverPendingFrames = 0;  -- frames the selection has been stable (frame-count cover-load settle)
      DetailsTotal = 0;       -- wrapped lines in the current description (0 = none)
      DetailsVisible = 0;     -- how many of them fit on screen this frame
      DescScrollFrames = nil; -- frames since last desc-scroll step (frame-count rate-limit)
      Reset = function ()
        UI.GameList.CURR = 1;
        UI.GameList.CoverLastIndex = nil
        UI.GameList.CoverPending = false
        UI.GameList.CoverPendingFrames = 0
        UI.GameList.DetailsTotal = 0
        UI.GameList.DetailsVisible = 0
        UI.GameList.DescScrollFrames = nil
      end;
      Play = function()
        local layout = UI.LAYOUT
        UI.GameList.MAXDRAW = layout.LIST_MAX
        -- Device gamelist pages no longer show a top device-name label. MMCE /
        -- MX4SIO / HDD (PFS) never did; on the pages that had one (USB, exFAT,
        -- net-SMB) the label sat right above the first row and duplicated the
        -- carousel the user just came from. Only USB's ever showed in practice
        -- (FifthFox review). Table kept empty so a genuinely-new backend could
        -- still opt back into a title if one is ever actually needed.
        local titles = {}
        local scene_title = titles[UI.CURSCENE]
        -- Lift the device label clear of the first game row: it's centered at
        -- TITLE_Y, only ~10px above LIST_Y, so a long first-row title overlaps it.
        -- Raise ~8px (to the top safe edge) without moving the list. (#501)
        local device_title_y = layout.TITLE_Y - 8
        if scene_title ~= nil and not UI.ShouldHideAuxText(UI.CURSCENE) then
          Font.ftPrint(LFONT, UI.SCR.X_MID, device_title_y, 8, UI.SCR.X, 16, scene_title, UI.CCOL.GREY)
        end
        -- No scenes are placeholders anymore: GBDMHDD (exFAT) + GSMBNET (SMB) render the
        -- real game list via `titles` above. Keeping the (now-empty) table + guard so a
        -- genuinely-unimplemented future backend can still opt into the stub render.
        local placeholders = {}
        local placeholder_title = placeholders[UI.CURSCENE]
        if placeholder_title ~= nil then
          if not UI.ShouldHideAuxText(UI.CURSCENE) then
            Font.ftPrint(LFONT, UI.SCR.X_MID, device_title_y, 8, UI.SCR.X, 16, placeholder_title, UI.CCOL.GREY)
            Font.ftPrintMultiLineAligned(BFONT, UI.SCR.X_MID, UI.SCR.Y_MID, 20, UI.SCR.X, 32, PLDR.L("Not implemented yet"), UI.CCOL.YELLOW)
          end
          Input_GetEvent()
        if UI.HandleGlobalInput(false) then return end
          if UI.Pad.Events.BACK then UI.SceneChange(UI.SCENES.MMAIN) end
          if UI.Pad.Events.CONFIRM then
            UI.Notif_queue.add("This backend isn't implemented yet", "warn")
          end
          local labels, order = UI.Footer.ResolveLegend({
            order = UI.Footer.order_with_start_r2,
            order_id = "start_r2",
            circle = UI.Footer.labels.circle_other,
            cross = UI.Footer.labels.cross_confirm,
            start = UI.Footer.labels.start_profiles
          })
          UI.Footer.Draw(labels, order)
          return
        end
        -- A game hidden under "Hidden games = Hidden" must leave THIS list, or the
        -- "Game hidden" toast fires while the row sits there looking untouched, which
        -- is indistinguishable from the feature not working (sAGA, rolling 2026-07-27).
        -- Dropped LOCALLY rather than by raising R1: the R1 rescan re-initialises the
        -- whole device -- SMB logs out and back in, MMCE re-detects, APA remounts --
        -- then resets the cursor to the top and fires a second toast, all to remove one
        -- row. Consumed HERE, immediately before `ammount` is taken, so the CLAMP just
        -- below repairs the cursor and nothing this frame ever sees a stale count.
        -- Matched by entry IDENTITY, so a flag that somehow outlives the page simply
        -- finds nothing on the next device's list and clears itself.
        if UI.PendingHideDrop ~= nil then
          local drop = UI.PendingHideDrop
          UI.PendingHideDrop = nil
          for i = #PLDR.GAMES, 1, -1 do
            if PLDR.GAMES[i] == drop then table.remove(PLDR.GAMES, i); break end
          end
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
            Font.ftPrint(SFONT, layout.LIST_X, layout.LIST_Y - 20, 0, UI.SCR.X, 16, PLDR.L("Slot:").." "..PLDR.MMCE.PREFIX, UI.CCOL.GREY)
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
          local hdd_part, hdd_relpath = string.match(display_name or "", "^([^|]+)|(.+)$")
          if hdd_relpath ~= nil then
            if type(PLDR.IsPartitionInstalledHddEntry) == "function"
               and PLDR.IsPartitionInstalledHddEntry(hdd_part, hdd_relpath) then
              -- Partition-installed game: show the partition name minus its
              -- 3-char prefix, not the fixed "IMAGE0" payload name.
              display_name = string.sub(hdd_part, 4)
            else
              display_name = string.match(hdd_relpath, "([^/]+)$") or hdd_relpath
            end
          end
	          local c = (i == UI.GameList.CURR) and UI.COLORS.LIST_SELECTED or UI.COLORS.LIST_UNSELECTED
          if PLDR.IsGameHidden and PLDR.IsGameHidden(PLDR.GAMES[i]) then
            c = (i == UI.GameList.CURR) and LIST_HIDDEN_SELECTED_COLOR or LIST_HIDDEN_COLOR
          end
          local label = StripVcdExtension(display_name)
          -- Collapsed multi-disc: the only disc-marked row visible is the disc-1
          -- representative, so drop its "(Disc N)" marker for a clean title. GATED on
          -- collapse -- with collapse OFF every disc shows and trimming would render the
          -- Disc 1 / Disc 2 rows identically.
          if type(PLDR) == "table" and PLDR.COLLAPSE_MULTIDISC == true then
            local trimmed = StripDiscMarker(label)
            if trimmed ~= "" then label = trimmed end
          end
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
          if cover_enabled and cover_img ~= nil then
            preview_img = cover_img
            preview_is_live_cover = true
          end
          -- When there is NO live cover -- preview OFF (Square), or ON but the game
          -- has no cover art -- the placeholder below draws cover_default.png, with
          -- cover_missing.png overlaid only when the preview is ON (enabled + missing).
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
          -- frame.png is the decorative border (256x256), same aspect correction so
          -- it stays square on BOTH standards instead of warping per video mode.
          -- Sized FIRST: the live cover below now fits inside the FRAME's window.
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
          local cover_w, cover_h, cover_x_abs, cover_y_off = nil, nil, nil, 0
          if preview_img ~= nil and preview_is_live_cover then
            local iw = Graphics.getImageWidth(preview_img)
            local ih = Graphics.getImageHeight(preview_img)
            if type(iw) ~= "number" or iw <= 0 then iw = 1 end
            if type(ih) ~= "number" or ih <= 0 then ih = 1 end
            local ratio = (iw / ih) * (480 / (UI.SCR.Y or 448))
            if frame_w ~= nil and frame_h ~= nil then
              -- Fit INSIDE the jewel case's cover window, measured from frame.png's
              -- alpha channel (256x256 art; the transparent slot right of the spine
              -- spans x 26..250, y 4..229). The window rect is FRAME-RELATIVE, so it
              -- scales with the case on every video mode and containment holds by
              -- construction. The old COVER_W screen-box sizing anchored the art to
              -- the frame's OUTER edge and overflowed the window (5px right on NTSC,
              -- 21px on PAL, and a portrait cover ran 17px past the window bottom,
              -- flush with the case's absolute bottom edge -- the GTA screenshot,
              -- 2026-07-20). Placeholder/disabled art keep their own tuned rect
              -- (maintainer confirmed those register correctly).
              local win_w = frame_w * (225 / 256)
              local win_h = frame_h * (226 / 256)
              local cw = win_h * ratio
              if cw > win_w then cw = win_w end
              cover_w = Round(cw)
              cover_h = Round(cw / ratio)
              local frame_x0 = draw_x + (draw_w - frame_w)
              -- Right-anchored INSIDE the window (window right edge = png x 251),
              -- top at the window top (png y 4); offset rides the lifted draw_y.
              cover_x_abs = Round(frame_x0 + frame_w * (251 / 256) - cover_w)
              cover_y_off = Round(frame_h * (4 / 256))
            else
              -- No frame art present: keep the original COVER_W box sizing.
              local box = math.min(layout.COVER_W or 232, draw_w, draw_h)
              if ratio >= 1 then
                cover_w = box
                cover_h = Round(box / ratio)
              else
                cover_h = box
                cover_w = Round(box * ratio)
              end
              if cover_w > draw_w then cover_w = draw_w end
              if cover_h > draw_h then cover_h = draw_h end
              cover_x_abs = draw_x + (draw_w - cover_w)
            end
          end
          -- Visible art height = the taller of the cover/frame (both top-anchored).
          -- The missing/disabled placeholder now shares the frame's aspect-corrected
          -- rect (see the draw below), so the frame_h branch already accounts for it;
          -- only fall back to the full box height when there is NO frame to size to,
          -- otherwise details would sit ~17px (NTSC) below a dead gap. (#496/#501)
          local art_h = 0
          if cover_h ~= nil and cover_h > art_h then art_h = cover_h end
          if frame_h ~= nil and frame_h > art_h then art_h = frame_h end
          if frame_h == nil and not preview_is_live_cover and draw_h > art_h then
            art_h = draw_h
          end
          if art_h <= 0 then art_h = draw_h end
          -- Per-game details: when the feature is on AND a "<name>.txt" was found,
          -- wrap it, place it DIRECTLY under the artwork, and lift the [art + gap +
          -- text] group so it CENTERS in the content area (top safe margin .. above
          -- the button bar) -- biased up so it doesn't feel bottom-heavy, and with no
          -- dead gap between art and text. A blurb taller than fits is windowed and
          -- SCROLLS with the right analog stick (input section). The art never moves
          -- DOWN from its normal spot; the line budget clears the footer icons.
          local details_lines, details_y, details_first = nil, nil, 1
          local details_line_h, details_gap = 14, 4
          local details_h, details_visible, details_total = 0, 0, 0
          UI.GameList.DetailsTotal = 0
          UI.GameList.DetailsVisible = 0
          -- HideTextMode ~= true: Select (Hide UI Text) hides this details blurb
          -- like the caption/footer text it shares the panel with (compute gate,
          -- not paint gate: also skips the wrap/window work and the cover-lift,
          -- so the cover renders at its normal details-off position).
          if cover_enabled and UI.HideTextMode ~= true
             and type(PLDR) == "table" and PLDR.SHOW_DETAILS == true
             and UI.CoverCache ~= nil and type(UI.CoverCache.last_desc) == "string"
             and UI.CoverCache.last_desc ~= "" then
            local footer_y = layout.FOOTER_ICON_Y or (UI.SCR.Y - 56)
            -- Clear the footer ICON ROW (icons are centred on footer_y, ~12px tall
            -- each half) with real breathing room, not just the icon centres: at -24
            -- the last info-text line sat right on top of the button menu (FifthFox).
            -- A bigger clearance also raises the whole centred [art + text] group, so
            -- the artwork lifts too (what FifthFox asked for once the device label is
            -- gone). Trades ~1 visible description line for the gap, which is fine.
            local bottom_limit = footer_y - 40
            local top_margin = ((layout.SAFE and layout.SAFE.T) or 24) + 8
            local avail = bottom_limit - top_margin
            -- Pull the Details window up into the frame's transparent bottom margin
            -- (frame.png's case art ends ~8px above frame_h) so it starts ~one line closer
            -- to the cover for a bigger window (oldman63). Only when the frame is the lower
            -- edge (placeholder, or a cover shorter than the frame).
            local details_art_h = art_h
            if frame_h ~= nil and frame_h >= (cover_h or 0) then
              details_art_h = art_h - Round(frame_h * 0.03)
              if details_art_h < 0 then details_art_h = 0 end
            end
            local cap = math.floor((avail - details_art_h - details_gap) / details_line_h)
            if cap < 1 then cap = 1 end
            local all_lines = UI.CoverCache.last_desc_lines
            if all_lines == nil then
              -- Wrap ONCE per selection and cache it; re-wrapping the .txt every
              -- frame was dragging list nav while cover preview is on (#499/#501).
              all_lines = WrapGameDetailsLines(UI.CoverCache.last_desc, 30)
              UI.CoverCache.last_desc_lines = all_lines
            end
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
              local group_h = details_art_h + details_gap + details_h
              local group_top = Round(top_margin + (avail - group_h) / 2)
              if group_top < top_margin then group_top = top_margin end
              if group_top > draw_y then group_top = draw_y end  -- only lift up, never down
              -- Belt-and-suspenders: never let the group bottom cross into the button
              -- bar, even on an unusually short screen where the art nearly fills the
              -- content band (unreachable on real PS2 video modes; keeps the footer
              -- icons clear if one ever exists). Prioritizes footer clearance.
              if group_top + group_h > bottom_limit then group_top = bottom_limit - group_h end
              draw_y = group_top
              details_y = draw_y + details_art_h + details_gap
            end
          end
          -- Draw the cover/placeholder at the (possibly lifted) draw_y. The default
          -- cover, the missing overlay, and the frame all share the frame's
          -- aspect-corrected, right-anchored rect (frame_x,draw_y,frame_w,frame_h) so
          -- they register with the jewel-case window on BOTH NTSC and PAL; a live
          -- cover uses its own COVER_W inset (also right-anchored).
          local frame_x = (frame_w ~= nil) and (draw_x + (draw_w - frame_w)) or draw_x
          if preview_is_live_cover and preview_img ~= nil and cover_w ~= nil and cover_h ~= nil then
            -- Live cover art: fitted + right-anchored inside the case WINDOW
            -- (cover_x_abs/cover_y_off computed with the frame sizing above).
            Graphics.drawScaleImage(preview_img, cover_x_abs, draw_y + cover_y_off, cover_w, cover_h)
          elseif frame_w ~= nil and frame_h ~= nil then
            -- No live cover -> the DEFAULT cover, drawn INSET in the case WINDOW exactly
            -- like a live cover (right of the spine, above the case bottom) so the case
            -- LEFT SPINE and borders don't cover it and it can't overhang the bottom.
            -- frame.png is a jewel case: opaque left spine (~x0-25), top/bottom bars, and a
            -- transparent cover window to the right. Drawing cover_default across the FULL
            -- frame rect hid its left edge under the spine AND poked ~9% below the case on
            -- PAL (provato). cover_default.png is square 256x256, so size it in the COVER_W
            -- box with the same aspect correction + right-anchor a live cover uses; the
            -- "missing cover" overlay rides the same rect.
            local pbox = math.min(layout.COVER_W or 232, draw_w, draw_h)
            local pratio = 480 / (UI.SCR.Y or 448)   -- square image -> iw/ih = 1
            local ph_w, ph_h
            if pratio >= 1 then ph_w = pbox; ph_h = Round(pbox / pratio)
            else ph_h = pbox; ph_w = Round(pbox * pratio) end
            if ph_w > draw_w then ph_w = draw_w end
            if ph_h > draw_h then ph_h = draw_h end
            local ph_x = draw_x + (draw_w - ph_w)
            if IMG.cover_default ~= nil then
              Graphics.drawScaleImage(IMG.cover_default, ph_x, draw_y, ph_w, ph_h)
            end
            if cover_enabled and IMG.cover_missing ~= nil then
              Graphics.drawScaleImage(IMG.cover_missing, ph_x, draw_y, ph_w, ph_h)
            end
          end
          if IMG.frame ~= nil and frame_w ~= nil and frame_h ~= nil then
            Graphics.drawScaleImage(IMG.frame, frame_x, draw_y, frame_w, frame_h)
          end
          -- (EXP56: the "Loading art..." line is REMOVED. It was added when a fetch
          -- could stall the frame; with loads off the render thread it resolves fast
          -- enough that the text only flickered. Maintainer: "unnecessary now.")
          -- EXP42: the "No cover. Looked for: <path>" caption is REMOVED (maintainer:
          -- "totally useless"). It shipped as a tester self-check aid back when cover
          -- paths were user-selectable; EXP35 hard-locked the location, so it only ever
          -- added noise for normal users, who read an empty jewel case fine. Cover
          -- preview OFF likewise shows the plain default cover above, with no text label.
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
            -- Left-align each line (ALIGN_LEFT = 0) at the panel's left edge instead
            -- of centering, so a "table"-style sidecar (Title=..., Genre=..., etc.)
            -- reads cleanly as a list. One ftPrint per visible line.
            -- Alignment of the description box per the Game-details setting: left
            -- (ALIGN_LEFT=0) at the panel's left edge, center (ALIGN_HCENTER=8) on its
            -- middle, right (ALIGN_RIGHT=4) at its right edge.
            local d_align = (type(PLDR) == "table") and PLDR.DETAILS_ALIGN or "left"
            local d_x, d_flag = draw_x, 0
            if d_align == "center" then d_x, d_flag = draw_x + Round(draw_w / 2), 8
            elseif d_align == "right" then d_x, d_flag = draw_x + draw_w, 4 end
            local ly = details_y
            for bi = 1, #buf do
              Font.ftPrint(SFONT, d_x, ly, d_flag, draw_w, details_line_h, buf[bi], UI.CCOL.GREY)
              ly = ly + details_line_h
            end
          end
        end
        if ammount <= 0 then
          if not UI.ShouldHideAuxText(UI.CURSCENE) then
            Font.ftPrintMultiLineAligned(LFONT, UI.SCR.X_MID, UI.SCR.Y_MID, 20, UI.SCR.X, 32, PLDR.L("No games found"), UI.CCOL.YELLOW)
            Font.ftPrintMultiLineAligned(LFONT, UI.SCR.X_MID+1, UI.SCR.Y_MID+1, 20, UI.SCR.X, 32, PLDR.L("No games found"), UI.CCOL.TRANSP_BLACK)
          end
        end
        Input_GetEvent()
        if UI.HandleGlobalInput(false) then return end
        if UI.Pad.Events.BACK then
          if UI.CURSCENE == UI.SCENES.GSMBNET and type(System) == "table" and type(System.disconnectSMB) == "function" then
            pcall(System.disconnectSMB)   -- free the share + connection when leaving the SMB page
          end
          -- Drop any transient R3 reveal on the way out (restore the real persisted hide
          -- setting) so reveal is per-visit and never leaks to the next device list.
          if PLDR._GLOBAL_HIDE_SAVED ~= nil then
            PLDR.GLOBAL_HIDE = (PLDR._GLOBAL_HIDE_SAVED == true)
          end
          UI.RevealHidden = false
          PLDR._GLOBAL_HIDE_SAVED = nil
          UI.PendingHideDrop = nil   -- never carry a pending row-drop to another device
          UI.SceneChange(UI.SCENES.MMAIN)
        end
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
          -- (Left-stick navigation now feeds the d-pad globally in the pad poll --
          -- OPL-style stick->d-pad fold -- so the stick does smooth item-by-item nav
          -- with auto-repeat just like the d-pad. The page-jump is NAV_LEFT/RIGHT
          -- (stick left/right or d-pad left/right) above; L1 jumps top/bottom.
          -- Replaces the old 250ms whole-page stick jump (oldman63 #501: "sped up
          -- like crazy, can't select individual items" -- jumping pages, not items).)
          -- Right analog stick scrolls a description that's too long to fully fit
          -- under the cover (when game details are on). The stick is otherwise
          -- unused here (R3 is the click, separate), so this is a free, discoverable
          -- "read the rest" gesture. Sensitivity + step rate come from the
          -- "Description scroll speed" setting (fast/medium/slow); slow is the
          -- deliberate default (firm push, ~2 lines/sec) so a light touch does
          -- nothing and it never flies past. DetailsTotal / DetailsVisible were set
          -- by the render block this frame.
          if UI.CoverCache ~= nil and (UI.GameList.DetailsTotal or 0) > (UI.GameList.DetailsVisible or 0)
             and type(Pads) == "table" and type(Pads.getRightStick) == "function" then
            local ok_rs, _, rv = pcall(Pads.getRightStick)
            -- One scroll step every _secs seconds, FRAME-COUNTED (not the wall clock):
            -- Timer.getTime() is microseconds on PS2, so a wall-clock gate would be
            -- sub-frame and scroll every frame. This block runs once per vblank-paced
            -- frame, so step_frames = ceil(_secs * fps) is unit-safe and identical in real
            -- seconds on PAL (50Hz) and NTSC (60Hz). Pace is fixed at Fast (the speed
            -- setting was removed -- provato + maintainer: Fast is best).
            local _dz, _secs = 48, 0.15        -- Fast: light push, ~7 lines/sec
            if ok_rs and type(rv) == "number" and math.abs(rv) > _dz then
              local fps = ((UI.SCR.Y or 448) >= 512) and 50 or 60
              local step_frames = math.ceil(_secs * fps)
              local f = (UI.GameList.DescScrollFrames or step_frames) + 1
              if f >= step_frames then
                local off = UI.CoverCache.desc_scroll or 0
                if rv > 0 then off = off + 1 else off = off - 1 end
                local max_off = (UI.GameList.DetailsTotal or 0) - (UI.GameList.DetailsVisible or 0)
                if off < 0 then off = 0 end
                if off > max_off then off = max_off end
                UI.CoverCache.desc_scroll = off
                f = 0
              end
              UI.GameList.DescScrollFrames = f
            else
              UI.GameList.DescScrollFrames = nil  -- released: next push scrolls right away
            end
          end
        end
        -- EXP42: Square no longer toggles cover art here. It was a session-only flip
        -- that reset every boot and was undiscoverable once the footer legend dropped
        -- it; it now lives in Settings > Game List > "Cover art" (PLDR.COVER_ART),
        -- which persists. UI.SetCoverPreview is what that setting drives.
        if UI.CoverCache ~= nil then
          -- EXP49: adopt a finished async cover (or advance past a miss). Pure bookkeeping:
          -- no filesystem work, never blocks. Must run every frame, before the settle below,
          -- so a texture that landed during the last frame is on screen immediately.
          if type(UI.CoverCache.Pump) == "function" then UI.CoverCache:Pump() end
          -- Cover-load settle: DECODE the selection's cover only after the cursor has been
          -- STABLE for ~250ms, FRAME-COUNTED (Timer.getTime is microseconds, so the old
          -- CoverIdleMs=200 was sub-frame and re-decoded the cover on nearly every selection
          -- change while scrolling, dragging navigation -- oldman63). CURR keeps changing
          -- while you scroll so the counter resets and nothing decodes; the cover loads only
          -- once you stop.
          local nav_event = UI.Pad.Events.NAV_DOWN or UI.Pad.Events.NAV_RIGHT or UI.Pad.Events.NAV_UP or UI.Pad.Events.NAV_LEFT
          local cover_fps = ((UI.SCR.Y or 448) >= 512) and 50 or 60
          local COVER_IDLE_FRAMES = math.ceil(cover_fps * 0.25)  -- ~250ms, above the nav repeat rate
          if UI.CoverPreviewEnabled == false then
            UI.GameList.CoverPending = false
            UI.GameList.CoverPendingFrames = 0
            UI.CoverCache:UpdateSelection(nil)
          elseif ammount <= 0 then
            UI.GameList.CoverLastIndex = nil
            UI.GameList.CoverPending = false
            UI.GameList.CoverPendingFrames = 0
            UI.CoverCache:UpdateSelection(nil)
          else
            if UI.GameList.CURR ~= UI.GameList.CoverLastIndex then
              UI.GameList.CoverLastIndex = UI.GameList.CURR
              UI.GameList.CoverPending = true
              UI.GameList.CoverPendingFrames = 0
            end
            if UI.GameList.CoverPending then
              UI.GameList.CoverPendingFrames = (UI.GameList.CoverPendingFrames or 0) + 1
              -- EXP33: never fire the cover probe while the scene transition is
              -- still running. UpdateSelection does a SYNCHRONOUS read on the
              -- game device, and a missing cover is a full FAT dir-chain walk
              -- (seconds on SD-over-SIO2 / USB 1.1). Firing it mid-fade blocked
              -- the render loop on the opaque background overlay -- the reported
              -- "only the background shows, activity light stuck on, then the
              -- list pops in". Let the list paint and the fade finish first.
              local transitioning = type(UI.Transition) == "table" and UI.Transition.active == true
              if not nav_event and not transitioning and UI.GameList.CoverPendingFrames >= COVER_IDLE_FRAMES then
                local entry = PLDR.GAMES[UI.GameList.CURR]
                local vcd_path = ResolveSelectedVcdPath(entry, PLDR.GAMEPATH)
                UI.CoverCache:UpdateSelection(vcd_path, UI.CURSCENE == UI.SCENES.GHDD, entry)
                UI.GameList.CoverPending = false
              end
            end
          end
        end
        local function LaunchSelectedGame(launch_options)
          if ammount <= 0 then
            UI.Notif_queue.add("No games found on this device", "warn")
            return
          end
          local entry = PLDR.GAMES[UI.GameList.CURR]
          if entry == nil then
            UI.Notif_queue.add("Couldn't read that game selection", "error")
            return
          end
          local root, rel = string.match(entry or "", "^([^|]+)|(.+)$")
          -- Launch progress (maintainer: an ATA launch sat "a very long time on a
          -- frozen state before the game launched"). Everything below -- the
          -- POPSTARTER probes, the game-file probe, the adaptive-BDMA driver
          -- staging inside RunPOPStarterGame -- is blocking device I/O that
          -- painted NOTHING, so the game list just froze. Paint before each slow
          -- step; the last frame stays up until POPStarter takes the screen
          -- (the exec never returns, so there is no hide to do on success).
          local function paint(msg, pct)
            if type(UI.ShowSavingOverlay) == "function" then pcall(UI.ShowSavingOverlay, msg, pct) end
          end
          local function unpaint()
            if type(UI.HideSavingOverlay) == "function" then pcall(UI.HideSavingOverlay) end
            PLDR.LaunchProgress = nil
          end
          paint(PLDR.L("Checking POPSTARTER..."), 0.12)
          -- Empty = Automatic (no user-defined path): the launch resolver walks
          -- the device/cwd/mc ladder on its own (profiles dropped -- R3Z3N).
          local configured_popstarter_path = tostring(PLDR.POPSTARTER_PATH or "")
          local popstarter_path = configured_popstarter_path
          -- Resolve against the root the launch call itself will use. USB entries encode
          -- their own device root ("<root>POPS/|name") and the USB page keeps
          -- PLDR.GAMEPATH = "" (multi-drive lists), so resolving with GAMEPATH here never
          -- checked <drive>:/POPS/POPSTARTER.ELF and a drive-resident-only POPSTARTER
          -- failed this gate even though RunPOPStarterGame(root, rel) below would have
          -- found it (sAGA/oldman63). GHDD keeps GAMEPATH: its entries encode a partition
          -- name, not a device root.
          local resolve_location = PLDR.GAMEPATH
          if UI.CURSCENE ~= UI.SCENES.GHDD and root ~= nil and IsDevicePath(root) then
            resolve_location = root
          end
          if type(PLDR.ResolveLaunchPopstarterPath) == "function" then
            popstarter_path = PLDR.ResolveLaunchPopstarterPath(resolve_location, configured_popstarter_path)
          elseif type(PLDR.ResolvePopstarterPath) == "function" then
            popstarter_path = PLDR.ResolvePopstarterPath(configured_popstarter_path)
          end
          local popstarter_ok = false
          if type(PLDR.PopstarterProbeWithEnsure) == "function" then
            popstarter_ok = PLDR.PopstarterProbeWithEnsure(popstarter_path)
          else
            popstarter_ok = doesFileExist(popstarter_path)
          end
          if not popstarter_ok then
            -- The only user-facing POPSTARTER warning by design: a set-but-stale
            -- custom path falls through the ladder SILENTLY; only "nothing found
            -- anywhere" warns (R3Z3N).
            local message
            if configured_popstarter_path == "" then
              -- Name the places we ACTUALLY probed. On the SMB page we deliberately
              -- do NOT read POPSTARTER.ELF from the share (system.lua
              -- ResolveDeviceLocalPopstarter refuses any smb: root), so the generic
              -- "checked the game device" wording was a lie there -- issue #560, where
              -- it sent a tester to put the file in his share twice, in the one place
              -- the ladder will never look.
              if UI.CURSCENE == UI.SCENES.GSMBNET then
                message = "No POPSTARTER.ELF found\nPOPSTARTER is never read from the share -- put it in mc0:/POPSTARTER/,\nor beside POPSLOADER.ELF, or set Settings > POPSTARTER Path"
              else
                message = "No POPSTARTER.ELF found\nchecked the game device, the launcher folder and mc0:/mc1:"
              end
            else
              message = PLDR.L("No POPSTARTER found at this path").."\n"..configured_popstarter_path
              if configured_popstarter_path ~= tostring(popstarter_path) then
                message = message.."\n"..PLDR.L("Resolved:").." "..tostring(popstarter_path)
              end
            end
            unpaint()
            UI.Notif_queue.add(message, "error")
            return
          end
          if type(launch_options) == "table" and launch_options.hdd_selector_mode == "full_hdd_pfs0" then
            local lowered_popstarter = string.lower(tostring(popstarter_path or ""))
            if string.match(lowered_popstarter, "^hdd%d:") == nil and string.match(lowered_popstarter, "^pfs%d*:/") == nil then
              unpaint()
              UI.Notif_queue.add("HDD Alt mode needs POPSTARTER on HDD", "warn")
              return
            end
          end
          -- SMB stream launches read their server/share from mc:/POPSTARTER/
          -- SMBCONFIG.DAT, which exists only once the SMB modules pack is
          -- installed. Browsing works WITHOUT it (the menu has its own embedded
          -- stack), so without this gate a launch fails in-game with zero
          -- explanation.
          -- Gate on the FILE, not just the setting. PLDR.SMB_MODULES is a saved
          -- preference; PLDR.SyncSmbDat tests `smbman.irx` actually being on the card
          -- before it will write SMBCONFIG.DAT. Those two can disagree -- a setting
          -- left true after a failed or partial install, or a card swapped out -- and
          -- when they do, this gate waved the launch through while SyncSmbDat silently
          -- no-op'd, handing POPStarter the placeholder SMBCONFIG.DAT the repo ships
          -- ("SMBip:SMBport SMBshareNAME"). The result is a launch that dies partway
          -- into loading with no explanation, which is issue #560's second symptom.
          if UI.CURSCENE == UI.SCENES.GSMBNET then
            local modules_staged = (type(PLDR.AreSmbModulesStaged) == "function")
              and PLDR.AreSmbModulesStaged() or (PLDR.SMB_MODULES == true)
            if not modules_staged then
              unpaint()
              if PLDR.SMB_MODULES == true then
                UI.Notif_queue.add("SMB modules are missing from the memory card\nThe setting is on but the files are not there --\nre-install via Settings > SMB modules, then Save", "error")
              else
                UI.Notif_queue.add("SMB modules are not installed\nGames list but won't boot without them --\ninstall via Settings > SMB modules, then Save", "error")
              end
              return
            end
            -- The pack being present is not enough: POPSTARTER also needs a literal
            -- address and a server/share, and every one of those is BLANK on a fresh
            -- install now that nothing is invented. A blank address means
            -- IPCONFIG.DAT is never written, which is the original #560 black
            -- screen by another route. Name the empty fields instead of letting the
            -- user find out by staring at a dead screen.
            local missing = (type(PLDR.MissingPopstarterNetFields) == "function")
              and PLDR.MissingPopstarterNetFields() or {}
            if #missing > 0 then
              unpaint()
              local names = {}
              for i = 1, #missing do
                names[#names + 1] = PLDR.L(UI._SMB_LABELS[missing[i]] or missing[i])
              end
              UI.Notif_queue.add(PLDR.L("POPSTARTER needs these filled in first:").."\n"
                ..table.concat(names, ", ").."\n"..PLDR.L("Settings > SMB / Network"), "error")
              return
            end
          end
          paint(PLDR.L("Checking the game file..."), 0.30)
          local vcd_full = ResolveSelectedVcdPath(entry, PLDR.GAMEPATH)
          -- Skip the existence preflight on net-SMB too: per-file stat over the live
          -- smb0: browse mount is unreliable, and this is only a (non-blocking) toast.
          if UI.CURSCENE ~= UI.SCENES.GHDD and UI.CURSCENE ~= UI.SCENES.GSMBNET then
            if not doesFileExist(vcd_full) then
              UI.Notif_queue.add(PLDR.L("Game file missing").."\n"..vcd_full, "error")
            end
          end
          -- Hook the slow stages INSIDE RunPOPStarterGame (adaptive-BDMA driver
          -- staging = several memory-card writes; the handoff itself). Cleared
          -- on the cancel path; on success the exec never comes back.
          PLDR.LaunchProgress = paint
          paint(PLDR.L("Starting the game..."), 0.50)
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
          -- Reached ONLY when the launch did not exec (cancelled by the adaptive
          -- -BDMA staging gate, or failed): a successful launch never returns
          -- here. Drop the overlay so the menu is usable and the failure toast
          -- is readable instead of sitting behind a stuck progress box.
          unpaint()
        end
        -- R3 = reveal / re-hide this device's hidden games. The "Hidden games"
        -- setting (GLOBAL_HIDE) filters hidden entries out of the list at SCAN
        -- time, so flipping it requires rebuilding the current device's list --
        -- reuse the proven R1 force-refresh path below by raising its event.
        -- Persisted so it stays in sync with Settings > Game List > Hidden games.
        -- Revealed games render dimmed; press L3 to unhide. Only the device list
        -- scenes R1 serves are eligible (others ignore R3 harmlessly).
        local r3_hide_toggle, r3_save_ok = false, true
        if UI.Pad.Events.R3 and (UI.CURSCENE == UI.SCENES.GHDD
             or UI.CURSCENE == UI.SCENES.GSMB
             or UI.CURSCENE == UI.SCENES.GMX4SIO
             or UI.CURSCENE == UI.SCENES.GBDMHDD
             or UI.CURSCENE == UI.SCENES.GSMBNET
             or UI.CURSCENE == UI.SCENES.GUSBFAT) then
          -- R3 reveal/re-hide only MEANS anything when the persisted "Hide hidden
          -- games" setting is ON -- that setting is what filters hidden entries out
          -- of the scan. When it is OFF, hidden games are ALWAYS shown (dimmed), so
          -- there is nothing to reveal or re-hide. R3 used to toggle regardless and
          -- fire "Hidden games filtered out again" while the games stayed on screen,
          -- contradicting what the user saw (sAGA #539). Detect the real setting and
          -- explain instead of lying. (During an active reveal GLOBAL_HIDE is the
          -- transient false, so consult the captured _GLOBAL_HIDE_SAVED.)
          local real_hide
          if PLDR._GLOBAL_HIDE_SAVED ~= nil then
            real_hide = (PLDR._GLOBAL_HIDE_SAVED == true)
          else
            real_hide = (PLDR.GLOBAL_HIDE == true)
          end
          if not real_hide then
            UI.Notif_queue.add(PLDR.L("Hidden games are already shown here (dimmed)\nEnable \"Hide hidden games\" in Settings to filter them out"), "ok")
          else
            -- Reveal is a TRANSIENT per-session view: temporarily clear GLOBAL_HIDE so the
            -- scan re-includes hidden games (dimmed); re-hide restores it. Does NOT touch the
            -- persisted setting -- Settings > Game List > Hidden games owns that single source
            -- of truth. (R3 used to flip+PERSIST GLOBAL_HIDE, fighting the Settings page and
            -- then blocking the L3 unhide it tells you to use -- provato HW report.)
            UI.RevealHidden = (UI.RevealHidden ~= true)
            if PLDR._GLOBAL_HIDE_SAVED == nil then
              PLDR._GLOBAL_HIDE_SAVED = (PLDR.GLOBAL_HIDE == true)   -- capture the real setting once (false stored as false, not nil)
            end
            if UI.RevealHidden then
              PLDR.GLOBAL_HIDE = false                               -- reveal: scan re-includes hidden (dimmed)
            else
              PLDR.GLOBAL_HIDE = (PLDR._GLOBAL_HIDE_SAVED == true)   -- re-hide: restore the captured setting
            end
            r3_save_ok = true   -- nothing persisted now, so never a save-failure case
            r3_hide_toggle = true
            UI.Pad.Events.R1 = true   -- drive the same in-place rebuild R1 performs
          end
        end
        -- A Settings visit cancelled an R3 reveal (restoring GLOBAL_HIDE) while
        -- this list still showed the revealed games: rebuild via the same R1
        -- raise so the list matches the restored setting on return.
        if UI.PendingHideRebuild == true then
          UI.PendingHideRebuild = false
          UI.Pad.Events.R1 = true
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
          if r3_hide_toggle then
            -- R3 drove this rebuild; its reveal/hide toast fires below instead.
          elseif #PLDR.GAMES < 1 then
            -- EXP33: same self-diagnosing readout as the first-entry toast.
            local d = PLDR.HDD.SCAN_DIAG
            local diag = ""
            if type(d) == "table" then
              if (tonumber(d.remount_fail) or 0) > 0 then
                diag = string.format("\nmounted %d/%d, remount-fail (rc %s on %s)",
                         tonumber(d.remounted) or 0, tonumber(d.avail) or 0,
                         tostring(d.last_fail_rc), tostring(d.last_fail_part))
              elseif (tonumber(d.avail) or 0) > 0 then
                diag = string.format("\n%d part, %d files, %d VCD",
                         tonumber(d.avail) or 0, tonumber(d.entries) or 0, tonumber(d.vcds) or 0)
                if (tonumber(d.hidden) or 0) > 0 then
                  diag = diag..PLDR.LFmt(" (%d hidden -- Global Hide is on)", tonumber(d.hidden) or 0)
                elseif (tonumber(d.collapsed) or 0) > 0 then
                  diag = diag..PLDR.LFmt(" (%d multi-disc collapsed)", tonumber(d.collapsed) or 0)
                end
              end
            end
            -- Translate the sentence, THEN append the diagnostic. Concatenating
            -- first defeats add()'s exact-key lookup and threw away the translation
            -- this string already has in all six languages. The diag tail stays
            -- English on purpose: raw mount rc codes and counters (README rule 3).
            UI.Notif_queue.add(PLDR.L("HDD list refreshed (no games found)")..diag, "warn")
          else
            UI.Notif_queue.add("HDD list refreshed", "ok")
          end
        elseif UI.Pad.Events.R1 and (UI.CURSCENE == UI.SCENES.GSMB
               or UI.CURSCENE == UI.SCENES.GMX4SIO
               or UI.CURSCENE == UI.SCENES.GBDMHDD
               or UI.CURSCENE == UI.SCENES.GSMBNET
               or UI.CURSCENE == UI.SCENES.GUSBFAT) then
          -- R1 re-runs the SAME scan entering the page does, in place: re-detect
          -- the device and rebuild the list -- for hotplugging a card/drive or a
          -- config change without leaving the page. This is the FORCE path: a
          -- fresh live scan that then OVERWRITES the device's .gamecache so the
          -- refresh survives a reboot.
          local rescan_scene = UI.CURSCENE
          local smb_rescan_err = nil   -- set by the GSMBNET arm; drives the toast below
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
                PLDR.SaveGameListCache(mmce_prefix.."POPS/.gamecache", PLDR.GAMES, PLDR.HIDDEN)
              end
            elseif rescan_scene == UI.SCENES.GMX4SIO then
              -- EXP32: enumeration only (driver is boot-resident); no markers,
              -- no bdm_query poke -- the bounded sweep IS the refresh.
              report("Checking the MX4SIO card...", 0.16)
              local mx4sio_root = PLDR.InitMX4SIOPopsRoot()
              PLDR.CleanupGameList()
              if type(mx4sio_root) == "string" and mx4sio_root ~= "" then
                report("Scanning MX4SIO games...", 0.30)
                PLDR.GetPS1GameLists(mx4sio_root, true, scan)
                PLDR.SaveGameListCache(mx4sio_root..".gamecache", PLDR.GAMES, PLDR.HIDDEN)
              end
            elseif rescan_scene == UI.SCENES.GBDMHDD then
              -- EXP32: enumeration only; the bounded sweep is the refresh.
              report("Checking the exFAT HDD...", 0.16)
              local ata_root = PLDR.InitATAPopsRoot()
              PLDR.CleanupGameList()
              if type(ata_root) == "string" and ata_root ~= "" then
                report("Scanning exFAT HDD games...", 0.30)
                PLDR.GetPS1GameLists(ata_root, true, scan)
                PLDR.SaveGameListCache(ata_root..".gamecache", PLDR.GAMES, PLDR.HIDDEN)
              end
            elseif rescan_scene == UI.SCENES.GSMBNET then
              report("Reconnecting to SMB...", 0.16)
              -- Tear the live session down first: R1 used to re-LOGON over the open
              -- smbman session (a state the entry path never reaches, HW-untested).
              if type(System) == "table" and type(System.disconnectSMB) == "function" then
                pcall(System.disconnectSMB)
              end
              local smb_root, smb_err = PLDR.InitSMBPopsRoot(report)
              PLDR.CleanupGameList()
              if type(smb_root) == "string" and smb_root ~= "" then
                report("Scanning SMB games...", 0.30)
                PLDR.GetPS1GameLists(smb_root, true, scan)
                PLDR.SaveGameListCache(smb_root..".gamecache", PLDR.GAMES, PLDR.HIDDEN)
              else
                -- Surface the REAL reconnect error instead of the generic
                -- "List refreshed (no games found)" the fallthrough would toast.
                smb_rescan_err = smb_err or "CONN_FAIL"
              end
            else
              report("Initializing USB backend...", 0.16)
              if type(System) == "table" and type(System.ensureUsbMass) == "function" then pcall(System.ensureUsbMass) end
              if type(PLDR.RefreshMassBackends) == "function" then pcall(PLDR.RefreshMassBackends) end
              PLDR.CleanupGameList()
              report("Building USB game list...", 0.30)
              PLDR.BuildMassGameListByType("usb", nil, scan)
              local usb_roots_r1 = PLDR.GetRootsByType("usb")
              -- #==1: never cache a combined multi-drive list to one root's file.
              if type(usb_roots_r1) == "table" and usb_roots_r1[1] ~= nil and #usb_roots_r1 == 1 and #PLDR.GAMES > 0 then
                PLDR.SaveGameListCache(usb_roots_r1[1].."POPS/.gamecache", PLDR.GAMES, PLDR.HIDDEN)
              end
            end
            report("Done", 1.0)
          end, "Failed to refresh list")
          UI.GameList.CURR = 1
          UI.GameList.CoverLastIndex = nil
          UI.GameList.CoverPending = false
          if r3_hide_toggle then
            -- R3 drove this rebuild; its reveal/hide toast fires below instead.
          elseif smb_rescan_err ~= nil then
            UI.Notif_queue.add(UI.SmbErrorMessage(smb_rescan_err), "warn")
          elseif #PLDR.GAMES < 1 then
            UI.Notif_queue.add("List refreshed (no games found)", "warn")
          else
            UI.Notif_queue.add("List refreshed", "ok")
          end
        end
        if UI.Pad.Events.L3 and ammount > 0 then
          -- Refuse ONLY when the selected game is already hidden, i.e. the user is
          -- trying to unhide something the filter is keeping off screen. With
          -- GLOBAL_HIDE on, the scan drops hidden entries outright (system.lua:
          -- `if not (PLDR.GLOBAL_HIDE and is_hidden)`), so every game still ON SCREEN
          -- is visible and the only action possible is HIDE. The old blanket guard
          -- blocked exactly that and then advised about unhiding, so with
          -- *Hidden games = Hidden* the L3 hide did nothing at all (sAGA, rolling
          -- 2026-07-27). The refusal is kept as a safety net for a list that somehow
          -- still carries a hidden entry; in the normal filtered case it is unreachable.
          local l3_entry = PLDR.GAMES[UI.GameList.CURR]
          local l3_hidden = (type(PLDR.IsGameHidden) == "function") and PLDR.IsGameHidden(l3_entry) == true
          if PLDR.GLOBAL_HIDE and UI.RevealHidden ~= true and l3_hidden then
            UI.Notif_queue.add("Hidden games are filtered out.\nPress R3 to reveal them, then L3 to unhide.", "warn")
          elseif UI.CURSCENE == UI.SCENES.GHDD then
            local entry = PLDR.GAMES[UI.GameList.CURR]
            local was_hidden = PLDR.IsGameHidden(entry)
            local ok, reason = PLDR.SetHddGameHidden(entry, not was_hidden)
            if ok then
              UI.Notif_queue.add(was_hidden and "Game shown" or "Game hidden", "ok")
              -- The game is now filtered out of this very list, so rebuild or the toast
              -- says "Game hidden" while the entry sits there looking untouched -- which
              -- is indistinguishable from the feature being broken. Deferred through the
              -- existing flag because the R1 handlers run ABOVE this block and
              -- UI.Pad.Events is cleared every frame, so raising R1 here would be lost.
              if (not was_hidden) and PLDR.GLOBAL_HIDE and UI.RevealHidden ~= true then
                UI.PendingHideDrop = entry
              end
            else
              UI.Notif_queue.add(PLDR.L("Couldn't write .hide to the HDD").." ("..tostring(reason or "")..")\n"..PLDR.L("You can still add a \"<game>.hide\" next to the .VCD from a PC."), "warn")
            end
          else
            local entry = PLDR.GAMES[UI.GameList.CURR]
            local vcd_path = ResolveSelectedVcdPath(entry, PLDR.GAMEPATH)
            local was_hidden = PLDR.IsGameHidden(entry)
            local ok, reason = PLDR.SetGameHidden(entry, vcd_path, not was_hidden)
            if ok then
              UI.Notif_queue.add(was_hidden and "Game shown" or "Game hidden", "ok")
              -- Same rebuild as the HDD branch: with the hide filter on, the entry we
              -- just hid must actually leave the list, or nothing visibly happened.
              -- Dropped on the NEXT frame (see the consumer above `local ammount`),
              -- so the cache save just below still sees the entry present and records
              -- it as hidden rather than losing the game from the cache entirely.
              if (not was_hidden) and PLDR.GLOBAL_HIDE and UI.RevealHidden ~= true then
                UI.PendingHideDrop = entry
              end
              -- Keep the opt-in per-device cache coherent: its H-records (written at
              -- scan time) would otherwise revert this hide on the next page re-entry,
              -- since a cache HIT never re-reads the live .hide. Re-save with the
              -- now-correct PLDR.HIDDEN; SaveGameListCache no-ops when the cache is off.
              -- USB GAMEPATH is "" (entries self-qualify) so derive its root. (audit)
              local cache_path = nil
              if (UI.CURSCENE == UI.SCENES.GSMB or UI.CURSCENE == UI.SCENES.GMX4SIO
                  or UI.CURSCENE == UI.SCENES.GBDMHDD or UI.CURSCENE == UI.SCENES.GSMBNET)
                 and type(PLDR.GAMEPATH) == "string" and PLDR.GAMEPATH ~= "" then
                cache_path = PLDR.GAMEPATH..".gamecache"
              elseif UI.CURSCENE == UI.SCENES.GUSBFAT and type(PLDR.GetRootsByType) == "function" then
                local r = PLDR.GetRootsByType("usb")
                -- #==1: same multi-drive guard as the USB scan cache sites.
                if type(r) == "table" and r[1] ~= nil and #r == 1 then cache_path = r[1].."POPS/.gamecache" end
              end
              if cache_path ~= nil and type(PLDR.SaveGameListCache) == "function" then
                PLDR.SaveGameListCache(cache_path, PLDR.GAMES, PLDR.HIDDEN)
              end
            else
              UI.Notif_queue.add(PLDR.L("Couldn't update hidden state").." ("..tostring(reason)..")", "error")
            end
          end
        end
        if r3_hide_toggle then
          local _r3msg = (UI.RevealHidden == true) and "Showing hidden games (dimmed) -- press L3 to unhide"
            or "Hidden games filtered out again"
          if r3_save_ok then
            UI.Notif_queue.add(_r3msg, "ok")
          else
            UI.Notif_queue.add(PLDR.L(_r3msg).."\n"..PLDR.L("(could NOT save -- reverts on reboot)"), "warn")
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
          start = UI.Footer.labels.start_profiles,
          R2 = UI.CURSCENE == UI.SCENES.GHDD and ammount > 0 and "HDD Alt" or nil
        })
        UI.Footer.Draw(labels, order)
      end;
    };
    ProfileQuery = {
      lastopt = 1;
      Play = function ()
        local layout = UI.LAYOUT
        Font.ftPrint(LFONT, UI.SCR.X_MID, layout.TITLE_Y, 8, UI.SCR.X, 16, PLDR.L("Settings"), UI.CCOL.GREY)

        -- OPL-style focused-list Settings page.
        --
        -- Layout: title -> stack of items (section headers, cycle rows, path
        -- rows). A single highlight bar follows the focused row. Section
        -- headers are non-selectable separators. The whole interaction is
        -- D-pad-driven so the previous one-button-per-field hotkey grid is
        -- gone (Square/L1/R1/Left/Right/Up/Down were each tied to a single
        -- widget; that has been replaced with a single focused cursor).
        --
        -- Bindings:
        --   D-pad Up/Down: move focus, skipping section headers and spacers.
        --   D-pad Left/Right: cycle the focused value (cycle items only).
        --   X (CONFIRM): activate focused item -- cycles a cycle row or
        --                opens the path editor for a path row.
        --   O (BACK): discard staged edits and return to the previous scene.
        --   Start: opens the Save Changes / Reset Defaults / Discard & Exit
        --          menu (UI.Modal.OpenSettingsMenu -- R3Z3N review).
        --   Select: hide-text toggle (global; handled outside this block).
        --
        -- Persistence: every field still routes through the same draft
        -- variables and PLDR.CommitSettingsChanges contract used by the
        -- previous Settings page, so S-01..S-09 and U-01..U-11 paths in
        -- QA_REGRESSION_MATRIX.md continue to apply unchanged.

        local safe = layout.SAFE or {L = 40, R = 40}

        local accent_color    = (UI.COLORS and UI.COLORS.TEXT_PRIMARY) or UI.CCOL.YELLOW
        local label_color     = UI.CCOL.GREY
        local highlight_color = Color.new(50, 80, 160, 110)
        local separator_color = Color.new(140, 200, 255, 60)
        -- Distinct row roles (R3Z3N review): headers get their own hue (warm
        -- gold -- they are chrome, not rows) instead of sharing the focus/dirty
        -- accent blue, and read-only rows render shades darker than selectable
        -- ones so they can't be mistaken for editable fields.
        local section_color      = Color.new(215, 185, 100, 128)
        local section_line_color = Color.new(215, 185, 100, 60)
        local readonly_color     = Color.new(82, 82, 82, 100)

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
          -- Revert the LIVE-applied UI language before re-syncing drafts (the
          -- Language row applies live; discard must undo it).
          if type(PLDR) == "table" and UI.SettingsEntryLanguage ~= nil then
            PLDR.LANGUAGE = tostring(UI.SettingsEntryLanguage)
          end
          UI.SyncSettingsSelectionFromRuntime()
          UI.SyncSettingsDraftFromRuntime()
          UI.SetHideTextMode(UI.SettingsEntryHideTextMode == true, false)
          UI.ProfileDirty = false
          UI.BdmaDirty = false
          UI.PopPathDirty = false
          UI.DkwdrvDirty = false
          UI.VideoStandardDirty = false
        end

        local function discard_settings_and_return()
          restore_settings_session()
          -- the live overscan preview changed the GS display; restore the saved value
          if type(Screen) == "table" and type(Screen.setOverscan) == "function" then
            pcall(Screen.setOverscan, math.floor(tonumber(PLDR.OVERSCAN) or 0))
          end
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
            apply_smb = 0.86,
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
          -- Empty = Automatic (profiles dropped -- R3Z3N): persists as-is.
          local pop_path = tostring(UI.PopstarterPathDraft or PLDR.POPSTARTER_PATH or "")
          local dkwdrv_path = tostring(UI.DkwdrvPathDraft or PLDR.DKWDRV_PATH or PLDR.DKWDRV_DEFAULT_PATH or "mc0:/PS1_DKWDRV/DKWDRV.ELF")
          local mode_entry = UI.BdmaModes[UI.BdmaModeIndex] or UI.BdmaModes[1]
          local mode_key = mode_entry and mode_entry.key or "FAT32"
          local video_entry = UI.VideoStandardModes[UI.VideoStandardIndex] or UI.VideoStandardModes[1]
          local video_key = video_entry and video_entry.key or VIDEO_STANDARD_NTSC
          local boot_page_entry = UI.BootPageModes[UI.BootPageIndex] or UI.BootPageModes[1]
          local boot_page_key = boot_page_entry and boot_page_entry.key or "Carousel"
          local multidisc_collapse_val = UI.MultiDiscCollapse == true
          local global_hide_val = UI.GlobalHide == true
          local show_details_val = (UI.DetailsAlign ~= nil and UI.DetailsAlign ~= "off")
          local details_align_val = (show_details_val and UI.DetailsAlign)
            or ((type(PLDR) == "table" and PLDR.DETAILS_ALIGN) or "left")
          if details_align_val ~= "center" and details_align_val ~= "right" then details_align_val = "left" end
          local hdd_fs_val = (type(PLDR.NormalizeHddFs) == "function")
          and PLDR.NormalizeHddFs(UI.HddFs) or "PFS"
          local art_location_val = (UI.ArtLocation == "pops" or UI.ArtLocation == "art") and UI.ArtLocation or "pops_art"
          local cover_art_val = UI.CoverArt ~= false
          local gamelist_cache_val = UI.GameListCache == true
          local boot_sound_val = UI.BootSound == true
          local bdma_adaptive_val = UI.BdmaAdaptive == true
          local overscan_val = math.floor(tonumber(UI.Overscan) or 0)
          local video_live_before = nil
          if type(Screen) == "table" and type(Screen.getMode) == "function" then
            local okb, mb = pcall(Screen.getMode)
            if okb and type(mb) == "table" then video_live_before = mb.mode end
          end
          local video_standard_before = (type(PLDR) == "table") and PLDR.VIDEO_STANDARD or nil
          local ok_run, result, reason = xpcall(function()
            if type(PLDR.CommitSettingsChanges) == "function" then
              return PLDR.CommitSettingsChanges({
                popstarter_path = pop_path,
                dkwdrv_path = dkwdrv_path,
                bdma_mode = mode_key,
                video_standard = video_key,
                keyboard_layout = UI.KeyboardLayoutDraft or (type(PLDR) == "table" and PLDR.KEYBOARD_LAYOUT) or "QWERTY",
                language = UI.LanguageDraft or (type(PLDR) == "table" and PLDR.LANGUAGE) or "EN",
                boot_page = boot_page_key,
                hidden_devices = UI.DeviceHiddenDraft,
                multidisc_collapse = multidisc_collapse_val,
                global_hide = global_hide_val,
                show_details = show_details_val,
                details_align = details_align_val,
                hdd_fs = hdd_fs_val,
                art_location = art_location_val,
                cover_art = cover_art_val,
                gamelist_cache = gamelist_cache_val,
                boot_sound = boot_sound_val,
                bdma_adaptive = bdma_adaptive_val,
                overscan = overscan_val,
                hide_text = UI.HideTextMode == true,
                prev_hide_text = UI.SettingsEntryHideTextMode == true,
                smb = UI.SmbDraft,
                smb_modules = UI.SmbModulesDraft,
                apply_smb = (UI.SmbModulesDirty == true)
                            or (UI.SmbModulesDraft == true and UI.SmbDirty == true),
                apply_bdma = UI.BdmaDirty,
                bdma_token = save_token,
                on_stage = report_stage
              })
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
            if type(PLDR) == "table" and type(PLDR.NormalizeLanguage) == "function" then
              PLDR.LANGUAGE = PLDR.NormalizeLanguage(UI.LanguageDraft or PLDR.LANGUAGE or "EN")
            else
              PLDR.LANGUAGE = UI.LanguageDraft or PLDR.LANGUAGE or "EN"
            end
            PLDR.BOOT_PAGE = boot_page_key
            if type(UI.DeviceHiddenDraft) == "table" and type(PLDR.NormalizeHiddenDevices) == "function" then
              PLDR.HIDDEN_DEVICES = PLDR.NormalizeHiddenDevices(UI.DeviceHiddenDraft)
            end
            PLDR.COLLAPSE_MULTIDISC = multidisc_collapse_val
            PLDR.GLOBAL_HIDE = global_hide_val
            PLDR._GLOBAL_HIDE_SAVED = nil   -- Settings Save re-establishes the persisted truth + drops any transient R3 reveal
            UI.RevealHidden = false
            -- A changed list-SHAPING setting must REBUILD the game list on return:
            -- the list scene otherwise keeps showing entries built under the OLD
            -- value -- choosing "Hidden" left hidden games visibly on screen until
            -- R3's rebuild happened to run (maintainer, 2026-07-20; the save+filter
            -- chain was always correct, only the rescan was missing). Reuses the
            -- same flag the R3-reveal cancellation path consumes (raises the
            -- in-place R1 refresh on the next list-scene frame).
            if (global_hide_val == true) ~= (UI.SettingsEntryGlobalHide == true)
               or (multidisc_collapse_val == true) ~= (UI.SettingsEntryMultiDiscCollapse == true) then
              UI.PendingHideRebuild = true
            end
            PLDR.SHOW_DETAILS = show_details_val
            PLDR.DETAILS_ALIGN = details_align_val
            PLDR.HDD_FS = hdd_fs_val
            PLDR.ART_LOCATION = art_location_val
            PLDR.COVER_ART = cover_art_val
            if type(UI.SetCoverPreview) == "function" then
              UI.SetCoverPreview(cover_art_val)
            end
            PLDR.GAMELIST_CACHE = gamelist_cache_val
            PLDR.BOOT_SOUND = boot_sound_val
            PLDR.BDMA_ADAPTIVE = bdma_adaptive_val
            PLDR.OVERSCAN = overscan_val
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
            UI.DkwdrvDirty = false
            UI.VideoStandardDirty = false
            UI.SmbDirty = false
            UI.SmbModulesDirty = false
            clear_settings_session()
            -- HDD-write probe (TEST): on an HDD boot, report whether a __.POPS
            -- GAME partition accepts a scoped write (used for HDD per-game .hide
            -- markers). Settings already saved to the HDD BOOT partition via
            -- EnsureBootPartitionWritable -- NOT mc0:; this is just a game-partition
            -- diagnostic. (nil return = not an HDD boot -> no toast.)
            if type(PLDR.ProbeHddSettingsWrite) == "function" then
              local hdd_w_ok, hdd_w_info = PLDR.ProbeHddSettingsWrite()
              -- Formattable keys, not concatenation: this fires on EVERY Settings
              -- save with the HDD loaded, so it is one of the most-seen toasts on
              -- an HDD rig -- and built by `..` it could never match a table key.
              -- The %s is only ever "__.POPS" or "__.POPS0".."9", so it stays as-is.
              if hdd_w_ok == true then
                UI.Notif_queue.add(PLDR.LFmt("__.POPS partition %s accepts writes (game-partition RW test)", tostring(hdd_w_info)), "ok")
              elseif hdd_w_ok == false then
                UI.Notif_queue.add(PLDR.LFmt("HDD game-partition write test FAILED (%s)", tostring(hdd_w_info)), "warn")
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
            -- Failure path: keep the DRAFTS intact (no draft resync from runtime) so
            -- the user's edits survive for a retry -- a failed save used to destroy
            -- every pending change. Toasts tell the truth about scope: on a BDMA/SMB
            -- apply failure the sidecar save already SUCCEEDED with everything else;
            -- only that one subsystem was rolled back (and re-persisted).
            if reason == "bdma_apply_failed" then
              UI.Notif_queue.add("BDMA mode change didn't apply\nBDMA reverted; other settings were saved", "error")
            elseif reason == "smb_apply_failed" then
              UI.Notif_queue.add("SMB modules didn't install/remove\nmodule setting reverted; other settings were saved", "error")
            else
              -- One formattable key for the whole sentence rather than a translated
              -- head with a bare English " may be read-only" welded on: Hungarian
              -- needs to put the path somewhere other than in front of the predicate,
              -- and a dangling suffix fragment cannot express that. The mx4sio probe
              -- tail stays English (technical diagnostic, README rule 3).
              UI.Notif_queue.add(PLDR.LFmt("Couldn't save settings\n%s may be read-only", tostring(PLDR.SETTINGS_PATH or "mc0:/POPSTARTER/.pldrs"))..((type(BOOT_MX4SIO_PROBE_RESULT) == "string" and BOOT_MX4SIO_PROBE_RESULT ~= "") and "\nmx4sio probe: "..BOOT_MX4SIO_PROBE_RESULT or ""), "error")
            end
            if allow_fallback_exit == true then
              UI.ProfileDirty = false
              UI.BdmaDirty = false
              UI.PopPathDirty = false
              UI.DkwdrvDirty = false
              UI.VideoStandardDirty = false
              UI.SmbDirty = false
              UI.SmbModulesDirty = false
              clear_settings_session()
              UI.SceneChange(target_scene)
            end
          end
        end

        -- Field-specific helpers (used by item callbacks below).
        local keyboard_layouts = (UI.PathEditor and UI.PathEditor.layout_order) or {"QWERTY", "DVORAK", "ABC"}
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

        -- UI language (i18n). Cycling LIVE-APPLIES (sets PLDR.LANGUAGE so the whole
        -- UI re-renders in that language immediately, per R3Z3N's "auto apply as you
        -- move about"); discard reverts it via restore_settings_session.
        local language_order = (type(PLDR) == "table" and PLDR.LANGUAGE_ORDER) or {"EN"}
        local function CurrentLanguageIndex()
          local key = string.upper(tostring(UI.LanguageDraft or "EN"))
          for i = 1, #language_order do
            if string.upper(tostring(language_order[i])) == key then return i end
          end
          return 1
        end
        local function CycleLanguage(delta)
          local n = #language_order
          if n <= 0 then return end
          local idx = CycleIndex(CurrentLanguageIndex(), delta, n)
          UI.LanguageDraft = language_order[idx]
          if type(PLDR) == "table" then PLDR.LANGUAGE = UI.LanguageDraft end  -- live-apply
        end
        local function LanguageDirty()
          return tostring(UI.LanguageDraft or "EN") ~= tostring(UI.SettingsEntryLanguage or "EN")
        end

        local function ResetDefaults()
          -- POPSTARTER path default = "" (Automatic ladder; profiles dropped).
          if tostring(UI.PopstarterPathDraft or "") ~= "" then
            UI.PopstarterPathDraft = ""
            UI.PopPathDirty = true
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
            -- vs the entry snapshot: resetting BACK to the mode the page was
            -- opened with must not trigger a needless BDMA module reinstall.
            UI.BdmaDirty = (UI.BdmaModeIndex ~= (UI.SettingsEntryBdmaModeIndex or 1))
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
          if UI.DetailsAlign ~= nil and UI.DetailsAlign ~= "off" then
            UI.DetailsAlign = "off"
            UI.ProfileDirty = true
          end
          if UI.GameListCache == true then
            UI.GameListCache = false
            UI.ProfileDirty = true
          end
          if UI.CoverArt ~= true then   -- default ON
            UI.CoverArt = true
            UI.ProfileDirty = true
          end
          if UI.BootSound ~= true then   -- default ON
            UI.BootSound = true
            UI.ProfileDirty = true
          end
          if UI.BdmaAdaptive ~= true then   -- default ON
            UI.BdmaAdaptive = true
            UI.ProfileDirty = true
          end
          if (math.floor(tonumber(UI.Overscan) or 0)) ~= 0 then   -- default 0 (off)
            UI.Overscan = 0
            if type(Screen) == "table" and type(Screen.setOverscan) == "function" then pcall(Screen.setOverscan, 0) end
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
            UI.VideoStandardDirty = (UI.VideoStandardIndex ~= (UI.SettingsEntryVideoStandardIndex or 1))
          end
          if UI.HideTextMode ~= true then   -- EXP56: default ON (graphics team)
            UI.SetHideTextMode(true, false)
            UI.ProfileDirty = true
          end
          -- "ABC" = the same default a genuine fresh install gets (LoadSettingsNonFatal
          -- + NormalizeKeyboardLayout's fall-through). This used to say QWERTY, so
          -- Reset Defaults produced a DIFFERENT state than factory-fresh.
          local default_keyboard_layout = "ABC"
          if type(PLDR) == "table" and type(PLDR.NormalizeKeyboardLayout) == "function" then
            default_keyboard_layout = PLDR.NormalizeKeyboardLayout(default_keyboard_layout)
          end
          if tostring(UI.KeyboardLayoutDraft or "") ~= tostring(default_keyboard_layout) then
            UI.KeyboardLayoutDraft = default_keyboard_layout
            UI.ProfileDirty = true
          end
          if tostring(UI.LanguageDraft or "") ~= "EN" then   -- default UI language = English
            UI.LanguageDraft = "EN"
            if type(PLDR) == "table" then PLDR.LANGUAGE = "EN" end  -- live-apply the reset
            UI.ProfileDirty = true
          end
          -- These three were MISSING from Reset Defaults (the action's label promised
          -- them): Internal HDD page, cover/details folder, carousel device visibility.
          -- EXP34: reset targets track the new factory defaults (HDD_FS=BOTH,
          -- ART_LOCATION=art, i.Link hidden) so Reset == factory-fresh (see comment above).
          if tostring(UI.HddFs) ~= "BOTH" then
            UI.HddFs = "BOTH"
            UI.ProfileDirty = true
          end
          if tostring(UI.ArtLocation) ~= "art" then
            UI.ArtLocation = "art"
            UI.ProfileDirty = true
          end
          -- Factory default hides the i.Link page (HIDDEN_DEVICES="ILINK").
          local default_hidden = { ILINK = true }
          local hidden_matches = true
          if type(UI.DeviceHiddenDraft) ~= "table" then
            hidden_matches = false
          else
            for k in pairs(default_hidden) do
              if UI.DeviceHiddenDraft[k] ~= true then hidden_matches = false break end
            end
            for k in pairs(UI.DeviceHiddenDraft) do
              if default_hidden[k] ~= true then hidden_matches = false break end
            end
          end
          if not hidden_matches then
            UI.DeviceHiddenDraft = { ILINK = true }
            UI.ProfileDirty = true
          end
          if type(PLDR.SmbDefaults) == "function" and type(PLDR.SMB_FIELDS) == "table" then
            local smb_def = PLDR.SmbDefaults()
            local smb_cur = (type(UI.SmbDraft) == "table") and UI.SmbDraft or {}
            local smb_changed = false
            for i = 1, #PLDR.SMB_FIELDS do
              local k = PLDR.SMB_FIELDS[i].key
              if tostring(smb_cur[k]) ~= tostring(smb_def[k]) then smb_changed = true end
            end
            UI.SmbDraft = smb_def
            if smb_changed then
              UI.SmbDirty = true
              UI.ProfileDirty = true
            end
          end
          if UI.SmbModulesDraft == true then   -- default = not installed (mirrors BDMA->FAT32 reset)
            UI.SmbModulesDraft = false
            UI.SmbModulesDirty = true
            UI.ProfileDirty = true
          end
          UI.Notif_queue.add("Defaults restored", "ok")
        end

        -- Trim the raw keyboard buffer (the OSK's SPACE key makes invisible
        -- leading/trailing spaces easy, and a trailing space silently fails the
        -- launch resolver's existence gate -- it would use a DIFFERENT POPSTARTER
        -- than the one configured, with zero indication). Then warn (save anyway --
        -- the device may simply be unplugged) when the typed file doesn't exist.
        -- HDD-form paths skip the probe: a bare doesFileExist on an unmounted hdd0:
        -- path would false-warn on perfectly valid custom HDD paths.
        local function TrimAndProbePathDraft(path)
          path = string.match(tostring(path or ""), "^%s*(.-)%s*$") or ""
          if path ~= "" and string.match(path, "^[Hh][Dd][Dd]%d*:") == nil
             and string.match(path, "^[Pp][Ff][Ss]%d*:") == nil then
            local ok, exists = pcall(doesFileExist, path)
            if not (ok and exists == true) then
              UI.Notif_queue.add(PLDR.L("Path saved, file not found:").."\n"..path, "warn")
            end
          end
          return path
        end

        local function OpenPopstarterPathEditor()
          UI.PathEditor.Open("Edit POPStarter Path", UI.PopstarterPathDraft or "", function(path)
            -- Committing an EMPTY value is meaningful: it selects Automatic.
            UI.PopstarterPathDraft = TrimAndProbePathDraft(path)
            UI.PopPathDirty = true
            UI.ProfileDirty = true
          end)
        end

        local function OpenDkwdrvPathEditor()
          UI.PathEditor.Open("Edit DKWDRV Path", UI.DkwdrvPathDraft or "", function(path)
            UI.DkwdrvPathDraft = TrimAndProbePathDraft(path)
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
        -- markers; cycle/path items respond to focus + activation. Save/Reset/
        -- Discard are NOT rows anymore: START opens them as a modal menu
        -- (UI.Modal.OpenSettingsMenu -- R3Z3N review).
        local items = {}
        -- ACCORDION model (R3Z3N review): every section's children are always in
        -- the item list so nav flows through them, but only the section holding the
        -- FOCUSED row renders expanded -- the others show a single header line.
        -- Headers are non-selectable, so nav skips them and lands on the next
        -- section's first item at a boundary, and the section you leave collapses
        -- on its own. `section` tags each child with its owning section label.
        local current_section = nil
        local function AddSection(label)
          current_section = label
          table.insert(items, { kind = "section", label = label })
        end
        local function AddSpacer()
          table.insert(items, { kind = "spacer" })
        end
        local function AddCycle(label, get_value, prev_fn, next_fn, dirty_fn)
          table.insert(items, {
            kind = "cycle",
            section = current_section,
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
          table.insert(items, { kind = "info", section = current_section, label = label, value = get_value })
        end
        local function AddPath(label, get_value, open_fn, dirty_fn)
          table.insert(items, {
            kind = "path",
            section = current_section,
            label = label,
            value = get_value,
            open = open_fn,
            dirty = dirty_fn
          })
        end
        -- A plain label row that DOES something on Confirm (no value, no dirty
        -- marker). Unlike the old Save/Reset/Discard action rows this one lives
        -- INSIDE a section, so it obeys the accordion and reads as a normal
        -- settings row -- which was the objection to the old ones.
        local function AddAction(label, activate_fn)
          table.insert(items, {
            kind = "action",
            section = current_section,
            label = label,
            activate = activate_fn
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
          -- Compare against the entry snapshot (not set-on-touch): cycling away
          -- and back used to leave a phantom dirty flag, and Save then ran a full
          -- needless BDMA module reinstall (ApplyBdmaMode has no same-mode
          -- short-circuit).
          UI.BdmaDirty = (UI.BdmaModeIndex ~= (UI.SettingsEntryBdmaModeIndex or 1))
        end
        AddCycle(
          "BDMA Mode",
          function() return tostring((UI.BdmaModes[UI.BdmaModeIndex] or UI.BdmaModes[1] or {}).label or "") end,
          function() CycleBdma(-1) end,
          function() CycleBdma(1) end,
          function() return UI.BdmaDirty == true end
        )
        -- Adaptive BDMA (issue #509): stage the BDMA variant per LAUNCHED game's
        -- device instead of the one global mode above (which then reads as the
        -- USB-page preference: exFAT-USB keeps the modules on USB launches, any
        -- other value means FAT32/none there). Zero card writes when the right
        -- variant is already staged.
        local function ToggleAdaptiveBdma()
          if UI.BdmaAdaptive ~= true and PLDR.POPSTARTER_MC_FOLDER == false then
            UI.Notif_queue.add("Enable the POPSTARTER Folder first\n(BDMA / SMB modules must live on the memory card)", "warn")
            return
          end
          UI.BdmaAdaptive = not (UI.BdmaAdaptive == true)
        end
        AddCycle(
          "Adaptive BDMA",
          function() return UI.BdmaAdaptive and "On (per-device)" or "Off" end,
          function() ToggleAdaptiveBdma() end,
          function() ToggleAdaptiveBdma() end,
          function() return (UI.BdmaAdaptive == true) ~= (UI.SettingsEntryBdmaAdaptive == true) end
        )

        AddSection("Display")
        AddCycle(
          "Video Standard",
          function() return tostring((UI.VideoStandardModes[UI.VideoStandardIndex] or UI.VideoStandardModes[1] or {}).label or "") end,
          function()
            UI.VideoStandardIndex = CycleIndex(UI.VideoStandardIndex, -1, #UI.VideoStandardModes)
            UI.VideoStandardDirty = (UI.VideoStandardIndex ~= (UI.SettingsEntryVideoStandardIndex or 1))
          end,
          function()
            UI.VideoStandardIndex = CycleIndex(UI.VideoStandardIndex,  1, #UI.VideoStandardModes)
            UI.VideoStandardDirty = (UI.VideoStandardIndex ~= (UI.SettingsEntryVideoStandardIndex or 1))
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
        -- Value reads On/Off (not Hidden/Visible): the old state-words made the
        -- row read like a description of the text, not a toggle -- R3Z3N review.
        AddCycle(
          "Hide UI Text",
          function() return UI.HideTextMode and "On" or "Off" end,
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
        -- Keyboard Layout lives under Startup (moved out of POPSTARTER: it is a
        -- global input preference, not a per-POPSTARTER setting -- R3Z3N review).
        AddCycle(
          "Keyboard Layout",
          function() return string.upper(tostring(UI.KeyboardLayoutDraft or "QWERTY")) end,
          function() CycleKeyboardLayout(-1) end,
          function() CycleKeyboardLayout( 1) end,
          KeyboardLayoutDirty
        )
        -- Language (i18n): shows the language's OWN name; cycling live-applies (R3Z3N).
        AddCycle(
          "Language",
          function()
            local code = tostring(UI.LanguageDraft or "EN")
            return (type(PLDR) == "table" and PLDR.LANGUAGE_NAMES and PLDR.LANGUAGE_NAMES[code]) or code
          end,
          function() CycleLanguage(-1) end,
          function() CycleLanguage( 1) end,
          LanguageDirty
        )

        -- Carousel device visibility checklist: a Shown/Hidden row per main-menu
        -- device. Toggling hides/shows it on the carousel (all shown by default).
        -- "Device List", not "Carousel Devices" -- R3Z3N review round 3:
        -- "carousel is actually device list". The rows pick which devices appear
        -- on the main menu; calling it by our internal widget name helped nobody.
        AddSection("Device List")
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
            -- EXFAT + PFS are governed by the single "Internal HDD" toggle below, not by a
            -- per-device Shown/Hidden row here (CosmicScale: one toggle, not two that fight).
            if dkey ~= "EXFAT" and dkey ~= "PFS" then
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
        end

        -- Internal-HDD page(s) on the carousel: Sony APA/PFS (default), APA-Jail exFAT,
        -- or BOTH. "Both" is new (R3Z3N: the two can coexist) and is purely a visibility
        -- choice -- the driver stacks were already unified onto one shared, load-once
        -- ata_bd that serves APA/PFS and exFAT together, settles included. A -page=ata
        -- launch still auto-enters exFAT and hides PFS regardless of this setting.
        local HDD_FS_SEQ = {"PFS", "EXFAT", "BOTH"}
        local HDD_FS_TXT = {PFS = "APA / PFS (default)", EXFAT = "exFAT", BOTH = "Both"}
        local function HddFsStep(cur, dir)
          local idx = 1
          for i = 1, #HDD_FS_SEQ do
            if HDD_FS_SEQ[i] == cur then idx = i; break end
          end
          return HDD_FS_SEQ[((idx - 1 + dir) % #HDD_FS_SEQ) + 1]
        end
        AddCycle(
          "Internal HDD",
          function() return HDD_FS_TXT[UI.HddFs] or "APA / PFS (default)" end,
          function() UI.HddFs = HddFsStep(UI.HddFs, -1) end,
          function() UI.HddFs = HddFsStep(UI.HddFs, 1) end,
          function() return tostring(UI.HddFs) ~= tostring(UI.SettingsEntryHddFs) end
        )

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
        -- This row said WHETHER hidden games show, but never how to hide one, so
        -- the feature was undiscoverable ("I dont know how to hide games..." --
        -- R3Z3N review round 3). A read-only hint costs one dimmed line and
        -- answers it where the question is actually asked.
        AddInfo(
          "How to hide a game",
          function() return "L3 on the game list" end
        )
        local DETAILS_ALIGN_SEQ = {"off", "left", "center", "right"}
        local DETAILS_ALIGN_TXT = {off = "Off", left = "Left aligned", center = "Center aligned", right = "Right aligned"}
        local function DetailsAlignStep(cur, dir)
          local idx = 1
          for i = 1, #DETAILS_ALIGN_SEQ do
            if DETAILS_ALIGN_SEQ[i] == cur then idx = i; break end
          end
          idx = ((idx - 1 + dir) % #DETAILS_ALIGN_SEQ) + 1
          return DETAILS_ALIGN_SEQ[idx]
        end
        AddCycle(
          "Game details",
          function() return DETAILS_ALIGN_TXT[UI.DetailsAlign] or "Off" end,
          function() UI.DetailsAlign = DetailsAlignStep(UI.DetailsAlign, 1) end,
          function() UI.DetailsAlign = DetailsAlignStep(UI.DetailsAlign, -1) end,
          function() return tostring(UI.DetailsAlign) ~= tostring(UI.SettingsEntryDetailsAlign) end
        )
        -- EXP35: the "Cover/details folder" (ART_LOCATION) row was REMOVED -- cover
        -- art is now HARD-LOCKED to <device-root>/ART/<name>_COV.png (OPL standard,
        -- maintainer). There is no folder choice to make anymore; ART_LOCATION is kept
        -- inert in the settings file only so older sidecars still parse.
        -- EXP42: cover art used to be a Square toggle on the game list -- session-only,
        -- lost on every boot, and invisible once the footer legend was trimmed. Same
        -- behaviour, now discoverable and persisted.
        AddCycle(
          "Cover art",
          function() return UI.CoverArt and "On" or "Off" end,
          function() UI.CoverArt = not UI.CoverArt end,
          function() UI.CoverArt = not UI.CoverArt end,
          function() return (UI.CoverArt == true) ~= (UI.SettingsEntryCoverArt == true) end
        )
        AddCycle(
          "Game list cache",
          function() return UI.GameListCache and "On" or "Off" end,
          function() UI.GameListCache = not UI.GameListCache end,
          function() UI.GameListCache = not UI.GameListCache end,
          function() return (UI.GameListCache == true) ~= (UI.SettingsEntryGameListCache == true) end
        )
        AddCycle(
          "Boot sound",
          function() return UI.BootSound and "On" or "Off" end,
          function() UI.BootSound = not UI.BootSound end,
          function() UI.BootSound = not UI.BootSound end,
          function() return (UI.BootSound == true) ~= (UI.SettingsEntryBootSound == true) end
        )
        AddCycle(
          "Overscan (CRT inset)",
          function() return (UI.Overscan or 0) == 0 and "Off" or tostring(UI.Overscan) end,
          function()
            UI.Overscan = math.min((UI.Overscan or 0) + 5, 100)
            if type(Screen) == "table" and type(Screen.setOverscan) == "function" then pcall(Screen.setOverscan, UI.Overscan) end
          end,
          function()
            UI.Overscan = math.max((UI.Overscan or 0) - 5, 0)
            if type(Screen) == "table" and type(Screen.setOverscan) == "function" then pcall(Screen.setOverscan, UI.Overscan) end
          end,
          function() return (UI.Overscan or 0) ~= (UI.SettingsEntryOverscan or 0) end
        )

        -- SMB / Network (Stage 1: config only -- the network stack loads lazily on
        -- the SMB page, never here/at boot). Spec-driven rows from PLDR.SMB_FIELDS;
        -- all editing routes through UI.SmbDraft + UI.SmbDirty (committed as opts.smb).
        if type(PLDR.SMB_FIELDS) == "table" then
          AddSection("SMB / Network")
          -- Master switch: install/remove the in-game SMB streaming pack in
          -- mc:/POPSTARTER (mirrors the BDMA Mode row). Applied at save time via
          -- opts.apply_smb -> PLDR.ApplySmbModules/RemoveSmbModules.
          AddCycle(
            "SMB modules",
            function() return (UI.SmbModulesDraft == true) and "Installed" or "Not installed" end,
            function() UI.ToggleSmbModulesDraft() end,
            function() UI.ToggleSmbModulesDraft() end,
            function() return (UI.SmbModulesDraft == true) ~= (PLDR.SMB_MODULES == true) end
          )
          for smb_i = 1, #PLDR.SMB_FIELDS do
            local smb_field = PLDR.SMB_FIELDS[smb_i]
            local smb_label = UI.SmbFieldLabel(smb_field)
            if smb_field.hidden == true then
              -- Spec-only field (ADDR_TYPE/NB_ADDR): kept so old sidecars parse,
              -- but not rendered -- the connect binding can't honor it (NetBIOS
              -- needs nbns.irx), so a row here would sell a guaranteed failure.
            elseif smb_field.kind == "bool" or smb_field.kind == "enum" then
              AddCycle(
                smb_label,
                function() return UI.SmbFieldDisplay(smb_field) end,
                function() UI.SmbFieldCycle(smb_field, -1) end,
                function() UI.SmbFieldCycle(smb_field, 1) end,
                function() return UI.SmbFieldDirty(smb_field.key) end
              )
            else
              AddPath(
                smb_label,
                function() return UI.SmbFieldDisplay(smb_field) end,
                function() UI.SmbFieldOpenEditor(smb_field) end,
                function() return UI.SmbFieldDirty(smb_field.key) end
              )
            end
          end
        end

        AddSection("POPSTARTER")
        -- No Profile preset row anymore (R3Z3N: dropped the inherited profile
        -- system): one user-defined path, empty = Automatic (the launch ladder:
        -- custom -> game device -> launcher folder -> mc), never showing a pfsN
        -- partition number. A legacy config's PROFILE=N pick is migrated into
        -- this path at load (system.lua LoadSettingsNonFatal) since the ladder
        -- does not probe every old preset location.
        AddPath(
          "POPSTARTER Path",
          -- Full path (DrawRow tickers it when focused, middle-ellipsis otherwise).
          function()
            local p = tostring(UI.PopstarterPathDraft or PLDR.POPSTARTER_PATH or "")
            if p == "" or string.lower(p) == "popstarter.elf" then return "Automatic" end
            return p
          end,
          OpenPopstarterPathEditor,
          function() return UI.PopPathDirty == true end
        )
        AddPath(
          "DKWDRV Path",
          -- Full path (DrawRow tickers it when focused, middle-ellipsis otherwise).
          function() return tostring(UI.DkwdrvPathDraft or PLDR.DKWDRV_PATH or PLDR.DKWDRV_DEFAULT_PATH or "mc0:/PS1_DKWDRV/DKWDRV.ELF") end,
          OpenDkwdrvPathEditor,
          function() return UI.DkwdrvDirty == true end
        )
        -- (Keyboard Layout moved to the Startup section -- R3Z3N review.)

        local function HasUnsavedChanges()
          return UI.ProfileDirty == true
            or UI.BdmaDirty == true
            or UI.PopPathDirty == true
            or UI.DkwdrvDirty == true
            or UI.VideoStandardDirty == true
            or HideTextDirty()
            or KeyboardLayoutDirty()
            or LanguageDirty()
            -- Value-cycle settings are tracked by snapshot comparison (their cycle
            -- handlers set NO dirty flag), so they must be compared here too -- else a
            -- lone change to one is dropped on BACK with no save prompt. Same
            -- expressions as each widget's own dirty indicator. (review)
            or (UI.MultiDiscCollapse == true) ~= (UI.SettingsEntryMultiDiscCollapse == true)
            or (UI.GlobalHide == true) ~= (UI.SettingsEntryGlobalHide == true)
            or tostring(UI.DetailsAlign) ~= tostring(UI.SettingsEntryDetailsAlign)
            or tostring(UI.ArtLocation) ~= tostring(UI.SettingsEntryArtLocation)
            or tostring(UI.HddFs) ~= tostring(UI.SettingsEntryHddFs)
            or (UI.CoverArt == true) ~= (UI.SettingsEntryCoverArt == true)
            or (UI.GameListCache == true) ~= (UI.SettingsEntryGameListCache == true)
            or (UI.BootSound == true) ~= (UI.SettingsEntryBootSound == true)
            or (UI.BdmaAdaptive == true) ~= (UI.SettingsEntryBdmaAdaptive == true)
            or (math.floor(tonumber(UI.Overscan) or 0)) ~= (math.floor(tonumber(UI.SettingsEntryOverscan) or 0))
            or (UI.BootPageIndex or 1) ~= (UI.SettingsEntryBootPageIndex or 1)
            or (UI.SmbDirty == true)
            or (UI.SmbModulesDirty == true)
        end

        local function ToggleMcFolder()
          if PLDR.POPSTARTER_MC_FOLDER == false then
            -- Gate the flag flip on the save actually persisting: with a failed save
            -- the sidecar still says 0, so next boot would re-delete what we just
            -- restored (flag/folder lockstep is the whole point of this toggle).
            PLDR.POPSTARTER_MC_FOLDER = true
            local on_saved = false
            pcall(function() on_saved = (PLDR.SaveSettingsAtomic() == true) end)
            if not on_saved then
              PLDR.POPSTARTER_MC_FOLDER = false
              UI.Notif_queue.add("Couldn't save settings -- POPSTARTER folder NOT restored", "error")
              return
            end
            pcall(PLDR.EnsurePopstarterDir)
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
          -- Same rule for SMB: the streaming pack lives in this folder, so it can't be
          -- deleted while SMB modules are installed (draft or saved).
          if (UI.SmbModulesDraft == true) or (PLDR.SMB_MODULES == true) then
            UI.Notif_queue.add("Can't disable while SMB modules are installed\nSet SMB modules to Not installed first", "warn")
            return
          end
          -- And for Adaptive BDMA: it stages modules INTO this folder at launch
          -- time, so deleting the folder while it's on would just silently
          -- neuter the feature (staging no-ops with the folder off).
          if (UI.BdmaAdaptive == true) or (PLDR.BDMA_ADAPTIVE == true) then
            UI.Notif_queue.add("Can't disable while Adaptive BDMA is on\nTurn Adaptive BDMA off first", "warn")
            return
          end
          -- ONE key per sentence; RunConfirm splits on \n after translating.
          local confirmed = UI.RunConfirm({
            "Delete the POPSTARTER folder from the memory card?",
            "",
            "This removes the POPSTARTER pack -- including the\nBDMA and SMB modules -- from mc0: / mc1:. They won't\nreturn until you turn this back On (or re-add them\nmanually). Your POPSLoader settings are kept.",
          })
          if confirmed then
            PLDR.POPSTARTER_MC_FOLDER = false
            -- Delete ONLY when the save persisted. It used to delete regardless: a
            -- failed save left the sidecar saying 1, so the next boot's
            -- EnsurePopstarterDir silently recreated the folder the user just
            -- deleted (the every-boot-recreation provato reported).
            local off_saved = false
            pcall(function() off_saved = (PLDR.SaveSettingsAtomic() == true) end)
            if not off_saved then
              PLDR.POPSTARTER_MC_FOLDER = true
              UI.Notif_queue.add("Couldn't save settings -- POPSTARTER folder NOT deleted", "error")
              return
            end
            pcall(PLDR.RemovePopstarterMcFolder)
            UI.Notif_queue.add("POPSTARTER folder deleted from the memory card", "warn")
          end
        end

        AddSpacer()
        AddSection("Memory Card")
        AddCycle(
          "POPSTARTER Folder",
          function() return (PLDR.POPSTARTER_MC_FOLDER == false) and "Off (deleted)" or "On (default)" end,
          function() ToggleMcFolder() end,
          function() ToggleMcFolder() end,
          function() return false end
        )

        -- Credits live here now, not on a Triangle binding advertised in every
        -- footer ("put credits in settings imo" -- R3Z3N review round 3).
        -- CreditsReturnScene is the existing generic return mechanism, so this
        -- comes back to Settings with the drafts intact (returning via
        -- SceneChange does NOT re-run SyncSettingsDraftFromRuntime -- only the
        -- START-entry handler does -- so staged edits survive the trip).
        AddSection("About")
        -- The advertised "check which build you are on" spot. POPSLDR_VER comes
        -- from the embedded boot.lua so it is ALWAYS available -- unlike the
        -- BUILD_INFO.txt stamp, which needs a loose file next to the ELF that a
        -- normal one-file install never has (sAGA: told to check the version,
        -- found nothing anywhere).
        AddInfo("Version", function()
          local ver = tostring(rawget(_G, "POPSLDR_VER") or "")
          if ver == "" then return "(unknown)" end
          return ver
        end)
        AddAction("Credits", function()
          UI.CreditsReturnScene = UI.SCENES.MPROFILE
          UI.SceneChange(UI.SCENES.CREDITS)
        end)

        -- Focus normalization: clamp + skip non-selectable rows.
        local function IsSelectable(idx)
          local it = items[idx]
          if it == nil then return false end
          -- Section headers are non-selectable (accordion): nav skips them so it
          -- lands on the section's first item, not the header.
          if it.kind == "section" then return false end
          return it.kind ~= "spacer" and it.kind ~= "info"
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

        -- Accordion: the OPEN section = the section of the focused row. A row is
        -- visible only if it's a header/spacer or a child of the open section;
        -- collapsed sections render as their single header line.
        do
          local ff = items[UI.SettingsFocus]
          if ff ~= nil and ff.section ~= nil then UI.SettingsOpenSection = ff.section end
          if UI.SettingsOpenSection == nil then
            for _, it in ipairs(items) do
              if it.kind == "section" then UI.SettingsOpenSection = it.label; break end
            end
          end
        end
        local open_section = UI.SettingsOpenSection

        -- Drop-down animation (R3Z3N review: instant accordion opens are
        -- jarring). Frame-counted -- one Play() call == one vblank-paced frame,
        -- NEVER Timer.getTime (microseconds trap): the newly-opened section's
        -- children reveal top-down over ~6 frames. The focused row is always
        -- included so nav never lands on a hidden row, which also means
        -- entering a section from below (focus = last child) opens instantly
        -- instead of jittering rows in above the cursor.
        local ACCORDION_FRAMES = 6
        if UI.SettingsAccordionSection ~= open_section then
          UI.SettingsAccordionSection = open_section
          UI.SettingsAccordionFrame = 1
        elseif (UI.SettingsAccordionFrame or ACCORDION_FRAMES) < ACCORDION_FRAMES then
          UI.SettingsAccordionFrame = (UI.SettingsAccordionFrame or 0) + 1
        end
        local anim_frame = UI.SettingsAccordionFrame or ACCORDION_FRAMES
        local child_ord = {}
        local reveal
        do
          local n_children = 0
          for i = 1, #items do
            local it = items[i]
            if it.kind ~= "section" and it.kind ~= "spacer" and it.section == open_section then
              n_children = n_children + 1
              child_ord[i] = n_children
            end
          end
          reveal = n_children
          if anim_frame < ACCORDION_FRAMES and n_children > 0 then
            reveal = math.ceil(n_children * anim_frame / ACCORDION_FRAMES)
            local f_ord = child_ord[UI.SettingsFocus]
            if f_ord ~= nil and f_ord > reveal then reveal = f_ord end
          end
        end

        local function IsVisibleItem(it, idx)
          if it == nil then return false end
          if it.kind == "section" or it.kind == "spacer" then return true end
          if it.section ~= open_section then return false end
          local ord = child_ord[idx]
          return ord == nil or ord <= reveal
        end

        -- Compute total content height for top-Y placement (visible rows only).
        local total_h = 0
        for i = 1, #items do
          local it = items[i]
          if IsVisibleItem(it, i) then
            if it.kind == "section" then
              total_h = total_h + SECTION_HEADER_H + (i > 1 and SECTION_GAP_BEFORE or 0)
            elseif it.kind == "spacer" then
              total_h = total_h + SPACER_H
            else
              total_h = total_h + ROW_H
            end
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

        -- Marquee tick for the FOCUSED row's overflowing label/value (ticker per
        -- R3Z3N review). Resets when the selection changes; MarqueeLabel is a
        -- no-op when the text already fits, so only genuinely-too-long focused
        -- text scrolls (holds at the head, then scrolls, then loops).
        if UI.SettingsMarqueeSel ~= UI.SettingsFocus then
          UI.SettingsMarqueeSel = UI.SettingsFocus
          UI.SettingsMarqueeTick = 0
        else
          UI.SettingsMarqueeTick = (UI.SettingsMarqueeTick or 0) + 1
        end
        local marquee_tick = UI.SettingsMarqueeTick or 0

        -- Draw
        local function DrawHighlight(row_y)
          Graphics.drawRect(SAFE_LEFT, row_y - 2, SAFE_RIGHT - SAFE_LEFT, ROW_H, highlight_color)
        end

        local function DrawSection(label, row_y, collapsed, focused)
          if focused then
            Graphics.drawRect(SAFE_LEFT, row_y - 2, SAFE_RIGHT - SAFE_LEFT, SECTION_HEADER_H, highlight_color)
          end
          -- "+" = collapsed (press to expand), "-" = expanded (ASCII, font-safe).
          Font.ftPrint(BFONT, SAFE_LEFT + 2, row_y, 0, 12, 16, collapsed and "+" or "-", focused and section_color or section_line_color)
          Font.ftPrint(BFONT, LABEL_X, row_y, 0, UI.SCR.X, 16, PLDR.L(label), section_color)
          Graphics.drawRect(SAFE_LEFT, row_y + SECTION_HEADER_H - 4, SAFE_RIGHT - SAFE_LEFT, 1, section_line_color)
        end

        local function DrawRow(it, row_y, focused)
          if focused then
            DrawHighlight(row_y)
          end
          -- Read-only rows dim BOTH label and value (they are never focused).
          local label_text_color = focused and accent_color
            or (it.kind == "info" and readonly_color)
            or label_color
          -- Focused row tickers a too-long label; others clip statically. Label is
          -- localized (L() falls back to English for anything untranslated).
          local base_label = PLDR.L(it.label)
          local label_disp = base_label
          if focused then label_disp = MarqueeLabel(BFONT, tostring(base_label or ""), LABEL_W, marquee_tick) end
          Font.ftPrint(BFONT, LABEL_X, row_y, 0, LABEL_W, 16, label_disp, label_text_color)
          local value_text = PLDR.L(it.value and tostring(it.value() or "") or "")
          local dirty = (it.dirty and it.dirty()) == true
          -- Editable values (cycle AND path) share the selectable grey; only
          -- read-only info values drop to the darker inert shade, so
          -- "looks dim" == "can't be edited" holds everywhere on the page.
          local value_text_color
          if dirty then
            value_text_color = accent_color
          elseif it.kind == "info" then
            value_text_color = readonly_color
          else
            value_text_color = label_color
          end
          -- Focused row tickers a too-long value/path; non-focused paths keep the
          -- middle-ellipsis so both the device prefix and filename stay visible.
          local value_disp = value_text
          if focused then
            value_disp = MarqueeLabel(BFONT, value_text, VALUE_W, marquee_tick)
          elseif it.kind == "path" then
            value_disp = TruncateMiddle(value_text, 40)
          end
          Font.ftPrint(BFONT, VALUE_X, row_y, 0, VALUE_W, 16, value_disp, value_text_color)
          if focused and it.kind == "cycle" then
            -- Small left/right arrow chevrons hint at D-pad cycling.
            Font.ftPrint(BFONT, VALUE_X - 14, row_y, 0, 12, 16, "<", accent_color)
            Font.ftPrint(BFONT, SAFE_RIGHT - 8, row_y, 0, 12, 16, ">", accent_color)
          end
        end

        -- Focus-following scroll viewport. The page previously placed a fixed
        -- top-Y and, when the item stack was taller than the title->footer
        -- area, simply OVERFLOWED off-screen -- lower rows (Show Devices
        -- checkboxes) became unreachable.
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
            if IsVisibleItem(it, i) then
              if it.kind == "section" and i > 1 then acc = acc + SECTION_GAP_BEFORE end
              item_off[i] = acc
              if it.kind == "section" then item_h[i] = SECTION_HEADER_H
              elseif it.kind == "spacer" then item_h[i] = SPACER_H
              else item_h[i] = ROW_H end
              acc = acc + item_h[i]
            else
              -- Collapsed-section child: no space, no offset advance.
              item_off[i] = acc
              item_h[i] = 0
            end
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
          if IsVisibleItem(it, i) then
            local row_y = base_y + item_off[i] - scroll
            -- When scrolling, draw only fully-visible rows so nothing paints
            -- over the title or footer; when it fits, draw everything (original).
            local show = (not scrolling)
              or (row_y >= view_top and (row_y + item_h[i]) <= (footer_top_y + 1))
            if show then
              if it.kind == "section" then
                -- "+" collapsed / "-" expanded, driven by the open section; headers
                -- are never focused (non-selectable).
                DrawSection(it.label, row_y, it.label ~= open_section, false)
              elseif it.kind == "spacer" then
                -- nothing to draw
              else
                DrawRow(it, row_y, UI.SettingsFocus == i)
              end
            end
          end
        end

        -- Minimal scrollbar so "there's more below/above" is discoverable.
        if scrolling and total_h > 0 then
          local bar_w = 6  -- 3x the old 2px hairline so it's actually discoverable (R3Z3N review)
          local track_x = SAFE_RIGHT + 4
          local thumb_h = math.max(16, math.floor(view_h * view_h / total_h))
          local max_scroll = total_h - view_h
          local t = (max_scroll > 0) and (scroll / max_scroll) or 0
          local thumb_y = view_top + math.floor((view_h - thumb_h) * t)
          Graphics.drawRect(track_x, view_top, bar_w, view_h, separator_color)
          Graphics.drawRect(track_x, thumb_y, bar_w, thumb_h, accent_color)
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
        -- Section jump (sAGA: "to skip the SMB block, you have to click through
        -- every item"). Move focus to the previous/next section's first selectable
        -- row; the accordion follows focus, so the old block collapses and the new
        -- one opens in one press. L1/R1 work from ANY row; LEFT/RIGHT do the same
        -- on rows that don't consume them (cycle rows keep left/right = value
        -- prev/next -- hijacking those would break value editing).
        local function JumpSection(delta)
          local order, seen = {}, {}
          for _, it in ipairs(items) do
            local sec = (it.kind == "section") and it.label or it.section
            if sec ~= nil and not seen[sec] then
              seen[sec] = true
              order[#order + 1] = sec
            end
          end
          if #order < 2 then return end
          local cur = (focused_item ~= nil and focused_item.section) or UI.SettingsOpenSection
          local idx = 1
          for i = 1, #order do
            if order[i] == cur then idx = i; break end
          end
          -- Walk past sections with no selectable rows (all-info blocks) instead
          -- of dead-ending on them.
          for step = 1, #order - 1 do
            local target = order[((idx - 1 + delta * step) % #order) + 1]
            for i = 1, #items do
              if items[i].section == target and IsSelectable(i) then
                UI.SettingsFocus = i
                return
              end
            end
          end
        end
        if UI.Pad.Events.L1 then JumpSection(-1) end
        if UI.Pad.Events.R1 then JumpSection(1) end
        -- Re-capture after a shoulder jump so same-frame LEFT/RIGHT/CONFIRM act
        -- on the row focus actually landed on, not the pre-jump one.
        focused_item = items[UI.SettingsFocus]
        if focused_item ~= nil then
          -- Focus is never on a section header (non-selectable), so there are no
          -- section-collapse branches: the accordion follows focus automatically.
          if UI.Pad.Events.NAV_LEFT then
            if focused_item.kind == "cycle" and focused_item.prev then
              focused_item.prev()
            else
              JumpSection(-1)
            end
          end
          if UI.Pad.Events.NAV_RIGHT then
            if focused_item.kind == "cycle" and focused_item.next then
              focused_item.next()
            else
              JumpSection(1)
            end
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

        -- ONE menu for both routes (R3Z3N review round 3: "the back button
        -- prompt is different than the start prompt ... they should be the
        -- same"). Back with unsaved edits and START now open the identical
        -- Save Changes / Reset Defaults / Discard & Exit chooser; the old
        -- X-Save/O-Cancel/Triangle-Don't-Save prompt is gone. Back with NOTHING
        -- staged still leaves immediately -- prompting to save nothing is noise.
        --
        -- The one deliberate difference is where a SAVE lands you, which is the
        -- user's own intent in each case: Back was on the way out, so it exits
        -- to the scene it came from (and allow_fallback_exit=true, since a
        -- failed save should not strand someone who was already leaving);
        -- START was not, so it stays put on failure (allow_fallback_exit=false)
        -- keeping every draft edit for a retry.
        local function OpenSettingsActionMenu(save_target, allow_fallback_exit)
          UI.Modal.OpenSettingsMenu(
            function() queue_exit(save_target, allow_fallback_exit) end,
            function() ResetDefaults() end,
            function() discard_settings_and_return() end
          )
        end

        if UI.Pad.Events.BACK then
          if HasUnsavedChanges() then
            OpenSettingsActionMenu(UI.GetSettingsReturnScene(), true)
          else
            discard_settings_and_return()
          end
          return
        end
        if UI.Pad.Events.START then
          OpenSettingsActionMenu(UI.SCENES.MMAIN, false)
        end

        local labels, order = UI.Footer.ResolveLegend({
          order = UI.Footer.order_settings_save,
          order_id = "settings_focus",
          circle = UI.Footer.labels.circle_other,
          cross = UI.Footer.labels.cross_select,
          start = UI.Footer.labels.start_menu
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
        allowOptWrite = false
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
          -- Frame-paced: runs once per render frame; the old dt was always clamped to
          -- 1/30 s, so advance a fixed 1/30 s per frame (no microsecond clock).
          local dt_sec = 1/30
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
        local function ResolveIcon(key)
          return IMG[key]
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
        local first_icon = ResolveIcon(icon_keys[1])
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
          Font.ftPrint(UI.FONT.LABEL, UI.SCR.X_MID, top_y, 8, UI.SCR.X, 16, PLDR.L(UI.MainMenu.opts[visible_seq[center_label_idx] or visible_seq[1]]), UI.COLORS.TEXT_PRIMARY)
        end
        -- STATUS_Y (TITLE_Y + 20), not top_y + 12: the status font draws at the
        -- post-reset 17px em (bigger than the 13.75px LABEL title above it!), so
        -- a 12px gap visibly collided on hardware (oldman63 photo). The carousel
        -- icon math already assumes STATUS_Y, so nothing below moves.
        local status_y = layout.STATUS_Y
        local boot_label = UI.boot_device_label
        if (boot_label == nil or boot_label == "") and UI.boot_device ~= nil and UI.boot_device ~= DEVLOCK.NONE then
          boot_label = UI.device_lock_name(UI.boot_device)
        end
        if boot_label ~= nil and boot_label ~= "" and not UI.ShouldHideAuxText(UI.CURSCENE) then
          Font.ftPrint(UI.FONT.STATUS, UI.SCR.X_MID, status_y, 8, UI.SCR.X, 16, PLDR.L("Booted from:").." "..tostring(boot_label), UI.COLORS.TEXT_PRIMARY)
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
        -- With a single visible device, draw ONLY the center icon. Otherwise the
        -- carousel ghosts the same icon across the -3..3 slots, which reads as a
        -- scrollable multi-item list of one repeated entry (oldman63).
        for k = -3, 3 do
          if profcnt > 1 or k == 0 then
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
        if not carousel.animActive and profcnt > 1 then  -- no left/right nav with a single visible device
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
                -- Toast and stay on the carousel (no SceneChange): every sibling
                -- no-device branch (MX4SIO/exFAT, and the second MMCE check just
                -- below) returns without entering an empty game list.
                UI.Notif_queue.add("No MMCE device detected\nchecked mmce0: and mmce1:", "warn")
                PLDR.CleanupGameList()
                PLDR.GAMEPATH = ""
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
	              local mmce_cache = mmce_pops..".gamecache"
	              local mmce_cg, mmce_ch = PLDR.LoadGameListCache(mmce_cache)
	              if mmce_cg ~= nil then
	                PLDR.ApplyGameListCache(mmce_cg, mmce_pops, mmce_ch)
	                report("Loaded MMCE list from cache...", 1.0)
	              elseif doesFolderExist(mmce_pops) then
	                report("Scanning MMCE games...", 0.48)
	                PLDR.GetPS1GameLists(mmce_pops, true, scan_progress)
	                PLDR.SaveGameListCache(mmce_cache, PLDR.GAMES, PLDR.HIDDEN)
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
	              PLDR.CleanupGameList()
	              PLDR.GAMEPATH = ""
              -- EXP32: mx4sio_bd loads LAZILY on this first entry (R3Z/OPL
              -- model; coexists with mmceman -- no gate, maintainer call).
              -- After the load: a bounded opendir+ioctl sweep (settle-retry, 1s
              -- settles). No markers, no bdm_query poke, no unbounded wait.
              report("Locating MX4SIO POPS folder...", 0.42)
              local mx4sio_root, mx4_status = PLDR.InitMX4SIOPopsRoot()
              if mx4sio_root == nil then
                if mx4_status == "notready" then
                  UI.Notif_queue.add("MX4SIO driver failed to load\ntry the page again, or reboot", "warn")
                else
                  UI.Notif_queue.add("No MX4SIO device detected", "warn")
                end
                return
	              end
	              PLDR.CleanupGameList()
	              local mx4sio_cache = mx4sio_root..".gamecache"
	              local mx4_cg, mx4_ch = PLDR.LoadGameListCache(mx4sio_cache)
	              if mx4_cg ~= nil then
	                PLDR.ApplyGameListCache(mx4_cg, mx4sio_root, mx4_ch)
	                report("Loaded MX4SIO list from cache...", 1.0)
	              else
	                report("Scanning MX4SIO games...", 0.48)
	                PLDR.GetPS1GameLists(mx4sio_root, true, scan_progress)
	                PLDR.SaveGameListCache(mx4sio_cache, PLDR.GAMES, PLDR.HIDDEN)
	              end
	              report("Opening MX4SIO list...", 1.0)
	              UI.SceneChange(UI.SCENES.GMX4SIO)
            end, "Failed to load MX4SIO")
            if not ok then return end
          elseif UI.MainMenu.OPT == 3 then
            local ok = UI.RunBusyTask("Loading HDD (exFAT)...", function (report)
              local scan_progress = UI.MakeBusyProgressReporter(report, "Scanning exFAT HDD games...", 0.48, 0.9)
              PLDR.CleanupGameList()
              PLDR.GAMEPATH = ""
              -- EXP32: the ata_bd worker was kicked in the BOOT window
              -- (do_boot_init) for exFAT installs, so this normally finds it
              -- already done and just enumerates. If the drive is still
              -- probing, the wait below is BOUNDED (10s, screen alive) and
              -- reports honestly instead of freezing; the worker keeps
              -- running, so re-entering the page a moment later succeeds.
              -- The old bdm_query re-poke (an RPC that could land mid-module-
              -- registration) is gone from this path.
              report(PLDR.L("Locating exFAT HDD POPS folder..."), 0.42)
              -- EXP43: hand the bring-up a reporter so each internal step paints
              -- BEFORE the call it names. A wedged drive freezes inside one of these
              -- IOP calls and never repaints, so whatever is on screen at that moment
              -- IS the diagnosis -- one photo names the stuck call and the slot. This
              -- is the EXP11 channel, dropped by the EXP32 rebuild; without it a
              -- failed exFAT round yields no information at all, which is what
              -- EXP38/39/40 each cost. Progress stays inside the 0.42-0.48 band the
              -- single step used to occupy, so the bar does not jump around.
              local ok_probe, ata_root, ata_status = pcall(PLDR.InitATAPopsRoot, function (msg)
                report(tostring(msg), 0.44)
              end)
              if not ok_probe then ata_root = nil; ata_status = nil end
              if ata_root == nil then
                if ata_status == "notready" then
                  UI.Notif_queue.add(PLDR.L("The internal drive is still starting\nopen this page again in a moment"), "warn")
                else
                  UI.Notif_queue.add("No exFAT HDD detected\nformat the internal drive exFAT (BDMA Mode = ATA)", "warn")
                end
                return
              end
              PLDR.CleanupGameList()
              local ata_cache = ata_root..".gamecache"
              local ata_cg, ata_ch = PLDR.LoadGameListCache(ata_cache)
              if ata_cg ~= nil then
                PLDR.ApplyGameListCache(ata_cg, ata_root, ata_ch)
                report("Loaded exFAT HDD list from cache...", 1.0)
              else
                report("Scanning exFAT HDD games...", 0.48)
                PLDR.GetPS1GameLists(ata_root, true, scan_progress)
                PLDR.SaveGameListCache(ata_cache, PLDR.GAMES, PLDR.HIDDEN)
              end
              report("Opening exFAT HDD list...", 1.0)
              UI.SceneChange(UI.SCENES.GBDMHDD)
            end, "Failed to load HDD (exFAT)")
            if not ok then return end
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
	                  -- The rc suffix tells a real mount fault apart from clean absence
                  -- (the empty-list-from-a-launcher-boot class reports only this toast).
                  local rc_hint = (PLDR.HDD.LAST_MOUNT_RC ~= nil) and (" (last mount rc: "..tostring(PLDR.HDD.LAST_MOUNT_RC)..")") or ""
                  UI.Notif_queue.add(PLDR.L("No '__.POPS' partitions on hdd0:\nformat one with __.POPS / __.POPS0...9")..rc_hint, "warn")
	                elseif #PLDR.GAMES < 1 then
                  -- EXP33: self-diagnosing. FOUNDANY means pass 1 mounted a
                  -- __.POPS partition; zero games then is EITHER a silent pass-2
                  -- re-mount failure (shows rc + partition) OR a mounted-but-
                  -- empty listing (shows file/VCD counts). The next report says
                  -- which, instead of the opaque "partitions are empty".
                  local d = PLDR.HDD.SCAN_DIAG
                  local diag = ""
                  if type(d) == "table" then
                    if (tonumber(d.remount_fail) or 0) > 0 then
                      diag = string.format("\nmounted %d/%d, remount-fail (rc %s on %s)",
                               tonumber(d.remounted) or 0, tonumber(d.avail) or 0,
                               tostring(d.last_fail_rc), tostring(d.last_fail_part))
                    else
                      diag = string.format("\n%d part, %d files, %d VCD",
                               tonumber(d.avail) or 0, tonumber(d.entries) or 0, tonumber(d.vcds) or 0)
                      if (tonumber(d.hidden) or 0) > 0 then
                        diag = diag..PLDR.LFmt(" (%d hidden -- Global Hide is on)", tonumber(d.hidden) or 0)
                      elseif (tonumber(d.collapsed) or 0) > 0 then
                        diag = diag..PLDR.LFmt(" (%d multi-disc collapsed)", tonumber(d.collapsed) or 0)
                      end
                    end
                  end
                  -- Translate the sentence, THEN append the diagnostic (README rule
                  -- 3 keeps rc codes and counters English). EXP33 swapped the static
                  -- second line for this runtime diag and orphaned the six-language
                  -- translation of the old two-line key; the key is now the sentence.
                  UI.Notif_queue.add(PLDR.L("No games found on hdd0:")..diag, "warn")
                end
              else
                UI.Notif_queue.add(PLDR.L("HDD not usable").."\n"..PLDR.L("status:").." "..PLDR.HDD.STATUS, "error")
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
              -- Show the retry so a longer probe reads as "still looking" and not as a
              -- freeze. Only an already-failing setup ever sees past attempt 1.
              PLDR.UsbProbeProgress = function(attempt, total)
                report(PLDR.L("Looking for USB drive...").." ("..tostring(attempt).."/"..tostring(total)..")", 0.38)
              end
              local usb_roots = PLDR.GetRootsByType("usb")
              PLDR.UsbProbeProgress = nil
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
	                -- Say WHY. The base string stays byte-identical so the five existing
	                -- translations still match; the diagnostic rides on a third line as raw
	                -- numbers (untranslated on purpose -- a tester photographing the screen
	                -- is the only telemetry this bug has).
	                -- Pre-translate: appending the [diag] line below defeats the toast
	                -- queue's add-time exact-match, so the translated base was reverting
	                -- to English in EXACTLY the failure case testers photograph.
	                local msg = PLDR.L("No USB backend detected\nreseat the drive and try again")
	                local diag = nil
	                if type(PLDR.GetUsbDiagText) == "function" then
	                  local ok_d, d = pcall(PLDR.GetUsbDiagText)
	                  if ok_d and type(d) == "string" and d ~= "" then diag = d end
	                end
	                if diag ~= nil then msg = msg.."\n["..diag.."]" end
	                UI.Notif_queue.add(msg, "warn")
	              end
	              report("Building USB game list...", 0.44)
	              -- Single-drive only: the combined multi-drive list was cached to the
	              -- FIRST root's file, so a later boot with only drive A served ghost
	              -- entries for absent drive B. Multi-drive setups always live-scan.
	              local usb_cache = (usb_roots ~= nil and usb_roots[1] ~= nil and #usb_roots == 1) and (usb_roots[1].."POPS/.gamecache") or nil
	              local usb_cg, usb_ch = nil, nil
	              if usb_cache ~= nil then usb_cg, usb_ch = PLDR.LoadGameListCache(usb_cache) end
	              if usb_cg ~= nil then
	                PLDR.ApplyGameListCache(usb_cg, "", usb_ch)
	                report("Loaded USB list from cache...", 1.0)
	              else
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
	                if usb_cache ~= nil and #PLDR.GAMES > 0 then
	                  PLDR.SaveGameListCache(usb_cache, PLDR.GAMES, PLDR.HIDDEN)
	                end
	              end
	              report("Opening USB list...", 1.0)
              UI.SceneChange(UI.SCENES.GUSBFAT)
            end, "Failed to load USB")
            if not ok then return end
	          elseif UI.MainMenu.OPT == 6 then
	            UI.Notif_queue.add("This backend isn't implemented yet", "warn")
	          elseif UI.MainMenu.OPT == 7 then
            -- SMB (v1): connect + browse (LAZY -- never at boot). The whole connect +
            -- blank-Share picker + reconnect flow lives in UI.RunSmbConnectFlow to keep
            -- this menu handler's locals under Lua's per-function cap.
            UI.RunSmbConnectFlow()
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
      NavHoldFrames = {}; -- per-direction frames-held counter (frame-count auto-repeat)
      StickV = 0;        -- latched left-stick vertical fold state (-1 up / 0 / +1 down)
      StickH = 0;        -- latched left-stick horizontal fold state (-1 left / 0 / +1 right)
      Queue = {};
      DebugPadTimer = nil;
      DebugPadLast = 0;
      NavEventTimer = nil;
      NavEventLast = 0;
      NavEventCount = 0;
      Listen = function ()
        if UI.Pad.Timer == nil then
          UI.Pad.Timer = Timer.new()
        end
        UI.Pad.OLDPAD = UI.Pad.GPAD
        UI.Pad.GPAD = Pads.get()
        GPAD = UI.Pad.GPAD
        -- OPL-style: fold the LEFT ANALOG STICK into the d-pad direction bits so
        -- stick navigation runs through the exact same edge + auto-repeat path as
        -- the d-pad (OPL pad.c readPad does this) -- smooth item-by-item, no separate
        -- page-jump. getLeftStick returns (h, v) centered at 0 (up/left negative,
        -- down/right positive).
        --
        -- GATE (mirrors OPL pad.c:201 `if ((pad->buttons.mode >> 4) == 0x07)`): only
        -- fold when the pad is ACTUALLY in analog/DualShock mode. A digital-mode pad
        -- (src/pad.cpp initializePad leaves modes==0 controllers digital) returns
        -- stale/zero analog bytes -> getLeftStick reports ~ -127 -> WITHOUT this gate
        -- that injects a phantom PAD_UP|PAD_LEFT every frame and breaks up/down nav
        -- (Nuno6573 #BETA-13). Pads.getMode() == PAD_MODECURID high nibble: 0x5
        -- analog, 0x7 DualShock, 0x4 digital, 0 no-data. nil-safe: if getMode is
        -- absent or non-analog, we skip the fold entirely (d-pad still works).
        --
        -- HYSTERESIS: assert a direction at |v|>64 but only RELEASE it below |v|<40,
        -- and latch the asserted side. A stick parked at the deadzone boundary can't
        -- dither across the threshold and edge-spam the immediate-fire nav branch
        -- (resolve_nav fresh-press bypass) -> no runaway scroll.
        local stick_analog = false
        if type(Pads) == "table" and type(Pads.getMode) == "function" then
          local ok_md, md = pcall(Pads.getMode)
          if ok_md and type(md) == "number" and (md == PAD_ANALOG or md == PAD_DUALSHOCK) then
            stick_analog = true
          end
        end
        if stick_analog and type(Pads.getLeftStick) == "function" then
          local ok_ls, lh, lv = pcall(Pads.getLeftStick)
          if ok_ls then
            local ASSERT, RELEASE = 64, 40
            if type(lv) ~= "number" then lv = 0 end
            if type(lh) ~= "number" then lh = 0 end
            -- vertical latch
            if UI.Pad.StickV == 0 then
              if lv < -ASSERT then UI.Pad.StickV = -1
              elseif lv > ASSERT then UI.Pad.StickV = 1 end
            elseif UI.Pad.StickV == -1 then
              if lv > -RELEASE then UI.Pad.StickV = 0 end
            else
              if lv < RELEASE then UI.Pad.StickV = 0 end
            end
            -- horizontal latch
            if UI.Pad.StickH == 0 then
              if lh < -ASSERT then UI.Pad.StickH = -1
              elseif lh > ASSERT then UI.Pad.StickH = 1 end
            elseif UI.Pad.StickH == -1 then
              if lh > -RELEASE then UI.Pad.StickH = 0 end
            else
              if lh < RELEASE then UI.Pad.StickH = 0 end
            end
            if UI.Pad.StickV == -1 then UI.Pad.GPAD = UI.Pad.GPAD | PAD_UP
            elseif UI.Pad.StickV == 1 then UI.Pad.GPAD = UI.Pad.GPAD | PAD_DOWN end
            if UI.Pad.StickH == -1 then UI.Pad.GPAD = UI.Pad.GPAD | PAD_LEFT
            elseif UI.Pad.StickH == 1 then UI.Pad.GPAD = UI.Pad.GPAD | PAD_RIGHT end
            GPAD = UI.Pad.GPAD
          end
        else
          -- not analog this frame: drop any latched stick direction so a stale
          -- latch can't keep asserting after the pad changes mode / disconnects.
          UI.Pad.StickV = 0
          UI.Pad.StickH = 0
        end

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

        -- Action emits ride the rising edge only (pressed = GPAD & ~OLDPAD), so a held
        -- button already fires once per press. The old MIN_ACTION_MS time debounce was a
        -- no-op (it compared a microsecond delta to a 220 "ms" constant) AND, since it
        -- shared one timestamp across every action button, "fixing" it would have dropped
        -- legit quick distinct presses (CONFIRM->EXIT). Removed: edge-triggering is the gate.
        local function emit_action(event)
          emit(event)
        end

        -- Region-native mapping: on Japanese-ROM consoles CIRCLE confirms and
        -- CROSS cancels (UI.ConfirmPadMask -- R3Z3N review). Every scene sees
        -- only the abstract CONFIRM/BACK events, so this is the single flip.
        if (pressed & UI.ConfirmPadMask()) ~= 0 then emit_action("CONFIRM") end
        if (pressed & UI.BackPadMask()) ~= 0 then emit_action("BACK") end
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

        -- Nav auto-repeat, the CANONICAL Enceladus-ecosystem way: COUNT FRAMES, never
        -- read the wall clock. Timer.getTime() returns raw clock() ticks -- MICROSECONDS
        -- on PS2 (CLOCKS_PER_SEC = 1e6), undocumented -- and comparing that us value to
        -- ms-named constants cleared both gates every frame, so UP/DOWN auto-repeated
        -- ~60x/sec ("one click = 5 lines", up/down only, ANY device incl. keyboard --
        -- nuno6573 / LVD14 #504). The sibling Enceladus launchers (OSDMenu-Configurator
        -- ui_common.lua, RETROLauncher funciones.lua) deliberately avoid the timer and
        -- gate nav on a per-frame hold counter scaled by the refresh rate. UI.Pad.Listen
        -- runs once per vblank-paced frame, so one increment == one frame: frame-rate
        -- independent and unit-safe. The press edge fires immediately; only UP/DOWN
        -- repeat (LEFT/RIGHT stay edge-only so holding never page-jumps/spins the
        -- carousel). Cadence keeps the OPL intent: ~0.6s initial delay then ~0.2s repeat,
        -- derived from the video mode (PAL 50Hz / NTSC 60Hz).
        local nav_fps = ((UI.SCR.Y or 448) >= 512) and 50 or 60
        local NAV_DELAY_FRAMES = math.ceil(nav_fps * 0.6)   -- frames before the 1st repeat
        local NAV_RATE_FRAMES  = math.ceil(nav_fps * 0.2)   -- frames between repeats (~5/s)
        local function resolve_nav(dir, is_down, repeatable)
          if not is_down then
            if UI.Pad.NavHeld[dir] == true then UI.Pad.NavNeutral[dir] = true end
            UI.Pad.NavHeld[dir] = false
            UI.Pad.NavHoldFrames[dir] = 0
            return false
          end
          local was_held = UI.Pad.NavHeld[dir] == true
          UI.Pad.NavHeld[dir] = true
          if not was_held and UI.Pad.NavNeutral[dir] then
            UI.Pad.NavNeutral[dir] = false
            UI.Pad.NavHoldFrames[dir] = 0
            return true
          end
          if repeatable and was_held then
            local f = (UI.Pad.NavHoldFrames[dir] or 0) + 1
            UI.Pad.NavHoldFrames[dir] = f
            if f >= NAV_DELAY_FRAMES and ((f - NAV_DELAY_FRAMES) % NAV_RATE_FRAMES) == 0 then
              return true
            end
          end
          return false
        end

        if resolve_nav("UP", ((UI.Pad.GPAD & PAD_UP) ~= 0), true) then emit_nav("NAV_UP") end
        if resolve_nav("DOWN", ((UI.Pad.GPAD & PAD_DOWN) ~= 0), true) then emit_nav("NAV_DOWN") end
        if resolve_nav("LEFT", ((UI.Pad.GPAD & PAD_LEFT) ~= 0), false) then emit_nav("NAV_LEFT") end
        if resolve_nav("RIGHT", ((UI.Pad.GPAD & PAD_RIGHT) ~= 0), false) then emit_nav("NAV_RIGHT") end

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
		
          Font.ftPrintMultiLineAligned(LFONT, UI.SCR.X_MID, layout.TITLE_Y, 20, UI.SCR.X, 40, PLDR.L("POPSLoader\nfor POPStarter"), currcol)
          Font.ftPrintMultiLineAligned(BFONT, UI.SCR.X_MID, layout.TITLE_Y + 60, 20, UI.SCR.X, 40, PLDR.L("Code by El_isra"), currcol)
          -- The long-string literal keeps a trailing newline that the TSV key
          -- lacks, so L() never matched and the body stayed English under every
          -- language even though the full translation exists (sAGA's photo:
          -- two Hungarian lines above an English block). Strip it for the
          -- lookup; the renderer never needed the trailing blank line.
          Font.ftPrintMultiLineAligned(BFONT, UI.SCR.X_MID, layout.TITLE_Y + 80, 20, UI.SCR.X, UI.SCR.Y, PLDR.L((([[
Design by Berion
Scripts by nuno6573 and Ripto
Based on Enceladus by Daniel Santos
Testing by P4NCHOL1NO, VizoR, provato,
nuno6573, oldman63, saildot4k, and Community

Special Thanks To:
krHACKen for making POPStarter
uyjulian, fjtrujy, HWC, and others for always helping

This program is free and open source
If you bought it, you have been scammed

Compatibility problems? Visit:
youtube.com/@hugopocked6695
]]):gsub("\n$", ""))), currcol)
        -- Build-identity + boot-timing lines (bottom-anchored above the footer).
        -- Line 1: the BUILD_INFO.txt stamp when that loose file sits next to the
        -- ELF, else the embedded POPSLDR_VER. A normal one-file install ships NO
        -- BUILD_INFO.txt (the zip buries it under source/), and the old block
        -- gated BOTH lines on the stamp -- so testers saw neither the version nor
        -- the boot timing this channel asks them to photograph (sAGA, EXP8).
        local id_line = nil
        if UI.BUILD_INFO ~= nil and UI.BUILD_INFO.stamp ~= nil then
          id_line = UI.BUILD_INFO.stamp
        else
          local ver = tostring(rawget(_G, "POPSLDR_VER") or "")
          if ver ~= "" then id_line = "POPSLoader "..ver end
        end
        -- Boot profile: the whole IRX block runs before the screen exists, so
        -- this is a direct measure of the boot black screen and of which module
        -- owns it. A tester can photograph it. NOT nested in the stamp gate.
        local boot_line = nil
        if type(PLDR.GetBootProfileText) == "function" then
          local ok_b, boot_txt = pcall(PLDR.GetBootProfileText)
          if ok_b and type(boot_txt) == "string" and boot_txt ~= "" then
            boot_line = boot_txt
          end
        end
        if id_line ~= nil or boot_line ~= nil then
          local line_count = ((id_line ~= nil) and 1 or 0) + ((boot_line ~= nil) and 1 or 0)
          local stack_h = 14 * (line_count - 1)
          local stamp_y = Round(layout.FOOTER_LABEL_Y - 18)
          -- The credits body above is TOP-anchored (fixed offsets from TITLE_Y) while
          -- this stack is BOTTOM-anchored. On the 64px-shorter NTSC screen the stack
          -- rides UP into the credits body (provato HW report), so floor it just below
          -- the body's lowest line (~TITLE_Y+80+14*20, spacing 20); PAL never floors.
          -- The OLD floor (16*20+4) put line 1 at y=434 on NTSC: baseline (y+15,
          -- fntsys) at row 449 = clipped on a 448-line framebuffer, and a second line
          -- at y=448 = entirely off-screen. Invisible while the BUILD_INFO gate hid
          -- this layout; fatal once EXP9 un-gated it (the boot line IS the tester
          -- photo this channel asks for). Floor at 15*20: NTSC lines land at 410/424,
          -- baselines 425/439 <= 447, with the body ending ~405-408 just above.
          local credits_bottom = (layout.TITLE_Y + 80) + (15 * 20)
          if stamp_y < credits_bottom then stamp_y = credits_bottom end
          -- Belt-and-braces: keep every baseline (y+15) on-screen whatever the floor
          -- did -- a few px of body overlap beats losing the photo line entirely.
          local max_first = UI.SCR.Y - 16 - stack_h
          if stamp_y > max_first then stamp_y = max_first end
          local line_y = stamp_y
          if id_line ~= nil then
            Font.ftPrint(SFONT, layout.SAFE.L, line_y, 0, UI.SCR.X, 16, id_line, UI.CCOL.GREY)
            line_y = line_y + 14
          end
          if boot_line ~= nil then
            Font.ftPrint(SFONT, layout.SAFE.L, line_y, 0, UI.SCR.X, 16, boot_line, UI.CCOL.GREY)
          end
        end

        if not UI.Credits._draw_only then
          Input_GetEvent()
          if UI.HandleGlobalInput(false) then return end
          if UI.Pad.Events.EXIT or UI.Pad.Events.BACK or UI.Pad.Events.ANY then
            -- Return to wherever Credits was opened from (e.g. the game list, so it
            -- doesn't bounce to the Main Menu and force a rescan); MMAIN otherwise.
            local back_scene = UI.CreditsReturnScene or UI.SCENES.MMAIN
            UI.CreditsReturnScene = nil
            UI.SceneChange(back_scene)
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
  [UI.SCENES.GBDMHDD] = true,
  [UI.SCENES.GSMBNET] = true
}
function UI.IsGameScene(scene)
  return UI.GAME_SCENES[scene] == true
end
function UI.IsUsbScene(scene)
  return scene == UI.SCENES.GUSBFAT
end
function UI.OnSceneExit(previous_scene, next_scene)
  if UI.IsGameScene(previous_scene) and previous_scene ~= next_scene then
    -- EXP33: free textures but keep the negative-miss memo (see ReleaseTextures)
    -- so re-entering the same device doesn't re-walk the FAT for missing covers.
    if UI.CoverCache ~= nil and UI.CoverCache.ReleaseTextures ~= nil then
      UI.CoverCache:ReleaseTextures()
    elseif UI.CoverCache ~= nil and UI.CoverCache.Clear ~= nil then
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
-- Generic blocking yes/no confirm (confirm = Yes, back = No; glyphs follow the
-- region-native mapping). `lines` = array of text lines. Frame-paced +
-- button-release-gated like RunVideoModeConfirm; defaults to NO on a ~30s
-- timeout so a destructive prompt can never auto-confirm itself.
function UI.RunConfirm(lines)
  if type(Screen) ~= "table" or type(Screen.flip) ~= "function"
     or type(Pads) ~= "table" or type(Pads.get) ~= "function" then
    return false
  end
  if type(lines) ~= "table" then lines = { tostring(lines or "") } end
  -- Translate FIRST, then split on \n into display lines. Callers pass ONE key
  -- per SENTENCE (line breaks inside it), never one key per display line: this
  -- prompt used to be four hand-wrapped fragments, each its own i18n key, so a
  -- translator was handed "...They won't" / "return until you turn this back On
  -- (or re-add them" / "manually)..." and had nowhere to put Hungarian word
  -- order. sAGA: "why does this expression consist of three parts? the logic of
  -- the translation falls apart completely." He was right. Splitting AFTER L()
  -- also lets each language choose its own break points.
  local disp = {}
  for i = 1, #lines do
    local s = PLDR.L(tostring(lines[i] or ""))
    local start = 1
    while true do
      local nl = string.find(s, "\n", start, true)
      if nl == nil then disp[#disp + 1] = string.sub(s, start); break end
      disp[#disp + 1] = string.sub(s, start, nl - 1)
      start = nl + 1
    end
  end
  lines = disp
  local yes_mask, no_mask = UI.ConfirmPadMask(), UI.BackPadMask()
  local settle = 0
  while settle < 30 do
    local okp, gp = pcall(Pads.get)
    if settle >= 8 and okp and type(gp) == "number" and (gp & (yes_mask | no_mask)) == 0 then break end
    Screen.flip()
    settle = settle + 1
  end
  local f, total = 0, 30 * 60
  while f < total do
    Screen.clear(UI.SCR.BGCOL or Color.new(20, 30, 80))
    local y = UI.SCR.Y_MID - (#lines * 11) - 24
    for i = 1, #lines do
      Font.ftPrint(SFONT, UI.SCR.X_MID, y, 8, UI.SCR.X, 16, PLDR.L(tostring(lines[i] or "")), UI.CCOL.GREY)
      y = y + 22
    end
    Font.ftPrint(BFONT, UI.SCR.X_MID, y + 16, 8, UI.SCR.X, 24, UI.PadHintPair("Yes", "No"), UI.CCOL.YELLOW)
    Screen.flip()
    f = f + 1
    local okp, gp = pcall(Pads.get)
    if okp and type(gp) == "number" then
      if (gp & yes_mask) ~= 0 then return true end
      if (gp & no_mask) ~= 0 then return false end
    end
  end
  return false
end

-- Blocking SMB share picker: list the discovered shares, Up/Down to move, X selects, O
-- cancels. Returns the chosen share name (string) or nil. Mirrors the RunConfirm modal
-- (Screen.clear/flip + raw Pads.get), with EDGE-detected nav (one press = one move; also
-- neutralises PCSX2's constant phantom PAD_UP) and a scrolling window for long lists.
function UI.RunSharePicker(shares)
  if type(Screen) ~= "table" or type(Screen.flip) ~= "function"
     or type(Pads) ~= "table" or type(Pads.get) ~= "function" then
    return nil
  end
  if type(shares) ~= "table" or #shares == 0 then return nil end
  local sel, prev, MAXVIS = 1, 0, 10
  local pick_mask, cancel_mask = UI.ConfirmPadMask(), UI.BackPadMask()
  local settle = 0
  while settle < 30 do
    local okp, gp = pcall(Pads.get)
    if settle >= 8 and okp and type(gp) == "number"
       and (gp & (pick_mask | cancel_mask | PAD_UP | PAD_DOWN)) == 0 then break end
    Screen.flip()
    settle = settle + 1
  end
  local f, total = 0, 60 * 60
  while f < total do
    Screen.clear(UI.SCR.BGCOL or Color.new(20, 30, 80))
    local vis = math.min(#shares, MAXVIS)
    local top = 1
    if #shares > MAXVIS then
      top = sel - math.floor(MAXVIS / 2)
      if top < 1 then top = 1 end
      if top > #shares - MAXVIS + 1 then top = #shares - MAXVIS + 1 end
    end
    local y = UI.SCR.Y_MID - (vis * 11) - 18
    Font.ftPrint(LFONT, UI.SCR.X_MID, y - 26, 8, UI.SCR.X, 24, PLDR.L("Select a share"), UI.CCOL.YELLOW)
    for i = top, math.min(top + MAXVIS - 1, #shares) do
      local is_sel = (i == sel)
      local label = is_sel and ("> "..tostring(shares[i]).." <") or tostring(shares[i])
      Font.ftPrint(SFONT, UI.SCR.X_MID, y, 8, UI.SCR.X, 16, label, is_sel and UI.CCOL.YELLOW or UI.CCOL.GREY)
      y = y + 22
    end
    Font.ftPrint(BFONT, UI.SCR.X_MID, y + 14, 8, UI.SCR.X, 24, UI.PadHintPair("Select", "Cancel"), UI.CCOL.GREY)
    Screen.flip()
    f = f + 1
    local okp, gp = pcall(Pads.get)
    gp = (okp and type(gp) == "number") and gp or 0
    local pressed = gp & ~prev
    prev = gp
    if (pressed & PAD_UP) ~= 0 then sel = (sel - 2) % #shares + 1 end
    if (pressed & PAD_DOWN) ~= 0 then sel = sel % #shares + 1 end
    if (pressed & pick_mask) ~= 0 then return shares[sel] end
    if (pressed & cancel_mask) ~= 0 then return nil end
  end
  return nil
end

-- Map a connectSMB error code to the user-facing message. Shared by the connect
-- flow below AND the R1 rescan arm (which used to swallow the reconnect error and
-- toast a misleading "List refreshed (no games found)").
function UI.SmbErrorMessage(err)
  if err == "NO_SHARE" then
    return "No Share set in SMB settings\n(server returned no shares)"
  end
  return ({
    NO_LINK       = "No network link\ncheck the Ethernet cable / adapter",
    IPCFG_FAIL    = "Couldn't apply the PS2 IP settings\ntry again or power-cycle the network adapter",
    DHCP_FAIL     = "DHCP failed\nset a static IP in SMB settings",
    CONN_FAIL     = "Can't reach the server\ncheck Server IP / Port in SMB settings",
    PROT_FAIL     = "Server refused SMBv1\nenable SMBv1 support on the host",
    LOGON_FAIL    = "SMB login failed\ncheck User / Password",
    ECHO_FAIL     = "SMB connection dropped",
    SHARE_FAIL    = "Share not found\ncheck the Share name (host must allow SMB1)",
    IRX_LOAD_FAIL = "SMB modules failed to load",
    NETBIOS_NA    = "NetBIOS isn't supported\nset Address type = IP + a Server IP",
  })[err] or "SMB connect failed"
end

-- Full net-SMB connect flow (OPT==7): connect + scan into GSMBNET. If the Share field is
-- blank, GETSHARELIST's shares are offered via UI.RunSharePicker (run OUTSIDE the busy
-- task, which owns the screen); the chosen share is persisted (settings sidecar + the
-- in-game SMBCONFIG.DAT) and we reconnect. Bounded rounds so a bad server can't loop forever.
-- Lives here (not inline in the menu handler) to keep that handler under Lua's local cap.
function UI.RunSmbConnectFlow()
  -- Browsing works without the mc:/POPSTARTER SMB pack (the menu has its own
  -- embedded stack), but LAUNCHING doesn't -- warn up front (browse stays usable;
  -- the launch dispatch enforces the hard gate).
  -- Three possible states, and only the last can actually play a game. Say which
  -- one the user is in BEFORE they browse a share and hit a black screen at launch.
  --
  -- 1. NO MEMORY CARD AT ALL. POPSTARTER keeps its whole SMB pack and both .DAT on
  --    mc0:/mc1:, so without a card an SMB game can never launch no matter how well
  --    the list populates. Browsing still works (the menu has its own embedded
  --    stack and needs no card), so this informs rather than blocks -- but it says
  --    plainly that nothing here will play.
  if type(PLDR) == "table" and type(PLDR.HasMemoryCard) == "function"
     and PLDR.HasMemoryCard() ~= true then
    UI.Notif_queue.add("No memory card detected\nSMB games will not launch or play without one --\nPOPSTARTER reads its network settings from mc0: or mc1:", "error")
  else
    -- 2. CARD PRESENT BUT NO PACK. Offer to install it right here rather than
    --    sending the user to another menu. Tested against the FILESYSTEM, not the
    --    saved preference, so this and the hard launch gate can never disagree.
    local modules_staged = (type(PLDR) == "table" and type(PLDR.AreSmbModulesStaged) == "function")
      and PLDR.AreSmbModulesStaged() or (type(PLDR) == "table" and PLDR.SMB_MODULES == true)
    if type(PLDR) == "table" and not modules_staged then
      local install = UI.RunConfirm({
        PLDR.L("The SMB modules are not on your memory card.\nGames will list, but none of them will boot."),
        PLDR.L("Install them now?"),
      })
      if install == true then
        local installed = false
        UI.RunBusyTask("Installing SMB modules...", function (report)
          installed = (PLDR.ApplySmbModules(function(i, n, name)
            report(tostring(name or ""), (tonumber(n) or 1) > 0 and ((tonumber(i) or 0) / n) or 0)
          end) == true)
        end, "Failed to install SMB modules")
        if installed then
          PLDR.SMB_MODULES = true
          pcall(PLDR.SaveSettingsAtomic)
          UI.Notif_queue.add("SMB modules installed", "info")
        else
          UI.Notif_queue.add("Could not install the SMB modules\nCheck the memory card is inserted and has free space", "error")
        end
      else
        UI.Notif_queue.add("Games will list but will not boot\nInstall them from Settings > SMB modules when ready", "warn")
      end
    end
  end
  local share_choices = nil   -- comma-list set when a connect returns NO_SHARE with shares
  local function attempt()
    share_choices = nil
    local entered = false
    UI.RunBusyTask("Connecting to SMB...", function (report)
      local scan_progress = UI.MakeBusyProgressReporter(report, "Scanning SMB games...", 0.55, 0.9)
      report("Bringing up network...", 0.2)
      PLDR.CleanupGameList()
      PLDR.GAMEPATH = ""
      local smb_root, smb_err, smb_extra = PLDR.InitSMBPopsRoot(report)
      if smb_root == nil then
        if smb_err == "NO_SHARE" and type(smb_extra) == "string" and smb_extra ~= "" then
          share_choices = smb_extra   -- offer the picker after this busy task closes
          return
        end
        UI.Notif_queue.add(UI.SmbErrorMessage(smb_err), "warn")
        return
      end
      PLDR.CleanupGameList()
      local smb_cache = smb_root..".gamecache"
      local smb_cg, smb_ch = PLDR.LoadGameListCache(smb_cache)
      if smb_cg ~= nil then
        PLDR.ApplyGameListCache(smb_cg, smb_root, smb_ch)
        report("Loaded SMB list from cache...", 1.0)
      else
        report("Scanning SMB games...", 0.55)
        PLDR.GetPS1GameLists(smb_root, true, scan_progress)
        PLDR.SaveGameListCache(smb_cache, PLDR.GAMES, PLDR.HIDDEN)
      end
      report("Opening SMB list...", 1.0)
      -- Games path shapes BROWSING only: POPStarter's SMBCONFIG.DAT carries just
      -- SERVER[:PORT] SHARE (no path), and it reads <share>/POPS -- so a set
      -- Games path lists games that cannot launch. Say so instead of half-working.
      do
        local gp = tostring((type(PLDR.SMB) == "table" and PLDR.SMB.PATH) or "")
        gp = string.match(gp, "^[%s/\\]*(.-)[%s/\\]*$") or ""
        if gp ~= "" and string.lower(gp) ~= "pops" then
          UI.Notif_queue.add("Games path affects browsing only:\nPOPStarter can only launch games from <share>/POPS", "warn")
        end
      end
      -- Refresh the in-game .DAT now that the interface is actually up. On DHCP this
      -- is the ONLY moment a real address exists to write: POPStarter cannot lease one
      -- itself, and the boot-time backfill runs long before the network comes up. The
      -- share-picker branch below also syncs, but that only fires when Share was blank
      -- -- the ordinary "share already configured" path reached the launch with a stale
      -- or absent IPCONFIG.DAT. Write-if-changed, so this is a no-op once it's current.
      pcall(PLDR.SyncSmbDat)
      UI.SceneChange(UI.SCENES.GSMBNET)
      entered = true
    end, "Failed to connect to SMB")
    return entered
  end
  local rounds = 0
  while true do
    if attempt() then break end               -- entered the SMB scene
    if share_choices == nil then break end     -- a real error was already shown
    rounds = rounds + 1
    if rounds > 3 then break end
    local shares = {}
    for s in string.gmatch(share_choices, "([^,]+)") do
      local t = string.match(s, "^%s*(.-)%s*$")
      if t ~= nil and t ~= "" then shares[#shares + 1] = t end
    end
    local picked = UI.RunSharePicker(shares)
    if picked == nil then
      UI.Notif_queue.add("No Share selected", "warn")
      break
    end
    -- Persist the choice so browse, launch, AND the in-game SMBCONFIG.DAT all use it.
    PLDR.SMB.SHARE = picked
    UI.SmbDraft = nil   -- force the settings editor to re-seed from the new value
    pcall(PLDR.SaveSettingsAtomic)
    pcall(PLDR.SyncSmbDat)
  end
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
  -- Let the freshly-switched GS settle (>= ~0.5s), AND wait for the Save
  -- confirm/back buttons to release so a still-held button isn't read as an
  -- instant confirm/revert.
  local keep_mask, revert_mask = UI.ConfirmPadMask(), UI.BackPadMask()
  local settle = 0
  while settle < 90 do
    local okp, gp = pcall(Pads.get)
    if settle >= 30 and okp and type(gp) == "number" and (gp & (keep_mask | revert_mask)) == 0 then break end
    Screen.flip()
    settle = settle + 1
  end
  local f = 0
  while f < total_frames do
    local remaining = math.max(0, math.ceil((total_frames - f) / FPS))
    Screen.clear(UI.SCR.BGCOL or Color.new(20, 30, 80))
    Font.ftPrint(LFONT, UI.SCR.X_MID, UI.SCR.Y_MID - 70, 8, UI.SCR.X, 32, PLDR.L("Keep this display mode?"), UI.CCOL.YELLOW)
    Font.ftPrint(BFONT, UI.SCR.X_MID, UI.SCR.Y_MID, 8, UI.SCR.X, 24, UI.PadHintPair("Keep", "Revert"), UI.CCOL.GREY)
    Font.ftPrint(SFONT, UI.SCR.X_MID, UI.SCR.Y_MID + 54, 8, UI.SCR.X, 16, PLDR.L("Reverting in").." "..tostring(remaining).."s "..PLDR.L("if not confirmed"), UI.CCOL.GREY)
    Screen.flip()
    f = f + 1
    local okp, gp = pcall(Pads.get)
    if okp and type(gp) == "number" then
      if (gp & keep_mask) ~= 0 then return true end
      if (gp & revert_mask) ~= 0 then return false end
    end
  end
  return false
end
-- ===== SMB / Network settings field helpers (Stage 1: config only) ==========
-- Spec-driven row rendering for the "SMB / Network" settings section. The field
-- spec + persistence live in system.lua (PLDR.SMB_FIELDS / PLDR.Smb*). These are
-- module-level (NOT Play-locals) to keep the big settings closure under Lua's
-- per-function local cap. Editing routes through a single draft (UI.SmbDraft) +
-- dirty flag (UI.SmbDirty); the settings commit passes opts.smb = UI.SmbDraft.
UI._SMB_LABELS = {
  DHCP = "IP assignment", PS2_IP = "PS2 IP", NETMASK = "Netmask",
  GATEWAY = "Gateway", DNS = "DNS", LINKMODE = "Link mode",
  ADDR_TYPE = "Address type", NB_ADDR = "NetBIOS name", SERVER = "Server IP",
  PORT = "Port", SHARE = "Share", USER = "User", PASS = "Password",
  PATH = "Games path (folder holding POPS)",
}
UI._SMB_ENUM_LABELS = {
  LINKMODE = { auto = "Auto", ["100full"] = "100M Full", ["100half"] = "100M Half", ["10full"] = "10M Full", ["10half"] = "10M Half" },
  ADDR_TYPE = { ip = "IP address", netbios = "NetBIOS name" },
}
local function _SmbTruncMiddle(s, max)
  s = tostring(s or "")
  if string.len(s) <= max then return s end
  local keep = math.floor((max - 3) / 2)
  if keep < 1 then keep = 1 end
  return string.sub(s, 1, keep).."..."..string.sub(s, string.len(s) - keep + 1)
end
function UI.SmbEnsureDraft()
  if type(UI.SmbDraft) ~= "table" then
    if type(PLDR) == "table" and type(PLDR.SmbCopy) == "function" then
      UI.SmbDraft = PLDR.SmbCopy(PLDR.SMB)
    else
      UI.SmbDraft = {}
    end
  end
  return UI.SmbDraft
end
function UI.SmbFieldLabel(field)
  return UI._SMB_LABELS[field.key] or field.key
end
function UI.SmbFieldDirty(key)
  local d = UI.SmbEnsureDraft()
  local cur = (type(PLDR) == "table" and type(PLDR.SMB) == "table") and PLDR.SMB[key] or nil
  return tostring(d[key]) ~= tostring(cur)
end
function UI.SmbFieldDisplay(field)
  local d = UI.SmbEnsureDraft()
  local v = d[field.key]
  if field.kind == "bool" then
    if field.key == "DHCP" then
      return (v == true) and "DHCP (automatic)" or "Static (manual)"
    end
    return (v == true) and "On" or "Off"
  elseif field.kind == "enum" then
    local m = UI._SMB_ENUM_LABELS[field.key]
    return (m and m[v]) or tostring(v or "")
  else
    local s = tostring(v or "")
    if field.key == "PASS" then
      if s == "" then return "(not set)" end
      return string.rep("*", math.min(string.len(s), 16))
    end
    if s == "" then
      -- There is no cwd on an SMB share and nothing is auto-detected: blank means
      -- the share ROOT, and POPS/ is always appended (browse root = <share>/POPS).
      if field.key == "PATH" then return "(share root)" end
      return "(not set)"
    end
    return _SmbTruncMiddle(s, 38)
  end
end
function UI.SmbFieldCycle(field, dir)
  local d = UI.SmbEnsureDraft()
  if field.kind == "bool" then
    d[field.key] = not (d[field.key] == true)
  elseif field.kind == "enum" then
    local choices = field.choices or {}
    local idx = 1
    for i = 1, #choices do
      if choices[i] == d[field.key] then idx = i break end
    end
    idx = idx + (tonumber(dir) or 1)
    if idx < 1 then idx = #choices elseif idx > #choices then idx = 1 end
    d[field.key] = choices[idx] or field.default
  end
  UI.SmbDirty = true
end
function UI.SmbFieldOpenEditor(field)
  local d = UI.SmbEnsureDraft()
  -- Full-phrase template, NOT L("Edit").." "..L(field): concatenating a fixed
  -- "Edit" translation in front of the field name produces wrong grammar in other
  -- languages (sAGA #538: "szerkesztes NETMASK" instead of "NETMASK szerkesztese").
  -- The translator supplies "Edit %s" with %s wherever the language needs it, and
  -- the (also-translated) field name is substituted. pcall guards a malformed
  -- translation (no %s) with the old concatenation so a bad string never crashes.
  local field_label = PLDR.L(UI._SMB_LABELS[field.key] or field.key)
  local fmt_ok, fmt_title = pcall(string.format, PLDR.L("Edit %s"), field_label)
  local title = fmt_ok and fmt_title or (PLDR.L("Edit").." "..field_label)
  if type(UI.PathEditor) == "table" and type(UI.PathEditor.Open) == "function" then
    UI.PathEditor.Open(title, tostring(d[field.key] or ""), function(value)
      local dd = UI.SmbEnsureDraft()
      local typed = string.gsub(tostring(value or ""), "[\r\n]", "")
      -- Sanitize NOW (trim + PORT/IP shape validation) so the row immediately
      -- shows what the connect path and SMBCONFIG.DAT will actually use -- and
      -- TELL the user when their input was rejected, instead of silently
      -- substituting at commit time and leaving a mysteriously reset field.
      local cleaned = typed
      if type(PLDR) == "table" and type(PLDR.SmbSanitize) == "function" then
        cleaned = PLDR.SmbSanitize(field, typed)
      end
      if tostring(cleaned) ~= typed and type(UI.Notif_queue) == "table" then
        -- Covers both a rejected shape (falls to the field default) and a
        -- whitespace trim -- either way the user sees the value actually kept.
        UI.Notif_queue.add(PLDR.L(UI._SMB_LABELS[field.key] or field.key).." "..PLDR.L("adjusted -- using").." \""..tostring(cleaned).."\"", "warn")
      end
      dd[field.key] = cleaned
      UI.SmbDirty = true
    end)
  end
end
-- Master toggle for the SMB pack. Mirrors CycleBdma's guard: can't install while the
-- POPSTARTER memory-card folder is off (the modules live there). Module-level to avoid
-- adding a Play-closure local.
function UI.ToggleSmbModulesDraft()
  if (UI.SmbModulesDraft ~= true) and type(PLDR) == "table" and PLDR.POPSTARTER_MC_FOLDER == false then
    if type(UI.Notif_queue) == "table" then
      UI.Notif_queue.add("Enable the POPSTARTER Folder first\n(SMB modules must live on the memory card)", "warn")
    end
    return
  end
  UI.SmbModulesDraft = not (UI.SmbModulesDraft == true)
  UI.SmbModulesDirty = true
end

function UI.SyncSettingsDraftFromRuntime()
  UI.PopstarterPathDraft = tostring(PLDR.POPSTARTER_PATH or "")
  UI.DkwdrvPathDraft = tostring(PLDR.DKWDRV_PATH or PLDR.DKWDRV_DEFAULT_PATH or "mc0:/PS1_DKWDRV/DKWDRV.ELF")
  if type(PLDR) == "table" and type(PLDR.NormalizeKeyboardLayout) == "function" then
    UI.KeyboardLayoutDraft = PLDR.NormalizeKeyboardLayout(PLDR.KEYBOARD_LAYOUT)
  else
    UI.KeyboardLayoutDraft = tostring(PLDR.KEYBOARD_LAYOUT or "QWERTY")
  end
  if type(PLDR) == "table" and type(PLDR.NormalizeLanguage) == "function" then
    UI.LanguageDraft = PLDR.NormalizeLanguage(PLDR.LANGUAGE)
  else
    UI.LanguageDraft = tostring(PLDR.LANGUAGE or "EN")
  end
  UI.PopPathDirty = false
  UI.DkwdrvDirty = false
  UI.VideoStandardDirty = false
  if type(PLDR) == "table" and type(PLDR.SmbCopy) == "function" then
    UI.SmbDraft = PLDR.SmbCopy(PLDR.SMB)
  else
    UI.SmbDraft = {}
  end
  UI.SmbDirty = false
  UI.SmbModulesDraft = (type(PLDR) == "table" and PLDR.SMB_MODULES == true)
  UI.SmbModulesDirty = false
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
