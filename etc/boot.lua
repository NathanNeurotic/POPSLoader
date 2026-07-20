POPSLDR_VER = "v1.0.2-dev"

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


-- Default to "" so a launcher that passes argc==0 (argv0 -> nil) can't crash the
-- string.find calls below into the boot error screen; "" just falls through to the
-- normal mass/mc resolution path, same as any non-HDD/non-MX4SIO launcher.
local ARGV0 = System.GetArgv0() or ""

-- First-entry storage hardening.
--
-- MX4SIO's block device and FAT mount come up asynchronously. The existing page
-- retry loop was bounded, but its first mass-root sweep still called fileXioDopen
-- through doesFolderExist/getMassMountDriver while bdmfs_fatfs could be holding its
-- mount lock. One blocked call meant the retry loop never reached attempt two. For
-- the ten bare mass roots immediately following initMX4SIO, answer presence and
-- driver identity from bdm_query's lock-free device list instead. Normal folder
-- probes (including massN:/POPS/) still use the real filesystem after the initial
-- one-second settle.
--
-- MMCE is lazy-loaded on non-MMCE boots. EnsureMmceReadyOnce intentionally calls
-- System.ensureMmceman only once, so an immediate probe can race the freshly loaded
-- driver and make first entry fail while a second entry works. Wrap the load with a
-- bounded first-load settle/probe window; the existing system.lua code still owns
-- the final slot detection and pad reinitialization.
local raw_does_folder_exist = doesFolderExist
local raw_get_mass_mount_driver = type(System) == "table" and System.getMassMountDriver or nil
local raw_refresh_mass_backends = type(System) == "table" and System.refreshMassBackends or nil
local raw_init_mx4sio = type(System) == "table" and System.initMX4SIO or nil
local raw_ensure_mmceman = type(System) == "table" and System.ensureMmceman or nil
local mx4_mass_root_probe_budget = 0
local mx4_initial_settle_done = false
local mmce_initial_settle_attempted = false
local bdm_snapshot = nil

local function invalidate_bdm_snapshot()
  bdm_snapshot = nil
end

local function read_bdm_snapshot()
  if type(bdm_snapshot) == "table" then
    return bdm_snapshot
  end
  bdm_snapshot = false
  if type(System) == "table" and type(System.bdmList) == "function" then
    local ok, list = pcall(System.bdmList)
    if ok and type(list) == "table" then
      bdm_snapshot = list
      return bdm_snapshot
    end
  end
  return nil
end

local function parse_mass_root_slot(path)
  local candidate = string.lower(tostring(path or ""))
  if candidate == "mass:/" or candidate == "mass0:/" then
    return 0
  end
  local slot = string.match(candidate, "^mass([1-9]):/$")
  return tonumber(slot)
end

local function bdm_driver_for_mass_slot(slot)
  local list = read_bdm_snapshot()
  if type(list) ~= "table" then
    return nil
  end
  for _, info in pairs(list) do
    if type(info) == "table" and tonumber(info.parId) == tonumber(slot) then
      local name = tostring(info.name or "")
      if name ~= "" then
        return name
      end
    end
  end
  return nil
end

if type(raw_refresh_mass_backends) == "function" then
  System.refreshMassBackends = function(...)
    local result = raw_refresh_mass_backends(...)
    invalidate_bdm_snapshot()
    return result
  end
end

if type(raw_init_mx4sio) == "function" then
  System.initMX4SIO = function(...)
    local ok, reason = raw_init_mx4sio(...)
    invalidate_bdm_snapshot()
    if ok == true then
      mx4_mass_root_probe_budget = 10
      if not mx4_initial_settle_done and type(System.sleep) == "function" then
        System.sleep(1)
        mx4_initial_settle_done = true
        invalidate_bdm_snapshot()
      end
    end
    return ok, reason
  end
end

if type(raw_get_mass_mount_driver) == "function" then
  System.getMassMountDriver = function(root)
    local slot = parse_mass_root_slot(root)
    if slot ~= nil then
      local driver = bdm_driver_for_mass_slot(slot)
      if driver ~= nil then
        return driver
      end
      -- During the MX4SIO root sweep, a missing BDM entry means "not present yet".
      -- Do not fall back to fileXioDopen while the mount thread may own the FS lock.
      if mx4_mass_root_probe_budget > 0 then
        return nil
      end
    end
    return raw_get_mass_mount_driver(root)
  end
end

if type(raw_does_folder_exist) == "function" then
  doesFolderExist = function(path)
    local slot = parse_mass_root_slot(path)
    if slot ~= nil and mx4_mass_root_probe_budget > 0 then
      mx4_mass_root_probe_budget = mx4_mass_root_probe_budget - 1
      return bdm_driver_for_mass_slot(slot) ~= nil
    end
    return raw_does_folder_exist(path)
  end
end

