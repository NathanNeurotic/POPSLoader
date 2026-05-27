POPSLDR_VER = "v1.0.0 - rev3"

--- Processes a HDD full path into its components.
--- Supports both explicit PFS paths (`hdd0:__system:pfs:/osd110/hosdsys.elf`)
--- and raw OPL-style paths (`hdd0:+OPL/APPS/PS1_POPSLOADER/POPSLOADER.ELF`).
---@param PATH string
---@return string mountpart: will return partition path for mounting (`hdd0:__system`)
---@return string pfsindx: will return pfs index (`pfs:`)
---@return string filepath: will return path to file when partition gets mounted (`pfs:/osd110/hosdsys.elf`)
function GetMountData(PATH)
  local candidate = tostring(PATH or "")
  local device, partition, pfsdev, suffix = string.match(candidate, "^([Hh][Dd][Dd]%d):([^:]+):([Pp][Ff][Ss]%d*):(.+)$")
  if device ~= nil and partition ~= nil and pfsdev ~= nil and suffix ~= nil then
    if string.sub(suffix, 1, 1) ~= "/" then
      suffix = "/"..suffix
    end
    return string.format("%s:%s", device, partition), string.lower(pfsdev)..":", string.lower(pfsdev)..":"..suffix
  end

  device, partition, suffix = string.match(candidate, "^([Hh][Dd][Dd]%d):/+([^/]+)/(.+)$")
  if device == nil or partition == nil then
    device, partition, suffix = string.match(candidate, "^([Hh][Dd][Dd]%d):([^:/]+)/(.+)$")
  end
  if device ~= nil and partition ~= nil and suffix ~= nil then
    suffix = string.gsub(suffix, "^/+", "")
    return string.format("%s:%s", device, partition), "pfs1:", "pfs1:/"..suffix
  end

  return "", "", ""
end


local ARGV0 = System.GetArgv0()
if string.find(ARGV0, "^hdd0:") then
  local MNTPART
  BOOTPATH = nil
  BOOT_HDD_MOUNTPART = nil
  BOOT_HDD_MOUNT_SLOT = nil
  BOOT_HDD_MOUNT_PREFIX = nil
  MNTPART, _, BOOTPATH = GetMountData(ARGV0)
  if string.find(BOOTPATH, "^pfs") then
    SUCCESS, MODULE, ID, RET = HDD.Initialize()
    if SUCCESS then
      System.sleep(2) -- lets give it time to get ready
      if HDD.MountPartition(MNTPART, 1) then -- mount to "pfs1:" and NEVER USE IT FOR ANYTHING ELSE
        BOOT_HDD_MOUNTPART = MNTPART
        BOOT_HDD_MOUNT_SLOT = 1
        BOOT_HDD_MOUNT_PREFIX = "pfs1:/"
        BOOTPATH, _, _ = string.match(BOOTPATH, "(.-)([^/]-([^%.]+))$")
        -- Normalize whatever pfs slot prefix came from ARGV0 to the
        -- actual mount slot we just established. GetMountData preserves
        -- the original prefix from ARGV0, which can be slot-less ("pfs:")
        -- when launchers don't include a digit -- e.g. wLaunchELF passing
        -- "hdd0:_OPL:pfs:/APPS/PS1_POPSLOADER/POPSLOADER.ELF". But we
        -- always mount to pfs1: above. Lua's cwd must match the mount
        -- or relative-path file I/O (and the settings sidecar at
        -- APP_DIR/.pldrs) fails: Nuno 2026-05-26 saw "pfs:/APPS/PS1_
        -- POPSLOADER/.pldrs may be read-only" because cwd was pfs:/...
        -- and pfs: isn't a real mount.
        BOOTPATH = string.gsub(BOOTPATH, "^[Pp][Ff][Ss]%d*:", "pfs1:")
        System.currentDirectory(BOOTPATH)
      end
    end
  end
end
GPAD = 0
Font.ftInit()
local BOOT_FONT_KEY = "fonts/Roboto-Regular.ttf"
local function load_boot_font_or_die()
  local h = Font.ftLoadEmbedded(BOOT_FONT_KEY)
  if type(h) ~= "number" then
    Screen.clear(Color.new(0,0,0))
    Font.fmLoad()
    Font.fmPrint(40, 40, 0.8, "FATAL: embedded boot font missing: "..BOOT_FONT_KEY, Color.new(255, 0, 0))
    Screen.flip()
    while true do end
  end
  return h
end

BFONT = load_boot_font_or_die()
SFONT = load_boot_font_or_die()
LFONT = load_boot_font_or_die()
Font.ftSetCharSize(BFONT, 800, 800)
Font.ftSetCharSize(SFONT, 600, 600)
Font.ftSetCharSize(LFONT, 900, 900)
function STOP() Screen.clear(Color.new(255,0,0)) Screen.flip() while true do end end

require("system")