if type(raw_ensure_mmceman) == "function" then
  System.ensureMmceman = function(...)
    local ok, reason = raw_ensure_mmceman(...)
    if ok ~= true or mmce_initial_settle_attempted then
      return ok, reason
    end

    mmce_initial_settle_attempted = true
    for attempt = 1, 5 do
      local slot_ready = false
      local ok0, ready0 = pcall(raw_does_folder_exist, "mmce0:/")
      local ok1, ready1 = pcall(raw_does_folder_exist, "mmce1:/")
      slot_ready = (ok0 and ready0 == true) or (ok1 and ready1 == true)
      if slot_ready then
        break
      end
      if attempt < 5 and type(System.sleep) == "function" then
        System.sleep(1)
      end
    end
    return ok, reason
  end
end

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

BOOT_MX4SIO_PREFIX = nil
BOOT_MX4SIO_PROBE_RESULT = nil
if string.find(ARGV0, "^[Mm][Xx]4[Ss][Ii][Oo]") then
  -- MX4SIO boot: the mx4sio:/ argv0 prefix is the BDM device-kind
  -- label, NOT a writable fileXio mount. The launcher (wLaunchELF,
  -- HOSDmenu, NHDDL, etc.) was able to load POPSLOADER.ELF through
  -- some kernel-side indirection, but fileXio file writes against
  -- mx4sio:/<path> fail with "may be read-only" (Nuno 2026-05-28 PM
  -- hardware: `mx4sio:/APPS/PS1_POPSLOADER/.pldrs may be read-only`).
  --
  -- The writable filesystem path is the mass*:/ slot where bdmfs_fatfs
  -- mounts the SD card once mx4sio_bd has loaded. The slot is volatile
  -- (depends on hotplug + IRX load order), so we identify it
  -- dynamically by the BDM driver name and parId. Unlike the old
  -- getMassMountDriver sweep, this does not fileXioDopen every mass root
  -- while the filesystem mount thread may still own its lock.
  --
  -- PR #472 also enforces at the C layer that mx4sio_bd requires
  -- usbmass_bd to be loaded first (maintainer rule: "mx4sio will need
  -- the usb drivers to activate before it with it"), so this branch
  -- calls System.ensureUsbMass before System.initMX4SIO.
  if type(System) == "table" and type(System.ensureUsbMass) == "function" then
    pcall(System.ensureUsbMass)
  end
  if type(System) == "table" and type(System.initMX4SIO) == "function" then
    pcall(System.initMX4SIO)
  end
  local function scan_for_mx4sio_root()
    if type(System.refreshMassBackends) == "function" then
      pcall(System.refreshMassBackends)
    end
    invalidate_bdm_snapshot()
    local list = read_bdm_snapshot()
    if type(list) ~= "table" then
      return nil, "no_bdm_list"
    end
    for _, info in pairs(list) do
      if type(info) == "table" then
        local driver = tostring(info.name or "")
        local lowered = string.lower(driver)
        if string.find(lowered, "mx4", 1, true) ~= nil or string.find(lowered, "sdc", 1, true) ~= nil then
          local slot = tonumber(info.parId)
          if slot ~= nil and slot >= 0 and slot <= 9 then
            local root = (slot == 0) and "mass:/" or ("mass"..tostring(slot)..":/")
            return root, "found:"..root.."="..driver
          end
        end
      end
    end
    return nil, "no_match"
  end
  local MX_ROOT = nil
  local probe_trace = {}
  for attempt = 1, 3 do
    local root, info = scan_for_mx4sio_root()
    probe_trace[#probe_trace + 1] = "a"..tostring(attempt)..":"..tostring(info or "nil")
    if root ~= nil then
      MX_ROOT = root
      break
    end
    if attempt < 3 then
      System.sleep(1)
    end
  end
  -- The boot-time scan does not consume the ten-probe page-sweep budget.
  -- Clear it so unrelated mass-root checks before page entry retain normal semantics.
  mx4_mass_root_probe_budget = 0
  invalidate_bdm_snapshot()
  BOOT_MX4SIO_PROBE_RESULT = table.concat(probe_trace, ";")
  if MX_ROOT ~= nil then
    BOOT_MX4SIO_PREFIX = MX_ROOT
    -- Translate mx4sio:/<rel> argv0 directory to MX_ROOT/<rel>/.
    -- ResolveAppDirLocal in system.lua will see APP_DIR is mx4sio:/-
    -- prefixed and cwd is mass*:/ and prefer the cwd, so settings
    -- sidecar resolves to the writable mass*:/ root.
    local relpath = string.match(ARGV0, "^[Mm][Xx]4[Ss][Ii][Oo]%d*:/?(.*)$") or ""
    -- Strip the filename so cwd is the directory containing the ELF
    -- (matches what the HDD branch does for its BOOTPATH).
    local dir_rel = string.match(relpath, "^(.-)/[^/]*$")
    if dir_rel == nil then
      dir_rel = ""
    end
    local translated_cwd = MX_ROOT..string.gsub(dir_rel, "^/+", "")
    if string.sub(translated_cwd, -1) ~= "/" then
      translated_cwd = translated_cwd.."/"
    end
    System.currentDirectory(translated_cwd)
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
