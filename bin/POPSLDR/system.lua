--[[
  ___  ___  ___  ___ _                 _         
 | _ \/ _ \| _ \/ __| |   ___  __ _ __| |___ _ _ 
 |  _/ (_) |  _/\__ \ |__/ _ \/ _` / _` / -_) '_|
 |_|  \___/|_|  |___/____\___/\__,_\__,_\___|_|  
                                                 

  POPSLoader Main script. dont touch unless you know what youre doing
  to do cosmetic changes, please check the `ui.lua` and `images.lua` files

  Licensed under GNU General public license v3.0
--]]
_G.PLDR = _G.PLDR or {}
PLDR = _G.PLDR
local BOOT_PATH_RAW = System.currentDirectory()
local BOOT_ARGV0_RAW = nil
if type(System) == "table" and type(System.GetArgv0) == "function" then
  local ok_argv0, argv0 = pcall(System.GetArgv0)
  if ok_argv0 and type(argv0) == "string" and argv0 ~= "" then
    BOOT_ARGV0_RAW = argv0
  end
end
local function EnsureTrailingSlash(path)
  if path == nil then
    return nil
  end
  if string.sub(path, -1) == "/" then
    return path
  end
  return path.."/"
end
_G.EnsureTrailingSlash = EnsureTrailingSlash
local function NormalizeDeviceRoot(path)
  if path == nil or path == "" then return path end
  if string.match(path, "^host:/") then
    return path
  end
  local device = string.match(path, "^([%a]+%d*):/?$")
  if device ~= nil then
    return device..":/"
  end
  return path
end

local function CanonicalizeMassSlot0(path)
  if type(path) ~= "string" or path == "" then return path end
  -- Slot 0 of the BDM 'mass' bus is spelled both 'mass:' (bare) and 'mass0:'
  -- (explicit unit 0) depending on which alias argv0 carried this boot -- the
  -- launch diag shows the two spellings appearing for the same device. They
  -- address the SAME physical slot: luasystem's ParseMassRootSlot folds
  -- 'mass:' == 'mass0:' == slot 0 and BuildMassRootPath(0) emits bare 'mass:/'.
  -- Canonicalize to that bare form so the settings sidecar path is identical
  -- across boots and save/load agree (GitHub #494). ONLY slot 0's bare/zero
  -- pair is folded; slot NUMBERS (mass1:, mass2:, ...) are left intact -- they
  -- can be different physical devices (USB vs MX4SIO), told apart downstream by
  -- the ioctl driver name, and must never be merged.
  local rest = string.match(path, "^mass0:(.*)$")
  if rest ~= nil then
    return "mass:"..rest
  end
  return path
end

local function MassSlot0PathAliases(path)
  -- Distinct slot-0 spellings of a path, canonical ('mass:') first, for probing
  -- on load so a .pldrs written under either spelling on a prior boot is found.
  -- Non-mass-slot-0 paths yield just themselves.
  local out = {}
  if type(path) ~= "string" or path == "" then return out end
  local canonical = CanonicalizeMassSlot0(path)
  out[#out + 1] = canonical
  local rest = string.match(canonical, "^mass:(.*)$")
  if rest ~= nil then
    out[#out + 1] = "mass0:"..rest
  end
  return out
end

local function NormalizeHostPath(path)
  if path == nil or path == "" then return path end
  if not string.match(path, "^host:") then
    return path
  end
  local rest = string.sub(path, 6)
  if string.sub(rest, 1, 1) == "/" then
    rest = string.sub(rest, 2)
  end
  rest = string.gsub(rest, "\\", "/")
  if string.match(rest, "^[%a]:[^/]") then
    rest = string.sub(rest, 1, 2).."/"..string.sub(rest, 3)
  end
  return "host:/"..rest
end

local function NormalizeFsPathRaw(path)
  if path == nil then return "" end
  local normalized = string.gsub(path, "\\", "/")
  if string.match(normalized, "^host:") and not string.match(normalized, "^host:/") then
    normalized = "host:/"..string.sub(normalized, 6)
  end
  local prefix = ""
  if string.match(normalized, "^host:/") then
    prefix = "host:/"
    normalized = string.sub(normalized, 7)
  end
  normalized = string.gsub(normalized, "/+", "/")
  return prefix..normalized
end

local function EnsureTrailingSlashNormRaw(path)
  local normalized = NormalizeFsPathRaw(path)
  normalized = string.gsub(normalized, "/+$", "")
  return normalized.."/"
end

local function IsPfsMountedPath(path)
  return string.match(string.lower(tostring(path or "")), "^pfs%d*:/") ~= nil
end

local function IsRawHddPartitionPath(path)
  local candidate = NormalizeFsPathRaw(tostring(path or ""))
  candidate = string.lower(candidate)
  if string.match(candidate, "^hdd%d:[^:]+:[%a]+%d*:/") ~= nil then
    return true
  end
  if string.match(candidate, "^hdd%d:/+[^/]+/.+") ~= nil then
    return true
  end
  return string.match(candidate, "^hdd%d:[^:/]+/.+") ~= nil
end

local function ResolveAppDirLocal()
  local current_dir = EnsureTrailingSlashNormRaw(System.currentDirectory() or "")
  local app_dir = APP_DIR or System.currentDirectory() or ""
  if IsPfsMountedPath(current_dir) and IsRawHddPartitionPath(app_dir) then
    return current_dir
  end
  -- MX4SIO boot: argv0 prefix mx4sio:/ is the BDM device-kind label,
  -- not a writable fileXio mount. etc/boot.lua translates cwd to the
  -- actual mass*:/ slot (identified by sdc/mx4 ioctl driver name --
  -- the same PR #472 rule). When that translation succeeded, prefer
  -- the cwd over the raw mx4sio:/-rooted APP_DIR so the settings
  -- sidecar at APP_DIR/.pldrs and other write paths target the
  -- writable mass*:/ root. Hardware regression 2026-05-28 PM:
  -- "mx4sio:/APPS/PS1_POPSLOADER/.pldrs may be read-only" (Nuno).
  local app_dir_lower = string.lower(app_dir or "")
  if string.match(app_dir_lower, "^mx4sio%d*:") and string.match(current_dir, "^mass%d*:/") then
    return current_dir
  end
  return EnsureTrailingSlashNormRaw(app_dir)
end

local function ResolveAppDirRaw()
  return EnsureTrailingSlashNormRaw(APP_DIR or System.currentDirectory() or "")
end

function NormalizeDirPath(path)
  if path == nil or path == "" then return "" end
  local normalized = NormalizeFsPathRaw(path)
  normalized = NormalizeHostPath(NormalizeDeviceRoot(normalized))
  normalized = string.gsub(normalized, "/+$", "/")
  if string.sub(normalized, -1) ~= "/" then
    normalized = normalized.."/"
  end
  return normalized
end

function JoinPath(base, rel)
  local normalized = NormalizeDirPath(base)
  if rel == nil or rel == "" then
    return normalized
  end
  local cleaned = string.gsub(rel, "^/+", "")
  return normalized..cleaned
end

local APP_DIR_RAW = ResolveAppDirRaw()
local APP_DIR_LOCAL = ResolveAppDirLocal()
APP_DIR_NORM = APP_DIR_LOCAL
local SELECTOR_MODE = "basename"

local function ResolveWritablePath(rel)
  local legacy_root = JoinPath(APP_DIR_LOCAL, "POPSLDR")
  local legacy = JoinPath(legacy_root, rel)
  local modern = JoinPath(APP_DIR_LOCAL, rel)
  if doesFileExist(legacy) or doesFolderExist(legacy_root) then
    return legacy
  end
  return modern
end

local function IsAbsoluteDevicePath(path)
  if path == nil then
    return false
  end
  if string.match(path, "^[%a]+%d*:/") ~= nil then
    return true
  end
  return string.match(path, "^hdd%d:[^:]+:[%a]+%d*:/") ~= nil
end

local function IsMassPath(path)
  return path ~= nil and string.match(path, "^mass%d*:/") ~= nil
end

local HDD_EXEC_INIT_DONE = false
local function EnsureHddRuntimeReadyForExec()
  if HDD_EXEC_INIT_DONE then
    return true
  end
  if type(HDD) ~= "table" then
    return false
  end
  if type(HDD.Initialize) ~= "function" then
    return false
  end
  local ok, initialized = pcall(HDD.Initialize)
  if ok and initialized then
    HDD_EXEC_INIT_DONE = true
    return true
  end
  return false
end

local function ParseHddPartitionMount(path)
  local candidate = tostring(path or "")
  local device, part = string.match(candidate, "^([Hh][Dd][Dd]%d):([^:]+):[%a]+%d*:?/?")
  if device ~= nil and part ~= nil and part ~= "" then
    return string.lower(device)..":"..part
  end
  device, part = string.match(candidate, "^([Hh][Dd][Dd]%d):([^:/]+):$")
  if device ~= nil and part ~= nil and part ~= "" then
    return string.lower(device)..":"..part
  end
  device, part = string.match(candidate, "^([Hh][Dd][Dd]%d):([^:/]+)/")
  if device ~= nil and part ~= nil and part ~= "" then
    return string.lower(device)..":"..part
  end
  device, part = string.match(candidate, "^([Hh][Dd][Dd]%d):/+([^/]+)/")
  if device ~= nil and part ~= nil and part ~= "" then
    return string.lower(device)..":"..part
  end
  device, part = string.match(candidate, "^([Hh][Dd][Dd]%d):([^:/]+)$")
  if device ~= nil and part ~= nil and part ~= "" then
    return string.lower(device)..":"..part
  end
  return nil
end

local function EnsureHddRuntimeReadyForPathAccess()
  if type(PLDR) == "table" and type(PLDR.LoadHDDModules) == "function" then
    pcall(PLDR.LoadHDDModules)
    if type(PLDR.HDD) == "table" and PLDR.HDD.LOADSTATE == 1 and PLDR.HDD.STATUS == 0 then
      return true
    end
  end
  return EnsureHddRuntimeReadyForExec()
end

local HDD_SLOT_BOOT = 0
local HDD_SLOT_GAME = 1
local HDD_SLOT_COMMON = 2
local HDD_SLOT_POPSTARTER = 3

local HDD_MOUNT_STATE = {
  slots = {},
  partitions = {}
}

local function GetBootHddMountSlot()
  local slot = tonumber(rawget(_G, "BOOT_HDD_MOUNT_SLOT"))
  if slot == nil or slot < 0 or slot > 3 then
    return nil
  end
  return slot
end

local function NormalizePfsPrefix(prefix)
  local device = string.match(string.lower(tostring(prefix or "")), "^(pfs%d*):/")
  if device ~= nil then
    return device..":/"
  end
  device = string.match(string.lower(tostring(prefix or "")), "^(pfs%d*):?$")
  if device ~= nil then
    return device..":/"
  end
  return nil
end

local function ParsePfsSlot(prefix)
  local normalized = NormalizePfsPrefix(prefix)
  if normalized == nil then
    return nil
  end
  local slot = string.match(normalized, "^pfs(%d*):/")
  if slot == nil or slot == "" then
    return 0
  end
  return tonumber(slot)
end

local function BuildMountedPfsPrefix(slot)
  if type(slot) ~= "number" then
    return nil
  end
  return "pfs"..tostring(slot)..":/"
end

local function ForgetRecordedHddMountSlot(slot)
  local entry = HDD_MOUNT_STATE.slots[slot]
  if entry == nil then
    return
  end
  if HDD_MOUNT_STATE.partitions[entry.partition] == entry.prefix then
    HDD_MOUNT_STATE.partitions[entry.partition] = nil
  end
  HDD_MOUNT_STATE.slots[slot] = nil
end

local function RememberRecordedHddMount(partition, prefix)
  local normalized_partition = ParseHddPartitionMount(partition)
  local normalized_prefix = NormalizePfsPrefix(prefix)
  local slot = ParsePfsSlot(normalized_prefix)
  if normalized_partition == nil or normalized_prefix == nil or slot == nil then
    return nil
  end
  ForgetRecordedHddMountSlot(slot)
  HDD_MOUNT_STATE.slots[slot] = {
    partition = normalized_partition,
    prefix = normalized_prefix
  }
  HDD_MOUNT_STATE.partitions[normalized_partition] = normalized_prefix
  return normalized_prefix
end

local function SeedBootHddMountState()
  local boot_part = ParseHddPartitionMount(rawget(_G, "BOOT_HDD_MOUNTPART"))
  local boot_slot = GetBootHddMountSlot()
  local boot_prefix = NormalizePfsPrefix(rawget(_G, "BOOT_HDD_MOUNT_PREFIX"))
  if boot_part == nil then
    return nil
  end
  if boot_prefix == nil and boot_slot ~= nil then
    boot_prefix = BuildMountedPfsPrefix(boot_slot)
  end
  if boot_prefix == nil then
    return nil
  end
  return RememberRecordedHddMount(boot_part, boot_prefix)
end

SeedBootHddMountState()

local function GetRecordedHddMountPrefix(partition)
  local normalized_partition = ParseHddPartitionMount(partition)
  if normalized_partition == nil then
    return nil
  end
  return HDD_MOUNT_STATE.partitions[normalized_partition]
end

local function GetDeterministicHddPartitionForSlot(slot)
  local normalized_slot = tonumber(slot)
  if normalized_slot == nil then
    return nil
  end

  local entry = HDD_MOUNT_STATE.slots[normalized_slot]
  if entry ~= nil and type(entry.partition) == "string" and entry.partition ~= "" then
    return ParseHddPartitionMount(entry.partition)
  end

  local boot_part = ParseHddPartitionMount(rawget(_G, "BOOT_HDD_MOUNTPART"))
  local boot_slot = GetBootHddMountSlot()
  if boot_part ~= nil and boot_slot == normalized_slot then
    return boot_part
  end

  local active_slot = tonumber(PLDR and PLDR.HDD and PLDR.HDD.GAME_SLOT or nil)
  if active_slot == normalized_slot then
    local context_candidates = {
      BOOT_ARGV0_RAW,
      BOOT_PATH_RAW,
      APP_DIR_RAW,
      APP_DIR_LOCAL
    }
    for i = 1, #context_candidates do
      local part = ParseHddPartitionMount(context_candidates[i])
      if part ~= nil then
        return part
      end
    end
  end

  return nil
end

local function BuildRawHddExecPathFromMounted(path)
  local candidate = tostring(path or "")
  local prefix = NormalizePfsPrefix(candidate)
  if prefix == nil then
    return nil, "not-mounted-pfs-path"
  end
  local slot = ParsePfsSlot(prefix)
  local relpath = string.gsub(candidate, "^pfs%d*:/", "")
  if relpath == "" then
    return nil, "empty-relative-path"
  end

  local partition = GetDeterministicHddPartitionForSlot(slot)
  if partition == nil then
    return nil, "slot-unknown"
  end
  return partition..":pfs:/"..relpath, nil
end

local function NormalizeHddPartitionLabelForMount(label)
  local candidate = tostring(label or "")
  if candidate == "" then
    return nil
  end
  local already = ParseHddPartitionMount(candidate)
  if already ~= nil then
    return already
  end
  -- HDD game entries from ParseHddGameEntry use bare partition labels (e.g. "__.POPS")
  -- because the prefixed form lives separately in PLDR.HDD.GAMEPARTS. Accept the
  -- bare form by stripping trailing punctuation and prepending the canonical
  -- "hdd0:" prefix before re-parsing.
  if string.match(candidate, "^[Hh][Dd][Dd]%d:") ~= nil then
    return nil
  end
  local stripped = string.gsub(candidate, "[:/]+$", "")
  if stripped == "" then
    return nil
  end
  if string.find(stripped, "[/\\|:]") ~= nil then
    return nil
  end
  if string.match(stripped, "^__") == nil and string.match(stripped, "^%+") == nil then
    return nil
  end
  return ParseHddPartitionMount("hdd0:"..stripped)
end

local function BuildPartitionRecoveryCandidates(extra)
  local candidates = {}
  local seen = {}
  local function push(partition)
    local normalized = NormalizeHddPartitionLabelForMount(partition)
    if normalized ~= nil and seen[normalized] ~= true then
      seen[normalized] = true
      table.insert(candidates, normalized)
    end
  end

  local context_candidates = {
    APP_DIR_RAW,
    APP_DIR_LOCAL,
    BOOT_ARGV0_RAW,
    BOOT_PATH_RAW,
    rawget(_G, "BOOT_HDD_MOUNTPART"),
    rawget(_G, "BOOT_HDD_PARTITION"),
    rawget(_G, "BOOT_PARTITION"),
    PLDR and PLDR.POPS_GAME_PARTITION or nil,
    PLDR and PLDR.GAME_PARTITION or nil,
    PLDR and PLDR.POPSTARTER_PATH or nil
  }

  for i = 1, #context_candidates do
    push(context_candidates[i])
  end

  if type(extra) == "table" then
    for i = 1, #extra do
      push(extra[i])
    end
  elseif type(extra) == "string" then
    push(extra)
  end

  return candidates
end

local function BuildMountedSlotRecoveryCandidates(slot, relpath, recovery_candidates)
  local ordered = {}
  local seen = {}
  local function push(partition)
    local normalized = ParseHddPartitionMount(partition)
    if normalized ~= nil and seen[normalized] ~= true then
      seen[normalized] = true
      table.insert(ordered, normalized)
    end
  end

  if relpath ~= nil and relpath ~= "" then
    local active_label = ParseHddPartitionMount(PLDR and PLDR.POPS_GAME_PARTITION or nil)
    if active_label == nil then
      active_label = ParseHddPartitionMount(PLDR and PLDR.GAME_PARTITION or nil)
    end
    push(active_label)

    local configured_popstarter = ParseHddPartitionMount(PLDR and PLDR.POPSTARTER_PATH or nil)
    push(configured_popstarter)

    push(rawget(_G, "BOOT_HDD_MOUNTPART"))
    push(rawget(_G, "BOOT_HDD_PARTITION"))
    push(rawget(_G, "BOOT_PARTITION"))
  end

  local extra = BuildPartitionRecoveryCandidates(recovery_candidates)
  for i = 1, #extra do
    push(extra[i])
  end
  return ordered
end

local function RecoverHddPartitionFromMountedPath(path, candidates)
  local candidate = tostring(path or "")
  local mounted_prefix = NormalizePfsPrefix(candidate)
  if mounted_prefix == nil then
    return nil, "not-mounted-pfs-path"
  end

  local slot = ParsePfsSlot(mounted_prefix)
  if slot == nil then
    return nil, "slot_unmapped"
  end

  local entry = HDD_MOUNT_STATE.slots[slot]
  if entry ~= nil and entry.partition ~= nil then
    return ParseHddPartitionMount(entry.partition), nil
  end

  local relpath = string.gsub(candidate, "^pfs%d*:/", "")
  if relpath == "" then
    return nil, "mount_probe_failed"
  end

  local recovery_candidates = BuildPartitionRecoveryCandidates(candidates)
  for i = 1, #recovery_candidates do
    local mount_ok, _ = MountHddPartitionTracked(recovery_candidates[i], slot, FIO_MT_RDONLY)
    if mount_ok then
      local probe_path = "pfs"..tostring(slot)..":/"..relpath
      if ProbePathExists(probe_path) then
        return recovery_candidates[i], nil
      end
    end
  end

  return nil, "mount_probe_failed"
end

local function BuildHddPartitionContext(path, recovery_candidates)
  local mount_part = ParseHddPartitionMount(path)
  if mount_part ~= nil then
    return mount_part..":", nil
  end

  local candidate = tostring(path or "")
  if string.match(candidate, "^pfs%d*:/") ~= nil then
    local slot = ParsePfsSlot(candidate)
    if slot == nil then
      return nil, "slot_unmapped"
    end

    local relpath = string.gsub(candidate, "^pfs%d*:/", "")
    if relpath == "" then
      return nil, "slot_relpath_missing"
    end

    local entry = HDD_MOUNT_STATE.slots[slot]
    if entry ~= nil and entry.partition ~= nil then
      return ParseHddPartitionMount(entry.partition)..":", nil
    end

    local candidates = BuildMountedSlotRecoveryCandidates(slot, relpath, recovery_candidates)
    local probe_path = "pfs"..tostring(slot)..":/"..relpath
    local mount_prefix = BuildMountedPfsPrefix(slot)

    for i = 1, #candidates do
      local part = ParseHddPartitionMount(candidates[i])
      local mount_ok, _ = MountHddPartitionTracked(part, slot, FIO_MT_RDONLY)
      if mount_ok and ProbePathExists(probe_path) then
        RememberRecordedHddMount(part, mount_prefix)
        return part..":", nil
      end
    end

    return nil, "slot_recovery_all_candidates_failed"
  end

  local slot = ParsePfsSlot(candidate)
  if slot ~= nil then
    return nil, "slot_unmapped"
  end

  local mounted_part, mounted_reason = RecoverHddPartitionFromMountedPath(path, recovery_candidates)
  if mounted_part ~= nil then
    return mounted_part..":", nil
  end
  if mounted_reason == "slot_unmapped" or mounted_reason == "mount_probe_failed" then
    return nil, mounted_reason
  end
  local raw_hdd, reason = BuildRawHddExecPathFromMounted(path)
  if raw_hdd ~= nil then
    local raw_part = ParseHddPartitionMount(raw_hdd)
    if raw_part ~= nil then
      return raw_part..":", nil
    end
  end
  return nil, reason
end

local function BuildPartitionScopedExecPath(path)
  local candidate = tostring(path or "")
  if candidate == "" then
    return nil
  end
  local relpath = string.gsub(candidate, "^pfs%d*:/", "")
  if relpath ~= candidate and relpath ~= "" then
    return "pfs:/"..relpath
  end
  local mounted_relpath = string.match(candidate, "^[Hh][Dd][Dd]%d:[^:]+:[%a]+%d*:/(.+)$")
  if mounted_relpath == nil then
    mounted_relpath = string.match(candidate, "^[Hh][Dd][Dd]%d:[^:]+:[%a]+%d*:(.+)$")
  end
  if mounted_relpath ~= nil and mounted_relpath ~= "" then
    return "pfs:/"..string.gsub(mounted_relpath, "^/+", "")
  end
  return nil
end

local function BuildPartitionScopedExecInfo(path, authoritative_partition_context)
  local candidate = tostring(path or "")
  local mounted_exec_path = BuildPartitionScopedExecPath(candidate)
  local mounted_source_slot = ParsePfsSlot(candidate)

  if candidate == "" then
    return {
      exec_path = nil,
      source_pfs_slot = nil,
      mounted_exec_path = nil,
      mounted_source_pfs_slot = nil,
      authoritative_partition_context = authoritative_partition_context
    }
  end

  return {
    exec_path = mounted_exec_path,
    source_pfs_slot = mounted_source_slot,
    mounted_exec_path = mounted_exec_path,
    mounted_source_pfs_slot = mounted_source_slot,
    authoritative_partition_context = authoritative_partition_context
  }
end

-- (The profile-preset system -- pops_profiles.lua, PROFILE=/POPSTARTER_MODE=
-- config keys, SELECTED_PROFILE -- was dropped per R3Z3N's review. One value
-- remains: PLDR.POPSTARTER_PATH. Empty = Automatic, i.e. the launch ladder in
-- ResolveLaunchPopstarterPath; non-empty = the user's path, tried first with
-- silent ladder fallback when it doesn't resolve.)

local function NormalizeHddHelperSlot(slot)
  local normalized = tonumber(slot)
  if normalized == nil or normalized < HDD_SLOT_COMMON then
    return HDD_SLOT_COMMON
  end
  return normalized
end

local function GetActiveHddGameSlot()
  local active = tonumber(PLDR and PLDR.HDD and PLDR.HDD.GAME_SLOT or nil)
  if active == HDD_SLOT_BOOT or active == HDD_SLOT_GAME then
    return active
  end
  return HDD_SLOT_GAME
end

local function GetHddGameSlotCandidates()
  -- Default order keeps the historical {GAME=1, BOOT=0} preference.
  local ordered = { HDD_SLOT_GAME, HDD_SLOT_BOOT }
  local active = tonumber(PLDR and PLDR.HDD and PLDR.HDD.GAME_SLOT or nil)
  if active == HDD_SLOT_BOOT then
    ordered = { HDD_SLOT_BOOT, HDD_SLOT_GAME }
  end
  -- Proposal A (root fix for the scan-clobbers-boot-mount bug, Nuno 2026-06-20):
  -- an HDD-resident boot keeps its boot/settings partition mounted on
  -- GetBootHddMountSlot() (pfs1: -- "NEVER USE IT FOR ANYTHING ELSE", boot.lua:48).
  -- Mounting a game partition onto that occupied slot FAILS at the C layer
  -- (luaHDD's warm single-attempt mnt) AND collaterally unmounts the boot
  -- partition, stranding the settings cwd. So never offer the live boot slot to
  -- the game scan; drop it and add HDD_SLOT_COMMON (a slot the scan never
  -- otherwise uses) as the off-boot fallback. On a non-HDD boot
  -- GetBootHddMountSlot() is nil -> return the full historical list UNCHANGED so
  -- the scan still fires (do NOT repeat the reverted bec5e90 firing gate).
  -- See memory reference-hdd-pfs-slot-model. NOT hardware-tested -- Nuno to verify
  -- game partitions still mount/list when forced off the boot slot.
  local boot_slot = nil
  if type(GetBootHddMountSlot) == "function" then boot_slot = GetBootHddMountSlot() end
  if boot_slot == nil then
    return ordered
  end
  local candidates = {}
  local seen = {}
  for i = 1, #ordered do
    local slot = ordered[i]
    if slot ~= boot_slot and not seen[slot] then
      candidates[#candidates + 1] = slot
      seen[slot] = true
    end
  end
  if not seen[HDD_SLOT_COMMON] and HDD_SLOT_COMMON ~= boot_slot then
    candidates[#candidates + 1] = HDD_SLOT_COMMON
  end
  return candidates
end

local function MountHddPartitionTracked(partition, slot, mode)
  local normalized_partition = ParseHddPartitionMount(partition)
  if normalized_partition == nil then
    return false, nil
  end
  if not EnsureHddRuntimeReadyForPathAccess() then
    return false, nil
  end
  if type(HDD) ~= "table" or type(HDD.MountPartition) ~= "function" then
    return false, nil
  end
  local mount_slot = tonumber(slot)
  if mount_slot == nil then
    return false, nil
  end
  local mount_mode = mode
  if type(mount_mode) ~= "number" then
    mount_mode = FIO_MT_RDONLY
    if type(mount_mode) ~= "number" then
      mount_mode = 0
    end
  end
  local ok, mounted, mount_rc = pcall(HDD.MountPartition, normalized_partition, mount_slot, mount_mode)
  if ok and mounted == true then
    local prefix = BuildMountedPfsPrefix(mount_slot)
    local recorded = RememberRecordedHddMount(normalized_partition, prefix)
    if recorded == nil then
      -- Mounted on the IOP but un-trackable (partition/prefix parse edge case).
      -- Don't leak the slot: unmount + report a clean failure so no caller is
      -- left holding a live pfs mount it never learns the slot to release.
      if type(HDD.UMountPartition) == "function" then pcall(HDD.UMountPartition, mount_slot) end
      return false, nil
    end
    return true, recorded
  end
  -- Third return = raw fileXioMount rc (when the mount was actually attempted)
  -- so scan callers can report WHY the HDD list came up empty, not just that it did.
  if ok then
    return false, nil, tonumber(mount_rc)
  end
  return false, nil
end

local function UMountHddPartitionTracked(slot)
  if type(HDD) ~= "table" or type(HDD.UMountPartition) ~= "function" then
    return false, nil
  end
  local ok, ret = pcall(HDD.UMountPartition, slot)
  if ok and (ret == 0 or ret == true) then
    ForgetRecordedHddMountSlot(slot)
  end
  return ok, ret
end

local function ParseHddExecMountAndRelpath(path)
  local candidate = tostring(path or "")
  local device, part, relpath = string.match(candidate, "^([Hh][Dd][Dd]%d):([^:]+):[%a]+%d*:/(.+)$")
  if device ~= nil and part ~= nil and relpath ~= nil and relpath ~= "" then
    return string.lower(device)..":"..part, relpath
  end
  device, part, relpath = string.match(candidate, "^([Hh][Dd][Dd]%d):([^:]+):[%a]+%d*:(.+)$")
  if device ~= nil and part ~= nil and relpath ~= nil and relpath ~= "" then
    relpath = string.gsub(relpath, "^/+", "")
    return string.lower(device)..":"..part, relpath
  end
  local mount_part
  mount_part, relpath = string.match(candidate, "^([Hh][Dd][Dd]%d:[^:]+):[%a]+%d*:/(.+)$")
  if mount_part ~= nil and relpath ~= nil and relpath ~= "" then
    local normalized_mount = string.lower(string.match(mount_part, "^([Hh][Dd][Dd]%d):"))..":"..string.match(mount_part, "^[Hh][Dd][Dd]%d:(.+)$")
    return normalized_mount, relpath
  end
  local rel
  device, part, rel = string.match(candidate, "^([Hh][Dd][Dd]%d):/+([^/]+)/(.+)$")
  if device ~= nil and part ~= nil and rel ~= nil and rel ~= "" then
    return string.lower(device)..":"..part, rel
  end
  device, part, rel = string.match(candidate, "^([Hh][Dd][Dd]%d):([^:/]+)/(.+)$")
  if device ~= nil and part ~= nil and rel ~= nil and rel ~= "" then
    return string.lower(device)..":"..part, rel
  end
  return nil, nil
end

local function BuildMountedReadablePath(prefix, relpath)
  local normalized_prefix = NormalizePfsPrefix(prefix)
  local clean_rel = string.gsub(tostring(relpath or ""), "^/+", "")
  if normalized_prefix == nil or clean_rel == "" then
    return nil
  end
  return normalized_prefix..clean_rel
end

local function ExtractEmbeddedHddMountPrefix(path)
  local candidate = tostring(path or "")
  local pfs_device = string.match(candidate, "^[Hh][Dd][Dd]%d:[^:]+:([Pp][Ff][Ss]%d*):")
  return NormalizePfsPrefix(pfs_device)
end

local ProbePathExists

local function ResolveHddPartitionReadablePath(partition, relpath, mounted_prefix_hint, slot)
  local mount_part = ParseHddPartitionMount(partition)
  local clean_relpath = string.gsub(tostring(relpath or ""), "^/+", "")
  if mount_part == nil or clean_relpath == "" then
    return nil
  end

  local mount_slot = NormalizeHddHelperSlot(slot)
  local embedded_prefix = NormalizePfsPrefix(mounted_prefix_hint)
  if embedded_prefix ~= nil then
    local embedded_target = BuildMountedReadablePath(embedded_prefix, clean_relpath)
    if embedded_target ~= nil and ProbePathExists(embedded_target) then
      RememberRecordedHddMount(mount_part, embedded_prefix)
      return embedded_target
    end
  end

  local recorded_prefix = GetRecordedHddMountPrefix(mount_part)
  if recorded_prefix ~= nil then
    local recorded_target = BuildMountedReadablePath(recorded_prefix, clean_relpath)
    if recorded_target ~= nil and ProbePathExists(recorded_target) then
      return recorded_target
    end
  end

  local mounted, mounted_prefix = MountHddPartitionTracked(mount_part, mount_slot, FIO_MT_RDONLY)
  if not mounted or mounted_prefix == nil then
    return nil
  end

  local mounted_target = BuildMountedReadablePath(mounted_prefix, clean_relpath)
  if mounted_target ~= nil and ProbePathExists(mounted_target) then
    return mounted_target
  end
  return nil
end

local function MountHddGamePartitionTracked(partition, mode)
  local normalized_partition = ParseHddPartitionMount(partition)
  if normalized_partition == nil then
    return false, nil, nil
  end
  local candidates = GetHddGameSlotCandidates()
  local last_rc = nil
  for i = 1, #candidates do
    local slot = candidates[i]
    local mounted, prefix, mount_rc = MountHddPartitionTracked(normalized_partition, slot, mode)
    if mounted and prefix ~= nil then
      if type(PLDR) == "table" and type(PLDR.HDD) == "table" then
        PLDR.HDD.GAME_SLOT = slot
      end
      return true, prefix, slot
    end
    if mount_rc ~= nil then last_rc = mount_rc end
  end
  return false, nil, nil, last_rc
end

local function ResolveHddGamePartitionReadablePath(partition, relpath)
  local mount_part = ParseHddPartitionMount(partition)
  local clean_relpath = string.gsub(tostring(relpath or ""), "^/+", "")
  if mount_part == nil or clean_relpath == "" then
    return nil
  end

  local recorded_prefix = GetRecordedHddMountPrefix(mount_part)
  if recorded_prefix ~= nil then
    local recorded_target = BuildMountedReadablePath(recorded_prefix, clean_relpath)
    if recorded_target ~= nil and ProbePathExists(recorded_target) then
      return recorded_target
    end
  end

  local mounted, mounted_prefix = MountHddGamePartitionTracked(mount_part, FIO_MT_RDONLY)
  if not mounted or mounted_prefix == nil then
    return nil
  end

  local mounted_target = BuildMountedReadablePath(mounted_prefix, clean_relpath)
  if mounted_target ~= nil and ProbePathExists(mounted_target) then
    return mounted_target
  end
  return nil
end

-- HDD-write probe (diagnostic, TEST): on an HDD boot, try a SCOPED read-write to
-- a __.POPS game partition -- mount RW, write+verify+delete a tiny test file,
-- unmount. Answers whether the bundled ps2hdd-osd driver can write a __.POPS GAME
-- partition (used for HDD per-game .hide markers via WriteGamePartitionFile).
-- NOTE: settings/.hide/cache now save to the HDD BOOT partition via
-- EnsureBootPartitionWritable's RW take-over -- the pre-#466 "save to mc0:" model
-- is SUPERSEDED. Real settings are unaffected; this only reports a game-partition
-- diagnostic toast. Returns: nil = not an HDD boot (skip);
-- true,<partition> = writable; false,<reason> = not.
function PLDR.ProbeHddSettingsWrite()
  -- Fire whenever the HDD is loaded + usable, NOT only on an HDD boot -- so it
  -- also reports for a NON-HDD boot whose HDD page loaded (e.g. an MC/USB boot;
  -- the old GetBootHddMountSlot gate skipped exactly Nuno/provato's case). The
  -- probe writes to a __.POPS GAME partition (never the boot mount), so it's safe
  -- regardless of boot source. nil = HDD not loaded/usable (skip, no toast).
  if type(PLDR.HDD) ~= "table" or PLDR.HDD.LOADSTATE ~= 1 then return nil end
  if type(HDD) ~= "table" then return false, "HDD modules not loaded" end
  local parts = { "__.POPS", "__.POPS0", "__.POPS1", "__.POPS2", "__.POPS3",
                  "__.POPS4", "__.POPS5", "__.POPS6", "__.POPS7", "__.POPS8", "__.POPS9" }
  local mounted_any = false
  for i = 1, #parts do
    local mounted, prefix, slot = MountHddGamePartitionTracked("hdd0:"..parts[i], FIO_MT_RDWR)
    if mounted and prefix ~= nil then
      mounted_any = true
      local probe_path = BuildMountedReadablePath(prefix, "pldrs_wtest.tmp")
      local wrote = false
      if probe_path ~= nil then
        local ok_open, fd = pcall(System.openFile, probe_path, FCREATE)
        if ok_open and fd ~= nil and not (type(fd) == "number" and fd < 0) then
          local okw, wn = pcall(System.writeFile, fd, "ok", 2)
          pcall(System.closeFile, fd)
          wrote = (okw and type(wn) == "number" and wn == 2 and doesFileExist(probe_path) == true)
          pcall(System.removeFile, probe_path)
        end
      end
      if slot ~= nil then UMountHddPartitionTracked(slot) end
      if wrote then return true, parts[i] end
      -- this partition mounted but rejected the write; try the next present one
    end
  end
  if mounted_any then return false, "partition(s) mounted, but none accepted a write" end
  return false, "no __.POPS partition could be mounted"
end

-- NOTE: PLDR.HDD.WriteGamePartitionFile and PLDR.HDD.EnsureBootPartitionWritable
-- used to be defined HERE, but PLDR.HDD does not exist yet at this point in the
-- chunk -- it is created by the pldr_defaults merge much further down -- so
-- `function PLDR.HDD.X` here indexed a nil value and bricked the boot
-- ("attempt to index a nil value (field 'HDD')"). They are now defined right
-- after the PLDR.HDD init block (search for "WriteGamePartitionFile").

local function ResolveHddReadablePath(path)
  local candidate = tostring(path or "")
  if candidate == "" then
    return nil
  end

  local mounted_direct = NormalizePfsPrefix(candidate)
  if mounted_direct ~= nil and ProbePathExists(candidate) then
    return candidate
  end

  local mount_part, relpath = ParseHddExecMountAndRelpath(candidate)
  if mount_part == nil or relpath == nil then
    return nil
  end

  return ResolveHddPartitionReadablePath(mount_part, relpath, ExtractEmbeddedHddMountPrefix(candidate), HDD_SLOT_POPSTARTER)
end

local function ResolveHddExecMountedPath(path)
  return ResolveHddReadablePath(path)
end

local function ExtractLaunchPfsSlot(path)
  local mounted_prefix = NormalizePfsPrefix(path)
  if mounted_prefix ~= nil then
    return ParsePfsSlot(mounted_prefix)
  end
  local embedded_prefix = ExtractEmbeddedHddMountPrefix(path)
  if embedded_prefix ~= nil then
    return ParsePfsSlot(embedded_prefix)
  end
  return nil
end

local function CollectHddKeepSlots(path, extra_keep_slots)
  local keep = {}
  local slot = ExtractLaunchPfsSlot(path)

  if slot == nil then
    local resolved = ResolveHddReadablePath(path)
    if resolved ~= nil then
      slot = ExtractLaunchPfsSlot(resolved)
    end
  end

  if slot ~= nil then
    keep[slot] = true
  end
  if type(extra_keep_slots) == "table" then
    for i = 1, #extra_keep_slots do
      local extra_slot = tonumber(extra_keep_slots[i])
      if extra_slot ~= nil then
        keep[extra_slot] = true
      end
    end
  elseif extra_keep_slots ~= nil then
    local extra_slot = tonumber(extra_keep_slots)
    if extra_slot ~= nil then
      keep[extra_slot] = true
    end
  end
  return keep
end

local function PreserveBootPfsSlotsDuringElfLoad(path, keep_slots)
  local boot_candidates = {
    BOOT_ARGV0_RAW,
    BOOT_PATH_RAW,
    APP_DIR_LOCAL
  }
  for i = 1, #boot_candidates do
    local candidate = boot_candidates[i]
    if candidate ~= nil and candidate ~= "" then
      local boot_slot = ExtractLaunchPfsSlot(candidate)
      if boot_slot == nil then
        local resolved = ResolveHddReadablePath(candidate)
        if resolved ~= nil then
          boot_slot = ExtractLaunchPfsSlot(resolved)
        end
      end
      if boot_slot ~= nil then
        keep_slots[boot_slot] = true
      end
    end
  end
  return keep_slots
end

local function BuildPfsKeepMask(keep_slots)
  local mask = 0
  if type(keep_slots) ~= "table" then
    return mask
  end
  for slot = 0, 3 do
    if keep_slots[slot] == true then
      mask = mask + (2 ^ slot)
    end
  end
  return mask
end

local function PrepareForExternalELFLaunch(path, extra_keep_slots, keep_slots_after_load, forced_keep_slot)
  local keep_slots = CollectHddKeepSlots(path, extra_keep_slots)
  local forced_slot = tonumber(forced_keep_slot)
  if forced_slot ~= nil and forced_slot >= 0 and forced_slot <= 3 then
    keep_slots[forced_slot] = true
  end
  local lowered_path = string.lower(tostring(path or ""))
  local is_hdd_exec_context = string.match(lowered_path, "^hdd%d:") ~= nil or string.match(lowered_path, "^pfs%d*:/") ~= nil
  if not is_hdd_exec_context then
    keep_slots = PreserveBootPfsSlotsDuringElfLoad(path, keep_slots)
  end
  local postload_keep_slots = keep_slots_after_load
  if type(postload_keep_slots) ~= "table" then
    postload_keep_slots = keep_slots
  elseif forced_slot ~= nil and forced_slot >= 0 and forced_slot <= 3 then
    postload_keep_slots[forced_slot] = true
  end
  if type(System) == "table" and type(System.setExecKeepPfsMask) == "function" then
    pcall(System.setExecKeepPfsMask, BuildPfsKeepMask(postload_keep_slots))
  end
  if type(HDD) ~= "table" or type(HDD.UMountPartition) ~= "function" then
    return
  end
  for slot = 0, 3 do
    if keep_slots[slot] ~= true then
      UMountHddPartitionTracked(slot)
    end
  end
end

local function PrepareForColdExternalELFLaunch()
  if type(System) == "table" and type(System.setExecKeepPfsMask) == "function" then
    pcall(System.setExecKeepPfsMask, 0)
  end
  if type(HDD) ~= "table" or type(HDD.UMountPartition) ~= "function" then
    return
  end
  for slot = 0, 3 do
    UMountHddPartitionTracked(slot)
  end
end

local function AppendUniquePath(out, seen, path)
  local candidate = tostring(path or "")
  if candidate == "" then
    return
  end
  if seen[candidate] == true then
    return
  end
  seen[candidate] = true
  table.insert(out, candidate)
end

local function ExpandHddExecAliases(path)
  local candidate = tostring(path or "")
  local out = {}

  local mount_part, relpath = ParseHddExecMountAndRelpath(candidate)
  if mount_part ~= nil and relpath ~= nil then
    local embedded_prefix = ExtractEmbeddedHddMountPrefix(candidate)
    if embedded_prefix ~= nil then
      local mounted_path = BuildMountedReadablePath(embedded_prefix, relpath)
      if mounted_path ~= nil then
        table.insert(out, mounted_path)
      end
    end
  end
  return out
end

local function ExpandPathCandidates(path)
  local expanded = {}
  local seen = {}
  local base = PLDR.ExpandMcAlias(path)
  for i = 1, #base do
    local candidate = base[i]
    AppendUniquePath(expanded, seen, candidate)
    local hdd_aliases = ExpandHddExecAliases(candidate)
    for j = 1, #hdd_aliases do
      AppendUniquePath(expanded, seen, hdd_aliases[j])
    end
  end
  return expanded
end

function PLDR.EnsureMmceReadyOnce()
  if PLDR._mmce_ready then
    return true
  end

  -- NO MMCE<->MX4SIO gate (maintainer, 2026-07-21): official OPL runs both
  -- drivers resident together in the field on the same freesio2 bus manager
  -- we now carry (EXP31). See the matching note in EnsureMassBackendsReady's
  -- mx4sio branch for the recorded R3Z3N tradeoff.

  -- Layer C lazy load: mmceman.irx is only loaded eagerly when boot
  -- device is MMCE (see src/main.cpp). For USB / MC / MX4SIO / HDD
  -- (any of hdd*, pfs*, ata*, apa*) boots, the IRX is deferred and
  -- must be loaded here before any mmce%d:/ accessor will work.
  -- MMCE (third-party memory card adapters like MemoryCard Pro) is a
  -- distinct device from standard PS2 MC -- MC uses mc%d:/ paths and
  -- the always-loaded mcman/mcserv IRX stack, not mmceman.
  -- System.ensureMmceman() is idempotent: no-op if already loaded.
  if type(System) == "table" and type(System.ensureMmceman) == "function" then
    pcall(System.ensureMmceman)
  end

  -- mmceman shares the SIO2 bus with the controller. Loading it on demand
  -- here (after padman already opened the pad at boot) can disrupt the pad's
  -- in-flight transfer and silently kill input on the MMCE list. Re-open the
  -- pad port now that mmceman is up so buttons keep working. Idempotent and
  -- only reached on the MMCE-page path, so it has no effect on other devices.
  if type(System) == "table" and type(System.reinitPad) == "function" then
    pcall(System.reinitPad)
  end

  PLDR._mmce_ready = true
  return true
end

function PLDR.ExpandMcAlias(path)
  local candidate = tostring(path or "")
  if candidate == "" then
    return {}
  end
  if string.match(candidate, "^mc%?:/") then
    local suffix = string.sub(candidate, 6)
    return {
      "mc0:/"..suffix,
      "mc1:/"..suffix
    }
  end
  return {candidate}
end

ProbePathExists = function(p)
  local candidate = tostring(p or "")
  if candidate == "" then
    return false
  end
  local ok, fd_or_err = pcall(System.openFile, candidate, FREAD)
  if ok and type(fd_or_err) == "number" and fd_or_err >= 0 then
    System.closeFile(fd_or_err)
    return true
  end
  local exists_ok, exists = pcall(doesFileExist, candidate)
  return exists_ok and exists == true
end

function PLDR.ResolveFirstExistingPath(path)
  local candidates = ExpandPathCandidates(path)
  for i = 1, #candidates do
    local candidate = candidates[i]
    if ProbePathExists(candidate) then
      return candidate
    end
  end
  return nil
end

local function ResolvePathWithEnsure(path)
  local candidates = ExpandPathCandidates(path)
  for i = 1, #candidates do
    local candidate = candidates[i]
    local low = string.lower(candidate)
    local is_mass = low:find("^mass") ~= nil
    local is_mmce = low:find("^mmce") ~= nil
    for pass = 1, 2 do
      if ProbePathExists(candidate) then
        return candidate
      end
      if pass == 1 then
        if is_mass then
          if type(PLDR) == "table" and type(PLDR.EnsureUsbMassReadyOnce) == "function" then
            pcall(PLDR.EnsureUsbMassReadyOnce)
          end
        elseif is_mmce then
          if type(PLDR) == "table" and type(PLDR.EnsureMmceReadyOnce) == "function" then
            pcall(PLDR.EnsureMmceReadyOnce)
          end
        end
      end
    end
  end
  return nil
end

function PLDR.PopstarterProbeWithEnsure(path)
  return ResolvePathWithEnsure(path) ~= nil
end

local function IsHddExecContextPath(path)
  local candidate = string.lower(tostring(path or ""))
  if candidate == "" then
    return false
  end
  if string.match(candidate, "^hdd%d:") ~= nil then
    return true
  end
  return string.match(candidate, "^pfs%d*:/") ~= nil
end

local function DirectoryFromExecPath(path)
  local candidate = tostring(path or "")
  if candidate == "" then
    return nil
  end
  candidate = NormalizeFsPathRaw(candidate)
  if string.sub(candidate, -1) == "/" then
    return EnsureTrailingSlashNormRaw(candidate)
  end
  local dirname = string.match(candidate, "^(.*)/[^/]+$")
  if dirname ~= nil and dirname ~= "" then
    return EnsureTrailingSlashNormRaw(dirname)
  end
  local device = string.match(candidate, "^([%a]+%d*):")
  if device ~= nil then
    return device..":/"
  end
  return nil
end

local function CaptureCurrentDirectory()
  if type(System) ~= "table" or type(System.currentDirectory) ~= "function" then
    return nil
  end
  local ok, cwd = pcall(System.currentDirectory)
  if ok and type(cwd) == "string" and cwd ~= "" then
    return EnsureTrailingSlashNormRaw(cwd)
  end
  return nil
end

local function BuildPopstarterSidecarCandidate(base_path)
  local basedir = DirectoryFromExecPath(base_path)
  if basedir == nil or basedir == "" then
    return nil
  end
  return JoinPath(basedir, "POPSTARTER.ELF")
end

local function SetLaunchWorkingDirectory(path)
  local previous_cwd = CaptureCurrentDirectory()
  local launch_dir = DirectoryFromExecPath(path)
  if launch_dir == nil or launch_dir == "" then
    return previous_cwd
  end
  local normalized_launch_dir = EnsureTrailingSlashNormRaw(launch_dir)
  if previous_cwd == normalized_launch_dir then
    return previous_cwd
  end
  if type(System) == "table" and type(System.currentDirectory) == "function" then
    pcall(System.currentDirectory, normalized_launch_dir)
  end
  return previous_cwd
end

local function RestoreWorkingDirectory(path)
  local previous_cwd = tostring(path or "")
  if previous_cwd == "" then
    return
  end
  if type(System) == "table" and type(System.currentDirectory) == "function" then
    pcall(System.currentDirectory, previous_cwd)
  end
end

local function CollectHddBootSidecarCandidates()
  local mounted_candidates = {}
  local hdd_candidates = {}
  local other_candidates = {}
  local seen = {}
  local function add_candidate(base_path)
    local sidecar = BuildPopstarterSidecarCandidate(base_path)
    if sidecar == nil or sidecar == "" then
      return
    end
    if seen[sidecar] == true then
      return
    end
    seen[sidecar] = true
    local lowered = string.lower(sidecar)
    if string.match(lowered, "^pfs%d*:/") ~= nil then
      table.insert(mounted_candidates, sidecar)
    elseif string.match(lowered, "^hdd%d:") ~= nil then
      table.insert(hdd_candidates, sidecar)
    else
      table.insert(other_candidates, sidecar)
    end
  end

  add_candidate(BOOT_ARGV0_RAW)
  add_candidate(BOOT_PATH_RAW)
  add_candidate(CaptureCurrentDirectory())
  add_candidate(APP_DIR_RAW)
  add_candidate(APP_DIR_LOCAL)

  return mounted_candidates, hdd_candidates, other_candidates
end

local function ResolveHddBootSidecarPopstarter()
  local mounted_candidates, hdd_candidates, other_candidates = CollectHddBootSidecarCandidates()

  for i = 1, #mounted_candidates do
    local mounted_candidate = mounted_candidates[i]
    if ProbePathExists(mounted_candidate) then
      return mounted_candidate
    end
    local raw_hdd = select(1, BuildRawHddExecPathFromMounted(mounted_candidate))
    if raw_hdd ~= nil then
      local resolved_hdd = ResolveHddReadablePath(raw_hdd)
      if resolved_hdd ~= nil then
        return resolved_hdd
      end
    end
  end

  for i = 1, #hdd_candidates do
    local resolved_hdd = ResolveHddReadablePath(hdd_candidates[i])
    if resolved_hdd ~= nil then
      return resolved_hdd
    end
  end

  for i = 1, #other_candidates do
    local mounted_candidate = ResolveHddReadablePath(other_candidates[i])
    if mounted_candidate ~= nil then
      return mounted_candidate
    end
    if ProbePathExists(other_candidates[i]) then
      return other_candidates[i]
    end
  end

  local all_candidates = {}
  for i = 1, #hdd_candidates do
    table.insert(all_candidates, hdd_candidates[i])
  end
  for i = 1, #other_candidates do
    table.insert(all_candidates, other_candidates[i])
  end

  for i = 1, #all_candidates do
    local resolved = ResolvePathWithEnsure(all_candidates[i])
    if resolved ~= nil then
      return resolved
    end
  end
  return nil
end

local function ResolveHddBootSidecarSourceContext()
  local mounted_candidates, hdd_candidates = CollectHddBootSidecarCandidates()

  for i = 1, #hdd_candidates do
    if ResolveHddReadablePath(hdd_candidates[i]) ~= nil then
      return select(1, BuildHddPartitionContext(hdd_candidates[i]))
    end
  end

  for i = 1, #mounted_candidates do
    local mounted = mounted_candidates[i]
    local raw_hdd = select(1, BuildRawHddExecPathFromMounted(mounted))
    if raw_hdd ~= nil and (ProbePathExists(mounted) or ResolveHddReadablePath(raw_hdd) ~= nil) then
      return select(1, BuildHddPartitionContext(raw_hdd))
    end
  end

  return nil
end

local function IsExplicitAbsoluteCustomPopstarterPath(path)
  local candidate = string.lower(NormalizeFsPathRaw(tostring(path or "")))
  if candidate == "" then
    return false
  end
  if string.match(candidate, "^mc[01]:/") ~= nil then
    return true
  end
  if string.match(candidate, "^mass%d*:/") ~= nil then
    return true
  end
  if string.match(candidate, "^hdd%d:/") ~= nil then
    return true
  end
  return string.match(candidate, "^hdd%d:[^:]+:[%a]+%d*:/") ~= nil
end

local function IsDefaultRelativePopstarterPath(path)
  if IsExplicitAbsoluteCustomPopstarterPath(path) or IsAbsoluteDevicePath(path) then
    return false
  end
  local candidate = string.lower(string.gsub(tostring(path or ""), "\\", "/"))
  candidate = string.gsub(candidate, "^%./", "")
  return candidate == "" or candidate == "popstarter.elf"
end

local function IsLegacyDefaultPopstarterPath(path)
  if IsExplicitAbsoluteCustomPopstarterPath(path) or IsAbsoluteDevicePath(path) then
    return false
  end
  local candidate = string.lower(NormalizeFsPathRaw(tostring(path or "")))
  return string.match(candidate, "^mass%d*:/pops/popstarter%.elf$") ~= nil
end

local function ResolveMx4sioMassAliasPath(path)
  local candidate = tostring(path or "")
  local relpath = string.match(candidate, "^[Mm][Xx]4[Ss][Ii][Oo]%d*:/(.+)$")
  if relpath == nil or relpath == "" then
    return path
  end

  local root = nil
  if type(PLDR) == "table" and type(PLDR.GetMX4SIOMassRootNow) == "function" then
    root = PLDR.GetMX4SIOMassRootNow()
  end
  if (type(root) ~= "string" or root == "") and type(PLDR) == "table" and type(PLDR.MX4SIO) == "table" then
    root = tostring(PLDR.MX4SIO.ROOT or "")
  end
  if type(root) ~= "string" or root == "" then
    return path
  end

  return EnsureTrailingSlash(root)..relpath
end

local function ResolvePopstarterPath(path)
  local raw_path = tostring(path or "")
  local can_sidecar_fallback = (raw_path == "" or not IsAbsoluteDevicePath(raw_path))
  if can_sidecar_fallback and (IsDefaultRelativePopstarterPath(raw_path) or IsLegacyDefaultPopstarterPath(raw_path)) then
    local sidecar = ResolveHddBootSidecarPopstarter()
    if sidecar ~= nil then
      return sidecar
    end
  end

  local chosen = path
  if chosen == nil or chosen == "" then
    chosen = JoinPath(APP_DIR_LOCAL, "POPSTARTER.ELF")
  elseif not IsAbsoluteDevicePath(chosen) then
    chosen = JoinPath(APP_DIR_LOCAL, chosen)
  end
  chosen = ResolveMx4sioMassAliasPath(chosen)

  if string.match(string.lower(chosen), "^hdd%d:") ~= nil then
    local resolved_hdd = ResolveHddExecMountedPath(chosen)
    if resolved_hdd ~= nil then
      return resolved_hdd
    end
  end
  local resolved = ResolvePathWithEnsure(chosen)
  if resolved ~= nil then
    return resolved
  end

  if IsAbsoluteDevicePath(raw_path) then
    return chosen
  end

  local fallbacks = {}
  local seen_fallbacks = {}
  local function add_fallback(path)
    AppendUniquePath(fallbacks, seen_fallbacks, path)
  end
  add_fallback(BuildPopstarterSidecarCandidate(APP_DIR_LOCAL))
  add_fallback(BuildPopstarterSidecarCandidate(CaptureCurrentDirectory()))
  add_fallback(BuildPopstarterSidecarCandidate(BOOT_ARGV0_RAW))
  add_fallback(BuildPopstarterSidecarCandidate(BOOT_PATH_RAW))
  add_fallback(BuildPopstarterSidecarCandidate(APP_DIR_RAW))
  add_fallback("mc0:/POPSTARTER/POPSTARTER.ELF")
  add_fallback("mc1:/POPSTARTER/POPSTARTER.ELF")
  for i = 1, #fallbacks do
    local candidate = fallbacks[i]
    local resolved_fallback = nil
    if string.match(string.lower(candidate), "^hdd%d:") ~= nil then
      resolved_fallback = ResolveHddReadablePath(candidate)
    end
    if resolved_fallback == nil then
      resolved_fallback = ResolvePathWithEnsure(candidate)
    end
    if candidate ~= chosen and resolved_fallback ~= nil then
      return resolved_fallback
    end
  end

  return chosen
end

local function ResolvePopstarterPartitionContext(path, resolved_path, preferred_partition_label)
  local configured = tostring(path or "")
  local can_sidecar_source_fallback = (configured == "" or not IsAbsoluteDevicePath(configured)) and not IsExplicitAbsoluteCustomPopstarterPath(configured)
  if can_sidecar_source_fallback and (IsDefaultRelativePopstarterPath(configured) or IsLegacyDefaultPopstarterPath(configured)) then
    local sidecar_source = ResolveHddBootSidecarSourceContext()
    if sidecar_source ~= nil then
      return sidecar_source
    end
  end

  local recovery_candidates = BuildPartitionRecoveryCandidates({
    preferred_partition_label,
    PLDR and PLDR.POPS_GAME_PARTITION or nil,
    PLDR and PLDR.GAME_PARTITION or nil,
    configured,
    resolved_path,
    rawget(_G, "BOOT_HDD_MOUNTPART"),
    rawget(_G, "BOOT_HDD_PARTITION"),
    rawget(_G, "BOOT_PARTITION")
  })

  if IsHddExecContextPath(configured) then
    local part, _ = BuildHddPartitionContext(configured, recovery_candidates)
    return part
  end

  if IsHddExecContextPath(resolved_path) then
    local part, _ = BuildHddPartitionContext(resolved_path, recovery_candidates)
    return part
  end

  return nil
end

local function BuildMountedExecProbePath(exec_path, mounted_prefix)
  local candidate = tostring(exec_path or "")
  local relpath = string.match(candidate, "^pfs%d*:/(.+)$")
  if relpath == nil or relpath == "" then
    relpath = select(2, ParseHddExecMountAndRelpath(candidate))
  end
  if relpath == nil or relpath == "" then
    return candidate
  end

  local mounted_candidate = BuildMountedReadablePath(mounted_prefix, relpath)
  if mounted_candidate ~= nil then
    return mounted_candidate
  end
  return candidate
end

local function ValidateHddPopstarterExecGate(exec_path, partition_context, source_pfs_slot)
  local target_exec_path = tostring(exec_path or "")
  if target_exec_path == "" then
    return false, "POPSTARTER executable path is empty"
  end

  local normalized_target = string.lower(target_exec_path)
  if string.match(normalized_target, "^hdd%d:") == nil and string.match(normalized_target, "^pfs%d*:/") == nil then
    return true, nil
  end

  local normalized_partition = ParseHddPartitionMount(partition_context)
  local partition_reason = nil
  if normalized_partition == nil then
    normalized_partition = ParseHddPartitionMount(target_exec_path)
  end
  if normalized_partition == nil then
    local raw_hdd, raw_reason = BuildRawHddExecPathFromMounted(target_exec_path)
    normalized_partition = ParseHddPartitionMount(raw_hdd)
    partition_reason = raw_reason
  end

  local target_slot = ParsePfsSlot(target_exec_path)
  if normalized_partition == nil and target_slot ~= nil then
    local recovered_partition = GetDeterministicHddPartitionForSlot(target_slot)
    if recovered_partition ~= nil then
      local mount_ok, prefix = MountHddPartitionTracked(recovered_partition, target_slot, FIO_MT_RDONLY)
      if mount_ok and prefix ~= nil then
        normalized_partition = recovered_partition
        partition_reason = nil
      else
        return false, "Cannot mount HDD partition required by POPSTARTER (slot pfs"..tostring(target_slot).." mount failed)"
      end
    end
  end

  if normalized_partition == nil then
    if partition_reason == "slot-unknown" then
      return false, "Cannot resolve HDD partition context for POPSTARTER (slot unknown, source_pfs_slot="..tostring(source_pfs_slot)..")"
    end
    return false, "Cannot resolve HDD partition context for POPSTARTER (source_pfs_slot="..tostring(source_pfs_slot)..")"
  end

  local mounted_prefix = GetRecordedHddMountPrefix(normalized_partition)
  if mounted_prefix == nil then
    local mount_slot = HDD_SLOT_POPSTARTER
    if target_slot ~= nil then
      mount_slot = target_slot
    end
    local mount_ok, prefix = MountHddPartitionTracked(normalized_partition, mount_slot, FIO_MT_RDONLY)
    if not mount_ok or prefix == nil then
      return false, "Cannot mount HDD partition required by POPSTARTER"
    end
    mounted_prefix = prefix
  end

  local mounted_probe_path = BuildMountedExecProbePath(target_exec_path, mounted_prefix)
  if not doesFileExist(mounted_probe_path) then
    return false, "POPSTARTER is not accessible using exec path: "..mounted_probe_path
  end

  local partition_scoped = BuildPartitionScopedExecPath(target_exec_path)
  if partition_scoped ~= nil then
    local partition_probe_path = BuildMountedExecProbePath(partition_scoped, mounted_prefix)
    if not doesFileExist(partition_probe_path) then
      return false, "POPSTARTER partition-scoped path is not accessible: "..partition_probe_path
    end
  end

  return true, nil
end

local function ResolveFallbackMountedPfsExecPath(exec_path, hdd_partition_label)
  local target_exec_path = tostring(exec_path or "")
  if target_exec_path == "" then
    return nil, "missing-target"
  end

  local relpath = string.match(target_exec_path, "^pfs%d*:/(.+)$")
  if relpath == nil or relpath == "" then
    return nil, "not-mounted-pfs-path"
  end

  local selected_game_part = NormalizeHddPartitionLabelForMount(hdd_partition_label)
  local recovered_context = select(1, BuildHddPartitionContext(target_exec_path, { selected_game_part }))
  local mount_part = ParseHddPartitionMount(recovered_context)
  if mount_part == nil then
    mount_part = selected_game_part
  end
  if mount_part == nil then
    return nil, "missing-target-partition"
  end

  -- Direct reconstruction: remount the recovered POPSTARTER source partition
  -- into the POPSTARTER slot and verify the mounted relpath still exists.
  local remount_ok, remount_prefix = MountHddPartitionTracked(mount_part, HDD_SLOT_POPSTARTER, FIO_MT_RDONLY)
  if not remount_ok or remount_prefix == nil then
    return nil, "slot3-remount-failed"
  end

  local direct_candidate = BuildMountedReadablePath(remount_prefix, relpath)
  if direct_candidate ~= nil and ProbePathExists(direct_candidate) then
    return direct_candidate, nil, mount_part
  end

  return nil, "direct-slot3-probe-failed"
end

local function ResolveIrx(name)
  return System.resolveAssetType(name, ASSET_IRX) or JoinPath(APP_DIR_LOCAL, name)
end

function PLDR.ResolvePopstarterPath(path)
  return ResolvePopstarterPath(path)
end

local function BuildDeviceLocalPopstarterCandidate(gamelocation, policy_name)
  if policy_name == "HDD" then
    return nil, nil
  end
  local root = EnsureTrailingSlash(tostring(gamelocation or ""))
  if root == "" or not IsAbsoluteDevicePath(root) then
    return nil, nil
  end
  local lowered = string.lower(root)
  -- smb roots are skipped alongside hdd/pfs: device-local resolution is scoped to
  -- USB/exFAT-ATA/MX4SIO/MMCE. A stale POPSTARTER.ELF left in a share's POPS/
  -- folder (common after wholesale USB copies) would otherwise silently shadow
  -- the known-good cwd/MC build AND route the exec ELF read over smb0:, a
  -- HW-unproven path; POPStarter's SMBCONFIG.DAT flow expects mc0/mc1 anyway.
  if string.match(lowered, "^hdd%d*:") ~= nil or string.match(lowered, "^pfs%d*:") ~= nil
     or string.match(lowered, "^smb%d*:") ~= nil then
    return nil, nil
  end
  return root.."POPSTARTER.ELF", root
end

local function ResolveCwdSidecarPopstarter()
  -- POPSTARTER.ELF sitting in the folder POPSLOADER.ELF itself launched from ("cwd").
  -- Probes the same launcher-dir sources the HDD boot-sidecar uses, but only for plain
  -- removable devices: HDD/pfs candidates are skipped here so they keep flowing through the
  -- (untouched) HDD-aware resolver + partition machinery in ResolvePopstarterPath.
  local bases = {}
  local function add_base(b)
    if b ~= nil and b ~= "" then bases[#bases + 1] = b end
  end
  add_base(APP_DIR_LOCAL)
  add_base(CaptureCurrentDirectory())
  add_base(BOOT_ARGV0_RAW)
  add_base(BOOT_PATH_RAW)
  add_base(APP_DIR_RAW)
  local seen = {}
  for i = 1, #bases do
    local candidate = BuildPopstarterSidecarCandidate(bases[i])
    if candidate ~= nil and candidate ~= "" and not seen[candidate] then
      seen[candidate] = true
      if not IsHddExecContextPath(candidate) then
        local resolved = ResolvePathWithEnsure(candidate)
        if resolved ~= nil then
          return resolved
        end
      end
    end
  end
  return nil
end

function PLDR.ResolveLaunchPopstarterPath(gamelocation, configured_path, policy_name)
  -- Deterministic launch-time POPSTARTER.ELF resolution for REMOVABLE devices
  -- (USB / exFAT-ATA / MX4SIO / MMCE):  custom -> <game device>:/POPS/ -> cwd .
  --   1. an explicit user-configured absolute path (custom field, or an absolute profile) when it resolves;
  --   2. else the game's own <device>:/POPS/POPSTARTER.ELF, when it exists -- this lets a per-device
  --      build (e.g. a USB-delay POPSTARTER on the USB drive, a faster one elsewhere) be used WITHOUT
  --      enforcing it: drop nothing on the device and step 3 covers you;
  --   3. else POPSTARTER.ELF next to where POPSLOADER.ELF launched from (cwd);
  --   4. else the existing fallback net (mc0:/mc1:/POPSTARTER + the configured default).
  -- HDD/APA takes the branch just below (BuildDeviceLocalPopstarterCandidate returns nil for
  -- HDD/pfs/empty roots): its own ordered resolution is custom -> hdd0:__common/POPS/ -> cwd -> net,
  -- routed through the SAME partition machinery as the shipped __common profiles (D-10/D-15 path).
  local colocated = BuildDeviceLocalPopstarterCandidate(gamelocation, policy_name)
  if colocated == nil then
    -- 1. Custom: an explicit absolute configured path wins when it resolves.
    if IsAbsoluteDevicePath(configured_path) then
      local custom = ResolvePopstarterPath(configured_path)
      if custom ~= nil and custom ~= "" and PLDR.PopstarterProbeWithEnsure(custom) then
        return custom
      end
    end
    -- 2. APA common partition: hdd0:__common/POPS/POPSTARTER.ELF when present. Resolved through the
    --    SAME path the shipped bare-pfs __common profile uses (mounts __common on the POPSTARTER slot,
    --    returns the pfs path), so the downstream D-10 partition-context + embedded-loader handoff is
    --    identical to selecting that profile. On a miss, release the probe's slot so the boot-sidecar
    --    fallback below starts from a clean slot state.
    if (policy_name == "HDD") or IsHddExecContextPath(gamelocation) then
      local common = ResolvePopstarterPath("hdd0:__common:pfs:/POPS/POPSTARTER.ELF")
      if common ~= nil and common ~= "" and PLDR.PopstarterProbeWithEnsure(common) then
        return common
      end
      UMountHddPartitionTracked(HDD_SLOT_POPSTARTER)
    end
    -- 3 + 4. cwd / net: the existing HDD-aware resolver (boot-device sidecar + mc fallback), unchanged.
    return ResolvePopstarterPath(configured_path)
  end

  -- 1. Custom: an explicit absolute path the user configured wins outright -- but only when it
  --    actually resolves, so a stale/typo'd custom path falls through instead of stranding a
  --    launch that the device/cwd steps would otherwise satisfy.
  if IsAbsoluteDevicePath(configured_path) then
    local custom = ResolvePopstarterPath(configured_path)
    if custom ~= nil and custom ~= "" and PLDR.PopstarterProbeWithEnsure(custom) then
      return custom
    end
  end

  -- 2. device-local: the game's own <device>:/POPS/POPSTARTER.ELF, when it exists.
  if doesFileExist(colocated) then
    return colocated
  end

  -- 3. cwd: POPSTARTER.ELF in the launcher's own folder.
  local cwd_popstarter = ResolveCwdSidecarPopstarter()
  if cwd_popstarter ~= nil then
    return cwd_popstarter
  end

  -- 4. fallback net: mc0:/mc1:/POPSTARTER + the configured default (unchanged resolver engine).
  return ResolvePopstarterPath(configured_path)
end

function PLDR.ResolveHddReadablePath(path)
  return ResolveHddReadablePath(path)
end

function PLDR.ResolveHddPartitionReadablePath(partition, relpath, mounted_prefix_hint, slot)
  return ResolveHddPartitionReadablePath(partition, relpath, mounted_prefix_hint, slot)
end

-- Expose the HDD exec-path parser so the launcher UI can extract the relpath
-- from any custom-HDD-path form (hdd0:PART:pfsN:/rel, hdd0:PART:pfs:/rel,
-- hdd0:PART/rel, ...). Returns (mount_part, relpath) or (nil, nil). Used for
-- the live-pfs-slot scan that resolves a custom DKWDRV path to whatever slot
-- the partition is actually mounted on (see ui.lua OpenDKWDRV).
function PLDR.ParseHddExecMountAndRelpath(path)
  return ParseHddExecMountAndRelpath(path)
end

function PLDR.PrepareForExternalELFLaunch(path, extra_keep_slots, keep_slots_after_load)
  return PrepareForExternalELFLaunch(path, extra_keep_slots, keep_slots_after_load)
end

-- Expose the HDD partition-context builder so the launcher UI can route
-- HDD-resident targets (e.g. DKWDRV on a custom HDD path) through the same
-- partition-aware path POPSTARTER games use. Returns (context, reason):
-- context is an "hdd?:PART:" string for System.loadELFWithPartition, or nil
-- (with a reason) when the path can't be mapped to a partition.
function PLDR.BuildHddPartitionContext(path, recovery_candidates)
  return BuildHddPartitionContext(path, recovery_candidates)
end

-- Expose the partition-scoped exec-path normalizer (the SAME one POPSTARTER
-- HDD custom paths use). Converts a composite/browsed HDD path like
-- "hdd0:__common:pfs1:/APPS/PS1_DKWDRV/DKWDRV.ELF" -> a slot-less
-- "pfs:/APPS/PS1_DKWDRV/DKWDRV.ELF". Paired with a "hdd?:PART:" context +
-- PrepareForColdExternalELFLaunch, this lets the C side mount the partition
-- FRESH on pfs0: by partition NAME -- so the launch never depends on which
-- pfs slot the browser happened to use (works for __common, +OPL, etc.).
-- Returns nil if the path carries no normalizable mounted/relpath form.
function PLDR.BuildPartitionScopedExecPath(path)
  return BuildPartitionScopedExecPath(path)
end

function PLDR.PrepareForColdExternalELFLaunch()
  return PrepareForColdExternalELFLaunch()
end

function PLDR.SetLaunchWorkingDirectory(path)
  return SetLaunchWorkingDirectory(path)
end

function PLDR.RestoreWorkingDirectory(path)
  return RestoreWorkingDirectory(path)
end

-- Single source of truth for "where did POPSLoader come from?". Combines
-- the C-side argv[0] classification hint (computed pre-IRX in main.cpp
-- detectBootDeviceHintFromArgv0) with Lua-side refinement (the mx4sio
-- mass:/ disambiguation via BDM driver lookup, plus the additive
-- usb/ata/apa SDK prefix recognition).
--
-- Returns a table:
--   kind         -- "USB"/"HDD"/"MC"/"MMCE"/"MX4SIO"/"SMB"/"HOST" or nil
--   prefix       -- raw argv prefix (e.g. "mass0", "hdd0"), or nil
--   boot_path    -- normalized BOOT_PATH_RAW (with trailing slash)
--   sidecar_path -- per-device .pldrs path if appropriate, else nil
--   c_hint       -- pre-IRX C-side classification (debug / fallback)
--
-- Robust to bad/missing argv: empty boot_path, nil prefix/kind, nil
-- sidecar_path -- all callers degrade gracefully (settings -> MC,
-- DetectBootDevice -> nil kind, UI -> default page).
--
-- Cheap enough to call per-invocation; classify_mass_boot's RPC is the
-- only non-trivial cost and is only hit when prefix matches "mass%d*".
local function ResolveBootContext()
  local boot_path = NormalizeDirPath(BOOT_PATH_RAW or "")
  local prefix = string.match(boot_path, "^([%a]+%d*):")

  local c_hint = ""
  if type(System) == "table" and type(System.getBootDeviceHint) == "function" then
    local ok, hint = pcall(System.getBootDeviceHint)
    if ok and type(hint) == "string" then
      c_hint = hint
    end
  end

  -- Authoritative mass: classification rule (maintainer, 2026-05-28):
  -- if ioctl/devctl identifies the mass slot as sdc/mx4, it is MX4SIO;
  -- anything else is USB. Do not load mx4sio_bd just to find out. MX4SIO
  -- does need the USB/BDM base first, but only after MX4SIO evidence is
  -- present (explicit mx4sio:/ boot, sdc/mx4 driver identity, or marker).
  local function classify_mass_boot(root)
    if type(System) == "table" and type(System.getMassMountDriver) == "function" then
      local ok, driver = pcall(System.getMassMountDriver, root)
      if ok and type(driver) == "string" and driver ~= "" then
        local lowered = string.lower(driver)
        if string.find(lowered, "mx4", 1, true) ~= nil or string.find(lowered, "sdc", 1, true) ~= nil then
          if type(System.initMX4SIO) == "function" then
            pcall(System.initMX4SIO)
          end
          return "MX4SIO"
        end
        if type(System.ensureUsbMass) == "function" then
          pcall(System.ensureUsbMass)
        end
        return "USB"
      end
    end

    if type(APP_DIR_LOCAL) == "string" and APP_DIR_LOCAL ~= "" then
      local mx_marker = JoinPath(APP_DIR_LOCAL, ".boot_mx4sio")
      local usb_marker = JoinPath(APP_DIR_LOCAL, ".boot_usb")
      if doesFileExist(mx_marker) then
        if type(System) == "table" and type(System.initMX4SIO) == "function" then
          pcall(System.initMX4SIO)
        end
        return "MX4SIO"
      end
      if doesFileExist(usb_marker) then
        if type(System) == "table" and type(System.ensureUsbMass) == "function" then
          pcall(System.ensureUsbMass)
        end
        return "USB"
      end
    end
    if type(System) == "table" and type(System.ensureUsbMass) == "function" then
      pcall(System.ensureUsbMass)
    end
    return "USB"
  end

  -- Lua-side prefix classification. Order preserves the historical
  -- DetectBootDevice precedence (mmce/mx4sio/mass/pfs|hdd/smb/host
  -- first; usb/ata/apa SDK additions below them so existing behavior
  -- never changes for the legacy prefixes).
  local kind = nil
  if prefix ~= nil then
    if string.match(prefix, "^mmce%d*$") then
      kind = "MMCE"
    elseif string.match(prefix, "^mx4sio%d*$") then
      kind = "MX4SIO"
    elseif string.match(prefix, "^mass%d*$") then
      kind = classify_mass_boot(prefix..":/")
    elseif string.match(prefix, "^pfs%d*$") or string.match(prefix, "^hdd%d*$") then
      kind = "HDD"
    elseif prefix == "smb" then
      kind = "SMB"
    elseif prefix == "host" then
      kind = "HOST"
    elseif string.match(prefix, "^usb%d*$") then
      kind = "USB"
    elseif string.match(prefix, "^ata%d*$") then
      kind = "HDD"
    elseif string.match(prefix, "^apa%d*$") then
      kind = "HDD"
    end
  end

  -- Fallback to C-side hint if Lua-side prefix classification yielded
  -- nothing (e.g. boot_path is empty because argv[0] was NULL/garbage
  -- but C saw enough to classify).
  if kind == nil and c_hint ~= "" then
    kind = c_hint
  end

  -- Settings sidecar path: APP_DIR_LOCAL/.pldrs.
  --
  -- HDD installs are EXCLUDED from sidecar (Nuno 2026-05-26 hardware
  -- report on PR #464: write to pfs1:/APPS/PS1_POPSLOADER/.pldrs still
  -- fails with "may be read-only" even after the boot.lua pfs1: prefix
  -- normalization). The bundled ps2hdd-osd.irx driver appears to have
  -- read-write limitations that we can't reliably work around without
  -- an IRX swap that risks regressing D-10 (the HDD POPSTARTER read
  -- path uses the same driver and is hardware-PASS).
  --
  -- Pragmatic decision: HDD-installed POPSLoader saves settings to
  -- mc0:/POPSTARTER/.pldrs like it did before PR #459. No regression
  -- vs. legacy behavior; the sidecar feature stays for the devices
  -- where it actually works (USB / MX4SIO / MMCE / MC).
  --
  -- Raw hdd0:partition:pfs:/ paths (no live mount), the newer ata:/
  -- apa: forms, AND the mounted pfs%d:/ form are all excluded -- HDD
  -- in any shape falls back to mc0 via the doesFileExist check in
  -- LoadSettingsNonFatal.
  --
  -- usb:/ and smb:/ argv0 prefixes are excluded for a harder reason: those
  -- filesystems DON'T EXIST inside POPSLoader (main.cpp fully resets the IOP,
  -- dropping the launcher's usbhdfsd/smbman; we embed only bdmfs "mass:", and
  -- the network stack is lazy-never-at-boot). A sidecar pinned there made
  -- settings load as defaults every boot and every save fail forever. With
  -- sidecar=nil the existing machinery falls back to mc0:/POPSTARTER/.pldrs,
  -- exactly like the HDD exclusion above. (uLaunchELF rewrites usb:->mass:
  -- before exec, so the usb: arm mostly guards other launchers; smb: is the
  -- real-world case via OPL/uLE network launches.)
  local sidecar = nil
  if type(APP_DIR_LOCAL) == "string" and APP_DIR_LOCAL ~= "" then
    local lower = string.lower(APP_DIR_LOCAL)
    local is_unwritable_boot = string.match(lower, "^hdd%d*:") ~= nil
       or string.match(lower, "^pfs%d*:") ~= nil
       or string.match(lower, "^ata%d*:") ~= nil
       or string.match(lower, "^apa%d*:") ~= nil
       or string.match(lower, "^usb%d*:") ~= nil
       or string.match(lower, "^smb%d*:") ~= nil
    if not is_unwritable_boot then
      sidecar = JoinPath(CanonicalizeMassSlot0(APP_DIR_LOCAL), ".pldrs")
    end
  end

  return {
    kind = kind,
    prefix = prefix,
    boot_path = boot_path,
    sidecar_path = sidecar,
    c_hint = c_hint,
  }
end

-- DetectBootDevice keeps its historical signature; thin wrapper around
-- ResolveBootContext so the call sites scattered through system.lua and
-- ui.lua continue to work unchanged.
local function DetectBootDevice()
  local ctx = ResolveBootContext()
  return ctx.kind, ctx.boot_path, ctx.prefix
end

-- Public APIs for callers that want the full boot context (UI, future
-- lazy-IRX consumers, telemetry, etc.) without having to glue three
-- separate detection paths together.
function PLDR.GetBootContext()
  return ResolveBootContext()
end

function PLDR.GetBootKind()
  return ResolveBootContext().kind
end

local function LoadIrxFromDir(dir)
  local normalized = NormalizeDirPath(dir)
  if not doesFolderExist(normalized) then return false end
  local IRXDIR = System.listDirectory(normalized)
  if IRXDIR == nil then return false end
  local loaded = false
  for x=1, #IRXDIR do
    local entry = IRXDIR[x]
    if entry ~= nil and not entry.directory then
      local name = entry.name
      if name ~= nil and string.lower(string.sub(name, -4)) == ".irx" then
        local PATH = ResolveIrx(name) or JoinPath(normalized, name)
        -- F-1: IOP is a C-binding global; guard it. A nil-global deref is invisible
        -- to luac/CI and only faults on real hardware -- the loadfile-class trap.
        if type(IOP) == "table" and type(IOP.loadModule) == "function" then
          local ID, RET = IOP.loadModule(PATH)
          loaded = true
        end
      end
    end
  end
  return loaded
end

local loadedIrx = LoadIrxFromDir(APP_DIR_LOCAL)
if not loadedIrx then
  loadedIrx = LoadIrxFromDir(JoinPath(APP_DIR_LOCAL, "IRX"))
end
if not loadedIrx then
  LoadIrxFromDir(JoinPath(APP_DIR_LOCAL, "POPSLDR/IRX"))
end
local pldr_defaults = {
  REBOOT_IOP_WHILE_LOADING_POPSTARTER = 0;
  STRICT_HDD_PREEXEC_GATE = false;
  -- "" = Automatic POPSTARTER resolution (the ladder); a path = custom-first.
  POPSTARTER_PATH = "";
  GAMEPATH = ".";
  GAMES = {};
  HDDCACHE = nil;
  HDD = {
    -- Cross-boot HDD disk cache: RE-ENABLED 2026-06-19 with a plain-text, loadfile-
    -- FREE reader (the old .lua cache used loadfile, which is NIL in the embedded
    -- runtime -> "attempt to call a nil value (global 'loadfile')" -> "Failed to load
    -- HDD"; provato). It is now gated on the PLDR.GAMELIST_CACHE setting (opt-in, OFF
    -- by default): OFF = the unchanged live HDD scan; the in-session memo (LIST_BUILT)
    -- is always on regardless. USECACHE is a dead legacy flag now -- the real gate is
    -- PLDR.GAMELIST_CACHE (see CreateCache / ReadCache / EnsureGameList below).
    USECACHE = false;
    LIST_BUILT = false; -- in-session memo: HDD already scanned/loaded this boot
    FROM_CACHE = false; -- current PLDR.GAMES came from cache, not a fresh scan
    LOADSTATE = 0; -- 0:NOT_LOADED, 1:LOADED, -1:LOADED_BUT_FAILED
    FOUNDANY = false;
    HAS_CHECKED = false;
    HAS_CHECKED_DEPS = false;
    STATUS = 3,
    AVAILABLE = {},
    POPS_PARTITIONS = {},
    GAMEPARTS = {}
  };
  USB = {
    MASSINDX = 0
  },
  MX4SIO = {
    READY = false,
    ROOT = nil,
    MASSINDX = nil,
    IS_MASS_ALIAS = false,
    PREFIX_HINT = nil
  },
  MMCE = {
    PROBED = false,
    PREFIX = nil,
    SLOTS = {},
    INDEX = 1
  }
}
for k, v in pairs(pldr_defaults) do
  if PLDR[k] == nil then
    PLDR[k] = v
  end
end

local DEFAULT_HDD_POPS_PARTITIONS = {
  "__.POPS",
  "__.POPS0",
  "__.POPS1",
  "__.POPS2",
  "__.POPS3",
  "__.POPS4",
  "__.POPS5",
  "__.POPS6",
  "__.POPS7",
  "__.POPS8",
  "__.POPS9"
}
PLDR.HDD = PLDR.HDD or {}
PLDR.HDD.AVAILABLE = PLDR.HDD.AVAILABLE or {}
if type(PLDR.HDD.POPS_PARTITIONS) ~= "table" or #PLDR.HDD.POPS_PARTITIONS < 1 then
  PLDR.HDD.POPS_PARTITIONS = {}
  for i = 1, #DEFAULT_HDD_POPS_PARTITIONS do
    PLDR.HDD.POPS_PARTITIONS[i] = DEFAULT_HDD_POPS_PARTITIONS[i]
  end
end
PLDR.HDD.GAMEPARTS = PLDR.HDD.GAMEPARTS or {}

-- RW write/delete a file on an HDD __.POPS game partition via a scoped RW
-- remount -- the SAME proven path as ProbeHddSettingsWrite (mount RW -> openFile
-- -> verify -> unmount), now that the probe confirmed __.POPS partitions accept
-- writes. `partition` may be "__.POPS" or "hdd0:__.POPS"; `relpath` is the file
-- within the partition; `content` nil = delete, string = create+write. Returns
-- true on success or false,<reason> so callers can fall back. Always unmounts.
-- (Defined HERE, after the PLDR.HDD init above -- not up by ProbeHddSettingsWrite --
--  because PLDR.HDD must exist before `function PLDR.HDD.X` can attach to it.)
function PLDR.HDD.WriteGamePartitionFile(partition, relpath, content)
  if type(HDD) ~= "table" then return false, "hdd_not_loaded" end
  local clean_part = string.gsub(tostring(partition or ""), "^[Hh][Dd][Dd]%d:", "")
  if clean_part == "" then return false, "bad_partition" end
  if type(relpath) ~= "string" or relpath == "" then return false, "bad_relpath" end
  local mounted, prefix, slot = MountHddGamePartitionTracked("hdd0:"..clean_part, FIO_MT_RDWR)
  if not mounted or prefix == nil then return false, "mount_failed" end
  local target = BuildMountedReadablePath(prefix, relpath)
  local ok_done, reason = false, "path_failed"
  if target ~= nil then
    if content == nil then
      if not doesFileExist(target) then
        ok_done, reason = true, nil
      elseif pcall(System.removeFile, target) and not doesFileExist(target) then
        ok_done, reason = true, nil
      else
        ok_done, reason = false, "remove_failed"
      end
    else
      local ok_open, fd = pcall(System.openFile, target, FCREATE)
      if ok_open and fd ~= nil and not (type(fd) == "number" and fd < 0) then
        local content_ok = true
        if #content > 0 then
          local okw, wn = pcall(System.writeFile, fd, content, #content)
          content_ok = (okw and type(wn) == "number" and wn == #content)
        end
        pcall(System.closeFile, fd)
        if content_ok and doesFileExist(target) then ok_done, reason = true, nil
        else ok_done, reason = false, "write_failed" end
      else
        ok_done, reason = false, "open_failed"
      end
    end
  end
  if slot ~= nil then UMountHddPartitionTracked(slot) end
  return ok_done, reason
end

-- HDD-cwd takeover: when the launcher mounted the boot partition READ-ONLY, POPSLoader
-- can't write its settings there, and PFS won't let us open a 2nd (RW) mount of the same
-- partition. So we take OWNERSHIP of the launcher's mount -- explicitly unmount it, then
-- remount the SAME partition RW at the SAME pfs slot (the OPL "own your mount" pattern;
-- mnt()'s warm single-attempt path won't self-recover an occupied slot, so the unmount
-- must be explicit and first). Idempotent. On failure it restores a read-only mount so
-- the cwd is never left stranded. Returns true if the boot partition is now RW-mounted.
function PLDR.HDD.EnsureBootPartitionWritable()
  -- The cached RW takeover is only valid while the boot partition is STILL
  -- mounted at the launcher cwd. A game scan (or any game-partition mount) can
  -- collaterally unmount the boot pfs slot at the C layer: luaHDD's warm
  -- single-attempt mnt() unmounts an occupied slot it failed to mount onto and
  -- does not remount it, so after a scan the boot slot (e.g. pfs1:) is left
  -- EMPTY and the cwd dangles. A stale BOOT_PARTITION_RW==true would then skip
  -- the remount and let WriteAtomic write to a dead slot ("...may be
  -- read-only" -- Nuno 2026-06-20: HDD save works, then fails after a scan).
  -- So verify the mount is live; if it's gone, clear the flag and fall through
  -- to re-take it. (doesFolderExist on the cwd is true only while pfs is mounted.)
  if PLDR.HDD.BOOT_PARTITION_RW == true then
    local cwd_dir = tostring(APP_DIR_LOCAL or "")
    if cwd_dir ~= "" and type(doesFolderExist) == "function" and doesFolderExist(cwd_dir) then
      return true
    end
    PLDR.HDD.BOOT_PARTITION_RW = false
  end
  if PLDR.SETTINGS_HDD_PARTITION == nil then return false end
  if type(HDD) ~= "table" or type(HDD.MountPartition) ~= "function"
     or type(HDD.UMountPartition) ~= "function" then return false end
  -- F-13: only ever operate on a real pfsN: cwd. A parse miss must NOT silently
  -- default to slot 0 -- that could unmount/remount an unrelated partition.
  local slot = tonumber(string.match(tostring(APP_DIR_LOCAL or ""), "^[Pp][Ff][Ss](%d+):"))
  if slot == nil then return false end
  pcall(HDD.UMountPartition, slot)
  local ok, mounted = pcall(HDD.MountPartition, PLDR.SETTINGS_HDD_PARTITION, slot, FIO_MT_RDWR)
  if ok and mounted == true then
    PLDR.HDD.BOOT_PARTITION_RW = true
    return true
  end
  -- RW remount failed -- restore a read-only mount so the cwd stays accessible. F-6:
  -- if even the RO restore fails the cwd now has NO mount; that is not silently
  -- recoverable, so surface it loudly (a reboot re-mounts the boot partition cleanly).
  local ro_ok, ro_mounted = pcall(HDD.MountPartition, PLDR.SETTINGS_HDD_PARTITION, slot, FIO_MT_RDONLY)
  if not (ro_ok and ro_mounted == true) and type(UI) == "table" and type(UI.Notif_queue) == "table" then
    UI.Notif_queue.add("HDD boot mount lost during settings write\nReboot to restore HDD access", "error")
  end
  return false
end

-- Launch arguments (NHDDL-style) parsed in main.cpp parseLaunchArgs().
-- Exposed via System.getLaunchArgs() and normalized here into a single
-- PLDR.LAUNCH_ARGS table. Downstream code (UI navigation, IRX deferral)
-- can read this to auto-route the boot.
local function NormalizeLaunchPage(value)
  if type(value) ~= "string" or value == "" then
    return nil
  end
  -- Defensive normalization. CNF-sourced values can arrive decorated:
  -- OSDMenu strips only \r\n from an arg line (trailing spaces survive),
  -- users sometimes quote values, and two flags written on ONE arg line
  -- arrive as a single argv token ("hdd -debug"). Strip leading junk, take
  -- the first whitespace-delimited token, THEN strip any quotes/whitespace
  -- left on that token. Order matters: a quoted value followed by another
  -- flag (-page="hdd" -debug -> '"hdd" -debug') leaves the closing quote
  -- mid-string, so it must be stripped AFTER the token is extracted, not
  -- before (Gemini review, PR #488). No legitimate page value contains a
  -- space or quote, so this is lossless.
  local key = string.lower(value)
  key = string.gsub(key, '^[%s"\']+', "")
  key = string.match(key, "^(%S+)") or ""
  key = string.gsub(key, '[%s"\']+$', "")
  if key == "" then
    return nil
  end
  -- ata / ata0 / ataN / exfat -> the exFAT internal-HDD page (BDMA ATA, scene
  -- GBDMHDD, opt 3). "exfat" is the obvious guess (the page is literally named
  -- "HDD (exFAT)" and the internal token is EXFAT) and used to be a silent no-op.
  -- hdd / hdd0, apa / apa0, and any pfs slot -> the classic APA/PFS HDD page (opt 4).
  if key == "exfat" or string.match(key, "^ata%d*$") then
    return "EXFAT"
  end
  if string.match(key, "^hdd%d*$") or string.match(key, "^apa%d*$") or string.match(key, "^pfs%d*$") then
    return "HDD"
  end
  if key == "usb" or key == "mass" then
    return "USB"
  end
  if key == "mc" or key == "memcard" then
    return "MC"
  end
  if key == "mmce" then
    return "MMCE"
  end
  if key == "mx4sio" or key == "mx4" or key == "sdc" then
    return "MX4SIO"
  end
  if key == "smb" then
    return "SMB"
  end
  if key == "bdma" then
    return "BDMA"
  end
  return nil
end

PLDR.LAUNCH_ARGS = PLDR.LAUNCH_ARGS or {
  page = nil,
  page_raw = nil,
  game = nil,
  debug = false,
}
if type(System) == "table" and type(System.getLaunchArgs) == "function" then
  local ok, args = pcall(System.getLaunchArgs)
  if ok and type(args) == "table" then
    local page_raw = tostring(args.page or "")
    if page_raw ~= "" then
      PLDR.LAUNCH_ARGS.page_raw = page_raw
      PLDR.LAUNCH_ARGS.page = NormalizeLaunchPage(page_raw)
    end
    local game_raw = tostring(args.game or "")
    if game_raw ~= "" then
      -- Trim surrounding whitespace/quotes only; game selectors contain
      -- internal spaces ("Bomberman - Party Edition") that must survive.
      game_raw = string.gsub(game_raw, '^[%s"\']+', "")
      game_raw = string.gsub(game_raw, '[%s"\']+$', "")
      if game_raw ~= "" then
        PLDR.LAUNCH_ARGS.game = game_raw
      end
    end
    PLDR.LAUNCH_ARGS.debug = (args.debug == true)
    -- Recover a -debug that was written on the same CNF arg line as the
    -- page flag ("-page=hdd -debug" arrives as ONE argv token; the C parse
    -- captures "hdd -debug" into page and the standalone -debug match
    -- never fires). NormalizeLaunchPage above already keeps only the
    -- first word of the page value.
    if not PLDR.LAUNCH_ARGS.debug and string.find(string.lower(page_raw), "%-debug") ~= nil then
      PLDR.LAUNCH_ARGS.debug = true
    end
  end
end

function PLDR.IsExplicitATASession()
  if type(PLDR.LAUNCH_ARGS) ~= "table" then
    return false
  end
  local page = string.upper(tostring(PLDR.LAUNCH_ARGS.page or ""))
  return page == "ATA" or page == "EXFAT"
end

-- EXP40: RESTORE LAZY. TRUE only when the session EXPLICITLY requests the ATA
-- backend, in which case ATA is warmed at boot (under the splash). The Internal-HDD
-- setting (EXFAT/BOTH) is a VISIBILITY control -- which HDD pages the carousel shows
-- -- NOT a "use the ATA device now" signal, so it must NOT trigger a boot-time load.
-- EXP38's mistake was conflating those: HDD_FS=BOTH (the default) boot-loaded ATA on
-- every MC/USB boot, which both violated the CWD/page-lazy architecture and was the
-- wrong device state (a normal boot never requested ATA). A normal boot now brings
-- ATA up LAZILY when the user opens the exFAT page (InitATAPopsRoot), exactly like
-- every other device. Only an explicit -page=ata / -page=exfat launch warms it early
-- (the user opted straight into that page). APA/PFS boots load ATAD separately via
-- boot.lua -> HDD.Initialize (pfs1: needs it), unchanged. Named + pure so the host
-- harness can lock the gate (EXP38 broadened it by mistake; keep it explicit-only).
function PLDR.WantExfatBootBringup()
  return (type(PLDR.IsExplicitATASession) == "function")
         and (PLDR.IsExplicitATASession() == true)
end

PLDR.VIDEO_STANDARD_AUTO = "AUTO"
PLDR.VIDEO_STANDARD_NTSC = "NTSC"
PLDR.VIDEO_STANDARD_PAL = "PAL"

-- The GS boots in the console's BIOS region (gsKit_check_rom) before any Lua
-- runs. Capture that mode ONCE here, before anything calls Screen.setMode, so
-- "Auto" resolves to the console's native region even after the user switches
-- modes and back. PAL console -> GS_MODE_PAL; NTSC console -> GS_MODE_NTSC.
local CONSOLE_REGION_MODE = NTSC
if type(Screen) == "table" and type(Screen.getMode) == "function" then
  local ok_region, region = pcall(Screen.getMode)
  if ok_region and type(region) == "table" and type(region.mode) == "number" then
    CONSOLE_REGION_MODE = region.mode
  end
end
PLDR.CONSOLE_REGION_MODE = CONSOLE_REGION_MODE

PLDR.KEYBOARD_LAYOUT_ABC = "ABC"
PLDR.KEYBOARD_LAYOUT_QWERTY = "QWERTY"
PLDR.KEYBOARD_LAYOUT_DVORAK = "DVORAK"
PLDR.KEYBOARD_LAYOUT_AZERTY = "AZERTY"  -- French
PLDR.KEYBOARD_LAYOUT_QWERTZ = "QWERTZ"  -- German
PLDR.KEYBOARD_LAYOUT_ABNT = "ABNT"      -- Brazilian Portuguese (letters mirror QWERTY; accents/cedilla need non-ASCII, out of scope here)

local function NormalizeVideoStandard(value)
  local key = string.upper(tostring(value or ""))
  if key == PLDR.VIDEO_STANDARD_NTSC then
    return PLDR.VIDEO_STANDARD_NTSC
  end
  if key == PLDR.VIDEO_STANDARD_PAL then
    return PLDR.VIDEO_STANDARD_PAL
  end
  return PLDR.VIDEO_STANDARD_AUTO
end

local function NormalizeKeyboardLayout(value)
  local key = string.upper(tostring(value or ""))
  if key == PLDR.KEYBOARD_LAYOUT_QWERTY then
    return PLDR.KEYBOARD_LAYOUT_QWERTY
  end
  if key == PLDR.KEYBOARD_LAYOUT_DVORAK then
    return PLDR.KEYBOARD_LAYOUT_DVORAK
  end
  if key == PLDR.KEYBOARD_LAYOUT_AZERTY then
    return PLDR.KEYBOARD_LAYOUT_AZERTY
  end
  if key == PLDR.KEYBOARD_LAYOUT_QWERTZ then
    return PLDR.KEYBOARD_LAYOUT_QWERTZ
  end
  if key == PLDR.KEYBOARD_LAYOUT_ABNT then
    return PLDR.KEYBOARD_LAYOUT_ABNT
  end
  -- QWERTY is the fallback for anything unrecognized, matching the fresh-profile
  -- default below (R3Z3N review round 3: "Keyboard layout default should be
  -- QWERTY"). It is what nearly every user expects; ABC remains selectable.
  return PLDR.KEYBOARD_LAYOUT_QWERTY
end

-- ============================================================================
-- UI localization (i18n). PLDR.L(s) returns the user-facing string translated
-- into the current PLDR.LANGUAGE, falling back to the English source when there
-- is no entry -- so partial coverage is always safe (anything unlisted stays
-- English, nothing blanks) and paths/numbers/identifiers pass straight through.
-- The UI redraws every frame and calls PLDR.L() at DRAW time, so changing
-- PLDR.LANGUAGE live-applies with no re-render machinery. Translations are
-- MACHINE-ASSISTED and community-correctable (PLDR.I18N; EN is the source, so it
-- has no table -- it is the fallback).
PLDR.LANGUAGE_EN = "EN"
PLDR.LANGUAGE_ORDER = {"EN", "FR", "DE", "PT", "ES", "IT", "HU"}
PLDR.LANGUAGE_NAMES = { EN = "English", FR = "Francais", DE = "Deutsch", PT = "Portugues", ES = "Espanol", IT = "Italiano", HU = "Magyar" }
PLDR.LANGUAGE = PLDR.LANGUAGE or "EN"
local function NormalizeLanguage(value)
  local key = string.upper(tostring(value or ""))
  if PLDR.LANGUAGE_NAMES[key] ~= nil then return key end
  return PLDR.LANGUAGE_EN
end
PLDR.NormalizeLanguage = NormalizeLanguage
PLDR.I18N = {
  FR = {
    ["(not set)"] = "(non défini)",
    ["(share root)"] = "(racine du partage)",
    ["(unknown)"] = "(inconnu)",
    ["100M Full"] = "100M intégral",
    ["100M Half"] = "100M semi",
    ["10M Full"] = "10M intégral",
    ["10M Half"] = "10M semi",
    ["APA / PFS (default)"] = "APA / PFS (défaut)",
    ["About"] = "À propos",
    ["Actual output"] = "Sortie réelle",
    ["Adaptive BDMA"] = "BDMA adaptatif",
    ["Applying BDMA mode"] = "Application du mode BDMA",
    ["At least one device must stay on the carousel"] = "Au moins un appareil doit rester dans le carrousel",
    ["Auto (console region)"] = "Auto (région console)",
    ["Automatic"] = "Automatique",
    ["BDMA Mode"] = "Mode BDMA",
    ["BDMA mode change didn't apply\nBDMA reverted; other settings were saved"] = "Échec du changement de mode BDMA\nBDMA rétabli ; autres réglages enregistrés",
    ["BOOT.ELF not found\nchecked mc0:/BOOT and mc1:/BOOT"] = "BOOT.ELF introuvable\nvérifié mc0:/BOOT et mc1:/BOOT",
    ["Back"] = "Retour",
    ["Backspace"] = "Retour arrière",
    ["Boot Page"] = "Page de démarrage",
    ["Boot sound"] = "Son de démarrage",
    ["Bringing up network..."] = "Activation du réseau...",
    ["Building HDD game list..."] = "Construction de la liste HDD...",
    ["Building USB game list..."] = "Construction de la liste USB...",
    ["Can't disable while Adaptive BDMA is on\nTurn Adaptive BDMA off first"] = "Désactivation impossible si BDMA adaptatif actif\nDésactivez d'abord BDMA adaptatif",
    ["Can't disable while BDMA is enabled\nSet BDMA Mode to FAT32 (None) first"] = "Désactivation impossible si BDMA activé\nRéglez d'abord Mode BDMA sur FAT32 (Aucun)",
    ["Can't disable while SMB modules are installed\nSet SMB modules to Not installed first"] = "Désactivation impossible si modules SMB installés\nRéglez d'abord modules SMB sur Non installé",
    ["Can't reach the server\ncheck Server IP / Port in SMB settings"] = "Serveur injoignable\nvérifiez IP / Port serveur dans réglages SMB",
    ["Cancel"] = "Annuler",
    ["Carousel (default)"] = "Carrousel (défaut)",
    ["Center aligned"] = "Aligné au centre",
    ["Checking POPSTARTER..."] = "Vérification de POPSTARTER...",
    ["Checking the game file..."] = "Vérification du fichier du jeu...",
    ["Code by El_isra"] = "Code par El_isra",
    ["Confirm"] = "Confirmer",
    ["Connecting to SMB..."] = "Connexion à SMB...",
    ["Couldn't apply the PS2 IP settings\ntry again or power-cycle the network adapter"] = "Échec des réglages IP PS2\nréessayez ou redémarrez l'adaptateur réseau",
    ["Couldn't read that game selection"] = "Impossible de lire cette sélection de jeu",
    ["Couldn't save settings -- POPSTARTER folder NOT deleted"] = "Échec d'enregistrement -- dossier POPSTARTER NON supprimé",
    ["Couldn't save settings -- POPSTARTER folder NOT restored"] = "Échec d'enregistrement -- dossier POPSTARTER NON restauré",
    ["Cover art"] = "Jaquettes",
    ["Cover/details folder"] = "Dossier jaquettes/détails",
    ["Credits"] = "Crédits",
    ["DHCP (automatic)"] = "DHCP (automatique)",
    ["DHCP failed\nset a static IP in SMB settings"] = "Échec DHCP\ndéfinissez une IP statique dans réglages SMB",
    ["DKWDRV Path"] = "Chemin DKWDRV",
    ["Defaults restored"] = "Valeurs par défaut restaurées",
    ["Delete the POPSTARTER folder from the memory card?"] = "Supprimer le dossier POPSTARTER de la carte mémoire ?",
    ["Design by Berion\nScripts by nuno6573 and Ripto\nBased on Enceladus by Daniel Santos\nTesting by P4NCHOL1NO, VizoR, provato,\nnuno6573, oldman63, saildot4k, and Community\n\nSpecial Thanks To:\nkrHACKen for making POPStarter\nuyjulian, fjtrujy, HWC, and others for always helping\n\nThis program is free and open source\nIf you bought it, you have been scammed\n\nCompatibility problems? Visit:\nyoutube.com/@hugopocked6695"] = "Conception par Berion\nScripts par nuno6573 et Ripto\nBasé sur Enceladus par Daniel Santos\nTests par P4NCHOL1NO, VizoR, provato,\nnuno6573, oldman63, saildot4k et la communauté\n\nRemerciements spéciaux à :\nkrHACKen pour avoir créé POPStarter\nuyjulian, fjtrujy, HWC et d'autres pour leur aide constante\n\nCe programme est libre et open source\nSi vous l'avez payé, vous avez été arnaqué\n\nProblèmes de compatibilité ? Visitez :\nyoutube.com/@hugopocked6695",
    ["Device List"] = "Liste des appareils",
    ["Disc (DKWDRV)"] = "Disque (DKWDRV)",
    ["Discard & Exit"] = "Abandonner et quitter",
    ["Display"] = "Affichage",
    ["Display reverted -- new mode wasn't confirmed"] = "Affichage rétabli -- nouveau mode non confirmé",
    ["Edit DKWDRV Path"] = "Modifier le chemin DKWDRV",
    ["Edit POPStarter Path"] = "Modifier le chemin POPStarter",
    ["Enable the POPSTARTER Folder first\n(BDMA / SMB modules must live on the memory card)"] = "Activez d'abord le dossier POPSTARTER\n(modules BDMA / SMB requis sur la carte mémoire)",
    ["Enable the POPSTARTER Folder first\n(SMB modules must live on the memory card)"] = "Activez d'abord le dossier POPSTARTER\n(modules SMB requis sur la carte mémoire)",
    ["Enter"] = "Entrée",
    ["Exit"] = "Quitter",
    ["FAT32-USB (None)"] = "FAT32-USB (Aucun)",
    ["Failed to connect to SMB"] = "Échec de connexion à SMB",
    ["Failed to load HDD"] = "Échec du chargement HDD",
    ["Failed to load HDD (exFAT)"] = "Échec du chargement HDD (exFAT)",
    ["Failed to load MMCE"] = "Échec du chargement MMCE",
    ["Failed to load MX4SIO"] = "Échec du chargement MX4SIO",
    ["Failed to load USB"] = "Échec du chargement USB",
    ["Failed to refresh HDD list"] = "Échec de l'actualisation de la liste HDD",
    ["Failed to refresh list"] = "Échec de l'actualisation de la liste",
    ["First disc only"] = "Premier disque seulement",
    ["Game List"] = "Liste des jeux",
    ["Game details"] = "Détails du jeu",
    ["Game hidden"] = "Jeu masqué",
    ["Game list cache"] = "Cache de la liste des jeux",
    ["Game shown"] = "Jeu affiché",
    ["Games path affects browsing only:\nPOPStarter can only launch games from <share>/POPS"] = "Le chemin des jeux n'affecte que la navigation :\nPOPStarter ne lance que les jeux de <share>/POPS",
    ["HDD Alt mode needs POPSTARTER on HDD"] = "Le mode HDD Alt nécessite POPSTARTER sur HDD",
    ["HDD list loaded from cache (R1 rescans)"] = "Liste HDD chargée du cache (R1 pour réanalyser)",
    ["HDD list refreshed"] = "Liste HDD actualisée",
    ["HDD list refreshed (no games found)"] = "Liste HDD actualisée (aucun jeu trouvé)",
    ["Hidden"] = "Masqué",
    ["Hidden games"] = "Jeux masqués",
    ["Hidden games are filtered out.\nPress R3 to reveal them, then L3 to unhide."] = "Jeux masqués filtrés.\nAppuyez sur R3 pour les révéler, puis L3 pour démasquer.",
    ["Hidden games filtered out again"] = "Jeux masqués de nouveau filtrés",
    ["Hide UI Text"] = "Masquer le texte de l'interface",
    ["How to hide a game"] = "Comment masquer un jeu",
    ["Installed"] = "Installé",
    ["Internal HDD"] = "HDD interne",
    ["Keep"] = "Conserver",
    ["Keep this display mode?"] = "Conserver ce mode d'affichage ?",
    ["Keyboard Layout"] = "Disposition du clavier",
    ["L3 on the game list"] = "L3 dans la liste des jeux",
    ["Launch"] = "Lancer",
    ["Launch DKWDRV?"] = "Lancer DKWDRV ?",
    ["Left aligned"] = "Aligné à gauche",
    ["List refreshed"] = "Liste actualisée",
    ["List refreshed (no games found)"] = "Liste actualisée (aucun jeu trouvé)",
    ["Loaded SMB list from cache..."] = "Liste SMB chargée du cache...",
    ["Loading HDD (exFAT)..."] = "Chargement HDD (exFAT)...",
    ["Loading HDD..."] = "Chargement HDD...",
    ["Loading MMCE..."] = "Chargement MMCE...",
    ["Loading MX4SIO..."] = "Chargement MX4SIO...",
    ["Loading USB..."] = "Chargement USB...",
    ["MMCE has no POPS folder\nexpected mmce0:/POPS/"] = "MMCE n'a pas de dossier POPS\nattendu mmce0:/POPS/",
    ["Memory Card"] = "Carte mémoire",
    ["Menu"] = "Menu",
    ["Multi-disc games"] = "Jeux multi-disques",
    ["NetBIOS isn't supported\nset Address type = IP + a Server IP"] = "NetBIOS non pris en charge\nréglez Type d'adresse = IP + une IP serveur",
    ["No"] = "Non",
    ["No MMCE device detected\nchecked mmce0: and mmce1:"] = "Aucun appareil MMCE détecté\nvérifié mmce0: et mmce1:",
    ["No MX4SIO device detected"] = "Aucun appareil MX4SIO détecté",
    ["No Share selected"] = "Aucun partage sélectionné",
    ["No Share set in SMB settings\n(server returned no shares)"] = "Aucun partage défini dans réglages SMB\n(le serveur n'a renvoyé aucun partage)",
    ["No USB backend detected\nreseat the drive and try again"] = "Aucun backend USB détecté\nreconnectez le lecteur et réessayez",
    ["No exFAT HDD detected\nformat the internal drive exFAT (BDMA Mode = ATA)"] = "Aucun HDD exFAT détecté\nformatez le disque interne en exFAT (Mode BDMA = ATA)",
    ["No games found"] = "Aucun jeu trouvé",
    ["No games found on hdd0:\n(__.POPS partitions are empty)"] = "Aucun jeu trouvé sur hdd0:\n(partitions __.POPS vides)",
    ["No games found on this device"] = "Aucun jeu trouvé sur cet appareil",
    ["No network link\ncheck the Ethernet cable / adapter"] = "Aucun lien réseau\nvérifiez le câble / l'adaptateur Ethernet",
    ["Not implemented yet"] = "Pas encore implémenté",
    ["Not installed"] = "Non installé",
    ["Off"] = "Désactivé",
    ["Off (deleted)"] = "Désactivé (supprimé)",
    ["On"] = "Activé",
    ["On (default)"] = "Activé (défaut)",
    ["On (per-device)"] = "Activé (par appareil)",
    ["Opening SMB list..."] = "Ouverture de la liste SMB...",
    ["Overscan (CRT inset)"] = "Overscan (marge CRT)",
    ["POPSLoader\nfor POPStarter"] = "POPSLoader\npour POPStarter",
    ["POPSTARTER Folder"] = "Dossier POPSTARTER",
    ["POPSTARTER Path"] = "Chemin POPSTARTER",
    ["POPSTARTER folder deleted from the memory card"] = "Dossier POPSTARTER supprimé de la carte mémoire",
    ["POPSTARTER folder restored on the memory card\n(set a BDMA mode to re-add the exFAT/SMB modules)"] = "Dossier POPSTARTER restauré sur la carte mémoire\n(réglez un mode BDMA pour rajouter les modules exFAT/SMB)",
    ["Press CIRCLE again to discard what you typed"] = "Appuyez de nouveau sur CIRCLE pour effacer votre saisie",
    ["Press CROSS again to discard what you typed"] = "Appuyez de nouveau sur CROSS pour effacer votre saisie",
    ["Rebuilding HDD game list..."] = "Reconstruction de la liste HDD...",
    ["Refreshing HDD list..."] = "Actualisation de la liste HDD...",
    ["Refreshing list..."] = "Actualisation de la liste...",
    ["Rescanning HDD partitions..."] = "Réanalyse des partitions HDD...",
    ["Reset"] = "Réinitialiser",
    ["Reset Defaults"] = "Rétablir les valeurs par défaut",
    ["Retrying USB scan..."] = "Nouvel essai d'analyse USB...",
    ["Return to OSDSYS?"] = "Retourner à OSDSYS ?",
    ["Revert"] = "Rétablir",
    ["Right aligned"] = "Aligné à droite",
    ["SMB / Network"] = "SMB / Réseau",
    ["SMB connect failed"] = "Échec de connexion SMB",
    ["SMB connection dropped"] = "Connexion SMB interrompue",
    ["SMB login failed\ncheck User / Password"] = "Échec de connexion SMB\nvérifiez Utilisateur / Mot de passe",
    ["SMB modules"] = "Modules SMB",
    ["SMB modules are not installed\nGames list but won't boot without them --\ninstall via Settings > SMB modules, then Save"] = "Modules SMB non installés\nLes jeux s'affichent mais ne démarrent pas sans eux --\ninstallez via Réglages > Modules SMB, puis Enregistrer",
    ["SMB modules are not installed\nGames will list but won't boot -- install them\nvia Settings > SMB modules first"] = "Modules SMB non installés\nLes jeux s'affichent mais ne démarrent pas -- installez-les\nd'abord via Réglages > Modules SMB",
    ["SMB modules didn't install/remove\nmodule setting reverted; other settings were saved"] = "Échec installation/suppression modules SMB\nréglage module rétabli ; autres réglages enregistrés",
    ["SMB modules failed to load"] = "Échec du chargement des modules SMB",
    ["Save"] = "Enregistrer",
    ["Save Changes"] = "Enregistrer les modifications",
    ["Saving settings"] = "Enregistrement des réglages",
    ["Saving..."] = "Enregistrement...",
    ["Saving/Applying..."] = "Enregistrement/Application...",
    ["Scanning HDD partitions..."] = "Analyse des partitions HDD...",
    ["Scanning MMCE games..."] = "Analyse des jeux MMCE...",
    ["Scanning MX4SIO games..."] = "Analyse des jeux MX4SIO...",
    ["Scanning SMB games..."] = "Analyse des jeux SMB...",
    ["Scanning exFAT HDD games..."] = "Analyse des jeux HDD exFAT...",
    ["Scanning games..."] = "Analyse des jeux...",
    ["Select"] = "Sélectionner",
    ["Select a share"] = "Sélectionnez un partage",
    ["Server refused SMBv1\nenable SMBv1 support on the host"] = "Le serveur a refusé SMBv1\nactivez la prise en charge SMBv1 sur l'hôte",
    ["Settings"] = "Réglages",
    ["Share not found\ncheck the Share name (host must allow SMB1)"] = "Partage introuvable\nvérifiez le nom du partage (l'hôte doit autoriser SMB1)",
    ["Show all discs"] = "Afficher tous les disques",
    ["Showing hidden games (dimmed) -- press L3 to unhide"] = "Jeux masqués affichés (grisés) -- L3 pour démasquer",
    ["Shown"] = "Affiché",
    ["Staging drivers for this device"] = "Préparation des pilotes pour cet appareil",
    ["Starting the game..."] = "Démarrage du jeu...",
    ["Startup"] = "Démarrage",
    ["Static (manual)"] = "Statique (manuel)",
    ["Storage"] = "Stockage",
    ["This backend isn't implemented yet"] = "Ce backend n'est pas encore implémenté",
    ["UI text hidden"] = "Texte de l'interface masqué",
    ["UI text shown"] = "Texte de l'interface affiché",
    ["Video Standard"] = "Standard vidéo",
    ["Visible (manage)"] = "Visible (gérer)",
    ["Working..."] = "En cours...",
    ["Yes"] = "Oui",
    -- EXP34: fill currently-used strings that were untranslated (machine-assisted)
    ["(could NOT save -- reverts on reboot)"] = "(échec de l'enregistrement -- annulé au redémarrage)",
    ["(the usual settings location wasn't writable)"] = "(l'emplacement habituel des réglages n'était pas accessible en écriture)",
    ["-- launch cancelled"] = "-- lancement annulé",
    ["Adaptive BDMA couldn't stage"] = "BDMA adaptatif n'a pas pu préparer",
    ["Applying SMB modules"] = "Application des modules SMB",
    ["BDMA source backend not ready:"] = "Backend source BDMA non prêt :",
    ["BOOT.ELF failed to launch"] = "Échec du lancement de BOOT.ELF",
    ["Booted from:"] = "Démarré depuis :",
    ["Cannot access"] = "Accès impossible",
    ["Case/Symbols: UPPER  (R2)"] = "Casse/Symboles : MAJ  (R2)",
    ["Case/Symbols: lower  (R2)"] = "Casse/Symboles : min  (R2)",
    ["Couldn't restore BDMA mode"] = "Impossible de restaurer le mode BDMA",
    ["Couldn't save settings"] = "Impossible d'enregistrer les réglages",
    ["Couldn't update hidden state"] = "Impossible de mettre à jour l'état masqué",
    ["Couldn't write .hide to the HDD"] = "Impossible d'écrire .hide sur le disque dur",
    ["Cursor: L1 / R1"] = "Curseur : L1 / R1",
    ["DKWDRV failed to launch"] = "Échec du lancement de DKWDRV",
    ["Edit"] = "Modifier",
    ["Edit %s"] = "Modifier %s",
    ["Game file missing"] = "Fichier de jeu manquant",
    ["HDD dir read failed:"] = "Échec de lecture du dossier du disque dur :",
    ["HDD not usable"] = "Disque dur inutilisable",
    ["Hidden games are already shown here (dimmed)\nEnable \"Hide hidden games\" in Settings to filter them out"] = "Les jeux masqués sont déjà affichés ici (grisés)\nActivez « Masquer les jeux cachés » dans les Réglages pour les filtrer",
    ["Locating exFAT HDD POPS folder..."] = "Localisation du dossier POPS du disque exFAT...",
    ["Looking for USB drive..."] = "Recherche d'un lecteur USB...",
    ["Missing BDMA UI source (tried):"] = "Source d'interface BDMA manquante (essayé) :",
    ["Missing BDMA source (tried):"] = "Source BDMA manquante (essayé) :",
    ["Missing SMB module (tried):"] = "Module SMB manquant (essayé) :",
    ["No '__.POPS' partitions on hdd0:\nformat one with __.POPS / __.POPS0...9"] = "Aucune partition '__.POPS' sur hdd0:\nformatez-en une avec __.POPS / __.POPS0...9",
    ["No DKWDRV found at this path"] = "Aucun DKWDRV trouvé à ce chemin",
    ["No POPSTARTER found at this path"] = "Aucun POPSTARTER trouvé à ce chemin",
    ["Path saved, file not found:"] = "Chemin enregistré, fichier introuvable :",
    ["Resolved:"] = "Résolu :",
    ["Reverting in"] = "Annulation dans",
    ["Saved to"] = "Enregistré dans",
    ["Slot:"] = "Emplacement :",
    ["The internal drive is still starting\nopen this page again in a moment"] = "Le disque interne démarre encore\nrouvrez cette page dans un instant",
    ["Triangle"] = "Triangle",
    ["Unknown BDMA mode:"] = "Mode BDMA inconnu :",
    ["You can still add a \"<game>.hide\" next to the .VCD from a PC."] = "Vous pouvez toujours ajouter un « <jeu>.hide » à côté du .VCD depuis un PC.",
    ["adjusted -- using"] = "ajusté -- utilise",
    ["check the memory card, or turn Adaptive BDMA off"] = "vérifiez la carte mémoire, ou désactivez le BDMA adaptatif",
    ["if not confirmed"] = "si non confirmé",
    ["re-select it under Settings > Storage to restage"] = "resélectionnez-le dans Réglages > Stockage pour le repréparer",
    ["return code:"] = "code de retour :",
    ["status:"] = "état :",
  },
  DE = {
    ["(not set)"] = "(nicht gesetzt)",
    ["(share root)"] = "(Freigabe-Stamm)",
    ["(unknown)"] = "(unbekannt)",
    ["100M Full"] = "100M Voll",
    ["100M Half"] = "100M Halb",
    ["10M Full"] = "10M Voll",
    ["10M Half"] = "10M Halb",
    ["APA / PFS (default)"] = "APA / PFS (Standard)",
    ["About"] = "Über",
    ["Actual output"] = "Tatsächliche Ausgabe",
    ["Adaptive BDMA"] = "Adaptives BDMA",
    ["Applying BDMA mode"] = "BDMA-Modus wird angewendet",
    ["At least one device must stay on the carousel"] = "Mindestens ein Gerät muss im Karussell bleiben",
    ["Auto (console region)"] = "Auto (Konsolenregion)",
    ["Automatic"] = "Automatisch",
    ["BDMA Mode"] = "BDMA-Modus",
    ["BDMA mode change didn't apply\nBDMA reverted; other settings were saved"] = "BDMA-Moduswechsel nicht angewendet\nBDMA zurückgesetzt; andere Einstellungen gespeichert",
    ["BOOT.ELF not found\nchecked mc0:/BOOT and mc1:/BOOT"] = "BOOT.ELF nicht gefunden\nmc0:/BOOT und mc1:/BOOT geprüft",
    ["Back"] = "Zurück",
    ["Boot Page"] = "Startseite",
    ["Boot sound"] = "Startton",
    ["Bringing up network..."] = "Netzwerk wird gestartet...",
    ["Building HDD game list..."] = "HDD-Spieleliste wird erstellt...",
    ["Building USB game list..."] = "USB-Spieleliste wird erstellt...",
    ["Can't disable while Adaptive BDMA is on\nTurn Adaptive BDMA off first"] = "Nicht deaktivierbar, solange Adaptives BDMA an ist\nErst Adaptives BDMA ausschalten",
    ["Can't disable while BDMA is enabled\nSet BDMA Mode to FAT32 (None) first"] = "Nicht deaktivierbar, solange BDMA aktiviert ist\nErst BDMA-Modus auf FAT32 (None) setzen",
    ["Can't disable while SMB modules are installed\nSet SMB modules to Not installed first"] = "Nicht deaktivierbar, solange SMB-Module installiert sind\nErst SMB-Module auf Nicht installiert setzen",
    ["Can't reach the server\ncheck Server IP / Port in SMB settings"] = "Server nicht erreichbar\nServer-IP / Port in SMB-Einstellungen prüfen",
    ["Cancel"] = "Abbrechen",
    ["Carousel (default)"] = "Karussell (Standard)",
    ["Center aligned"] = "Zentriert",
    ["Checking POPSTARTER..."] = "POPSTARTER wird geprüft...",
    ["Checking the game file..."] = "Spieldatei wird geprüft...",
    ["Code by El_isra"] = "Code von El_isra",
    ["Confirm"] = "Bestätigen",
    ["Connecting to SMB..."] = "Verbinde mit SMB...",
    ["Couldn't apply the PS2 IP settings\ntry again or power-cycle the network adapter"] = "PS2-IP-Einstellungen nicht anwendbar\nerneut versuchen oder Netzwerkadapter neu starten",
    ["Couldn't read that game selection"] = "Spielauswahl nicht lesbar",
    ["Couldn't save settings -- POPSTARTER folder NOT deleted"] = "Einstellungen nicht gespeichert -- POPSTARTER-Ordner NICHT gelöscht",
    ["Couldn't save settings -- POPSTARTER folder NOT restored"] = "Einstellungen nicht gespeichert -- POPSTARTER-Ordner NICHT wiederhergestellt",
    ["Cover art"] = "Coverbild",
    ["Cover/details folder"] = "Cover-/Detailordner",
    ["Credits"] = "Mitwirkende",
    ["DHCP (automatic)"] = "DHCP (automatisch)",
    ["DHCP failed\nset a static IP in SMB settings"] = "DHCP fehlgeschlagen\nstatische IP in SMB-Einstellungen setzen",
    ["DKWDRV Path"] = "DKWDRV-Pfad",
    ["Defaults restored"] = "Standardwerte wiederhergestellt",
    ["Delete the POPSTARTER folder from the memory card?"] = "POPSTARTER-Ordner von der Memory Card löschen?",
    ["Design by Berion\nScripts by nuno6573 and Ripto\nBased on Enceladus by Daniel Santos\nTesting by P4NCHOL1NO, VizoR, provato,\nnuno6573, oldman63, saildot4k, and Community\n\nSpecial Thanks To:\nkrHACKen for making POPStarter\nuyjulian, fjtrujy, HWC, and others for always helping\n\nThis program is free and open source\nIf you bought it, you have been scammed\n\nCompatibility problems? Visit:\nyoutube.com/@hugopocked6695"] = "Design von Berion\nSkripte von nuno6573 und Ripto\nBasiert auf Enceladus von Daniel Santos\nGetestet von P4NCHOL1NO, VizoR, provato,\nnuno6573, oldman63, saildot4k und Community\n\nBesonderer Dank an:\nkrHACKen für POPStarter\nuyjulian, fjtrujy, HWC und andere für die stete Hilfe\n\nDieses Programm ist frei und Open Source\nWenn du dafür bezahlt hast, wurdest du betrogen\n\nKompatibilitätsprobleme? Besuche:\nyoutube.com/@hugopocked6695",
    ["Device List"] = "Geräteliste",
    ["Discard & Exit"] = "Verwerfen & Beenden",
    ["Display"] = "Anzeige",
    ["Display reverted -- new mode wasn't confirmed"] = "Anzeige zurückgesetzt -- neuer Modus nicht bestätigt",
    ["Edit DKWDRV Path"] = "DKWDRV-Pfad bearbeiten",
    ["Edit POPStarter Path"] = "POPStarter-Pfad bearbeiten",
    ["Enable the POPSTARTER Folder first\n(BDMA / SMB modules must live on the memory card)"] = "Erst POPSTARTER-Ordner aktivieren\n(BDMA-/SMB-Module müssen auf der Memory Card liegen)",
    ["Enable the POPSTARTER Folder first\n(SMB modules must live on the memory card)"] = "Erst POPSTARTER-Ordner aktivieren\n(SMB-Module müssen auf der Memory Card liegen)",
    ["Exit"] = "Beenden",
    ["FAT32-USB (None)"] = "FAT32-USB (Keine)",
    ["Failed to connect to SMB"] = "Verbindung zu SMB fehlgeschlagen",
    ["Failed to load HDD"] = "HDD konnte nicht geladen werden",
    ["Failed to load HDD (exFAT)"] = "HDD (exFAT) konnte nicht geladen werden",
    ["Failed to load MMCE"] = "MMCE konnte nicht geladen werden",
    ["Failed to load MX4SIO"] = "MX4SIO konnte nicht geladen werden",
    ["Failed to load USB"] = "USB konnte nicht geladen werden",
    ["Failed to refresh HDD list"] = "HDD-Liste konnte nicht aktualisiert werden",
    ["Failed to refresh list"] = "Liste konnte nicht aktualisiert werden",
    ["First disc only"] = "Nur erste Disc",
    ["Game List"] = "Spieleliste",
    ["Game details"] = "Spieldetails",
    ["Game hidden"] = "Spiel ausgeblendet",
    ["Game list cache"] = "Spieleliste-Cache",
    ["Game shown"] = "Spiel eingeblendet",
    ["Games path affects browsing only:\nPOPStarter can only launch games from <share>/POPS"] = "Spielepfad betrifft nur das Durchsuchen:\nPOPStarter startet Spiele nur aus <share>/POPS",
    ["HDD Alt mode needs POPSTARTER on HDD"] = "HDD-Alt-Modus benötigt POPSTARTER auf HDD",
    ["HDD list loaded from cache (R1 rescans)"] = "HDD-Liste aus Cache geladen (R1 = neu scannen)",
    ["HDD list refreshed"] = "HDD-Liste aktualisiert",
    ["HDD list refreshed (no games found)"] = "HDD-Liste aktualisiert (keine Spiele gefunden)",
    ["Hidden"] = "Ausgeblendet",
    ["Hidden games"] = "Ausgeblendete Spiele",
    ["Hidden games are filtered out.\nPress R3 to reveal them, then L3 to unhide."] = "Ausgeblendete Spiele sind gefiltert.\nR3 zum Anzeigen, dann L3 zum Einblenden.",
    ["Hidden games filtered out again"] = "Ausgeblendete Spiele wieder gefiltert",
    ["Hide UI Text"] = "UI-Text ausblenden",
    ["How to hide a game"] = "Ein Spiel ausblenden",
    ["Installed"] = "Installiert",
    ["Internal HDD"] = "Interne HDD",
    ["Keep"] = "Behalten",
    ["Keep this display mode?"] = "Diesen Anzeigemodus behalten?",
    ["Keyboard Layout"] = "Tastaturlayout",
    ["L3 on the game list"] = "L3 in der Spieleliste",
    ["Launch"] = "Starten",
    ["Launch DKWDRV?"] = "DKWDRV starten?",
    ["Left aligned"] = "Linksbündig",
    ["List refreshed"] = "Liste aktualisiert",
    ["List refreshed (no games found)"] = "Liste aktualisiert (keine Spiele gefunden)",
    ["Loaded SMB list from cache..."] = "SMB-Liste aus Cache geladen...",
    ["Loading HDD (exFAT)..."] = "HDD (exFAT) wird geladen...",
    ["Loading HDD..."] = "HDD wird geladen...",
    ["Loading MMCE..."] = "MMCE wird geladen...",
    ["Loading MX4SIO..."] = "MX4SIO wird geladen...",
    ["Loading USB..."] = "USB wird geladen...",
    ["MMCE has no POPS folder\nexpected mmce0:/POPS/"] = "MMCE hat keinen POPS-Ordner\nerwartet mmce0:/POPS/",
    ["Menu"] = "Menü",
    ["Multi-disc games"] = "Mehrfach-Disc-Spiele",
    ["NetBIOS isn't supported\nset Address type = IP + a Server IP"] = "NetBIOS wird nicht unterstützt\nAdresstyp = IP + Server-IP setzen",
    ["No"] = "Nein",
    ["No MMCE device detected\nchecked mmce0: and mmce1:"] = "Kein MMCE-Gerät erkannt\nmmce0: und mmce1: geprüft",
    ["No MX4SIO device detected"] = "Kein MX4SIO-Gerät erkannt",
    ["No Share selected"] = "Keine Freigabe ausgewählt",
    ["No Share set in SMB settings\n(server returned no shares)"] = "Keine Freigabe in SMB-Einstellungen gesetzt\n(Server lieferte keine Freigaben)",
    ["No USB backend detected\nreseat the drive and try again"] = "Kein USB-Backend erkannt\nLaufwerk neu einstecken und erneut versuchen",
    ["No exFAT HDD detected\nformat the internal drive exFAT (BDMA Mode = ATA)"] = "Keine exFAT-HDD erkannt\ninternes Laufwerk als exFAT formatieren (BDMA-Modus = ATA)",
    ["No games found"] = "Keine Spiele gefunden",
    ["No games found on hdd0:\n(__.POPS partitions are empty)"] = "Keine Spiele auf hdd0: gefunden\n(__.POPS-Partitionen sind leer)",
    ["No games found on this device"] = "Keine Spiele auf diesem Gerät gefunden",
    ["No network link\ncheck the Ethernet cable / adapter"] = "Keine Netzwerkverbindung\nEthernet-Kabel / Adapter prüfen",
    ["Not implemented yet"] = "Noch nicht implementiert",
    ["Not installed"] = "Nicht installiert",
    ["Off"] = "Aus",
    ["Off (deleted)"] = "Aus (gelöscht)",
    ["On"] = "An",
    ["On (default)"] = "An (Standard)",
    ["On (per-device)"] = "An (pro Gerät)",
    ["Opening SMB list..."] = "SMB-Liste wird geöffnet...",
    ["Overscan (CRT inset)"] = "Overscan (CRT-Einzug)",
    ["POPSLoader\nfor POPStarter"] = "POPSLoader\nfür POPStarter",
    ["POPSTARTER Folder"] = "POPSTARTER-Ordner",
    ["POPSTARTER Path"] = "POPSTARTER-Pfad",
    ["POPSTARTER folder deleted from the memory card"] = "POPSTARTER-Ordner von der Memory Card gelöscht",
    ["POPSTARTER folder restored on the memory card\n(set a BDMA mode to re-add the exFAT/SMB modules)"] = "POPSTARTER-Ordner auf der Memory Card wiederhergestellt\n(BDMA-Modus setzen, um exFAT/SMB-Module wieder hinzuzufügen)",
    ["Press CIRCLE again to discard what you typed"] = "CIRCLE erneut drücken, um Eingabe zu verwerfen",
    ["Press CROSS again to discard what you typed"] = "CROSS erneut drücken, um Eingabe zu verwerfen",
    ["Rebuilding HDD game list..."] = "HDD-Spieleliste wird neu erstellt...",
    ["Refreshing HDD list..."] = "HDD-Liste wird aktualisiert...",
    ["Refreshing list..."] = "Liste wird aktualisiert...",
    ["Rescanning HDD partitions..."] = "HDD-Partitionen werden neu gescannt...",
    ["Reset"] = "Zurücksetzen",
    ["Reset Defaults"] = "Standardwerte zurücksetzen",
    ["Retrying USB scan..."] = "USB-Scan wird wiederholt...",
    ["Return to OSDSYS?"] = "Zurück zu OSDSYS?",
    ["Revert"] = "Zurücksetzen",
    ["Right aligned"] = "Rechtsbündig",
    ["SMB / Network"] = "SMB / Netzwerk",
    ["SMB connect failed"] = "SMB-Verbindung fehlgeschlagen",
    ["SMB connection dropped"] = "SMB-Verbindung getrennt",
    ["SMB login failed\ncheck User / Password"] = "SMB-Anmeldung fehlgeschlagen\nBenutzer / Passwort prüfen",
    ["SMB modules"] = "SMB-Module",
    ["SMB modules are not installed\nGames list but won't boot without them --\ninstall via Settings > SMB modules, then Save"] = "SMB-Module sind nicht installiert\nSpiele werden gelistet, starten aber nicht --\nüber Einstellungen > SMB-Module installieren, dann Speichern",
    ["SMB modules are not installed\nGames will list but won't boot -- install them\nvia Settings > SMB modules first"] = "SMB-Module sind nicht installiert\nSpiele werden gelistet, starten aber nicht -- erst\nüber Einstellungen > SMB-Module installieren",
    ["SMB modules didn't install/remove\nmodule setting reverted; other settings were saved"] = "SMB-Module nicht installiert/entfernt\nModul-Einstellung zurückgesetzt; andere Einstellungen gespeichert",
    ["SMB modules failed to load"] = "SMB-Module konnten nicht geladen werden",
    ["Save"] = "Speichern",
    ["Save Changes"] = "Änderungen speichern",
    ["Saving settings"] = "Einstellungen werden gespeichert",
    ["Saving..."] = "Wird gespeichert...",
    ["Saving/Applying..."] = "Speichern/Anwenden...",
    ["Scanning HDD partitions..."] = "HDD-Partitionen werden gescannt...",
    ["Scanning MMCE games..."] = "MMCE-Spiele werden gescannt...",
    ["Scanning MX4SIO games..."] = "MX4SIO-Spiele werden gescannt...",
    ["Scanning SMB games..."] = "SMB-Spiele werden gescannt...",
    ["Scanning exFAT HDD games..."] = "exFAT-HDD-Spiele werden gescannt...",
    ["Scanning games..."] = "Spiele werden gescannt...",
    ["Select"] = "Auswählen",
    ["Select a share"] = "Freigabe auswählen",
    ["Server refused SMBv1\nenable SMBv1 support on the host"] = "Server hat SMBv1 abgelehnt\nSMBv1-Unterstützung am Host aktivieren",
    ["Settings"] = "Einstellungen",
    ["Share not found\ncheck the Share name (host must allow SMB1)"] = "Freigabe nicht gefunden\nFreigabename prüfen (Host muss SMB1 erlauben)",
    ["Show all discs"] = "Alle Discs anzeigen",
    ["Showing hidden games (dimmed) -- press L3 to unhide"] = "Zeige ausgeblendete Spiele (gedimmt) -- L3 zum Einblenden",
    ["Shown"] = "Eingeblendet",
    ["Staging drivers for this device"] = "Treiber für dieses Gerät werden vorbereitet",
    ["Starting the game..."] = "Spiel wird gestartet...",
    ["Startup"] = "Start",
    ["Static (manual)"] = "Statisch (manuell)",
    ["Storage"] = "Speicher",
    ["This backend isn't implemented yet"] = "Dieses Backend ist noch nicht implementiert",
    ["UI text hidden"] = "UI-Text ausgeblendet",
    ["UI text shown"] = "UI-Text eingeblendet",
    ["Video Standard"] = "Videostandard",
    ["Visible"] = "Sichtbar",
    ["Visible (manage)"] = "Sichtbar (verwalten)",
    ["Working..."] = "Arbeite...",
    ["Yes"] = "Ja",
    -- EXP34: fill currently-used strings that were untranslated (machine-assisted)
    ["(could NOT save -- reverts on reboot)"] = "(konnte NICHT speichern -- wird beim Neustart verworfen)",
    ["(the usual settings location wasn't writable)"] = "(der übliche Einstellungsort war nicht beschreibbar)",
    ["-- launch cancelled"] = "-- Start abgebrochen",
    ["Adaptive BDMA couldn't stage"] = "Adaptives BDMA konnte nicht bereitstellen",
    ["Applying SMB modules"] = "SMB-Module werden angewendet",
    ["BDMA source backend not ready:"] = "BDMA-Quell-Backend nicht bereit:",
    ["BOOT.ELF failed to launch"] = "BOOT.ELF konnte nicht gestartet werden",
    ["Booted from:"] = "Gestartet von:",
    ["Cannot access"] = "Kein Zugriff auf",
    ["Case/Symbols: UPPER  (R2)"] = "Groß/Zeichen: GROSS  (R2)",
    ["Case/Symbols: lower  (R2)"] = "Groß/Zeichen: klein  (R2)",
    ["Couldn't restore BDMA mode"] = "BDMA-Modus konnte nicht wiederhergestellt werden",
    ["Couldn't save settings"] = "Einstellungen konnten nicht gespeichert werden",
    ["Couldn't update hidden state"] = "Verborgen-Status konnte nicht aktualisiert werden",
    ["Couldn't write .hide to the HDD"] = "Konnte .hide nicht auf die HDD schreiben",
    ["Cursor: L1 / R1"] = "Cursor: L1 / R1",
    ["DKWDRV failed to launch"] = "DKWDRV konnte nicht gestartet werden",
    ["Edit"] = "Bearbeiten",
    ["Edit %s"] = "%s bearbeiten",
    ["Game file missing"] = "Spieldatei fehlt",
    ["HDD dir read failed:"] = "HDD-Verzeichnis konnte nicht gelesen werden:",
    ["HDD not usable"] = "HDD nicht verwendbar",
    ["Hidden games are already shown here (dimmed)\nEnable \"Hide hidden games\" in Settings to filter them out"] = "Verborgene Spiele werden hier bereits angezeigt (abgedunkelt)\nAktiviere \"Verborgene Spiele ausblenden\" in den Einstellungen, um sie zu filtern",
    ["Locating exFAT HDD POPS folder..."] = "exFAT-HDD-POPS-Ordner wird gesucht...",
    ["Looking for USB drive..."] = "USB-Laufwerk wird gesucht...",
    ["Missing BDMA UI source (tried):"] = "BDMA-UI-Quelle fehlt (versucht):",
    ["Missing BDMA source (tried):"] = "BDMA-Quelle fehlt (versucht):",
    ["Missing SMB module (tried):"] = "SMB-Modul fehlt (versucht):",
    ["No '__.POPS' partitions on hdd0:\nformat one with __.POPS / __.POPS0...9"] = "Keine '__.POPS'-Partitionen auf hdd0:\nlege eine mit __.POPS / __.POPS0...9 an",
    ["No DKWDRV found at this path"] = "Kein DKWDRV unter diesem Pfad gefunden",
    ["No POPSTARTER found at this path"] = "Kein POPSTARTER unter diesem Pfad gefunden",
    ["Path saved, file not found:"] = "Pfad gespeichert, Datei nicht gefunden:",
    ["Resolved:"] = "Aufgelöst:",
    ["Reverting in"] = "Zurücksetzen in",
    ["Saved to"] = "Gespeichert in",
    ["Slot:"] = "Slot:",
    ["The internal drive is still starting\nopen this page again in a moment"] = "Das interne Laufwerk startet noch\nöffne diese Seite gleich erneut",
    ["Triangle"] = "Dreieck",
    ["Unknown BDMA mode:"] = "Unbekannter BDMA-Modus:",
    ["You can still add a \"<game>.hide\" next to the .VCD from a PC."] = "Du kannst weiterhin eine \"<Spiel>.hide\" neben die .VCD vom PC aus hinzufügen.",
    ["adjusted -- using"] = "angepasst -- verwende",
    ["check the memory card, or turn Adaptive BDMA off"] = "prüfe die Memory Card oder schalte adaptives BDMA aus",
    ["if not confirmed"] = "wenn nicht bestätigt",
    ["re-select it under Settings > Storage to restage"] = "wähle es unter Einstellungen > Speicher erneut, um es neu bereitzustellen",
    ["return code:"] = "Rückgabecode:",
    ["status:"] = "Status:",
  },
  PT = {
    ["(not set)"] = "(não definido)",
    ["(share root)"] = "(raiz do share)",
    ["(unknown)"] = "(desconhecido)",
    ["APA / PFS (default)"] = "APA / PFS (padrão)",
    ["About"] = "Sobre",
    ["Actual output"] = "Saída real",
    ["Adaptive BDMA"] = "BDMA Adaptativo",
    ["Applying BDMA mode"] = "Aplicando modo BDMA",
    ["At least one device must stay on the carousel"] = "Ao menos um dispositivo deve ficar no carrossel",
    ["Auto (console region)"] = "Auto (região do console)",
    ["Automatic"] = "Automático",
    ["BDMA Mode"] = "Modo BDMA",
    ["BDMA mode change didn't apply\nBDMA reverted; other settings were saved"] = "Mudança de modo BDMA não aplicada\nBDMA revertido; outras configurações foram salvas",
    ["BOOT.ELF not found\nchecked mc0:/BOOT and mc1:/BOOT"] = "BOOT.ELF não encontrado\nverificado mc0:/BOOT e mc1:/BOOT",
    ["Back"] = "Voltar",
    ["Boot Page"] = "Página de inicialização",
    ["Boot sound"] = "Som de inicialização",
    ["Bringing up network..."] = "Ativando a rede...",
    ["Building HDD game list..."] = "Montando lista de jogos do HDD...",
    ["Building USB game list..."] = "Montando lista de jogos do USB...",
    ["Can't disable while Adaptive BDMA is on\nTurn Adaptive BDMA off first"] = "Não é possível desativar com BDMA Adaptativo ligado\nDesligue o BDMA Adaptativo primeiro",
    ["Can't disable while BDMA is enabled\nSet BDMA Mode to FAT32 (None) first"] = "Não é possível desativar com BDMA ativado\nDefina o Modo BDMA como FAT32 (None) primeiro",
    ["Can't disable while SMB modules are installed\nSet SMB modules to Not installed first"] = "Não é possível desativar com os módulos SMB instalados\nDefina os módulos SMB como Não instalados primeiro",
    ["Can't reach the server\ncheck Server IP / Port in SMB settings"] = "Não foi possível acessar o servidor\nverifique o IP / Porta do servidor nas configurações SMB",
    ["Cancel"] = "Cancelar",
    ["Carousel (default)"] = "Carrossel (padrão)",
    ["Center aligned"] = "Alinhado ao centro",
    ["Checking POPSTARTER..."] = "A verificar o POPSTARTER...",
    ["Checking the game file..."] = "A verificar o ficheiro do jogo...",
    ["Code by El_isra"] = "Código por El_isra",
    ["Confirm"] = "Confirmar",
    ["Connecting to SMB..."] = "Conectando ao SMB...",
    ["Couldn't apply the PS2 IP settings\ntry again or power-cycle the network adapter"] = "Não foi possível aplicar as configurações de IP do PS2\ntente novamente ou reinicie o adaptador de rede",
    ["Couldn't read that game selection"] = "Não foi possível ler essa seleção de jogo",
    ["Couldn't save settings -- POPSTARTER folder NOT deleted"] = "Não foi possível salvar -- pasta POPSTARTER NÃO excluída",
    ["Couldn't save settings -- POPSTARTER folder NOT restored"] = "Não foi possível salvar -- pasta POPSTARTER NÃO restaurada",
    ["Cover art"] = "Capa",
    ["Cover/details folder"] = "Pasta de capas/detalhes",
    ["Credits"] = "Créditos",
    ["DHCP (automatic)"] = "DHCP (automático)",
    ["DHCP failed\nset a static IP in SMB settings"] = "DHCP falhou\ndefina um IP estático nas configurações SMB",
    ["DKWDRV Path"] = "Caminho do DKWDRV",
    ["Defaults restored"] = "Padrões restaurados",
    ["Delete the POPSTARTER folder from the memory card?"] = "Excluir a pasta POPSTARTER do cartão de memória?",
    ["Design by Berion\nScripts by nuno6573 and Ripto\nBased on Enceladus by Daniel Santos\nTesting by P4NCHOL1NO, VizoR, provato,\nnuno6573, oldman63, saildot4k, and Community\n\nSpecial Thanks To:\nkrHACKen for making POPStarter\nuyjulian, fjtrujy, HWC, and others for always helping\n\nThis program is free and open source\nIf you bought it, you have been scammed\n\nCompatibility problems? Visit:\nyoutube.com/@hugopocked6695"] = "Design por Berion\nScripts por nuno6573 e Ripto\nBaseado em Enceladus por Daniel Santos\nTestes por P4NCHOL1NO, VizoR, provato,\nnuno6573, oldman63, saildot4k e Comunidade\n\nAgradecimentos especiais a:\nkrHACKen por criar o POPStarter\nuyjulian, fjtrujy, HWC e outros por sempre ajudarem\n\nEste programa é livre e de código aberto\nSe você pagou por ele, foi enganado\n\nProblemas de compatibilidade? Visite:\nyoutube.com/@hugopocked6695",
    ["Device List"] = "Lista de dispositivos",
    ["Disc (DKWDRV)"] = "Disco (DKWDRV)",
    ["Discard & Exit"] = "Descartar e Sair",
    ["Display"] = "Tela",
    ["Display reverted -- new mode wasn't confirmed"] = "Tela revertida -- novo modo não confirmado",
    ["Edit DKWDRV Path"] = "Editar caminho do DKWDRV",
    ["Edit POPStarter Path"] = "Editar caminho do POPStarter",
    ["Enable the POPSTARTER Folder first\n(BDMA / SMB modules must live on the memory card)"] = "Ative a pasta POPSTARTER primeiro\n(módulos BDMA / SMB devem ficar no cartão de memória)",
    ["Enable the POPSTARTER Folder first\n(SMB modules must live on the memory card)"] = "Ative a pasta POPSTARTER primeiro\n(módulos SMB devem ficar no cartão de memória)",
    ["Exit"] = "Sair",
    ["Failed to connect to SMB"] = "Falha ao conectar ao SMB",
    ["Failed to load HDD"] = "Falha ao carregar HDD",
    ["Failed to load HDD (exFAT)"] = "Falha ao carregar HDD (exFAT)",
    ["Failed to load MMCE"] = "Falha ao carregar MMCE",
    ["Failed to load MX4SIO"] = "Falha ao carregar MX4SIO",
    ["Failed to load USB"] = "Falha ao carregar USB",
    ["Failed to refresh HDD list"] = "Falha ao atualizar lista do HDD",
    ["Failed to refresh list"] = "Falha ao atualizar a lista",
    ["First disc only"] = "Apenas o primeiro disco",
    ["Game List"] = "Lista de jogos",
    ["Game details"] = "Detalhes do jogo",
    ["Game hidden"] = "Jogo ocultado",
    ["Game list cache"] = "Cache da lista de jogos",
    ["Game shown"] = "Jogo exibido",
    ["Games path affects browsing only:\nPOPStarter can only launch games from <share>/POPS"] = "O caminho de jogos afeta só a navegação:\nPOPStarter só inicia jogos de <share>/POPS",
    ["HDD Alt mode needs POPSTARTER on HDD"] = "Modo HDD Alt precisa do POPSTARTER no HDD",
    ["HDD list loaded from cache (R1 rescans)"] = "Lista do HDD carregada do cache (R1 rescaneia)",
    ["HDD list refreshed"] = "Lista do HDD atualizada",
    ["HDD list refreshed (no games found)"] = "Lista do HDD atualizada (nenhum jogo encontrado)",
    ["Hidden"] = "Oculto",
    ["Hidden games"] = "Jogos ocultos",
    ["Hidden games are filtered out.\nPress R3 to reveal them, then L3 to unhide."] = "Jogos ocultos estão filtrados.\nPressione R3 para revelá-los, depois L3 para reexibir.",
    ["Hidden games filtered out again"] = "Jogos ocultos filtrados novamente",
    ["Hide UI Text"] = "Ocultar texto da interface",
    ["How to hide a game"] = "Como ocultar um jogo",
    ["Installed"] = "Instalado",
    ["Internal HDD"] = "HDD interno",
    ["Keep"] = "Manter",
    ["Keep this display mode?"] = "Manter este modo de tela?",
    ["Keyboard Layout"] = "Layout do teclado",
    ["L3 on the game list"] = "L3 na lista de jogos",
    ["Launch"] = "Iniciar",
    ["Launch DKWDRV?"] = "Iniciar DKWDRV?",
    ["Left aligned"] = "Alinhado à esquerda",
    ["List refreshed"] = "Lista atualizada",
    ["List refreshed (no games found)"] = "Lista atualizada (nenhum jogo encontrado)",
    ["Loaded SMB list from cache..."] = "Lista SMB carregada do cache...",
    ["Loading HDD (exFAT)..."] = "Carregando HDD (exFAT)...",
    ["Loading HDD..."] = "Carregando HDD...",
    ["Loading MMCE..."] = "Carregando MMCE...",
    ["Loading MX4SIO..."] = "Carregando MX4SIO...",
    ["Loading USB..."] = "Carregando USB...",
    ["MMCE has no POPS folder\nexpected mmce0:/POPS/"] = "MMCE não tem pasta POPS\nesperado mmce0:/POPS/",
    ["Memory Card"] = "Cartão de memória",
    ["Menu"] = "Menu",
    ["Multi-disc games"] = "Jogos multi-disco",
    ["NetBIOS isn't supported\nset Address type = IP + a Server IP"] = "NetBIOS não é suportado\ndefina Tipo de endereço = IP + um IP do servidor",
    ["No"] = "Não",
    ["No MMCE device detected\nchecked mmce0: and mmce1:"] = "Nenhum dispositivo MMCE detectado\nverificado mmce0: e mmce1:",
    ["No MX4SIO device detected"] = "Nenhum dispositivo MX4SIO detectado",
    ["No Share selected"] = "Nenhum Share selecionado",
    ["No Share set in SMB settings\n(server returned no shares)"] = "Nenhum Share definido nas configurações SMB\n(servidor não retornou shares)",
    ["No USB backend detected\nreseat the drive and try again"] = "Nenhum backend USB detectado\nreconecte o drive e tente novamente",
    ["No exFAT HDD detected\nformat the internal drive exFAT (BDMA Mode = ATA)"] = "Nenhum HDD exFAT detectado\nformate o drive interno em exFAT (Modo BDMA = ATA)",
    ["No games found"] = "Nenhum jogo encontrado",
    ["No games found on hdd0:\n(__.POPS partitions are empty)"] = "Nenhum jogo encontrado em hdd0:\n(partições __.POPS estão vazias)",
    ["No games found on this device"] = "Nenhum jogo encontrado neste dispositivo",
    ["No network link\ncheck the Ethernet cable / adapter"] = "Sem link de rede\nverifique o cabo / adaptador Ethernet",
    ["Not implemented yet"] = "Ainda não implementado",
    ["Not installed"] = "Não instalado",
    ["Off"] = "Desligado",
    ["Off (deleted)"] = "Desligado (excluído)",
    ["On"] = "Ligado",
    ["On (default)"] = "Ligado (padrão)",
    ["On (per-device)"] = "Ligado (por dispositivo)",
    ["Opening SMB list..."] = "Abrindo lista SMB...",
    ["Overscan (CRT inset)"] = "Overscan (recuo CRT)",
    ["POPSLoader\nfor POPStarter"] = "POPSLoader\npara POPStarter",
    ["POPSTARTER Folder"] = "Pasta POPSTARTER",
    ["POPSTARTER Path"] = "Caminho do POPSTARTER",
    ["POPSTARTER folder deleted from the memory card"] = "Pasta POPSTARTER excluída do cartão de memória",
    ["POPSTARTER folder restored on the memory card\n(set a BDMA mode to re-add the exFAT/SMB modules)"] = "Pasta POPSTARTER restaurada no cartão de memória\n(defina um modo BDMA para readicionar os módulos exFAT/SMB)",
    ["Press CIRCLE again to discard what you typed"] = "Pressione CIRCLE novamente para descartar o que digitou",
    ["Press CROSS again to discard what you typed"] = "Pressione CROSS novamente para descartar o que digitou",
    ["Rebuilding HDD game list..."] = "Reconstruindo lista de jogos do HDD...",
    ["Refreshing HDD list..."] = "Atualizando lista do HDD...",
    ["Refreshing list..."] = "Atualizando lista...",
    ["Rescanning HDD partitions..."] = "Rescaneando partições do HDD...",
    ["Reset"] = "Redefinir",
    ["Reset Defaults"] = "Restaurar padrões",
    ["Retrying USB scan..."] = "Tentando escanear USB novamente...",
    ["Return to OSDSYS?"] = "Voltar ao OSDSYS?",
    ["Revert"] = "Reverter",
    ["Right aligned"] = "Alinhado à direita",
    ["SMB / Network"] = "SMB / Rede",
    ["SMB connect failed"] = "Falha na conexão SMB",
    ["SMB connection dropped"] = "Conexão SMB perdida",
    ["SMB login failed\ncheck User / Password"] = "Falha no login SMB\nverifique Usuário / Senha",
    ["SMB modules"] = "Módulos SMB",
    ["SMB modules are not installed\nGames list but won't boot without them --\ninstall via Settings > SMB modules, then Save"] = "Módulos SMB não instalados\nJogos aparecem mas não iniciam sem eles --\ninstale em Configurações > Módulos SMB, depois Salvar",
    ["SMB modules are not installed\nGames will list but won't boot -- install them\nvia Settings > SMB modules first"] = "Módulos SMB não instalados\nJogos aparecem mas não iniciam -- instale-os\nprimeiro em Configurações > Módulos SMB",
    ["SMB modules didn't install/remove\nmodule setting reverted; other settings were saved"] = "Módulos SMB não instalados/removidos\nconfiguração de módulos revertida; outras foram salvas",
    ["SMB modules failed to load"] = "Falha ao carregar módulos SMB",
    ["Save"] = "Salvar",
    ["Save Changes"] = "Salvar alterações",
    ["Saving settings"] = "Salvando configurações",
    ["Saving..."] = "Salvando...",
    ["Saving/Applying..."] = "Salvando/Aplicando...",
    ["Scanning HDD partitions..."] = "Escaneando partições do HDD...",
    ["Scanning MMCE games..."] = "Escaneando jogos do MMCE...",
    ["Scanning MX4SIO games..."] = "Escaneando jogos do MX4SIO...",
    ["Scanning SMB games..."] = "Escaneando jogos do SMB...",
    ["Scanning exFAT HDD games..."] = "Escaneando jogos do HDD exFAT...",
    ["Scanning games..."] = "Escaneando jogos...",
    ["Select"] = "Selecionar",
    ["Select a share"] = "Selecione um share",
    ["Server refused SMBv1\nenable SMBv1 support on the host"] = "Servidor recusou SMBv1\native o suporte a SMBv1 no host",
    ["Settings"] = "Configurações",
    ["Share not found\ncheck the Share name (host must allow SMB1)"] = "Share não encontrado\nverifique o nome do Share (host deve permitir SMB1)",
    ["Show all discs"] = "Mostrar todos os discos",
    ["Showing hidden games (dimmed) -- press L3 to unhide"] = "Mostrando jogos ocultos (esmaecidos) -- pressione L3 para reexibir",
    ["Shown"] = "Exibido",
    ["Staging drivers for this device"] = "A preparar os controladores para este dispositivo",
    ["Starting the game..."] = "A iniciar o jogo...",
    ["Startup"] = "Inicialização",
    ["Static (manual)"] = "Estático (manual)",
    ["Storage"] = "Armazenamento",
    ["This backend isn't implemented yet"] = "Este backend ainda não foi implementado",
    ["UI text hidden"] = "Texto da interface ocultado",
    ["UI text shown"] = "Texto da interface exibido",
    ["Video Standard"] = "Padrão de vídeo",
    ["Visible"] = "Visível",
    ["Visible (manage)"] = "Visível (gerenciar)",
    ["Working..."] = "Trabalhando...",
    ["Yes"] = "Sim",
    -- EXP34: fill currently-used strings that were untranslated (machine-assisted)
    ["(could NOT save -- reverts on reboot)"] = "(NÃO foi possível salvar -- revertido ao reiniciar)",
    ["(the usual settings location wasn't writable)"] = "(o local usual das configurações não era gravável)",
    ["-- launch cancelled"] = "-- lançamento cancelado",
    ["Adaptive BDMA couldn't stage"] = "BDMA adaptativo não pôde preparar",
    ["Applying SMB modules"] = "Aplicando módulos SMB",
    ["BDMA source backend not ready:"] = "Backend de origem BDMA não está pronto:",
    ["BOOT.ELF failed to launch"] = "Falha ao iniciar BOOT.ELF",
    ["Booted from:"] = "Iniciado a partir de:",
    ["Cannot access"] = "Não é possível acessar",
    ["Case/Symbols: UPPER  (R2)"] = "Maiúsc./Símbolos: MAIÚSC  (R2)",
    ["Case/Symbols: lower  (R2)"] = "Maiúsc./Símbolos: minúsc  (R2)",
    ["Couldn't restore BDMA mode"] = "Não foi possível restaurar o modo BDMA",
    ["Couldn't save settings"] = "Não foi possível salvar as configurações",
    ["Couldn't update hidden state"] = "Não foi possível atualizar o estado oculto",
    ["Couldn't write .hide to the HDD"] = "Não foi possível gravar .hide no HDD",
    ["Cursor: L1 / R1"] = "Cursor: L1 / R1",
    ["DKWDRV failed to launch"] = "Falha ao iniciar DKWDRV",
    ["Edit"] = "Editar",
    ["Edit %s"] = "Editar %s",
    ["Game file missing"] = "Arquivo do jogo ausente",
    ["HDD dir read failed:"] = "Falha ao ler o diretório do HDD:",
    ["HDD not usable"] = "HDD não utilizável",
    ["Hidden games are already shown here (dimmed)\nEnable \"Hide hidden games\" in Settings to filter them out"] = "Os jogos ocultos já são exibidos aqui (esmaecidos)\nAtive \"Ocultar jogos ocultos\" nas Configurações para filtrá-los",
    ["Locating exFAT HDD POPS folder..."] = "Localizando a pasta POPS do HDD exFAT...",
    ["Looking for USB drive..."] = "Procurando unidade USB...",
    ["Missing BDMA UI source (tried):"] = "Origem da interface BDMA ausente (tentado):",
    ["Missing BDMA source (tried):"] = "Origem BDMA ausente (tentado):",
    ["Missing SMB module (tried):"] = "Módulo SMB ausente (tentado):",
    ["No '__.POPS' partitions on hdd0:\nformat one with __.POPS / __.POPS0...9"] = "Nenhuma partição '__.POPS' em hdd0:\nformate uma com __.POPS / __.POPS0...9",
    ["No DKWDRV found at this path"] = "Nenhum DKWDRV encontrado neste caminho",
    ["No POPSTARTER found at this path"] = "Nenhum POPSTARTER encontrado neste caminho",
    ["Path saved, file not found:"] = "Caminho salvo, arquivo não encontrado:",
    ["Resolved:"] = "Resolvido:",
    ["Reverting in"] = "Revertendo em",
    ["Saved to"] = "Salvo em",
    ["Slot:"] = "Slot:",
    ["The internal drive is still starting\nopen this page again in a moment"] = "A unidade interna ainda está iniciando\nabra esta página novamente em instantes",
    ["Triangle"] = "Triângulo",
    ["Unknown BDMA mode:"] = "Modo BDMA desconhecido:",
    ["You can still add a \"<game>.hide\" next to the .VCD from a PC."] = "Você ainda pode adicionar um \"<jogo>.hide\" ao lado do .VCD a partir de um PC.",
    ["adjusted -- using"] = "ajustado -- usando",
    ["check the memory card, or turn Adaptive BDMA off"] = "verifique o cartão de memória ou desative o BDMA adaptativo",
    ["if not confirmed"] = "se não confirmado",
    ["re-select it under Settings > Storage to restage"] = "selecione-o novamente em Configurações > Armazenamento para repreparar",
    ["return code:"] = "código de retorno:",
    ["status:"] = "status:",
  },
  ES = {
    ["(not set)"] = "(sin definir)",
    ["(share root)"] = "(raíz del recurso)",
    ["(unknown)"] = "(desconocido)",
    ["100M Full"] = "100M completo",
    ["100M Half"] = "100M medio",
    ["10M Full"] = "10M completo",
    ["10M Half"] = "10M medio",
    ["APA / PFS (default)"] = "APA / PFS (predet.)",
    ["About"] = "Acerca de",
    ["Actual output"] = "Salida real",
    ["Adaptive BDMA"] = "BDMA adaptativo",
    ["Applying BDMA mode"] = "Aplicando modo BDMA",
    ["At least one device must stay on the carousel"] = "Al menos un dispositivo debe permanecer en el carrusel",
    ["Auto (console region)"] = "Auto (región de consola)",
    ["Automatic"] = "Automático",
    ["BDMA Mode"] = "Modo BDMA",
    ["BDMA mode change didn't apply\nBDMA reverted; other settings were saved"] = "No se aplicó el cambio de modo BDMA\nBDMA revertido; se guardaron los demás ajustes",
    ["BOOT.ELF not found\nchecked mc0:/BOOT and mc1:/BOOT"] = "BOOT.ELF no encontrado\nse revisó mc0:/BOOT y mc1:/BOOT",
    ["Back"] = "Atrás",
    ["Backspace"] = "Retroceso",
    ["Boot Page"] = "Página de inicio",
    ["Boot sound"] = "Sonido de inicio",
    ["Bringing up network..."] = "Activando la red...",
    ["Building HDD game list..."] = "Creando lista de juegos HDD...",
    ["Building USB game list..."] = "Creando lista de juegos USB...",
    ["Can't disable while Adaptive BDMA is on\nTurn Adaptive BDMA off first"] = "No se puede desactivar con BDMA adaptativo activo\nDesactiva BDMA adaptativo primero",
    ["Can't disable while BDMA is enabled\nSet BDMA Mode to FAT32 (None) first"] = "No se puede desactivar con BDMA activado\nPon Modo BDMA en FAT32 (None) primero",
    ["Can't disable while SMB modules are installed\nSet SMB modules to Not installed first"] = "No se puede desactivar con módulos SMB instalados\nPon los módulos SMB en No instalado primero",
    ["Can't reach the server\ncheck Server IP / Port in SMB settings"] = "No se puede contactar al servidor\nrevisa IP / puerto del servidor en ajustes SMB",
    ["Cancel"] = "Cancelar",
    ["Carousel (default)"] = "Carrusel (predet.)",
    ["Center aligned"] = "Centrado",
    ["Checking POPSTARTER..."] = "Comprobando POPSTARTER...",
    ["Checking the game file..."] = "Comprobando el archivo del juego...",
    ["Code by El_isra"] = "Código de El_isra",
    ["Confirm"] = "Confirmar",
    ["Connecting to SMB..."] = "Conectando a SMB...",
    ["Couldn't apply the PS2 IP settings\ntry again or power-cycle the network adapter"] = "No se pudieron aplicar los ajustes de IP de la PS2\nreintenta o reinicia el adaptador de red",
    ["Couldn't read that game selection"] = "No se pudo leer esa selección de juego",
    ["Couldn't save settings -- POPSTARTER folder NOT deleted"] = "No se pudieron guardar los ajustes -- carpeta POPSTARTER NO eliminada",
    ["Couldn't save settings -- POPSTARTER folder NOT restored"] = "No se pudieron guardar los ajustes -- carpeta POPSTARTER NO restaurada",
    ["Cover art"] = "Carátulas",
    ["Cover/details folder"] = "Carpeta de carátulas/detalles",
    ["Credits"] = "Créditos",
    ["DHCP (automatic)"] = "DHCP (automático)",
    ["DHCP failed\nset a static IP in SMB settings"] = "DHCP falló\nconfigura una IP estática en ajustes SMB",
    ["DKWDRV Path"] = "Ruta de DKWDRV",
    ["Defaults restored"] = "Valores predeterminados restaurados",
    ["Delete the POPSTARTER folder from the memory card?"] = "¿Eliminar la carpeta POPSTARTER de la tarjeta de memoria?",
    ["Design by Berion\nScripts by nuno6573 and Ripto\nBased on Enceladus by Daniel Santos\nTesting by P4NCHOL1NO, VizoR, provato,\nnuno6573, oldman63, saildot4k, and Community\n\nSpecial Thanks To:\nkrHACKen for making POPStarter\nuyjulian, fjtrujy, HWC, and others for always helping\n\nThis program is free and open source\nIf you bought it, you have been scammed\n\nCompatibility problems? Visit:\nyoutube.com/@hugopocked6695"] = "Diseño de Berion\nScripts de nuno6573 y Ripto\nBasado en Enceladus de Daniel Santos\nPruebas de P4NCHOL1NO, VizoR, provato,\nnuno6573, oldman63, saildot4k y la comunidad\n\nAgradecimientos especiales a:\nkrHACKen por crear POPStarter\nuyjulian, fjtrujy, HWC y otros por ayudar siempre\n\nEste programa es libre y de código abierto\nSi lo compraste, te estafaron\n\n¿Problemas de compatibilidad? Visita:\nyoutube.com/@hugopocked6695",
    ["Device List"] = "Lista de dispositivos",
    ["Disc (DKWDRV)"] = "Disco (DKWDRV)",
    ["Discard & Exit"] = "Descartar y salir",
    ["Display"] = "Pantalla",
    ["Display reverted -- new mode wasn't confirmed"] = "Pantalla revertida -- el nuevo modo no se confirmó",
    ["Edit DKWDRV Path"] = "Editar ruta de DKWDRV",
    ["Edit POPStarter Path"] = "Editar ruta de POPStarter",
    ["Enable the POPSTARTER Folder first\n(BDMA / SMB modules must live on the memory card)"] = "Activa primero la carpeta POPSTARTER\n(los módulos BDMA / SMB deben estar en la tarjeta de memoria)",
    ["Enable the POPSTARTER Folder first\n(SMB modules must live on the memory card)"] = "Activa primero la carpeta POPSTARTER\n(los módulos SMB deben estar en la tarjeta de memoria)",
    ["Enter"] = "Intro",
    ["Exit"] = "Salir",
    ["Failed to connect to SMB"] = "No se pudo conectar a SMB",
    ["Failed to load HDD"] = "No se pudo cargar HDD",
    ["Failed to load HDD (exFAT)"] = "No se pudo cargar HDD (exFAT)",
    ["Failed to load MMCE"] = "No se pudo cargar MMCE",
    ["Failed to load MX4SIO"] = "No se pudo cargar MX4SIO",
    ["Failed to load USB"] = "No se pudo cargar USB",
    ["Failed to refresh HDD list"] = "No se pudo actualizar la lista HDD",
    ["Failed to refresh list"] = "No se pudo actualizar la lista",
    ["First disc only"] = "Solo el primer disco",
    ["Game List"] = "Lista de juegos",
    ["Game details"] = "Detalles del juego",
    ["Game hidden"] = "Juego oculto",
    ["Game list cache"] = "Caché de lista de juegos",
    ["Game shown"] = "Juego mostrado",
    ["Games path affects browsing only:\nPOPStarter can only launch games from <share>/POPS"] = "La ruta de juegos solo afecta la navegación:\nPOPStarter solo puede iniciar juegos desde <share>/POPS",
    ["HDD Alt mode needs POPSTARTER on HDD"] = "El modo HDD Alt necesita POPSTARTER en HDD",
    ["HDD list loaded from cache (R1 rescans)"] = "Lista HDD cargada desde caché (R1 reexplora)",
    ["HDD list refreshed"] = "Lista HDD actualizada",
    ["HDD list refreshed (no games found)"] = "Lista HDD actualizada (sin juegos)",
    ["Hidden"] = "Oculto",
    ["Hidden games"] = "Juegos ocultos",
    ["Hidden games are filtered out.\nPress R3 to reveal them, then L3 to unhide."] = "Los juegos ocultos están filtrados.\nPulsa R3 para revelarlos, luego L3 para mostrarlos.",
    ["Hidden games filtered out again"] = "Juegos ocultos filtrados de nuevo",
    ["Hide UI Text"] = "Ocultar texto de interfaz",
    ["How to hide a game"] = "Cómo ocultar un juego",
    ["Installed"] = "Instalado",
    ["Internal HDD"] = "HDD interno",
    ["Keep"] = "Mantener",
    ["Keep this display mode?"] = "¿Mantener este modo de pantalla?",
    ["Keyboard Layout"] = "Distribución del teclado",
    ["L3 on the game list"] = "L3 en la lista de juegos",
    ["Launch"] = "Iniciar",
    ["Launch DKWDRV?"] = "¿Iniciar DKWDRV?",
    ["Left aligned"] = "Alineado a la izquierda",
    ["List refreshed"] = "Lista actualizada",
    ["List refreshed (no games found)"] = "Lista actualizada (sin juegos)",
    ["Loaded SMB list from cache..."] = "Lista SMB cargada desde caché...",
    ["Loading HDD (exFAT)..."] = "Cargando HDD (exFAT)...",
    ["Loading HDD..."] = "Cargando HDD...",
    ["Loading MMCE..."] = "Cargando MMCE...",
    ["Loading MX4SIO..."] = "Cargando MX4SIO...",
    ["Loading USB..."] = "Cargando USB...",
    ["MMCE has no POPS folder\nexpected mmce0:/POPS/"] = "MMCE no tiene carpeta POPS\nse esperaba mmce0:/POPS/",
    ["Memory Card"] = "Tarjeta de memoria",
    ["Menu"] = "Menú",
    ["Multi-disc games"] = "Juegos multidisco",
    ["NetBIOS isn't supported\nset Address type = IP + a Server IP"] = "NetBIOS no es compatible\npon Tipo de dirección = IP + una IP de servidor",
    ["No"] = "No",
    ["No MMCE device detected\nchecked mmce0: and mmce1:"] = "No se detectó dispositivo MMCE\nse revisó mmce0: y mmce1:",
    ["No MX4SIO device detected"] = "No se detectó dispositivo MX4SIO",
    ["No Share selected"] = "Sin recurso seleccionado",
    ["No Share set in SMB settings\n(server returned no shares)"] = "Sin recurso definido en ajustes SMB\n(el servidor no devolvió recursos)",
    ["No USB backend detected\nreseat the drive and try again"] = "No se detectó backend USB\nreconecta la unidad e inténtalo de nuevo",
    ["No exFAT HDD detected\nformat the internal drive exFAT (BDMA Mode = ATA)"] = "No se detectó HDD exFAT\nformatea la unidad interna en exFAT (Modo BDMA = ATA)",
    ["No games found"] = "No se encontraron juegos",
    ["No games found on hdd0:\n(__.POPS partitions are empty)"] = "No se encontraron juegos en hdd0:\n(las particiones __.POPS están vacías)",
    ["No games found on this device"] = "No se encontraron juegos en este dispositivo",
    ["No network link\ncheck the Ethernet cable / adapter"] = "Sin enlace de red\nrevisa el cable / adaptador Ethernet",
    ["Not implemented yet"] = "Aún no implementado",
    ["Not installed"] = "No instalado",
    ["Off"] = "Desactivado",
    ["Off (deleted)"] = "Desactivado (eliminado)",
    ["On"] = "Activado",
    ["On (default)"] = "Activado (predet.)",
    ["On (per-device)"] = "Activado (por dispositivo)",
    ["Opening SMB list..."] = "Abriendo lista SMB...",
    ["Overscan (CRT inset)"] = "Overscan (margen CRT)",
    ["POPSLoader\nfor POPStarter"] = "POPSLoader\npara POPStarter",
    ["POPSTARTER Folder"] = "Carpeta POPSTARTER",
    ["POPSTARTER Path"] = "Ruta de POPSTARTER",
    ["POPSTARTER folder deleted from the memory card"] = "Carpeta POPSTARTER eliminada de la tarjeta de memoria",
    ["POPSTARTER folder restored on the memory card\n(set a BDMA mode to re-add the exFAT/SMB modules)"] = "Carpeta POPSTARTER restaurada en la tarjeta de memoria\n(elige un modo BDMA para volver a añadir los módulos exFAT/SMB)",
    ["Press CIRCLE again to discard what you typed"] = "Pulsa CIRCLE de nuevo para descartar lo escrito",
    ["Press CROSS again to discard what you typed"] = "Pulsa CROSS de nuevo para descartar lo escrito",
    ["Rebuilding HDD game list..."] = "Recreando lista de juegos HDD...",
    ["Refreshing HDD list..."] = "Actualizando lista HDD...",
    ["Refreshing list..."] = "Actualizando lista...",
    ["Rescanning HDD partitions..."] = "Reexplorando particiones HDD...",
    ["Reset"] = "Restablecer",
    ["Reset Defaults"] = "Restablecer valores",
    ["Retrying USB scan..."] = "Reintentando escaneo USB...",
    ["Return to OSDSYS?"] = "¿Volver a OSDSYS?",
    ["Revert"] = "Revertir",
    ["Right aligned"] = "Alineado a la derecha",
    ["SMB / Network"] = "SMB / Red",
    ["SMB connect failed"] = "Falló la conexión SMB",
    ["SMB connection dropped"] = "Conexión SMB perdida",
    ["SMB login failed\ncheck User / Password"] = "Falló el inicio de sesión SMB\nrevisa Usuario / Contraseña",
    ["SMB modules"] = "Módulos SMB",
    ["SMB modules are not installed\nGames list but won't boot without them --\ninstall via Settings > SMB modules, then Save"] = "Los módulos SMB no están instalados\nLos juegos aparecen pero no arrancan sin ellos --\ninstala en Ajustes > Módulos SMB, luego Guardar",
    ["SMB modules are not installed\nGames will list but won't boot -- install them\nvia Settings > SMB modules first"] = "Los módulos SMB no están instalados\nLos juegos aparecen pero no arrancan -- instálalos\nprimero en Ajustes > Módulos SMB",
    ["SMB modules didn't install/remove\nmodule setting reverted; other settings were saved"] = "Los módulos SMB no se instalaron/quitaron\najuste de módulo revertido; se guardaron los demás ajustes",
    ["SMB modules failed to load"] = "No se pudieron cargar los módulos SMB",
    ["Save"] = "Guardar",
    ["Save Changes"] = "Guardar cambios",
    ["Saving settings"] = "Guardando ajustes",
    ["Saving..."] = "Guardando...",
    ["Saving/Applying..."] = "Guardando/Aplicando...",
    ["Scanning HDD partitions..."] = "Escaneando particiones HDD...",
    ["Scanning MMCE games..."] = "Escaneando juegos MMCE...",
    ["Scanning MX4SIO games..."] = "Escaneando juegos MX4SIO...",
    ["Scanning SMB games..."] = "Escaneando juegos SMB...",
    ["Scanning exFAT HDD games..."] = "Escaneando juegos HDD exFAT...",
    ["Scanning games..."] = "Escaneando juegos...",
    ["Select"] = "Seleccionar",
    ["Select a share"] = "Selecciona un recurso",
    ["Server refused SMBv1\nenable SMBv1 support on the host"] = "El servidor rechazó SMBv1\nactiva la compatibilidad con SMBv1 en el host",
    ["Settings"] = "Ajustes",
    ["Share not found\ncheck the Share name (host must allow SMB1)"] = "Recurso no encontrado\nrevisa el nombre del recurso (el host debe permitir SMB1)",
    ["Show all discs"] = "Mostrar todos los discos",
    ["Showing hidden games (dimmed) -- press L3 to unhide"] = "Mostrando juegos ocultos (atenuados) -- pulsa L3 para mostrarlos",
    ["Shown"] = "Mostrado",
    ["Staging drivers for this device"] = "Preparando los controladores para este dispositivo",
    ["Starting the game..."] = "Iniciando el juego...",
    ["Startup"] = "Arranque",
    ["Static (manual)"] = "Estática (manual)",
    ["Storage"] = "Almacenamiento",
    ["This backend isn't implemented yet"] = "Este backend aún no está implementado",
    ["UI text hidden"] = "Texto de interfaz oculto",
    ["UI text shown"] = "Texto de interfaz mostrado",
    ["Video Standard"] = "Estándar de vídeo",
    ["Visible (manage)"] = "Visible (gestionar)",
    ["Working..."] = "Trabajando...",
    ["Yes"] = "Sí",
    -- EXP34: fill currently-used strings that were untranslated (machine-assisted)
    ["(could NOT save -- reverts on reboot)"] = "(NO se pudo guardar -- se revierte al reiniciar)",
    ["(the usual settings location wasn't writable)"] = "(la ubicación habitual de ajustes no admitía escritura)",
    ["-- launch cancelled"] = "-- lanzamiento cancelado",
    ["Adaptive BDMA couldn't stage"] = "BDMA adaptativo no pudo preparar",
    ["Applying SMB modules"] = "Aplicando módulos SMB",
    ["BDMA source backend not ready:"] = "Backend de origen BDMA no está listo:",
    ["BOOT.ELF failed to launch"] = "No se pudo iniciar BOOT.ELF",
    ["Booted from:"] = "Arrancado desde:",
    ["Cannot access"] = "No se puede acceder",
    ["Case/Symbols: UPPER  (R2)"] = "Mayús/Símbolos: MAYÚS  (R2)",
    ["Case/Symbols: lower  (R2)"] = "Mayús/Símbolos: minús  (R2)",
    ["Couldn't restore BDMA mode"] = "No se pudo restaurar el modo BDMA",
    ["Couldn't save settings"] = "No se pudieron guardar los ajustes",
    ["Couldn't update hidden state"] = "No se pudo actualizar el estado oculto",
    ["Couldn't write .hide to the HDD"] = "No se pudo escribir .hide en el HDD",
    ["Cursor: L1 / R1"] = "Cursor: L1 / R1",
    ["DKWDRV failed to launch"] = "No se pudo iniciar DKWDRV",
    ["Edit"] = "Editar",
    ["Edit %s"] = "Editar %s",
    ["Game file missing"] = "Falta el archivo del juego",
    ["HDD dir read failed:"] = "Error al leer el directorio del HDD:",
    ["HDD not usable"] = "HDD no utilizable",
    ["Hidden games are already shown here (dimmed)\nEnable \"Hide hidden games\" in Settings to filter them out"] = "Los juegos ocultos ya se muestran aquí (atenuados)\nActiva \"Ocultar juegos ocultos\" en Ajustes para filtrarlos",
    ["Locating exFAT HDD POPS folder..."] = "Localizando la carpeta POPS del HDD exFAT...",
    ["Looking for USB drive..."] = "Buscando unidad USB...",
    ["Missing BDMA UI source (tried):"] = "Falta la fuente de interfaz BDMA (probado):",
    ["Missing BDMA source (tried):"] = "Falta la fuente BDMA (probado):",
    ["Missing SMB module (tried):"] = "Falta el módulo SMB (probado):",
    ["No '__.POPS' partitions on hdd0:\nformat one with __.POPS / __.POPS0...9"] = "No hay particiones '__.POPS' en hdd0:\nformatea una con __.POPS / __.POPS0...9",
    ["No DKWDRV found at this path"] = "No se encontró DKWDRV en esta ruta",
    ["No POPSTARTER found at this path"] = "No se encontró POPSTARTER en esta ruta",
    ["Path saved, file not found:"] = "Ruta guardada, archivo no encontrado:",
    ["Resolved:"] = "Resuelto:",
    ["Reverting in"] = "Revirtiendo en",
    ["Saved to"] = "Guardado en",
    ["Slot:"] = "Ranura:",
    ["The internal drive is still starting\nopen this page again in a moment"] = "La unidad interna aún está iniciando\nabre esta página de nuevo en un momento",
    ["Triangle"] = "Triángulo",
    ["Unknown BDMA mode:"] = "Modo BDMA desconocido:",
    ["You can still add a \"<game>.hide\" next to the .VCD from a PC."] = "Aún puedes añadir un \"<juego>.hide\" junto al .VCD desde un PC.",
    ["adjusted -- using"] = "ajustado -- usando",
    ["check the memory card, or turn Adaptive BDMA off"] = "comprueba la tarjeta de memoria o desactiva el BDMA adaptativo",
    ["if not confirmed"] = "si no se confirma",
    ["re-select it under Settings > Storage to restage"] = "vuelve a seleccionarlo en Ajustes > Almacenamiento para reprepararlo",
    ["return code:"] = "código de retorno:",
    ["status:"] = "estado:",
  },
  IT = {
    ["(not set)"] = "(non impostato)",
    ["(share root)"] = "(radice condivisione)",
    ["(unknown)"] = "(sconosciuto)",
    ["APA / PFS (default)"] = "APA / PFS (predefinito)",
    ["About"] = "Informazioni",
    ["Actual output"] = "Uscita effettiva",
    ["Adaptive BDMA"] = "BDMA adattivo",
    ["Applying BDMA mode"] = "Applicazione modalità BDMA",
    ["At least one device must stay on the carousel"] = "Almeno un dispositivo deve restare nel carosello",
    ["Auto (console region)"] = "Auto (regione console)",
    ["Automatic"] = "Automatico",
    ["BDMA Mode"] = "Modalità BDMA",
    ["BDMA mode change didn't apply\nBDMA reverted; other settings were saved"] = "Modifica modalità BDMA non applicata\nBDMA ripristinato; altre impostazioni salvate",
    ["BOOT.ELF not found\nchecked mc0:/BOOT and mc1:/BOOT"] = "BOOT.ELF non trovato\ncontrollati mc0:/BOOT e mc1:/BOOT",
    ["Back"] = "Indietro",
    ["Boot Page"] = "Pagina di avvio",
    ["Boot sound"] = "Suono di avvio",
    ["Bringing up network..."] = "Attivazione rete...",
    ["Building HDD game list..."] = "Creazione lista giochi HDD...",
    ["Building USB game list..."] = "Creazione lista giochi USB...",
    ["Can't disable while Adaptive BDMA is on\nTurn Adaptive BDMA off first"] = "Impossibile disattivare con BDMA adattivo attivo\nDisattiva prima BDMA adattivo",
    ["Can't disable while BDMA is enabled\nSet BDMA Mode to FAT32 (None) first"] = "Impossibile disattivare con BDMA abilitato\nImposta prima Modalità BDMA su FAT32 (Nessuno)",
    ["Can't disable while SMB modules are installed\nSet SMB modules to Not installed first"] = "Impossibile disattivare con i moduli SMB installati\nImposta prima Moduli SMB su Non installati",
    ["Can't reach the server\ncheck Server IP / Port in SMB settings"] = "Impossibile raggiungere il server\ncontrolla IP server / Porta nelle impostazioni SMB",
    ["Cancel"] = "Annulla",
    ["Carousel (default)"] = "Carosello (predefinito)",
    ["Center aligned"] = "Allineato al centro",
    ["Checking POPSTARTER..."] = "Verifica di POPSTARTER...",
    ["Checking the game file..."] = "Verifica del file di gioco...",
    ["Code by El_isra"] = "Codice di El_isra",
    ["Confirm"] = "Conferma",
    ["Connecting to SMB..."] = "Connessione a SMB...",
    ["Couldn't apply the PS2 IP settings\ntry again or power-cycle the network adapter"] = "Impossibile applicare le impostazioni IP PS2\nriprova o riavvia l'adattatore di rete",
    ["Couldn't read that game selection"] = "Impossibile leggere la selezione del gioco",
    ["Couldn't save settings -- POPSTARTER folder NOT deleted"] = "Impossibile salvare le impostazioni -- cartella POPSTARTER NON eliminata",
    ["Couldn't save settings -- POPSTARTER folder NOT restored"] = "Impossibile salvare le impostazioni -- cartella POPSTARTER NON ripristinata",
    ["Cover art"] = "Copertine",
    ["Cover/details folder"] = "Cartella copertine/dettagli",
    ["Credits"] = "Crediti",
    ["DHCP (automatic)"] = "DHCP (automatico)",
    ["DHCP failed\nset a static IP in SMB settings"] = "DHCP non riuscito\nimposta un IP statico nelle impostazioni SMB",
    ["DKWDRV Path"] = "Percorso DKWDRV",
    ["Defaults restored"] = "Predefiniti ripristinati",
    ["Delete the POPSTARTER folder from the memory card?"] = "Eliminare la cartella POPSTARTER dalla memory card?",
    ["Design by Berion\nScripts by nuno6573 and Ripto\nBased on Enceladus by Daniel Santos\nTesting by P4NCHOL1NO, VizoR, provato,\nnuno6573, oldman63, saildot4k, and Community\n\nSpecial Thanks To:\nkrHACKen for making POPStarter\nuyjulian, fjtrujy, HWC, and others for always helping\n\nThis program is free and open source\nIf you bought it, you have been scammed\n\nCompatibility problems? Visit:\nyoutube.com/@hugopocked6695"] = "Design di Berion\nScript di nuno6573 e Ripto\nBasato su Enceladus di Daniel Santos\nTest di P4NCHOL1NO, VizoR, provato,\nnuno6573, oldman63, saildot4k e la Community\n\nRingraziamenti speciali a:\nkrHACKen per aver creato POPStarter\nuyjulian, fjtrujy, HWC e altri per l'aiuto costante\n\nQuesto programma è gratuito e open source\nSe l'hai pagato, sei stato truffato\n\nProblemi di compatibilità? Visita:\nyoutube.com/@hugopocked6695",
    ["Device List"] = "Elenco dispositivi",
    ["Disc (DKWDRV)"] = "Disco (DKWDRV)",
    ["Discard & Exit"] = "Scarta ed esci",
    ["Display"] = "Schermo",
    ["Display reverted -- new mode wasn't confirmed"] = "Schermo ripristinato -- nuova modalità non confermata",
    ["Edit DKWDRV Path"] = "Modifica percorso DKWDRV",
    ["Edit POPStarter Path"] = "Modifica percorso POPStarter",
    ["Enable the POPSTARTER Folder first\n(BDMA / SMB modules must live on the memory card)"] = "Attiva prima la cartella POPSTARTER\n(i moduli BDMA / SMB devono stare sulla memory card)",
    ["Enable the POPSTARTER Folder first\n(SMB modules must live on the memory card)"] = "Attiva prima la cartella POPSTARTER\n(i moduli SMB devono stare sulla memory card)",
    ["Enter"] = "Invio",
    ["Exit"] = "Esci",
    ["FAT32-USB (None)"] = "FAT32-USB (Nessuno)",
    ["Failed to connect to SMB"] = "Connessione a SMB non riuscita",
    ["Failed to load HDD"] = "Caricamento HDD non riuscito",
    ["Failed to load HDD (exFAT)"] = "Caricamento HDD (exFAT) non riuscito",
    ["Failed to load MMCE"] = "Caricamento MMCE non riuscito",
    ["Failed to load MX4SIO"] = "Caricamento MX4SIO non riuscito",
    ["Failed to load USB"] = "Caricamento USB non riuscito",
    ["Failed to refresh HDD list"] = "Aggiornamento lista HDD non riuscito",
    ["Failed to refresh list"] = "Aggiornamento lista non riuscito",
    ["First disc only"] = "Solo primo disco",
    ["Game List"] = "Lista giochi",
    ["Game details"] = "Dettagli gioco",
    ["Game hidden"] = "Gioco nascosto",
    ["Game list cache"] = "Cache lista giochi",
    ["Game shown"] = "Gioco mostrato",
    ["Games path affects browsing only:\nPOPStarter can only launch games from <share>/POPS"] = "Il percorso giochi riguarda solo la navigazione:\nPOPStarter avvia i giochi solo da <share>/POPS",
    ["HDD Alt mode needs POPSTARTER on HDD"] = "La modalità HDD Alt richiede POPSTARTER su HDD",
    ["HDD list loaded from cache (R1 rescans)"] = "Lista HDD caricata dalla cache (R1 riscansiona)",
    ["HDD list refreshed"] = "Lista HDD aggiornata",
    ["HDD list refreshed (no games found)"] = "Lista HDD aggiornata (nessun gioco trovato)",
    ["Hidden"] = "Nascosto",
    ["Hidden games"] = "Giochi nascosti",
    ["Hidden games are filtered out.\nPress R3 to reveal them, then L3 to unhide."] = "I giochi nascosti sono filtrati.\nPremi R3 per mostrarli, poi L3 per renderli visibili.",
    ["Hidden games filtered out again"] = "Giochi nascosti di nuovo filtrati",
    ["Hide UI Text"] = "Nascondi testo UI",
    ["How to hide a game"] = "Come nascondere un gioco",
    ["Installed"] = "Installati",
    ["Internal HDD"] = "HDD interno",
    ["Keep"] = "Mantieni",
    ["Keep this display mode?"] = "Mantenere questa modalità schermo?",
    ["Keyboard Layout"] = "Layout tastiera",
    ["L3 on the game list"] = "L3 nell'elenco giochi",
    ["Launch"] = "Avvia",
    ["Launch DKWDRV?"] = "Avviare DKWDRV?",
    ["Left aligned"] = "Allineato a sinistra",
    ["List refreshed"] = "Lista aggiornata",
    ["List refreshed (no games found)"] = "Lista aggiornata (nessun gioco trovato)",
    ["Loaded SMB list from cache..."] = "Lista SMB caricata dalla cache...",
    ["Loading HDD (exFAT)..."] = "Caricamento HDD (exFAT)...",
    ["Loading HDD..."] = "Caricamento HDD...",
    ["Loading MMCE..."] = "Caricamento MMCE...",
    ["Loading MX4SIO..."] = "Caricamento MX4SIO...",
    ["Loading USB..."] = "Caricamento USB...",
    ["MMCE has no POPS folder\nexpected mmce0:/POPS/"] = "MMCE non ha la cartella POPS\nprevisto mmce0:/POPS/",
    ["Menu"] = "Menu",
    ["Multi-disc games"] = "Giochi multi-disco",
    ["NetBIOS isn't supported\nset Address type = IP + a Server IP"] = "NetBIOS non è supportato\nimposta Tipo indirizzo = IP + un IP server",
    ["No"] = "No",
    ["No MMCE device detected\nchecked mmce0: and mmce1:"] = "Nessun dispositivo MMCE rilevato\ncontrollati mmce0: e mmce1:",
    ["No MX4SIO device detected"] = "Nessun dispositivo MX4SIO rilevato",
    ["No Share selected"] = "Nessuna condivisione selezionata",
    ["No Share set in SMB settings\n(server returned no shares)"] = "Nessuna condivisione impostata nelle impostazioni SMB\n(il server non ha restituito condivisioni)",
    ["No USB backend detected\nreseat the drive and try again"] = "Nessun backend USB rilevato\nreinserisci l'unità e riprova",
    ["No exFAT HDD detected\nformat the internal drive exFAT (BDMA Mode = ATA)"] = "Nessun HDD exFAT rilevato\nformatta l'unità interna in exFAT (Modalità BDMA = ATA)",
    ["No games found"] = "Nessun gioco trovato",
    ["No games found on hdd0:\n(__.POPS partitions are empty)"] = "Nessun gioco trovato su hdd0:\n(le partizioni __.POPS sono vuote)",
    ["No games found on this device"] = "Nessun gioco trovato su questo dispositivo",
    ["No network link\ncheck the Ethernet cable / adapter"] = "Nessun collegamento di rete\ncontrolla il cavo / adattatore Ethernet",
    ["Not implemented yet"] = "Non ancora implementato",
    ["Not installed"] = "Non installati",
    ["Off"] = "Disattivato",
    ["Off (deleted)"] = "Off (eliminato)",
    ["On"] = "Attivato",
    ["On (default)"] = "On (predefinito)",
    ["On (per-device)"] = "On (per dispositivo)",
    ["Opening SMB list..."] = "Apertura lista SMB...",
    ["Overscan (CRT inset)"] = "Overscan (rientro CRT)",
    ["POPSLoader\nfor POPStarter"] = "POPSLoader\nper POPStarter",
    ["POPSTARTER Folder"] = "Cartella POPSTARTER",
    ["POPSTARTER Path"] = "Percorso POPSTARTER",
    ["POPSTARTER folder deleted from the memory card"] = "Cartella POPSTARTER eliminata dalla memory card",
    ["POPSTARTER folder restored on the memory card\n(set a BDMA mode to re-add the exFAT/SMB modules)"] = "Cartella POPSTARTER ripristinata sulla memory card\n(imposta una modalità BDMA per riaggiungere i moduli exFAT/SMB)",
    ["Press CIRCLE again to discard what you typed"] = "Premi di nuovo CIRCLE per scartare il testo digitato",
    ["Press CROSS again to discard what you typed"] = "Premi di nuovo CROSS per scartare il testo digitato",
    ["Rebuilding HDD game list..."] = "Ricreazione lista giochi HDD...",
    ["Refreshing HDD list..."] = "Aggiornamento lista HDD...",
    ["Refreshing list..."] = "Aggiornamento lista...",
    ["Rescanning HDD partitions..."] = "Riscansione partizioni HDD...",
    ["Reset"] = "Ripristina",
    ["Reset Defaults"] = "Ripristina predefiniti",
    ["Retrying USB scan..."] = "Nuovo tentativo scansione USB...",
    ["Return to OSDSYS?"] = "Tornare a OSDSYS?",
    ["Revert"] = "Ripristina",
    ["Right aligned"] = "Allineato a destra",
    ["SMB / Network"] = "SMB / Rete",
    ["SMB connect failed"] = "Connessione SMB non riuscita",
    ["SMB connection dropped"] = "Connessione SMB interrotta",
    ["SMB login failed\ncheck User / Password"] = "Accesso SMB non riuscito\ncontrolla Utente / Password",
    ["SMB modules"] = "Moduli SMB",
    ["SMB modules are not installed\nGames list but won't boot without them --\ninstall via Settings > SMB modules, then Save"] = "I moduli SMB non sono installati\nI giochi appaiono ma non si avviano senza --\ninstallali da Impostazioni > Moduli SMB, poi Salva",
    ["SMB modules are not installed\nGames will list but won't boot -- install them\nvia Settings > SMB modules first"] = "I moduli SMB non sono installati\nI giochi appaiono ma non si avviano -- installali\nprima da Impostazioni > Moduli SMB",
    ["SMB modules didn't install/remove\nmodule setting reverted; other settings were saved"] = "Moduli SMB non installati/rimossi\nimpostazione moduli ripristinata; altre impostazioni salvate",
    ["SMB modules failed to load"] = "Caricamento moduli SMB non riuscito",
    ["Save"] = "Salva",
    ["Save Changes"] = "Salva modifiche",
    ["Saving settings"] = "Salvataggio impostazioni",
    ["Saving..."] = "Salvataggio...",
    ["Saving/Applying..."] = "Salvataggio/Applicazione...",
    ["Scanning HDD partitions..."] = "Scansione partizioni HDD...",
    ["Scanning MMCE games..."] = "Scansione giochi MMCE...",
    ["Scanning MX4SIO games..."] = "Scansione giochi MX4SIO...",
    ["Scanning SMB games..."] = "Scansione giochi SMB...",
    ["Scanning exFAT HDD games..."] = "Scansione giochi HDD exFAT...",
    ["Scanning games..."] = "Scansione giochi...",
    ["Select"] = "Seleziona",
    ["Select a share"] = "Seleziona una condivisione",
    ["Server refused SMBv1\nenable SMBv1 support on the host"] = "Il server ha rifiutato SMBv1\nabilita il supporto SMBv1 sull'host",
    ["Settings"] = "Impostazioni",
    ["Share not found\ncheck the Share name (host must allow SMB1)"] = "Condivisione non trovata\ncontrolla il nome condivisione (l'host deve consentire SMB1)",
    ["Show all discs"] = "Mostra tutti i dischi",
    ["Showing hidden games (dimmed) -- press L3 to unhide"] = "Giochi nascosti mostrati (in grigio) -- premi L3 per renderli visibili",
    ["Shown"] = "Mostrato",
    ["Staging drivers for this device"] = "Preparazione dei driver per questo dispositivo",
    ["Starting the game..."] = "Avvio del gioco...",
    ["Startup"] = "Avvio",
    ["Static (manual)"] = "Statico (manuale)",
    ["Storage"] = "Archiviazione",
    ["This backend isn't implemented yet"] = "Questo backend non è ancora implementato",
    ["UI text hidden"] = "Testo UI nascosto",
    ["UI text shown"] = "Testo UI mostrato",
    ["Video Standard"] = "Standard video",
    ["Visible"] = "Visibile",
    ["Visible (manage)"] = "Visibile (gestisci)",
    ["Working..."] = "Elaborazione...",
    ["Yes"] = "Sì",
    -- EXP34: fill currently-used strings that were untranslated (machine-assisted)
    ["(could NOT save -- reverts on reboot)"] = "(salvataggio NON riuscito -- annullato al riavvio)",
    ["(the usual settings location wasn't writable)"] = "(la posizione abituale delle impostazioni non era scrivibile)",
    ["-- launch cancelled"] = "-- avvio annullato",
    ["Adaptive BDMA couldn't stage"] = "BDMA adattivo non è riuscito a preparare",
    ["Applying SMB modules"] = "Applicazione dei moduli SMB",
    ["BDMA source backend not ready:"] = "Backend di origine BDMA non pronto:",
    ["BOOT.ELF failed to launch"] = "Avvio di BOOT.ELF non riuscito",
    ["Booted from:"] = "Avviato da:",
    ["Cannot access"] = "Impossibile accedere",
    ["Case/Symbols: UPPER  (R2)"] = "Maiusc/Simboli: MAIUSC  (R2)",
    ["Case/Symbols: lower  (R2)"] = "Maiusc/Simboli: minusc  (R2)",
    ["Couldn't restore BDMA mode"] = "Impossibile ripristinare la modalità BDMA",
    ["Couldn't save settings"] = "Impossibile salvare le impostazioni",
    ["Couldn't update hidden state"] = "Impossibile aggiornare lo stato nascosto",
    ["Couldn't write .hide to the HDD"] = "Impossibile scrivere .hide sull'HDD",
    ["Cursor: L1 / R1"] = "Cursore: L1 / R1",
    ["DKWDRV failed to launch"] = "Avvio di DKWDRV non riuscito",
    ["Edit"] = "Modifica",
    ["Edit %s"] = "Modifica %s",
    ["Game file missing"] = "File di gioco mancante",
    ["HDD dir read failed:"] = "Lettura della cartella HDD non riuscita:",
    ["HDD not usable"] = "HDD non utilizzabile",
    ["Hidden games are already shown here (dimmed)\nEnable \"Hide hidden games\" in Settings to filter them out"] = "I giochi nascosti sono già mostrati qui (in grigio)\nAttiva \"Nascondi giochi nascosti\" nelle Impostazioni per filtrarli",
    ["Locating exFAT HDD POPS folder..."] = "Ricerca della cartella POPS dell'HDD exFAT...",
    ["Looking for USB drive..."] = "Ricerca dell'unità USB...",
    ["Missing BDMA UI source (tried):"] = "Origine UI BDMA mancante (tentato):",
    ["Missing BDMA source (tried):"] = "Origine BDMA mancante (tentato):",
    ["Missing SMB module (tried):"] = "Modulo SMB mancante (tentato):",
    ["No '__.POPS' partitions on hdd0:\nformat one with __.POPS / __.POPS0...9"] = "Nessuna partizione '__.POPS' su hdd0:\nformattane una con __.POPS / __.POPS0...9",
    ["No DKWDRV found at this path"] = "Nessun DKWDRV trovato in questo percorso",
    ["No POPSTARTER found at this path"] = "Nessun POPSTARTER trovato in questo percorso",
    ["Path saved, file not found:"] = "Percorso salvato, file non trovato:",
    ["Resolved:"] = "Risolto:",
    ["Reverting in"] = "Ripristino tra",
    ["Saved to"] = "Salvato in",
    ["Slot:"] = "Slot:",
    ["The internal drive is still starting\nopen this page again in a moment"] = "L'unità interna si sta ancora avviando\nriapri questa pagina tra un momento",
    ["Triangle"] = "Triangolo",
    ["Unknown BDMA mode:"] = "Modalità BDMA sconosciuta:",
    ["You can still add a \"<game>.hide\" next to the .VCD from a PC."] = "Puoi comunque aggiungere un \"<gioco>.hide\" accanto al .VCD da un PC.",
    ["adjusted -- using"] = "regolato -- in uso",
    ["check the memory card, or turn Adaptive BDMA off"] = "controlla la memory card oppure disattiva il BDMA adattivo",
    ["if not confirmed"] = "se non confermato",
    ["re-select it under Settings > Storage to restage"] = "riselezionalo in Impostazioni > Archiviazione per ripreparare",
    ["return code:"] = "codice di ritorno:",
    ["status:"] = "stato:",
  },
  HU = {
    ["(could NOT save -- reverts on reboot)"] = "(NEM sikerült menteni -- újraindításkor visszaáll az eredeti állapotra)",
    ["(not set)"] = "(nincs beállítva)",
    ["(share root)"] = "(gyökérkönyvtár megosztása)",
    ["(the usual settings location wasn't writable)"] = "(a beállítások szokásos helye nem volt írható)",
    ["(unknown)"] = "(ismeretlen)",
    ["-- launch cancelled"] = "-- az indítás megszakítva",
    ["About"] = "Névjegy",
    ["Actual output"] = "Aktuális kimenet",
    ["Adaptive BDMA"] = "Adaptív BDMA",
    ["Adaptive BDMA couldn't stage"] = "Az adaptív BDMA nem tudott szakaszosan működni",
    ["adjusted -- using"] = "kiigazítva -- a következővel",
    ["APA / PFS (default)"] = "APA / PFS (alapértelmezett)",
    ["Applying BDMA mode"] = "BDMA mód alkalmazása",
    ["Applying SMB modules"] = "SMB modulok alkalmazása",
    ["ART (at root)"] = "ART (a főkönyvtárban)",
    ["At least one device must stay on the carousel"] = "Legalább egy eszköznek meg kell maradnia",
    ["Auto (console region)"] = "Automatikus (a konzol régiója)",
    ["Automatic"] = "Automatikus",
    ["Back"] = "Vissza",
    ["Backspace"] = "Visszatörlés",
    ["BDMA Mode"] = "BDMA mód",
    ["BDMA mode change didn't apply\nBDMA reverted; other settings were saved"] = "A BDMA-mód váltása nem került alkalmazásra\nA BDMA-mód visszaállt; az egyéb beállítások mentésre kerültek",
    ["BDMA source backend not ready:"] = "A BDMA forrás-háttérrendszer még nem áll készen:",
    ["Boot Page"] = "Startlap",
    ["Boot sound"] = "Starthang",
    ["BOOT.ELF failed to launch"] = "A BOOT.ELF elindítása sikertelen volt",
    ["BOOT.ELF not found\nchecked mc0:/BOOT and mc1:/BOOT"] = "A BOOT.ELF fájl nem található\nEllenőrizve: mc0:/BOOT és mc1:/BOOT",
    ["Booted from:"] = "Boot eszköz:",
    ["Bringing up network..."] = "Hálózat felépítése...",
    ["Building HDD game list..."] = "HDD játéklista összeállítása...",
    ["Building USB game list..."] = "USB játéklista összeállítása...",
    ["Can't disable while Adaptive BDMA is on\nTurn Adaptive BDMA off first"] = "Az Adaptive BDMA bekapcsolt állapotában nem lehet kikapcsolni\nElőször kapcsolja ki az Adaptive BDMA-t",
    ["Can't disable while BDMA is enabled\nSet BDMA Mode to FAT32 (None) first"] = "A BDMA engedélyezése mellett nem lehet letiltani\nElőször állítsa a BDMA módot FAT32 (No BDMA) értékre",
    ["Can't disable while SMB modules are installed\nSet SMB modules to Not installed first"] = "Az SMB-modulok telepítése mellett nem lehet letiltani\nElőször állítsa az SMB-modulokat 'Nincs telepítve' állapotra",
    ["Can't reach the server\ncheck Server IP / Port in SMB settings"] = "Nem sikerült kapcsolatot létesíteni a szerverrel\nEllenőrizze a szerver IP-címét és portját az SMB-beállításokban",
    ["Cancel"] = "Mégsem",
    ["Cannot access"] = "Nem lehet hozzáférni",
    ["Carousel (default)"] = "Eszközlista (alapértelmezett)",
    ["Carousel Devices"] = "Eszközök",
    ["Case/Symbols: lower  (R2)"] = "Betűk/szimbólumok: kisbetűs  (R2)",
    ["Case/Symbols: UPPER  (R2)"] = "Betűk/szimbólumok: NAGYBETŰS  (R2)",
    ["Center aligned"] = "Középre igazítva",
    ["check the memory card, or turn Adaptive BDMA off"] = "ellenőrizze a memóriakártyát, vagy kapcsolja ki az Adaptive BDMA funkciót",
    ["Checking POPSTARTER..."] = "POPSTARTER ellenőrzése...",
    ["Checking the game file..."] = "A játékfájl ellenőrzése...",
    ["Code by El_isra"] = "Kódolás: El_isra",
    ["Confirm"] = "Megerősítés",
    ["Connecting to SMB..."] = "Csatlakozás az SMB-hez...",
    ["Couldn't apply the PS2 IP settings\ntry again or power-cycle the network adapter"] = "A PS2 IP-beállításai nem alkalmazhatók\npróbálja meg újra, vagy indítsa újra a hálózati adaptert",
    ["Couldn't read that game selection"] = "Nem sikerült elolvasni ezt a játékválasztást",
    ["Couldn't restore BDMA mode"] = "Nem sikerült visszaállítani a BDMA módot",
    ["Couldn't save settings"] = "A beállítások mentése nem sikerült",
    ["Couldn't save settings -- POPSTARTER folder NOT deleted"] = "A beállítások mentése nem sikerült -- a POPSTARTER mappa NEM került törlésre",
    ["Couldn't save settings -- POPSTARTER folder NOT restored"] = "A beállítások mentése nem sikerült -- a POPSTARTER mappa NEM került visszaállításra",
    ["Couldn't update hidden state"] = "A rejtett állapotot nem sikerült frissíteni",
    ["Couldn't write .hide to the HDD"] = "Nem sikerült a .hide fájlt a HDD-re írni",
    ["Cover art"] = "Borítókép",
    ["Cover/details folder"] = "Borító/Részletek mappa",
    ["Credits"] = "Közreműködők",
    ["Cursor: L1 / R1"] = "Kurzor: L1 / R1",
    ["Defaults restored"] = "Alapértelmezések visszaállítva",
    ["Delete the POPSTARTER folder from the memory card?"] = "Törli a POPSTARTER mappát a memóriakártyáról?",
    ["Design by Berion\nScripts by nuno6573 and Ripto\nBased on Enceladus by Daniel Santos\nTesting by P4NCHOL1NO, VizoR, provato,\nnuno6573, oldman63, saildot4k, and Community\n\nSpecial Thanks To:\nkrHACKen for making POPStarter\nuyjulian, fjtrujy, HWC, and others for always helping\n\nThis program is free and open source\nIf you bought it, you have been scammed\n\nCompatibility problems? Visit:\nyoutube.com/@hugopocked6695"] = "Tervezés: Berion\nSzkriptek: nuno6573 és Ripto\nBázis: Daniel Santos 'Enceladus' című munkája\nTesztelés: P4NCHOL1NO, VizoR, provato,\nnuno6573, sAGA/oldman63, saildot4k és a közösség\n\nKülön köszönet:\nkrHACKennek a POPStarter elkészítéséért\nuyjuliannek, fjtrujy-nak, HWC-nek és másoknak a folyamatos segítségért\n\nEz a program ingyenes és nyílt forráskódú\nHa megvásárolta, akkor átverték\n\nKompatibilitási problémák? Látogasson el ide:\nyoutube.com/@hugopocked6695",
    ["Device List"] = "Eszközlista",
    ["DHCP (automatic)"] = "DHCP (automatikus)",
    ["DHCP failed\nset a static IP in SMB settings"] = "A DHCP nem sikerült\nÁllítson be statikus IP-címet az SMB-beállításokban",
    ["Disc (DKWDRV)"] = "Fizikai lemez (DKWDRV)",
    ["Discard & Exit"] = "Elvetés & Kilépés",
    ["Display"] = "Megjelenés",
    ["Display reverted -- new mode wasn't confirmed"] = "A kijelzőmód visszaállt -- az új mód nem került megerősítésre",
    ["DKWDRV failed to launch"] = "A DKWDRV indítása nem sikerült",
    ["DKWDRV Path"] = "DKWDRV útvonal",
    ["Don't Save"] = "Ne mentse el",
    ["Edit"] = "Szerkesztés",
    ["Edit DKWDRV Path"] = "DKWDRV útvonal szerkesztése",
    ["Edit POPStarter Path"] = "POPStarter útvonal szerkesztése",
    ["Enable the POPSTARTER Folder first\n(BDMA / SMB modules must live on the memory card)"] = "Először engedélyezze a POPSTARTER mappát\n(a BDMA / SMB moduloknak a memóriakártyán kell lenniük)",
    ["Enable the POPSTARTER Folder first\n(SMB modules must live on the memory card)"] = "Először engedélyezze a POPSTARTER mappát\n(az SMB moduloknak a memóriakártyán kell lenniük)",
    ["Exit"] = "Kilépés",
    ["Failed to connect to SMB"] = "Nem sikerült csatlakozni az SMB-hez",
    ["Failed to load HDD"] = "A HDD betöltése nem sikerült",
    ["Failed to load HDD (exFAT)"] = "Az exFAT HDD betöltése nem sikerült",
    ["Failed to load MMCE"] = "Az MMCE betöltése nem sikerült",
    ["Failed to load MX4SIO"] = "Az MX4SIO betöltése nem sikerült",
    ["Failed to load USB"] = "Az USB betöltése nem sikerült",
    ["Failed to refresh HDD list"] = "A HDD-lista frissítése nem sikerült",
    ["Failed to refresh list"] = "A lista frissítése nem sikerült",
    ["FAT32-USB (None)"] = "FAT32-USB (No BDMA)",
    ["First disc only"] = "Csak az első lemez",
    ["Game details"] = "Játék részletek",
    ["Game file missing"] = "Hiányzik a játékfájl",
    ["Game hidden"] = "Játék elrejtve",
    ["Game List"] = "Játéklista",
    ["Game list cache"] = "Játéklista-gyorsítótár",
    ["Game shown"] = "Játék megjelenítve",
    ["Games path affects browsing only:\nPOPStarter can only launch games from <share>/POPS"] = "A játékok elérési útvonala kizárólag a böngészést érinti:\nA POPStarter csak a <share>/POPS mappából indíthat játékokat",
    ["HDD Alt mode needs POPSTARTER on HDD"] = "A HDD Alt módhoz POPSTARTER szükséges a HDD-n",
    ["HDD dir read failed:"] = "A HDD könyvtár olvasása sikertelen:",
    ["HDD list loaded from cache (R1 rescans)"] = "A HDD-lista betöltődött a gyorsítótárból (R1 - lista frissítése)",
    ["HDD list refreshed"] = "A HDD-lista frissült",
    ["HDD list refreshed (no games found)"] = "A HDD-lista frissült (nincs játék)",
    ["HDD not usable"] = "A HDD nem használható",
    ["Hidden"] = "Elrejtve",
    ["Hidden games"] = "Elrejtett játékok",
    ["Hidden games are filtered out.\nPress R3 to reveal them, then L3 to unhide."] = "A rejtett játékok kiszűrésre kerülnek.\nNyomja meg az R3 gombot a megjelenítéshez, az L3 gombot a rejtés feloldásához.",
    ["Hidden games filtered out again"] = "Rejtett játékok kiszűrve",
    ["Hide Text"] = "Szöveg elrejtése",
    ["Hide UI Text"] = "UI szövegek elrejtése",
    ["How to hide a game"] = "Játék elrejtése",
    ["if not confirmed"] = "ha nincs megerősítve",
    ["Installed"] = "Telepített",
    ["Internal HDD"] = "Belső HDD",
    ["Keep"] = "Megtart",
    ["Keep this display mode?"] = "Megtartja ezt a megjelenítési módot?",
    ["Keyboard Layout"] = "Billentyűzetkiosztás",
    ["L3 on the game list"] = "L3 a játéklistán",
    ["Launch"] = "Indítás",
    ["Launch DKWDRV?"] = "Elindítja a DKWDRV-t?",
    ["Left aligned"] = "Balra igazítva",
    ["List refreshed"] = "Lista frissítve",
    ["List refreshed (no games found)"] = "A lista frissítve (nincsenek játékok)",
    ["Loaded SMB list from cache..."] = "Az SMB-lista betöltése a gyorsítótárból...",
    ["Loading HDD (exFAT)..."] = "exFAT HDD betöltése...",
    ["Loading HDD..."] = "HDD betöltése...",
    ["Loading MMCE..."] = "MMCE betöltése...",
    ["Loading MX4SIO..."] = "MX4SIO betöltése...",
    ["Loading USB..."] = "USB betöltése...",
    ["Locating exFAT HDD POPS folder..."] = "Az exFAT HDD-n lévő POPS mappa megkeresése...",
    ["Looking for USB drive..."] = "USB-meghajtó keresése...",
    ["Memory Card"] = "Memóriakártya",
    ["Menu"] = "Menü",
    ["Missing BDMA source (tried):"] = "Hiányzó BDMA forrás (megpróbálva):",
    ["Missing BDMA UI source (tried):"] = "Hiányzó BDMA UI forrás (megpróbálva):",
    ["Missing SMB module (tried):"] = "Hiányzó SMB modul (megpróbálva):",
    ["MMCE has no POPS folder\nexpected mmce0:/POPS/"] = "Az MMCE-n nincs POPS mappa\nelvárás az mmce0:/POPS/ mappa",
    ["Multi-disc games"] = "Többlemezes játékok",
    ["NetBIOS isn't supported\nset Address type = IP + a Server IP"] = "A NetBIOS nem támogatott\nállítsa be a címtípust: IP + egy szerver IP-címe",
    ["No"] = "Nem",
    ["No '__.POPS' partitions on hdd0:\nformat one with __.POPS / __.POPS0...9"] = "Nincs '__.POPS' partíció a hdd0-on:\nHozzon létre egyet __.POPS / __.POPS0...9 néven",
    ["No DKWDRV found at this path"] = "Ezen az elérési úton nincs DKWDRV",
    ["No exFAT HDD detected\nformat the internal drive exFAT (BDMA Mode = ATA)"] = "Nincs észlelt exFAT HDD\nformázza le a belső HDD-t exFAT formátumra (BDMA mód = ATA)",
    ["No games found"] = "Nincsenek játékok",
    ["No games found on hdd0:\n(__.POPS partitions are empty)"] = "Nincsenek játékok a hdd0-n:\n(a __.POPS partíciók üresek)",
    ["No games found on this device"] = "Az eszközön nem találhatóak játékok",
    ["No MMCE device detected\nchecked mmce0: and mmce1:"] = "Nem észlelhető MMCE-eszköz\nellenőrizve itt: mmce0: és mmce1:",
    ["No MX4SIO device detected"] = "Nem észlelhető MX4SIO eszköz",
    ["No network link\ncheck the Ethernet cable / adapter"] = "Nincs hálózati kapcsolat\nEllenőrizze az Ethernet-kábelt / adaptert",
    ["No POPSTARTER found at this path"] = "Ezen az elérési úton nincs POPSTARTER",
    ["No POPSTARTER.ELF found\nchecked the game device, the launcher folder and mc0:/mc1:"] = "Nem található a POPSTARTER.ELF fájl\nellenőrizve itt: a játék eszköze, az indító mappája és mc0:/mc1:",
    ["No Share selected"] = "Nincs kiválasztott megosztás",
    ["No Share set in SMB settings\n(server returned no shares)"] = "Az SMB-beállításokban nincs megadva megosztás\n(a szerver nem adott vissza megosztásokat)",
    ["No USB backend detected\nreseat the drive and try again"] = "Nem észlelhető USB-háttérrendszer\nHelyezze be ismételten a meghajtót, majd próbálja újra",
    ["Not implemented yet"] = "Jelenleg nincs megvalósítva",
    ["Not installed"] = "Nincs telepítve",
    ["Off"] = "Ki",
    ["Off (deleted)"] = "Ki (törölt)",
    ["On"] = "Be",
    ["On (default)"] = "Be (alapértelmezett)",
    ["On (per-device)"] = "Be (eszközönként)",
    ["Opening SMB list..."] = "SMB-lista megnyitása...",
    ["Operation failed"] = "Sikertelen művelet",
    ["Path saved, file not found:"] = "Az elérési út elmentve, fájl nem található:",
    ["POPS (beside game)"] = "POPS (a játék mellett)",
    ["POPSLoader\nfor POPStarter"] = "POPSLoader\na POPStarter kezeléséhez",
    ["POPSTARTER Folder"] = "POPSTARTER mappa",
    ["POPSTARTER folder deleted from the memory card"] = "A POPSTARTER mappa törölve lett a memóriakártyáról",
    ["POPSTARTER folder restored on the memory card\n(set a BDMA mode to re-add the exFAT/SMB modules)"] = "A POPSTARTER mappa visszaállítva a memóriakártyán\n(állítsa be a BDMA módot az exFAT/SMB modulok újbóli hozzáadásához)",
    ["POPSTARTER Path"] = "POPSTARTER útvonal",
    ["Press CIRCLE again to discard what you typed"] = "Nyomja meg újra a KÖR gombot, hogy törölje a beírt szöveget",
    ["Press CROSS again to discard what you typed"] = "Nyomja meg újra a KERESZT gombot a beírtak elvetéséhez",
    ["Profile"] = "Profil",
    ["Profile defaults restored"] = "Alapértelmezett profilbeállítások visszaállítva",
    ["re-select it under Settings > Storage to restage"] = "A Beállítások > Tárhely menüpont alatt válassza ki újra, hogy újra feltöltse",
    ["Rebuilding HDD game list..."] = "A HDD-n lévő játékok listájának ismételt összeállítása...",
    ["Refreshing HDD list..."] = "A HDD-lista frissítése...",
    ["Refreshing list..."] = "Lista frissítése...",
    ["Rescanning HDD partitions..."] = "A HDD partíciók újraszkennelése...",
    ["Reset"] = "Visszaállítás",
    ["Reset Defaults"] = "Alapértelmezések visszaállítása",
    ["Retrying USB scan..."] = "Az USB-ellenőrzés újraindítása...",
    ["return code:"] = "válaszkód:",
    ["Return to OSDSYS?"] = "Kilépés az OSDSYS-be?",
    ["Revert"] = "Visszavon",
    ["Reverting in"] = "Visszaállítás",
    ["Right aligned"] = "Jobbra igazítva",
    ["Save"] = "Mentés",
    ["Save Changes"] = "Változások mentése",
    ["Save Settings"] = "Beállítások mentése",
    ["Save your changes before leaving?"] = "Elmenti a módosításokat, mielőtt kilép?",
    ["Saved to"] = "Mentve ide",
    ["Saving settings"] = "Beállítások mentése",
    ["Saving..."] = "Mentés...",
    ["Saving/Applying..."] = "Mentés/Alkalmazás...",
    ["Scanning exFAT HDD games..."] = "exFAT HDD-n lévő játékok beolvasása...",
    ["Scanning games..."] = "Játékok beolvasása...",
    ["Scanning HDD partitions..."] = "HDD partíciók beolvasása...",
    ["Scanning MMCE games..."] = "MMCE-játékok beolvasása...",
    ["Scanning MX4SIO games..."] = "MX4SIO-játékok beolvasása...",
    ["Scanning SMB games..."] = "SMB-játékok beolvasása...",
    ["Select"] = "Kiválasztás",
    ["Select a share"] = "Válasszon megosztást",
    ["Server refused SMBv1\nenable SMBv1 support on the host"] = "A szerver elutasította az SMBv1-et\nEngedélyezze az SMBv1 támogatást a gazdagépen",
    ["Settings"] = "Beállítások",
    ["Share not found\ncheck the Share name (host must allow SMB1)"] = "A megosztás nem található\nEllenőrizze a megosztás nevét (a gazdagépnek engedélyeznie kell az SMB1-et)",
    ["Show all discs"] = "Összes lemez",
    ["Showing hidden games (dimmed) -- press L3 to unhide"] = "Rejtett játékok megjelenítése (elhalványítva) -- az L3 megnyomásával láthatóvá tehetők",
    ["Shown"] = "Megjelenítés",
    ["Slot:"] = "Nyílás:",
    ["SMB / Network"] = "SMB / Hálózat",
    ["SMB connect failed"] = "Az SMB-kapcsolat sikertelen",
    ["SMB connection dropped"] = "Az SMB-kapcsolat megszakadt",
    ["SMB login failed\ncheck User / Password"] = "Az SMB-bejelentkezés sikertelen volt\nEllenőrizze a felhasználónevet és a jelszót",
    ["SMB modules"] = "SMB modulok",
    ["SMB modules are not installed\nGames list but won't boot without them --\ninstall via Settings > SMB modules, then Save"] = "Az SMB-modulok nincsenek telepítve\nA játékok listája megjelenik, de ezek nélkül a rendszer nem indul el --\nTelepítse őket a Beállítások > SMB-modulok menüpontban, majd kattintson a Mentés gombra",
    ["SMB modules are not installed\nGames will list but won't boot -- install them\nvia Settings > SMB modules first"] = "Az SMB-modulok nincsenek telepítve\nA játékok megjelennek a listában, de nem indulnak el -- először telepítse őket\na Beállítások > SMB-modulok menüpontban",
    ["SMB modules didn't install/remove\nmodule setting reverted; other settings were saved"] = "Az SMB-modulok telepítése/eltávolítása nem sikerült\nA modul beállításai visszaálltak; az egyéb beállítások mentésre kerültek",
    ["SMB modules failed to load"] = "Az SMB-modulok betöltése nem sikerült",
    ["Staging drivers for this device"] = "Illesztőprogramok előkészítése ehhez az eszközhöz",
    ["Starting the game..."] = "A játék indítása...",
    ["Startup"] = "Indítás",
    ["Static (manual)"] = "Statikus (manuális)",
    ["status:"] = "státusz:",
    ["Storage"] = "Tároló",
    ["This backend isn't implemented yet"] = "Ez a háttérrendszer még nincs megvalósítva",
    ["This removes the POPSTARTER pack -- including the\nBDMA and SMB modules -- from mc0: / mc1:. They won't\nreturn until you turn this back On (or re-add them\nmanually). Your POPSLoader settings are kept."] = "Ezzel eltávolítja a POPSTARTER csomagot -- beleértve a\nBDMA és SMB modulokat -- az mc0: / mc1: eszközökről.\nAddig nem jelennek meg, amíg ezt újra be nem kapcsolja\n(vagy kézzel újra hozzá nem adja). A beállítások megmaradnak.",
    ["Triangle"] = "Háromszög",
    ["UI text hidden"] = "UI szövegek elrejtve",
    ["UI text shown"] = "UI szövegek megjelenítve",
    ["Unknown BDMA mode:"] = "Ismeretlen BDMA mód:",
    ["Video Standard"] = "Videó szabvány",
    ["Visible"] = "Látható",
    ["Visible (manage)"] = "Láthatóak (kezelhetők)",
    ["Working..."] = "Dolgozok...",
    ["X = Keep      O = Revert"] = "X = Megtart      O = Visszavon",
    ["X = Select      O = Cancel"] = "X = Kiválaszt      O = Mégsem",
    ["X = Yes      O = No"] = "X = Igen      O = Nem",
    ["Yes"] = "Igen",
    ["You can still add a \"<game>.hide\" next to the .VCD from a PC."] = "PC-ről továbbra is hozzáadhat egy \"<game>.hide\" fájlt a .VCD mellé.",
    -- EXP34: fill currently-used strings that were untranslated (machine-assisted)
    ["Edit %s"] = "%s szerkesztése",
    ["Hidden games are already shown here (dimmed)\nEnable \"Hide hidden games\" in Settings to filter them out"] = "A rejtett játékok itt már láthatók (halványítva)\nKapcsolja be a \"Rejtett játékok elrejtése\" opciót a Beállításokban a szűréshez",
    ["Resolved:"] = "Feloldva:",
    ["The internal drive is still starting\nopen this page again in a moment"] = "A belső meghajtó még indul\nnyissa meg újra ezt az oldalt egy pillanat múlva",
  },
}
function PLDR.L(s)
  if s == nil then return "" end
  local lang = PLDR.LANGUAGE
  if lang == nil or lang == PLDR.LANGUAGE_EN then return s end
  local tbl = PLDR.I18N[lang]
  if tbl ~= nil then
    local t = tbl[s]
    if t ~= nil then return t end
  end
  return s
end

local function BuildVideoStandardSpec(standard)
  local key = NormalizeVideoStandard(standard)
  if key == PLDR.VIDEO_STANDARD_PAL then
    return {
      key = PLDR.VIDEO_STANDARD_PAL,
      mode = PAL,
      width = 640,
      -- PAL-native 512-line framebuffer so the UI FILLS the PAL screen (no
      -- letterbox). The square 512x512 art stretches LESS than at 448, and the
      -- layout is UI.SCR.Y-relative so it repositions automatically (OPL does this).
      height = 512,
      fps = 50
    }
  end
  if key == PLDR.VIDEO_STANDARD_NTSC then
    return {
      key = PLDR.VIDEO_STANDARD_NTSC,
      mode = NTSC,
      width = 640,
      height = 448,
      fps = 60
    }
  end
  -- AUTO: follow the console's native region (captured at boot), so we never
  -- force a mode switch the user didn't ask for. Explicit NTSC/PAL above force.
  return {
    key = PLDR.VIDEO_STANDARD_AUTO,
    mode = CONSOLE_REGION_MODE,
    width = 640,
    height = (CONSOLE_REGION_MODE == PAL) and 512 or 448,
    fps = (CONSOLE_REGION_MODE == PAL) and 50 or 60
  }
end

PLDR.VIDEO_STANDARD = NormalizeVideoStandard(PLDR.VIDEO_STANDARD)
PLDR.KEYBOARD_LAYOUT = NormalizeKeyboardLayout(PLDR.KEYBOARD_LAYOUT)

function PLDR.GetVideoStandardSpec(standard)
  return BuildVideoStandardSpec(standard)
end

function PLDR.NormalizeKeyboardLayout(value)
  return NormalizeKeyboardLayout(value)
end

function PLDR.ApplyVideoStandardRuntime(standard)
  local normalized = NormalizeVideoStandard(standard)
  PLDR.VIDEO_STANDARD = normalized
  if type(UI) == "table" and type(UI.ApplyVideoStandardFromRuntime) == "function" then
    pcall(UI.ApplyVideoStandardFromRuntime, normalized)
  end
  return normalized
end

local function ParseMassIndexFromRoot(root)
  if type(root) ~= "string" then return nil end
  if string.match(root, "^mass:/") then
    return 0
  end
  local idx = string.match(root, "^mass(%d+):/")
  if idx ~= nil then
    return tonumber(idx)
  end
  return nil
end

function PLDR.SetMX4SIORoot(root)
  PLDR.MX4SIO.ROOT = root
  local idx = ParseMassIndexFromRoot(root)
  PLDR.MX4SIO.MASSINDX = idx
  PLDR.MX4SIO.IS_MASS_ALIAS = (idx ~= nil)
  PLDR.MX4SIO.READY = (root ~= nil)
  return root
end

local function DetectMX4SIOPrefixHint()
  local mx_marker = JoinPath(APP_DIR_LOCAL, ".boot_mx4sio")
  if doesFileExist(mx_marker) then
    return "mx4sio:/"
  end
  return nil
end
PLDR.MX4SIO.PREFIX_HINT = DetectMX4SIOPrefixHint()
-- Keep runtime slot/status discovery page-driven; startup may still initialize
-- backend drivers when boot/configured paths require them.
PLDR.MMCE.PROBED = false
PLDR.MMCE.SLOTS = {}
PLDR.MMCE.PREFIX = nil
PLDR.MMCE.INDEX = 1


function CLAMP(a, MIN, MAX)
  if a < MIN then return MIN end
  if a > MAX then return MAX end
  return a
end

function CYCLE_CLAMP(a, MIN, MAX)
  if a < MIN then return MAX end
  if a > MAX then return MIN end
  return a
end

local ok_ui, ui_or_err = pcall(require, "ui")
if not ok_ui then
  local traceback = ui_or_err
  if debug ~= nil and debug.traceback ~= nil then
    traceback = debug.traceback(ui_or_err, 2)
  end
  error("UI module failed to load (expected ui.lua to return/set UI): "..tostring(traceback))
end
if ui_or_err ~= nil and ui_or_err ~= true then
  UI = ui_or_err
end
if UI == nil then
  error("UI global not initialized (expected ui.lua to return UI or set _G.UI)")
end
UI.LASTSCENE = UI.SCENES.MMAIN

if UI.DEVLOCK ~= nil then
  local boot_name, boot_path, boot_prefix = DetectBootDevice()
  UI.boot_device = UI.DEVLOCK.NONE
  UI.boot_device_label = boot_name
  UI.boot_locks = {}
  if boot_name == "MX4SIO" then
    UI.boot_device = UI.DEVLOCK.MX4SIO
  elseif boot_name == "USB" then
    UI.boot_device = UI.DEVLOCK.USB
  elseif boot_name == "MMCE" then
    UI.boot_device = UI.DEVLOCK.MMCE
  end
end

-- Apply NHDDL-style launch arg -page=<kind> / -mode=<kind> to start the
-- main menu carousel on a specific page. PLDR.LAUNCH_ARGS.page is set by
-- parseLaunchArgs in main.cpp + NormalizeLaunchPage above. Only fires
-- when the launch arg is explicitly present AND maps to a real page;
-- default carousel behavior (start at MMCE / index 1) is unchanged when
-- the flag is absent or unrecognized.
--
-- Page mapping mirrors UI.MainMenu.opts at the time of this writing:
--   opts = {"MMCE","MX4SIO","HDD (exFAT)","HDD (PFS)","USB","i.Link","SMB (v1)","Disc (DKWDRV)"}
-- HDD launch arg targets the implemented PFS page (index 4); EXFAT targets the
-- BDM HDD-exFAT page (index 3, now implemented via ata_bd). i.Link (index 6) and
-- SMB-v1 remain stubs, so we don't auto-route to those.
if type(PLDR) == "table" and type(PLDR.LAUNCH_ARGS) == "table"
   and type(PLDR.LAUNCH_ARGS.page) == "string" and PLDR.LAUNCH_ARGS.page ~= "" then
  local page_to_opt = {
    MMCE = 1,
    MX4SIO = 2,
    EXFAT = 3,
    ATA = 3,
    HDD = 4,
    USB = 5,
    SMB = 7,
  }
  local opt = page_to_opt[PLDR.LAUNCH_ARGS.page]
  if opt ~= nil and type(UI.MainMenu) == "table" then
    -- UI.MainMenu carries a __newindex write-guard (ui.lua tail) that
    -- SILENTLY DROPS any OPT assignment unless Carousel.allowOptWrite is
    -- raised -- the carousel's own animation handler is the only code that
    -- raises it. Without raising the same gate here, this whole block is a
    -- no-op: the OPT write is swallowed, and the Carousel index writes
    -- below get overwritten by the first MainMenu.Play(), which re-syncs
    -- the carousel FROM OPT (still 1) on every non-animating frame. That
    -- double clobber is exactly why -page/-mode had no visible effect on
    -- hardware (CosmicScale, 2026-06-09).
    local carousel = type(UI.MainMenu.Carousel) == "table" and UI.MainMenu.Carousel or nil
    if carousel ~= nil then
      carousel.allowOptWrite = true
    end
    UI.MainMenu.OPT = opt
    if carousel ~= nil then
      carousel.allowOptWrite = false
      carousel.currentIndex = opt
      carousel.targetIndex = opt
      carousel.scrollPos = opt + 0.0
    end
    -- If -page/-mode was given WITHOUT -game, auto-ENTER that device's game
    -- list on the first settled main-menu frame, rather than only
    -- pre-positioning the carousel (CosmicScale 2026-06-12: "-page=hdd
    -- highlights HDD (PFS) but doesn't open the list"). MainMenu.Play
    -- consumes this flag by synthesizing one CONFIRM, reusing the exact
    -- device-entry path (load games + SceneChange). With -game, the direct
    -- auto-launch (PLDR.AutoLaunchFromLaunchArgs) handles it instead, so we
    -- do NOT also auto-enter. All page_to_opt targets (MMCE/MX4SIO/HDD/USB/
    -- SMB) are enterable via the same CONFIRM dispatch.
    local has_game = type(PLDR.LAUNCH_ARGS.game) == "string" and PLDR.LAUNCH_ARGS.game ~= ""
    if not has_game then
      UI.MainMenu.PendingAutoEnter = true
    end
  end
end

require("images")

-- POPSTARTER pack root: prefer mc0:/POPSTARTER whenever slot 1 has a card
-- (existing installs + the legacy settings migration unchanged), else fall to
-- mc1:/POPSTARTER when slot 2 does. This was hardcoded mc0:, which stranded
-- memory-card-slot-2-only consoles: BDMA/SMB module installs failed with
-- "Cannot access mc0:/POPSTARTER", the MC settings fallback failed, and the
-- MX4SIO crash marker never persisted. POPStarter itself documentedly reads
-- every pack file from mc0:/POPSTARTER with a per-file mc1:/POPSTARTER
-- fallback, so staging on mc1 is coherent end-to-end. Resolved ONCE here,
-- BEFORE the locals below capture it (POPSTARTER_PACK_ROOT, the bdma marker,
-- the FAT32 remove list, SETTINGS_PATH_FALLBACK, the MX4SIO pending marker).
PLDR.POPSTARTER_DIR = "mc0:/POPSTARTER"
do
  local mc0_ok = false
  pcall(function() mc0_ok = (doesFolderExist("mc0:/") == true) end)
  if not mc0_ok then
    local mc1_ok = false
    pcall(function() mc1_ok = (doesFolderExist("mc1:/") == true) end)
    if mc1_ok then
      PLDR.POPSTARTER_DIR = "mc1:/POPSTARTER"
    end
  end
end

-- Settings path resolution: prefer a per-device sidecar at
-- APP_DIR_LOCAL/.pldrs so a POPSLoader installed on USB / MX4SIO / MMCE
-- keeps its own settings. Fall back to the legacy mc0:/POPSTARTER/.pldrs
-- for first-run migration AND for HDD-backed boots (where writing into
-- the PFS partition would require an RW remount).
--
-- The sidecar path comes from the unified boot-context resolver above
-- (ResolveBootContext().sidecar_path), so settings/IRX/UI navigation
-- all derive from the same argv[0]-rooted detection pipeline.
--
-- The actual PLDR.SETTINGS_PATH is decided at load time in
-- LoadSettingsNonFatal: whichever path's settings file is opened first
-- becomes the path subsequent saves use, so saves go back where loads
-- came from. If neither file exists yet, sidecar wins (or fallback if
-- no sidecar is computable, e.g. HDD-backed APP_DIR).
PLDR.SETTINGS_PATH_FALLBACK = PLDR.POPSTARTER_DIR.."/.pldrs"
PLDR.SETTINGS_PATH_SIDECAR = ResolveBootContext().sidecar_path
PLDR.SETTINGS_PATH = PLDR.SETTINGS_PATH_SIDECAR or PLDR.SETTINGS_PATH_FALLBACK
-- HDD-cwd install: POPSLoader booted FROM the HDD, so its settings belong ON the
-- HDD next to it (the cwd) -- NEVER scattered to mc0: (a single-device HDD setup
-- may have no memory card at all). PFS cannot mount the same partition at two
-- points at once (OPL structures OPL/__common around exactly this limit), so we
-- never open a 2nd mount: reads + writes use the boot partition's existing pfs
-- mount, and if the launcher mounted it read-only the save TAKES OVER that slot and
-- remounts it RW in place (PLDR.HDD.EnsureBootPartitionWritable). No mc0: fallback.
do
  local hdd_part = ParseHddPartitionMount(APP_DIR_RAW or "")
  if hdd_part ~= nil and IsPfsMountedPath(APP_DIR_LOCAL) then
    local rel_dir = string.gsub(tostring(APP_DIR_LOCAL or ""), "^[Pp][Ff][Ss]%d*:/+", "")
    PLDR.SETTINGS_HDD_PARTITION = hdd_part
    PLDR.SETTINGS_HDD_RELPATH = rel_dir..".pldrs"
    PLDR.SETTINGS_PATH_SIDECAR = JoinPath(APP_DIR_LOCAL, ".pldrs")
    PLDR.SETTINGS_PATH = PLDR.SETTINGS_PATH_SIDECAR
  end
end
PLDR.BDMA_MODE_KEY = "FAT32"
PLDR.DKWDRV_DEFAULT_PATH = "mc0:/PS1_DKWDRV/DKWDRV.ELF"
PLDR.DKWDRV_PATH = tostring(PLDR.DKWDRV_PATH or PLDR.DKWDRV_DEFAULT_PATH)
PLDR.KEYBOARD_LAYOUT = NormalizeKeyboardLayout(PLDR.KEYBOARD_LAYOUT)

local POPSTARTER_PACK_ROOT = PLDR.POPSTARTER_DIR
-- BDMA-mode marker in the POPSTARTER pack folder (records which mass-storage
-- backend is installed). Renamed .pldr_bdma_mode -> bdma_mode.txt on 2026-06-17
-- for a clearer, shared name (mSAS reads the same file, per Nad). Old names are
-- still READ for back-compat in ResolveEffectiveBdmaMode so existing cards keep
-- working; the writer always writes this current name.
local BDMA_MODE_MARKER_PATH = POPSTARTER_PACK_ROOT.."/bdma_mode.txt"
local BDMA_COPY_FILES = {
  "usbd.irx",
  "usbhdfsd.irx"
}
-- Derived from the resolved pack root (NOT hardcoded mc0:) so the FAT32-revert
-- path cleans the same slot the modules were staged to.
local BDMA_FAT32_REMOVE_FILES = {
  POPSTARTER_PACK_ROOT.."/usbd.irx",
  POPSTARTER_PACK_ROOT.."/usbhdfsd.irx"
}
local BDMA_UI_FILES = {
  { src = "icon.sys.bdma", dst = "icon.sys" },
  { src = "list.icn.bdma", dst = "list.icn" },
  { src = "del.icn.bdma", dst = "del.icn" }
}
local BDMA_SUFFIX = {
  USBEXFAT = ".usbexfat",
  MX4SIO = ".mx4sio",
  MMCE = ".mmce",
  ATA = ".ata"
}

-- SMB-modules pack (mirrors the BDMA install pattern; SAME mc:/POPSTARTER folder,
-- DISJOINT file set). The 6 IRX install statically (no per-backend suffix); the 2
-- .DAT are GENERATED at install time from PLDR.SMB. SMB-OFF deletes ONLY these 8
-- files, leaving icon.sys/*.icn and the BDMA usbd/usbhdfsd modules untouched
-- (basenames verified disjoint from BDMA_COPY_FILES + BDMA_UI_FILES). Uppercase
-- SMSUTILS.irx matches bin/POPSLDR/popsmb/ exactly (the mc FS is case-preserving,
-- so install name and delete name must stay in lockstep).
-- PLDR fields (NOT chunk-level locals) -- system.lua is near Lua's 200-local cap.
PLDR.SMB_IRX_FILES = {
  "poweroff.irx", "ps2dev9.irx", "ps2ip.irx",
  "ps2smap.irx", "smbman.irx", "SMSUTILS.irx"
}

PLDR.MASS = PLDR.MASS or {
  CACHE = {},
  ORDER = {},
  REFRESHED = false
}

PLDR._bdma_apply_guard = PLDR._bdma_apply_guard or { in_progress = false, last_token = nil }
PLDR._bdma_apply_seq = PLDR._bdma_apply_seq or 0

local function ReadWholeFile(path)
  local ok_open, fd = pcall(System.openFile, path, FREAD)
  if not ok_open or fd == nil or (type(fd) == "number" and fd < 0) then
    return nil, "open failed"
  end
  local chunks = {}
  local ok = true
  while true do
    local ok_read, buffer = pcall(System.readFile, fd, 32768)
    if not ok_read then
      ok = false
      break
    end
    if buffer == nil or buffer == "" then
      break
    end
    chunks[#chunks + 1] = buffer
  end
  pcall(System.closeFile, fd)
  if not ok then
    return nil, "read failed"
  end
  return table.concat(chunks)
end

-- Console button convention from rom0:ROMVER (byte 5 = region letter, e.g.
-- "0170JC20030325"): Japanese-ROM consoles use CIRCLE = confirm / CROSS =
-- cancel (R3Z3N review). Probed ONCE here at boot -- the pad mapping
-- (UI.Pad.Listen) and every footer/hint glyph follow PLDR.CONFIRM_CIRCLE via
-- the UI.Confirm*/Back* helpers, so the whole UI flips together. rom0: is
-- kernel-resident (no module load needed); any failure leaves the Western
-- cross-confirm default.
PLDR.ROMVER = nil
PLDR.CONFIRM_CIRCLE = false
do
  local ok, data = pcall(ReadWholeFile, "rom0:ROMVER")
  if ok and type(data) == "string" and string.len(data) >= 5 then
    PLDR.ROMVER = string.match(data, "^%w+") or nil
    PLDR.CONFIRM_CIRCLE = (string.sub(data, 5, 5) == "J")
  end
end

-- Promote a fully-written temp file onto dest as safely as System.rename allows.
-- System.rename is copy-then-delete (not an atomic kernel rename), so a failure
-- during its internal copy could otherwise destroy an existing dest. Back dest up
-- first and restore it if the promotion fails, so a failed save never leaves the
-- caller with a lost or half-written dest (e.g. the settings file).
local function PromoteTmpToDest(tmp, dest)
  local bak = dest..".bak"
  local had_dest = doesFileExist(dest)
  if had_dest then
    if doesFileExist(bak) then pcall(System.removeFile, bak) end
    -- System.rename is copy+delete: a failed dest->bak fails its COPY before
    -- deleting the source, so dest stays intact. REQUIRE the backup exists before
    -- letting tmp->dest open dest with O_TRUNC -- otherwise a doubly-failed save
    -- (backup fails, then tmp->dest fails) truncates the live file with no .bak to
    -- restore, losing the original .pldrs/cache. (Codex F1 2026-06-20)
    pcall(System.rename, dest, bak)
    if not doesFileExist(bak) then
      pcall(System.removeFile, tmp)
      return false
    end
  end
  local ok = pcall(System.rename, tmp, dest)
  if not ok then
    pcall(System.removeFile, dest)
    if had_dest and doesFileExist(bak) then pcall(System.rename, bak, dest) end
    pcall(System.removeFile, tmp)
    return false
  end
  if doesFileExist(bak) then pcall(System.removeFile, bak) end
  return true
end

local function WriteAtomic(dest, data)
  local tmp = dest..".tmp"
  if doesFileExist(tmp) then
    pcall(System.removeFile, tmp)
  end
  local ok_open, fd = pcall(System.openFile, tmp, FCREATE)
  if not ok_open or fd == nil or (type(fd) == "number" and fd < 0) then
    return false
  end
  local total = string.len(data)
  local offset = 1
  while offset <= total do
    local chunk = string.sub(data, offset, math.min(offset + 32768 - 1, total))
    local chunk_len = string.len(chunk)
    -- System.writeFile is a raw POSIX write(): it returns the bytes ACTUALLY written
    -- (short on a full/flaky device, -1 on error) and does NOT throw. Require the full
    -- count, else a truncated temp file gets promoted as a valid save/cache. (Codex F1)
    local ok_write, wrote = pcall(System.writeFile, fd, chunk, chunk_len)
    if not ok_write or type(wrote) ~= "number" or wrote ~= chunk_len then
      pcall(System.closeFile, fd)
      pcall(System.removeFile, tmp)
      return false
    end
    offset = offset + chunk_len
  end
  pcall(System.closeFile, fd)
  if not PromoteTmpToDest(tmp, dest) then
    return false
  end
  return true
end

local function GetFileSizeSafe(path)
  if path == nil or path == "" then
    return nil
  end
  if not doesFileExist(path) then
    return nil
  end
  local ok_open, fd = pcall(System.openFile, path, FREAD)
  if not ok_open or fd == nil or (type(fd) == "number" and fd < 0) then
    return nil
  end
  local ok_size, size_val = pcall(System.sizeFile, fd)
  pcall(System.closeFile, fd)
  if not ok_size or type(size_val) ~= "number" or size_val < 0 then
    return nil
  end
  return size_val
end

local function CopyExternalAtomicBounded(source, dest, expected_size)
  local tmp = dest..".tmp"
  if doesFileExist(tmp) then
    pcall(System.removeFile, tmp)
  end

  local ok_src, src_fd = pcall(System.openFile, source, FREAD)
  if not ok_src or src_fd == nil or (type(src_fd) == "number" and src_fd < 0) then
    return false, "open source failed"
  end

  local expected = nil
  if type(expected_size) == "number" and expected_size > 0 then
    expected = expected_size
  else
    local ok_size, size_val = pcall(System.sizeFile, src_fd)
    if ok_size and type(size_val) == "number" and size_val > 0 then
      expected = size_val
    end
  end

  local ok_dst, dst_fd = pcall(System.openFile, tmp, FCREATE)
  if not ok_dst or dst_fd == nil or (type(dst_fd) == "number" and dst_fd < 0) then
    pcall(System.closeFile, src_fd)
    return false, "open destination failed"
  end

  local copied = true
  local copied_bytes = 0
  local iters = 0
  local MAX_ITERS = 4096
  local max_bytes = (expected or 0) + 65536
  if max_bytes < 65536 then
    max_bytes = 65536
  end

  while true do
    iters = iters + 1
    if iters > MAX_ITERS then
      copied = false
      break
    end
    if expected ~= nil and copied_bytes >= expected then
      break
    end

    local before = copied_bytes
    local ok_read, chunk = pcall(System.readFile, src_fd, 32768)
    if not ok_read then
      copied = false
      break
    end
    if chunk == nil or chunk == "" then
      break
    end

    local chunk_len = string.len(chunk)
    local ok_write, wrote = pcall(System.writeFile, dst_fd, chunk, chunk_len)
    if not ok_write or type(wrote) ~= "number" then
      copied = false
      break
    end
    if wrote <= 0 then
      copied = false
      break
    end

    copied_bytes = copied_bytes + wrote
    if copied_bytes == before then
      copied = false
      break
    end
    if wrote ~= chunk_len then
      copied = false
      break
    end
    if copied_bytes > max_bytes then
      copied = false
      break
    end
  end

  pcall(System.closeFile, src_fd)
  pcall(System.closeFile, dst_fd)

  if expected ~= nil and copied and copied_bytes < expected then
    copied = false
  end

  if not copied then
    pcall(System.removeFile, tmp)
    return false, "copy failed"
  end

  if not PromoteTmpToDest(tmp, dest) then
    return false, "rename failed"
  end
  return true
end


-- Direct single-pass write: delete dest, create, chunked full-count writes.
-- For SELF-HEALING files only (BDMA driver staging): the variant marker is
-- written AFTER the files succeed, so a torn write leaves marker ~= target and
-- IsBdmaModeEquipped forces a clean re-stage on the next launch. The atomic
-- tmp/.bak dance below is for files where a torn write LOSES data (.pldrs);
-- on a memory card System.rename is copy+delete, so that dance costs ~3x the
-- payload in writes -- the "Staging drivers... takes forever" launch stall
-- (maintainer, EXP24). Do NOT reroute settings/cache saves through this.
local function WriteBytesDirectBounded(data, dest)
  if type(data) ~= "string" then
    return false, "invalid data"
  end
  if doesFileExist(dest) then
    pcall(System.removeFile, dest)
  end
  local ok_open, fd = pcall(System.openFile, dest, FCREATE)
  if not ok_open or fd == nil or (type(fd) == "number" and fd < 0) then
    return false, "open destination failed"
  end
  local expected = string.len(data)
  local offset = 1
  local iters = 0
  local MAX_ITERS = 4096
  local wrote_all = true
  while offset <= expected and iters < MAX_ITERS do
    iters = iters + 1
    local chunk = string.sub(data, offset, math.min(offset + 32768 - 1, expected))
    local chunk_len = string.len(chunk)
    local ok_write, wrote = pcall(System.writeFile, fd, chunk, chunk_len)
    if not ok_write or type(wrote) ~= "number" or wrote ~= chunk_len then
      wrote_all = false
      break
    end
    offset = offset + chunk_len
  end
  if offset <= expected then
    wrote_all = false
  end
  pcall(System.closeFile, fd)
  if not wrote_all then
    -- A torn dest must not survive: without it, the file "exists" and only the
    -- marker mismatch protects us. Delete so the equipped check fails cleanly.
    pcall(System.removeFile, dest)
    return false, "write failed"
  end
  return true
end

local function WriteBytesAtomicBounded(data, dest)
  if type(data) ~= "string" then
    return false, "invalid data"
  end

  local tmp = dest..".tmp"
  if doesFileExist(tmp) then
    pcall(System.removeFile, tmp)
  end

  local ok_open, fd = pcall(System.openFile, tmp, FCREATE)
  if not ok_open or fd == nil or (type(fd) == "number" and fd < 0) then
    return false, "open destination failed"
  end

  local expected = string.len(data)
  local offset = 1
  local iters = 0
  local MAX_ITERS = 4096
  local wrote_all = true

  while offset <= expected and iters < MAX_ITERS do
    iters = iters + 1
    local chunk = string.sub(data, offset, math.min(offset + 32768 - 1, expected))
    local chunk_len = string.len(chunk)
    local ok_write, wrote = pcall(System.writeFile, fd, chunk, chunk_len)
    if not ok_write or type(wrote) ~= "number" or wrote ~= chunk_len then
      wrote_all = false
      break
    end
    offset = offset + chunk_len
  end

  if offset <= expected then
    wrote_all = false
  end

  pcall(System.closeFile, fd)

  if not wrote_all then
    pcall(System.removeFile, tmp)
    return false, "write failed"
  end

  if not PromoteTmpToDest(tmp, dest) then
    return false, "rename failed"
  end
  return true
end



local function EnsureDirectory(path)
  if doesFolderExist(path) then
    return true
  end
  local ok = pcall(System.createDirectory, path)
  return ok
end

local function GetEmbeddedAssetBytes(path)
  if type(System) ~= "table" or type(System.getEmbeddedAsset) ~= "function" then
    return nil
  end
  local ok_embedded, embedded = pcall(System.getEmbeddedAsset, path)
  if not ok_embedded or embedded == nil then
    return nil
  end
  return embedded
end

local function EnsurePopstarterPackDir(path)
  local pack_root = string.gsub(tostring(path or ""), "/+$", "")
  if pack_root == "" then
    return false
  end
  if not EnsureDirectory(pack_root) then
    return false
  end
  for i = 1, #BDMA_UI_FILES do
    local asset = BDMA_UI_FILES[i]
    local dest = pack_root.."/"..asset.dst
    if not doesFileExist(dest) then
      local bytes = GetEmbeddedAssetBytes(asset.src)
      if bytes == nil then
        return false
      end
      local ok_write, wrote = pcall(WriteBytesAtomicBounded, bytes, dest)
      if not ok_write or not wrote then
        return false
      end
    end
  end
  return true
end

function PLDR.EnsurePopstarterDir()
  -- When the user disabled the POPSTARTER memory-card folder, do NOT recreate it
  -- (the toggle deletes it; we must not bring it back on the next settings save).
  if PLDR.POPSTARTER_MC_FOLDER == false then return true end
  return EnsurePopstarterPackDir(PLDR.POPSTARTER_DIR)
end

-- EXP32: the MX4SIO auto-enter crash-marker is GONE (no reference launcher
-- persists failure state -- grep OPL/NHDDL for crash markers: zero). The hang
-- it bounded (a page-entry driver load that never returned) no longer exists:
-- mx4sio_bd loads lazily via the matched-vintage SDK set (the wedge was the
-- c1debd1 mismatched core, fixed), the load returns promptly (card detection
-- runs on the driver's own IOP thread), and every enumeration wait after it
-- is bounded (settle-retry budget, never an unbounded probe). One legacy duty
-- remains:
-- an install upgrading from a marker-era build may have the marker file on
-- the memory card; clear it opportunistically so it cannot confuse anything.
local MX4SIO_PENDING_MARKER = PLDR.POPSTARTER_DIR.."/.mx4sio_autoenter_pending"
function PLDR.ClearLegacyMx4sioMarker()
  pcall(System.removeFile, MX4SIO_PENDING_MARKER)
end

local function RecursiveRemoveDir(dir, preserve_path, depth)
  -- F-12: bound the recursion. mc:/POPSTARTER is shallow; a pathological or looping
  -- structure must not blow the Lua stack. 16 levels is far past any real layout.
  depth = depth or 0
  if depth > 16 then return end
  local entries = System.listDirectory(dir)
  if type(entries) == "table" then
    for i = 1, #entries do
      local name = entries[i].name
      if name ~= nil and name ~= "." and name ~= ".." then
        local full = dir.."/"..name
        if entries[i].directory then
          RecursiveRemoveDir(full, preserve_path, depth + 1)
        elseif full ~= preserve_path then
          pcall(System.removeFile, full)
        end
      end
    end
  end
  -- removeDirectory (rmdir) only succeeds when empty; a preserved file keeps it.
  pcall(System.removeDirectory, dir)
end

-- Delete the mc0:/mc1: POPSTARTER pack folder entirely (OSD icons + the BDMA/SMB
-- modules). Preserves the ACTIVE settings file if it happens to live inside (rare
-- mc0: fallback installs) so the user never loses their config.
function PLDR.RemovePopstarterMcFolder()
  local preserve = (type(PLDR.SETTINGS_PATH) == "string") and PLDR.SETTINGS_PATH or ""
  for _, root in ipairs({ "mc0:/POPSTARTER", "mc1:/POPSTARTER" }) do
    if doesFolderExist(root) then
      RecursiveRemoveDir(root, preserve)
    end
  end
  return true
end

function PLDR.EnsureTrailingSlashNorm(p)
  return EnsureTrailingSlashNormRaw(p)
end

function PLDR.TryOpenFirst(paths)
  for _, path in ipairs(paths) do
    local ok, fd = pcall(System.openFile, path, FREAD)
    if ok and fd ~= nil and (type(fd) ~= "number" or fd >= 0) then
      return fd, path
    end
  end
  return -1, nil
end

APP_DIR_NORM = ResolveAppDirLocal()
APP_DIR_LOCAL = APP_DIR_NORM

function PLDR.BdmaSourceCandidates(rel)
  local out = {}
  local base = APP_DIR_NORM or APP_DIR_LOCAL or ""
  rel = (rel or ""):gsub("\\", "/")
  base = base:gsub("\\", "/")
  if base ~= "" and base:sub(-1) ~= "/" then
    base = base.."/"
  end

  if base:sub(1, 5) == "host:" then
    table.insert(out, "host:./"..rel)
    table.insert(out, "host:"..rel)
    table.insert(out, base..rel)
  else
    table.insert(out, base..rel)
  end
  return out
end

-- Carousel device visibility: which main-menu carousel entries the user has
-- hidden. Stored as a CSV of stable device KEYS (default empty = all shown),
-- index-aligned with the carousel opts in ui.lua (MMCE / MX4SIO / HDD exFAT /
-- HDD PFS / USB / i.Link / SMB / Disc DKWDRV). Persisted via the HIDDEN_DEVICES
-- settings key. (PLDR exists here -- attach-after-init load-order is safe.)
PLDR.CAROUSEL_DEVICE_KEYS = {"MMCE", "MX4SIO", "EXFAT", "PFS", "USB", "ILINK", "SMB", "DKWDRV"}
local CAROUSEL_DEVICE_KEY_SET = {}
for i = 1, #PLDR.CAROUSEL_DEVICE_KEYS do
  CAROUSEL_DEVICE_KEY_SET[PLDR.CAROUSEL_DEVICE_KEYS[i]] = true
end

-- Normalize a hidden-devices value (a CSV string OR a {KEY=true} set table) to a
-- clean CSV of known keys in canonical carousel order, deduped. REFUSES to hide
-- every device (returns "" if asked to) so the carousel can never go empty.
function PLDR.NormalizeHiddenDevices(value)
  local hidden = {}
  if type(value) == "table" then
    for k, v in pairs(value) do
      local key = string.upper(tostring(k))
      if v == true and CAROUSEL_DEVICE_KEY_SET[key] then hidden[key] = true end
    end
  elseif value ~= nil then
    for token in string.gmatch(string.upper(tostring(value)), "[^,%s]+") do
      if CAROUSEL_DEVICE_KEY_SET[token] then hidden[token] = true end
    end
  end
  local hidden_count = 0
  for _ in pairs(hidden) do hidden_count = hidden_count + 1 end
  if hidden_count >= #PLDR.CAROUSEL_DEVICE_KEYS then
    return ""
  end
  local out = {}
  for i = 1, #PLDR.CAROUSEL_DEVICE_KEYS do
    if hidden[PLDR.CAROUSEL_DEVICE_KEYS[i]] then out[#out + 1] = PLDR.CAROUSEL_DEVICE_KEYS[i] end
  end
  return table.concat(out, ",")
end

-- The Internal-HDD page selector: "PFS" (default) | "EXFAT" | "BOTH".
-- ONE normalizer so every site (encode/snapshot/apply/parse/commit/UI/visibility)
-- agrees; each used to inline its own `(x == "EXFAT") and "EXFAT" or "PFS"`, which
-- silently collapses any third value back to PFS. Anything unrecognized -- and a
-- MISSING key -- still resolves to PFS, so no existing install changes until the
-- user opts in (the back-compat contract from 1f2d7ca).
PLDR.HDD_FS_VALUES = {"PFS", "EXFAT", "BOTH"}
function PLDR.NormalizeHddFs(v)
  local u = string.upper(tostring(v or ""))
  if u == "EXFAT" then return "EXFAT" end
  if u == "BOTH" then return "BOTH" end
  return "PFS"
end

-- True if the given carousel device key is currently hidden from the carousel.
function PLDR.IsDeviceHidden(key)
  if key == nil then return false end
  local ukey = string.upper(tostring(key))
  -- Which internal-HDD page(s) the carousel shows: Settings > Device List > Internal HDD.
  -- PFS (default) or EXFAT shows exactly one; BOTH shows both (R3Z3N: APA-Jail and PFS can
  -- coexist). This is ONLY a visibility rule -- it has never gated a driver, mount or IRX.
  -- The stacks were already unified onto ONE load-once ata_bd that serves APA/PFS and exFAT
  -- together (`EnsureAtaBdm`, src/luasystem.cpp; called by BOTH luaHDD.cpp's Load_HDD_IRX and
  -- lua_ata_init, and it already carries R3Z3N's two 1s settles). So BOTH needs no C change.
  -- An explicit -page=ata launch is still an exFAT session regardless of this setting: that
  -- isolation is launch-arg-scoped and deliberately unchanged.
  if ukey == "EXFAT" or ukey == "PFS" then
    if type(PLDR.IsExplicitATASession) == "function" and PLDR.IsExplicitATASession() then
      return ukey ~= "EXFAT"
    end
    local fs = PLDR.NormalizeHddFs(PLDR.HDD_FS)
    if fs == "BOTH" then return false end
    return ukey ~= fs
  end
  local csv = string.upper(tostring(PLDR.HIDDEN_DEVICES or ""))
  if csv == "" then return false end
  return string.find(","..csv..",", ","..ukey..",", 1, true) ~= nil
end

-- Boot Page (persisted landing page after the boot sequence): "Carousel"
-- (default device carousel) or a device key that auto-enters that game list.
local function NormalizeBootPage(value)
  local key = string.upper(tostring(value or ""))
  if key == "MX4SIO" then return "MX4SIO" end
  if key == "USB" then return "USB" end
  if key == "MMCE" then return "MMCE" end
  if key == "HDD" or key == "APAHDD" or key == "APA" or key == "PFS" then return "HDD" end
  -- exFAT internal HDD (carousel opt 3). Accepting EXFAT/ATA here is what lets the
  -- Boot Page target the exFAT page at all (it used to fold to Carousel).
  if key == "EXFAT" or key == "ATA" then return "EXFAT" end
  return "Carousel"
end

-- ============================================================================
-- SMB / Network config (Stage 1: settings only -- no network code yet).
-- Mirrors OPL's net/SMB fields, but the games path is cwd-relative by default
-- (blank PATH = auto), resolved later with arg > custom > cwd precedence (the
-- same ladder POPSTARTER/DKWDRV paths use). Stored as a PLDR.SMB sub-table,
-- persisted as individual SMB_<KEY>= sidecar lines so arbitrary share/user/pass
-- strings stay intact (only newline is forbidden, and the on-screen keyboard
-- can't produce one). SMB never touches the boot path: the network stack is
-- brought up lazily on SMB-page entry (a later stage), never here or at boot.
PLDR.SMB_FIELDS = {
  { key = "DHCP",      kind = "bool", default = true },
  { key = "PS2_IP",    kind = "str",  default = "192.168.1.10" },
  { key = "NETMASK",   kind = "str",  default = "255.255.255.0" },
  { key = "GATEWAY",   kind = "str",  default = "192.168.1.1" },
  { key = "DNS",       kind = "str",  default = "192.168.1.1" },
  { key = "LINKMODE",  kind = "enum", default = "auto", choices = { "auto", "100full", "100half", "10full", "10half" } },
  -- ADDR_TYPE/NB_ADDR are kept in the spec so old sidecar lines still parse, but
  -- HIDDEN from the settings UI: the connect binding hard-rejects "netbios"
  -- (nbns.irx is OPL-custom, deliberately not built), so offering it was selling a
  -- guaranteed connect failure as a peer choice. Dropping "netbios" from choices
  -- makes SmbSanitize's enum branch coerce any persisted value back to "ip".
  { key = "ADDR_TYPE", kind = "enum", default = "ip",   choices = { "ip" }, hidden = true },
  { key = "NB_ADDR",   kind = "str",  default = "", hidden = true },
  { key = "SERVER",    kind = "str",  default = "192.168.1.100" },
  { key = "PORT",      kind = "str",  default = "1111" },
  { key = "SHARE",     kind = "str",  default = "games" },
  { key = "USER",      kind = "str",  default = "guest" },
  { key = "PASS",      kind = "str",  default = "" },
  { key = "PATH",      kind = "str",  default = "" },
}

-- Normalize one field value to its kind: bool -> boolean, enum -> a valid choice
-- (else its default), str -> single-line string capped at 255 chars, trimmed of
-- leading/trailing whitespace (except PASS -- a password may legitimately begin or
-- end with a space, and trimming would break a working config on reload).
-- PLDR method (NOT a chunk-level local) -- system.lua is near Lua's 200-local cap.
function PLDR.SmbSanitize(field, value)
  if field == nil then return nil end
  if field.kind == "bool" then
    if type(value) == "boolean" then return value end
    local s = string.lower(tostring(value or ""))
    return (s == "1" or s == "true" or s == "on" or s == "yes")
  elseif field.kind == "enum" then
    local s = string.lower(tostring(value or ""))
    for i = 1, #field.choices do
      if field.choices[i] == s then return s end
    end
    return field.default
  else
    local s = tostring(value or "")
    s = string.gsub(s, "[\r\n]", "")  -- sidecar is line-delimited; keep values single-line
    if field.key ~= "PASS" then
      -- The on-screen keyboard's SPACE key makes an invisible trailing space one
      -- press away, and the row renders untrimmed values with no quoting -- the
      -- user sees "right" settings and an unexplainable connect failure.
      s = string.match(s, "^%s*(.-)%s*$") or s
    end
    -- Per-key shape validation: garbage used to be silently REINTERPRETED
    -- differently by each consumer (PORT="44S" -> the C connect sscanf'd 44, the
    -- .DAT tonumber'd nil and implied 445, the row displayed "44S"). Invalid
    -- values fall to the field default so the row always shows what both the
    -- connect path and SMBCONFIG.DAT will actually use.
    if field.key == "PORT" then
      local p = string.match(s, "^%d+$") and tonumber(s) or nil
      if p == nil or p < 1 or p > 65535 then return field.default end
    elseif field.key == "PS2_IP" or field.key == "NETMASK"
           or field.key == "GATEWAY" or field.key == "DNS" then
      local a, b, c, d = string.match(s, "^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
      local function octet(o) o = tonumber(o); return o ~= nil and o >= 0 and o <= 255 end
      if not (octet(a) and octet(b) and octet(c) and octet(d)) then return field.default end
    end
    if string.len(s) > 255 then s = string.sub(s, 1, 255) end
    return s
  end
end

-- Fresh config from the spec defaults.
function PLDR.SmbDefaults()
  local cfg = {}
  for i = 1, #PLDR.SMB_FIELDS do
    cfg[PLDR.SMB_FIELDS[i].key] = PLDR.SMB_FIELDS[i].default
  end
  return cfg
end

-- Copy + sanitize a config against the spec (drops unknown keys, fills missing
-- keys with defaults). Used for snapshot/apply rollback + commit ingestion.
function PLDR.SmbCopy(src)
  src = (type(src) == "table") and src or {}
  local cfg = {}
  for i = 1, #PLDR.SMB_FIELDS do
    local f = PLDR.SMB_FIELDS[i]
    local v = src[f.key]
    if v == nil then v = f.default end
    cfg[f.key] = PLDR.SmbSanitize(f,v)
  end
  return cfg
end

-- Append SMB_<KEY>=value lines to an EncodeSettings line list. bool -> 1/0.
function PLDR.SmbAppendLines(lines, cfg)
  cfg = PLDR.SmbCopy(cfg)
  for i = 1, #PLDR.SMB_FIELDS do
    local f = PLDR.SMB_FIELDS[i]
    local v = cfg[f.key]
    if f.kind == "bool" then
      v = (v == true) and "1" or "0"
    else
      v = tostring(v or "")
    end
    lines[#lines + 1] = "SMB_"..f.key.."="..v
  end
end

-- Parse SMB_<KEY>= lines from sidecar data into a fresh config (a missing key
-- keeps its default; a present-but-empty value -- SMB_SHARE= -- parses to "").
function PLDR.SmbParse(data)
  local cfg = PLDR.SmbDefaults()
  if type(data) ~= "string" then return cfg end
  for i = 1, #PLDR.SMB_FIELDS do
    local f = PLDR.SMB_FIELDS[i]
    local k = "SMB_"..f.key
    local raw = string.match(data, "\n"..k.."=([^\n]*)") or string.match(data, "^"..k.."=([^\n]*)")
    if raw ~= nil then
      cfg[f.key] = PLDR.SmbSanitize(f,raw)
    end
  end
  return cfg
end

local function EncodeSettings()
  -- POPSTARTER_PATH: "" = Automatic. (The legacy PROFILE=/POPSTARTER_MODE=
  -- keys are no longer written; on load, an old file's PROFILE=N preset pick
  -- is migrated into POPSTARTER_PATH -- see LoadSettingsNonFatal -- so the
  -- first save after upgrading persists the migrated path and sheds the keys.)
  local lines = {
    "POPSTARTER_PATH="..tostring(PLDR.POPSTARTER_PATH or ""),
    "BDMA="..tostring(PLDR.BDMA_MODE_KEY or "FAT32"),
    "BDMA_ADAPTIVE="..((PLDR.BDMA_ADAPTIVE == true) and "1" or "0"),
    "DKWDRV_PATH="..tostring(PLDR.DKWDRV_PATH or PLDR.DKWDRV_DEFAULT_PATH),
    "STRICT_HDD_PREEXEC_GATE="..((PLDR.STRICT_HDD_PREEXEC_GATE == true) and "1" or "0"),
    "VIDEO_STANDARD="..tostring(NormalizeVideoStandard(PLDR.VIDEO_STANDARD)),
    "HIDE_TEXT="..(((type(UI) == "table" and UI.HideTextMode == true) and "1") or "0"),
    "KEYBOARD_LAYOUT="..tostring(NormalizeKeyboardLayout(PLDR.KEYBOARD_LAYOUT)),
    "LANGUAGE="..tostring(NormalizeLanguage(PLDR.LANGUAGE)),
    "BOOT_PAGE="..NormalizeBootPage(PLDR.BOOT_PAGE),
    "MULTIDISC_COLLAPSE="..((PLDR.COLLAPSE_MULTIDISC == true) and "1" or "0"),
    "GLOBAL_HIDE="..((PLDR.GLOBAL_HIDE == true) and "1" or "0"),
    "POPSTARTER_MC_FOLDER="..((PLDR.POPSTARTER_MC_FOLDER == false) and "0" or "1"),
    "HIDDEN_DEVICES="..PLDR.NormalizeHiddenDevices(PLDR.HIDDEN_DEVICES),
    "SHOW_DETAILS="..((PLDR.SHOW_DETAILS == true) and "1" or "0"),
    "DETAILS_ALIGN="..((PLDR.DETAILS_ALIGN == "center" or PLDR.DETAILS_ALIGN == "right") and PLDR.DETAILS_ALIGN or "left"),
    "ART_LOCATION="..((PLDR.ART_LOCATION == "pops" or PLDR.ART_LOCATION == "art") and PLDR.ART_LOCATION or "pops_art"),
    "HDD_FS="..PLDR.NormalizeHddFs(PLDR.HDD_FS),
    "COVER_ART="..((PLDR.COVER_ART ~= false) and "1" or "0"),
    "GAMELIST_CACHE="..((PLDR.GAMELIST_CACHE == true) and "1" or "0"),
    "BOOT_SOUND="..((PLDR.BOOT_SOUND ~= false) and "1" or "0"),
    "OVERSCAN="..tostring(math.floor(tonumber(PLDR.OVERSCAN) or 0)),
    "SMB_MODULES="..((PLDR.SMB_MODULES == true) and "1" or "0")
  }
  PLDR.SmbAppendLines(lines, PLDR.SMB)
  return table.concat(lines, "\n").."\n"
end

local function NormalizeBdmaModeKey(mode)
  if mode == nil then
    return nil
  end
  local value = string.upper(tostring(mode or ""))
  -- F-28: strip ALL non-alphanumerics. Every key is alphanumeric (FAT32/USBEXFAT/
  -- MX4SIO/MMCE), so quoting or paren artifacts from any source can't dodge the match.
  value = string.gsub(value, "[^%w]", "")
  if value == "FAT32" then
    return "FAT32"
  elseif value == "USBEXFAT" or value == "EXFAT" then
    return "USBEXFAT"
  elseif value == "MX4SIO" then
    return "MX4SIO"
  elseif value == "MMCE" then
    return "MMCE"
  elseif value == "ATA" or value == "HDDEXFAT" then
    return "ATA"
  end
  return nil
end

local function SnapshotSettingsState()
  return {
    popstarter_path = tostring(PLDR.POPSTARTER_PATH or ""),
    bdma_mode = NormalizeBdmaModeKey(PLDR.BDMA_MODE_KEY) or "FAT32",
    bdma_adaptive = (PLDR.BDMA_ADAPTIVE == true),
    dkwdrv_path = tostring(PLDR.DKWDRV_PATH or PLDR.DKWDRV_DEFAULT_PATH),
    video_standard = NormalizeVideoStandard(PLDR.VIDEO_STANDARD),
    hide_text = (type(UI) == "table" and UI.HideTextMode == true) or false,
    keyboard_layout = NormalizeKeyboardLayout(PLDR.KEYBOARD_LAYOUT),
    language = NormalizeLanguage(PLDR.LANGUAGE),
    boot_page = NormalizeBootPage(PLDR.BOOT_PAGE),
    multidisc_collapse = (PLDR.COLLAPSE_MULTIDISC == true),
    global_hide = (PLDR.GLOBAL_HIDE == true),
    hidden_devices = PLDR.NormalizeHiddenDevices(PLDR.HIDDEN_DEVICES),
    show_details = (PLDR.SHOW_DETAILS == true),
    details_align = ((PLDR.DETAILS_ALIGN == "center" or PLDR.DETAILS_ALIGN == "right") and PLDR.DETAILS_ALIGN or "left"),
    art_location = ((PLDR.ART_LOCATION == "pops" or PLDR.ART_LOCATION == "art") and PLDR.ART_LOCATION or "pops_art"),
    hdd_fs = PLDR.NormalizeHddFs(PLDR.HDD_FS),
    cover_art = (PLDR.COVER_ART ~= false),
    gamelist_cache = (PLDR.GAMELIST_CACHE == true),
    boot_sound = (PLDR.BOOT_SOUND ~= false),
    overscan = math.floor(tonumber(PLDR.OVERSCAN) or 0),
    smb = PLDR.SmbCopy(PLDR.SMB),
    smb_modules = (PLDR.SMB_MODULES == true)
  }
end

local function ApplySettingsState(state)
  if state == nil then
    return
  end
  if state.popstarter_path ~= nil then
    PLDR.POPSTARTER_PATH = tostring(state.popstarter_path)
  end
  local bdma = NormalizeBdmaModeKey(state.bdma_mode)
  if bdma ~= nil then
    PLDR.BDMA_MODE_KEY = bdma
  end
  if type(state.bdma_adaptive) == "boolean" then
    PLDR.BDMA_ADAPTIVE = state.bdma_adaptive
  end
  if state.dkwdrv_path ~= nil then
    PLDR.DKWDRV_PATH = tostring(state.dkwdrv_path)
  end
  if state.video_standard ~= nil then
    PLDR.VIDEO_STANDARD = NormalizeVideoStandard(state.video_standard)
  end
  if state.keyboard_layout ~= nil then
    PLDR.KEYBOARD_LAYOUT = NormalizeKeyboardLayout(state.keyboard_layout)
  end
  if state.language ~= nil then
    PLDR.LANGUAGE = NormalizeLanguage(state.language)
  end
  if state.boot_page ~= nil then
    PLDR.BOOT_PAGE = NormalizeBootPage(state.boot_page)
  end
  if type(state.multidisc_collapse) == "boolean" then
    PLDR.COLLAPSE_MULTIDISC = state.multidisc_collapse
  end
  if type(state.global_hide) == "boolean" then
    PLDR.GLOBAL_HIDE = state.global_hide
  end
  if state.hidden_devices ~= nil then
    PLDR.HIDDEN_DEVICES = PLDR.NormalizeHiddenDevices(state.hidden_devices)
  end
  if type(state.show_details) == "boolean" then
    PLDR.SHOW_DETAILS = state.show_details
  end
  if type(state.details_align) == "string" then
    PLDR.DETAILS_ALIGN = (state.details_align == "center" or state.details_align == "right") and state.details_align or "left"
  end
  if type(state.art_location) == "string" then
    PLDR.ART_LOCATION = (state.art_location == "pops" or state.art_location == "art") and state.art_location or "pops_art"
  end
  if type(state.hdd_fs) == "string" then
    PLDR.HDD_FS = PLDR.NormalizeHddFs(state.hdd_fs)
  end
  if type(state.cover_art) == "boolean" then
    PLDR.COVER_ART = state.cover_art
    -- Keep the live list in step, including on the rollback path (a failed save
    -- re-applies the previous state and the preview box must follow it back).
    if type(UI) == "table" and type(UI.SetCoverPreview) == "function" then
      UI.SetCoverPreview(state.cover_art)
    end
  end
  if type(state.gamelist_cache) == "boolean" then
    PLDR.GAMELIST_CACHE = state.gamelist_cache
  end
  if type(state.boot_sound) == "boolean" then
    PLDR.BOOT_SOUND = state.boot_sound
  end
  if state.overscan ~= nil then
    PLDR.OVERSCAN = math.floor(tonumber(state.overscan) or 0)
    if type(Screen) == "table" and type(Screen.setOverscan) == "function" then pcall(Screen.setOverscan, PLDR.OVERSCAN) end
  end
  if type(state.smb) == "table" then
    PLDR.SMB = PLDR.SmbCopy(state.smb)
  end
  if type(state.smb_modules) == "boolean" then
    PLDR.SMB_MODULES = state.smb_modules
  end
  PLDR.ApplyVideoStandardRuntime(PLDR.VIDEO_STANDARD)
  if type(state.hide_text) == "boolean" and type(UI) == "table" then
    if type(UI.SetHideTextMode) == "function" then
      UI.SetHideTextMode(state.hide_text, false)
    else
      UI.HideTextMode = state.hide_text
    end
  end
end

local function ParseBooleanSetting(value)
  if value == nil then
    return nil
  end
  local raw = string.lower(tostring(value or ""))
  if raw == "1" or raw == "true" or raw == "yes" or raw == "on" then
    return true
  end
  if raw == "0" or raw == "false" or raw == "no" or raw == "off" then
    return false
  end
  return nil
end

local function ReadBdmaModeMarkerCompat(path)
  local marker = ReadWholeFile(path)
  if marker == nil then
    return nil
  end
  marker = string.gsub(marker, "[\r\n]+", "")
  if marker == "" then
    return nil
  end
  return marker
end

local function ResolveEffectiveBdmaMode()
  local marker_candidates = {
    ReadBdmaModeMarkerCompat(BDMA_MODE_MARKER_PATH),                    -- bdma_mode.txt (current)
    ReadBdmaModeMarkerCompat(POPSTARTER_PACK_ROOT.."/.pldr_bdma_mode"), -- back-compat: pre-2026-06-17 name
    ReadBdmaModeMarkerCompat(POPSTARTER_PACK_ROOT.."/.pldr_bdma")       -- back-compat: older alt name
  }
  for i = 1, #marker_candidates do
    local normalized = NormalizeBdmaModeKey(marker_candidates[i])
    if normalized ~= nil then
      return normalized
    end
  end
  return nil
end

function PLDR.ReconcileBdmaModeWithEffectiveState()
  local effective = ResolveEffectiveBdmaMode()
  -- With Adaptive BDMA on, bdma_mode.txt tracks the LAST LAUNCH's variant, not
  -- the user's chosen mode -- letting it override here would clobber the saved
  -- preference (which the adaptive USB arm resolves from). The marker still
  -- answers "what is installed" for the equipped check; only the override is gated.
  if effective ~= nil and PLDR.BDMA_ADAPTIVE ~= true then
    PLDR.BDMA_MODE_KEY = effective
  else
    PLDR.BDMA_MODE_KEY = NormalizeBdmaModeKey(PLDR.BDMA_MODE_KEY) or "FAT32"
  end
  return PLDR.BDMA_MODE_KEY
end

function PLDR.SaveSettingsAtomic()
  local data = EncodeSettings()
  -- HDD-cwd install: settings live ON the HDD next to POPSLoader, written through the
  -- boot partition's EXISTING mount (the launcher's pfs0:, = PLDR.SETTINGS_PATH). PFS
  -- can't mount the same partition twice, so we never open a 2nd mount. If the write
  -- fails because the launcher mounted the partition read-only, TAKE OVER the mount
  -- (remount the same partition RW in place) and retry. NEVER mc0:.
  if PLDR.SETTINGS_HDD_PARTITION ~= nil then
    local ok = WriteAtomic(PLDR.SETTINGS_PATH, data)
    if not ok and type(PLDR.HDD.EnsureBootPartitionWritable) == "function"
       and PLDR.HDD.EnsureBootPartitionWritable() then
      ok = WriteAtomic(PLDR.SETTINGS_PATH, data)
    end
    if not ok and UI ~= nil and UI.Notif_queue ~= nil then
      UI.Notif_queue.add("Couldn't save settings to the HDD", "error")
    end
    return ok
  end
  local target = PLDR.SETTINGS_PATH or PLDR.SETTINGS_PATH_FALLBACK
  local target_is_mc = (target == PLDR.SETTINGS_PATH_FALLBACK)
  -- Always best-effort the MC POPSTARTER pack dir so the BDMA OSD icon
  -- assets remain valid regardless of where settings actually live.
  local mc_dir_ok = PLDR.EnsurePopstarterDir()
  -- Only treat the MC pack failure as fatal when our target IS the MC
  -- fallback. Per-device sidecar saves (mass:/.pldrs, usb:/.pldrs, etc.)
  -- don't depend on mc0:/POPSTARTER existing.
  if target_is_mc and not mc_dir_ok then
    if UI ~= nil and UI.Notif_queue ~= nil then
      UI.Notif_queue.add(PLDR.L("Cannot access").." "..tostring(PLDR.POPSTARTER_DIR))
    end
    return false
  end
  local ok = WriteAtomic(target, data)
  -- Belt-and-suspenders: a non-MC sidecar target that fails to write (unplugged
  -- device, or a boot source whose filesystem isn't live in-app) retries the MC
  -- fallback ONCE and pins future saves there on success -- "Failed to save
  -- settings" forever was the old behavior.
  if not ok and not target_is_mc and PLDR.SETTINGS_PATH_FALLBACK ~= nil then
    if PLDR.EnsurePopstarterDir() and WriteAtomic(PLDR.SETTINGS_PATH_FALLBACK, data) then
      PLDR.SETTINGS_PATH = PLDR.SETTINGS_PATH_FALLBACK
      ok = true
      if UI ~= nil and UI.Notif_queue ~= nil then
        UI.Notif_queue.add(PLDR.L("Saved to").." "..tostring(PLDR.SETTINGS_PATH_FALLBACK).."\n"..PLDR.L("(the usual settings location wasn't writable)"), "warn")
      end
    end
  end
  if not ok and UI ~= nil and UI.Notif_queue ~= nil then
    UI.Notif_queue.add("Failed to save settings")
  end
  return ok
end

-- The old pops_profiles.lua preset paths, kept ONLY for the one-time legacy
-- config migration in LoadSettingsNonFatal (see the POPSTARTER_PATH block
-- there). The load-bearing entries are the hdd0:__common ones (an
-- HDD-resident POPSTARTER driving removable-device games is the supported
-- D-14 setup, and the ladder probes __common only for HDD-page launches) and
-- the cross-device removable ones. Intentionally absent: index 1 (the
-- relative same-folder default) and the old mc?:/POPS presets 13/14 -- a
-- memory card never carries a POPS folder (maintainer), so migrating those
-- could only pin a phantom path; they map to Automatic instead.
local LEGACY_PROFILE_PRESET_PATHS = {
  [2]  = "hdd0:__common:pfs:/POPS/POPSTARTER.ELF",
  [3]  = "hdd0:__common:pfs3:/POPS/POPSTARTER.ELF",
  [4]  = "hdd0:__common:pfs1:/POPS/POPSTARTER.ELF",
  [5]  = "hdd0:__common:pfs2:/POPS/POPSTARTER.ELF",
  [6]  = "mass:/POPS/POPSTARTER.ELF",
  [7]  = "mass0:/POPS/POPSTARTER.ELF",
  [8]  = "mass1:/POPS/POPSTARTER.ELF",
  [9]  = "mass2:/POPS/POPSTARTER.ELF",
  [10] = "mx4sio:/POPS/POPSTARTER.ELF",
  [11] = "mmce0:/POPS/POPSTARTER.ELF",
  [12] = "mmce1:/POPS/POPSTARTER.ELF",
  [15] = "mc1:/POPSTARTER/POPSTARTER.ELF",
  [16] = "mc0:/POPSTARTER/POPSTARTER.ELF",
}

function PLDR.LoadSettingsNonFatal()
  -- NOTE: do NOT EnsurePopstarterDir() here. This runs while applying DEFAULTS, before the
  -- saved POPSTARTER_MC_FOLDER is parsed from the sidecar -- so the OFF guard couldn't see
  -- the user's choice and the folder (+ its OSD icons) was rebuilt on EVERY boot even when
  -- toggled OFF (provato HW report). The ensure now happens AFTER the load, at the call site.
  PLDR.BDMA_MODE_KEY = "FAT32"
  PLDR.BDMA_ADAPTIVE = false  -- per-launch BDMA variant staging (issue #509); default OFF, user opts in
  PLDR.POPSTARTER_PATH = ""  -- "" = Automatic (the launch ladder); a path = custom-first
  PLDR.STRICT_HDD_PREEXEC_GATE = false
  PLDR.VIDEO_STANDARD = PLDR.VIDEO_STANDARD_AUTO
  PLDR.DKWDRV_PATH = tostring(PLDR.DKWDRV_DEFAULT_PATH or "mc0:/PS1_DKWDRV/DKWDRV.ELF")
  PLDR.KEYBOARD_LAYOUT = PLDR.KEYBOARD_LAYOUT_QWERTY  -- R3Z3N review round 3: QWERTY is what users expect; ABC stays selectable
  PLDR.LANGUAGE = "EN"  -- UI language (i18n); default English (source, fallback)
  PLDR.BOOT_PAGE = "Carousel"
  PLDR.COLLAPSE_MULTIDISC = false
  PLDR.GLOBAL_HIDE = false
  PLDR.POPSTARTER_MC_FOLDER = true
  PLDR.HIDDEN_DEVICES = "ILINK"  -- EXP34: hide the i.Link page by default (maintainer); users re-show it in Settings > Device List
  PLDR.SHOW_DETAILS = false
  PLDR.DETAILS_ALIGN = "left"  -- left|center|right; alignment of the game-details box (used only when SHOW_DETAILS)
  PLDR.ART_LOCATION = "art"  -- EXP34 default "art" = <device-root>/ART/ (matches OPL's mass:/ART layout); pops|pops_art|art. Cover .png + details .txt live here on REMOVABLE devices (HDD uses __common/POPS/ART)
  PLDR.HDD_FS = "BOTH"  -- EXP34 default BOTH (maintainer): show both internal-HDD pages (PFS + exFAT). PFS|EXFAT|BOTH. BOTH means the exFAT boot warm-up runs each boot (EXP33 cascade-bound + sema make that safe).
  PLDR.COVER_ART = true  -- draw cover art in the game-list preview box (default ON; was a session-only Square toggle until EXP42 made it a saved setting)
  PLDR.GAMELIST_CACHE = false  -- opt-in persistent per-device USB/MMCE/MX4SIO list cache (OFF = always live scan)
  PLDR.BOOT_SOUND = true  -- play the boot/splash chime (default ON; oldman63 #501 wanted an off switch)
  PLDR.OVERSCAN = 0  -- CRT overscan inset, permille (0 = off; OPL rmSetOverscan units/math)
  PLDR.SMB = PLDR.SmbDefaults()  -- SMB/Network config (settings only; network loads lazily, never at boot)
  PLDR.SMB_MODULES = false  -- whether the SMB streaming pack is installed in mc:/POPSTARTER (sidecar-truthed)
  if type(UI) == "table" then
    if type(UI.SetHideTextMode) == "function" then
      UI.SetHideTextMode(false, false)
    else
      UI.HideTextMode = false
    end
  end
  -- Resolve actual settings source: prefer per-device sidecar
  -- (APP_DIR/.pldrs), fall back to legacy mc0:/POPSTARTER/.pldrs.
  -- Whichever file is found first wins -- PLDR.SETTINGS_PATH is then
  -- pinned to that path so subsequent saves go to the same place,
  -- EXCEPT when we load from the MC fallback AND a sidecar location
  -- is computable. In that case (first-run migration), we read from
  -- MC but pin PLDR.SETTINGS_PATH to the SIDECAR so the next save
  -- writes the user's settings to the per-device location and the
  -- legacy MC copy stops being authoritative. Subsequent boots will
  -- find the sidecar first and stay on it.
  local sidecar = PLDR.SETTINGS_PATH_SIDECAR
  local fallback = PLDR.SETTINGS_PATH_FALLBACK
  local loaded_path = nil
  local migrate_to_sidecar = false
  local pin_to_sidecar = false
  -- The BDM 'mass' bus spells slot 0 as both 'mass:' and 'mass0:', and the
  -- launcher's argv0 can alternate between them across boots (see launch diag),
  -- so a .pldrs saved under one spelling must still be found under the other.
  -- Probe every slot-0 spelling of the sidecar; if a non-canonical one matches,
  -- read it but pin SETTINGS_PATH to the canonical sidecar so the next save
  -- converges to one spelling. (Only slot 0's bare/zero pair is aliased -- slot
  -- NUMBERS are never folded; they may be distinct physical devices.)
  if sidecar ~= nil and sidecar ~= "" then
    local function ProbeSidecarAliases()
      local candidates = MassSlot0PathAliases(sidecar)
      for i = 1, #candidates do
        if doesFileExist(candidates[i]) then
          return candidates[i]
        end
      end
      return nil
    end
    loaded_path = ProbeSidecarAliases()
    -- A 'mass' (USB/BDM) sidecar mounts LAZILY: the SDK reset at startup drops
    -- the mount FMCB used to launch us, and bdmfs_fatfs re-enumerates the drive
    -- asynchronously, so a cold boot can run this probe BEFORE the device is
    -- back -- missing the .pldrs sitting in our own cwd and falling through to
    -- defaults (#494: "saving works, but config not loaded after restart"). The
    -- game-launch read already self-heals this way (TryOpenForLaunch); mirror it
    -- here with the same bounded settle+retry the USB list build uses
    -- (BuildUsbIdentityDeferred). Only a mass*: sidecar needs it -- MC/HDD/MMCE
    -- are already mounted at boot, so they skip the retry (and its sleep).
    if loaded_path == nil and string.match(string.lower(sidecar), "^mass%d*:/") ~= nil then
      -- Legacy-mass boot-device resolution (maintainer, 2026-07-21): an old
      -- launcher can hand us a mass* argv0 that is REALLY an MX4SIO card or
      -- the internal exFAT drive, not USB -- and that slot only exists once
      -- ITS driver is loaded. So the heal ladder escalates: pass 1 = USB only
      -- (the common case, unchanged); passes 2-3 also lazy-load mx4sio_bd
      -- (cheap; its slot then mounts and the ioctl names it "sdc") and kick
      -- the ata worker (non-blocking; an exFAT-backed cwd resolves once the
      -- drive registers). Bounded: 3 passes x 1s, same as before.
      for attempt = 1, 3 do
        if type(PLDR.EnsureUsbMassReadyOnce) == "function" then pcall(PLDR.EnsureUsbMassReadyOnce) end
        if attempt >= 2 and type(System) == "table" then
          if type(System.initMX4SIO) == "function" then pcall(System.initMX4SIO) end
          if type(System.initATAAsync) == "function" then pcall(System.initATAAsync) end
        end
        if type(PLDR.RefreshMassBackends) == "function" then pcall(PLDR.RefreshMassBackends) end
        if type(System) == "table" and type(System.sleep) == "function" then pcall(System.sleep, 1) end
        loaded_path = ProbeSidecarAliases()
        if loaded_path ~= nil then break end
      end
    end
    if loaded_path ~= nil then
      pin_to_sidecar = true
    end
  end
  if loaded_path == nil and fallback ~= nil and fallback ~= "" and doesFileExist(fallback) then
    loaded_path = fallback
    -- First-run migration: if we have a usable sidecar target but the
    -- sidecar file doesn't exist yet, schedule the next save to write
    -- there instead of back to MC.
    if sidecar ~= nil and sidecar ~= "" then
      migrate_to_sidecar = true
    end
  end
  if loaded_path == nil then
    -- No settings yet on either path. Leave PLDR.SETTINGS_PATH at its
    -- init default (sidecar preferred, fallback if no sidecar) so the
    -- first save lands on the right device.
    PLDR.ReconcileBdmaModeWithEffectiveState()
    PLDR.ApplyVideoStandardRuntime(PLDR.VIDEO_STANDARD)
    return false
  end
  if migrate_to_sidecar or pin_to_sidecar then
    PLDR.SETTINGS_PATH = sidecar
  else
    PLDR.SETTINGS_PATH = loaded_path
  end
  -- Always READ from loaded_path: the migration case sets PLDR.SETTINGS_PATH
  -- to the sidecar (which doesn't exist yet) so the next SAVE writes there,
  -- but the actual settings data still has to come from the file we found.
  local data = ReadWholeFile(loaded_path)
  if data == nil then
    PLDR.ReconcileBdmaModeWithEffectiveState()
    PLDR.ApplyVideoStandardRuntime(PLDR.VIDEO_STANDARD)
    return false
  end
  -- Normalize CRLF (and stray lone CR) BEFORE any key is matched: a .pldrs
  -- hand-edited in Windows Notepad keeps the trailing \r in every ([^\n]+)
  -- capture, silently reverting booleans/enums to defaults and appending a
  -- literal \r to paths. Also covers the SMB block (SmbParse gets this data).
  data = string.gsub(data, "\r\n?", "\n")
  local popstarter_path = string.match(data, "\nPOPSTARTER_PATH=([^\n]*)") or string.match(data, "^POPSTARTER_PATH=([^\n]*)")
  local bdma_mode = string.match(data, "\nBDMA=([^\n]+)") or string.match(data, "^BDMA=([^\n]+)") or string.match(data, "\nBDMA_MODE=([^\n]+)") or string.match(data, "^BDMA_MODE=([^\n]+)")
  local dkwdrv_path = string.match(data, "\nDKWDRV_PATH=([^\n]*)") or string.match(data, "^DKWDRV_PATH=([^\n]*)")
  local strict_hdd_preexec_gate = string.match(data, "\nSTRICT_HDD_PREEXEC_GATE=([^\n]+)") or string.match(data, "^STRICT_HDD_PREEXEC_GATE=([^\n]+)")
  local video_standard = string.match(data, "\nVIDEO_STANDARD=([^\n]+)") or string.match(data, "^VIDEO_STANDARD=([^\n]+)")
  local hide_text = string.match(data, "\nHIDE_TEXT=([^\n]+)") or string.match(data, "^HIDE_TEXT=([^\n]+)")
  local keyboard_layout = string.match(data, "\nKEYBOARD_LAYOUT=([^\n]+)") or string.match(data, "^KEYBOARD_LAYOUT=([^\n]+)")
  local boot_page = string.match(data, "\nBOOT_PAGE=([^\n]+)") or string.match(data, "^BOOT_PAGE=([^\n]+)")
  local multidisc_collapse = string.match(data, "\nMULTIDISC_COLLAPSE=([^\n]+)") or string.match(data, "^MULTIDISC_COLLAPSE=([^\n]+)")
  local global_hide = string.match(data, "\nGLOBAL_HIDE=([^\n]+)") or string.match(data, "^GLOBAL_HIDE=([^\n]+)")
  local popstarter_mc_folder = string.match(data, "\nPOPSTARTER_MC_FOLDER=([^\n]+)") or string.match(data, "^POPSTARTER_MC_FOLDER=([^\n]+)")
  local hidden_devices = string.match(data, "\nHIDDEN_DEVICES=([^\n]*)") or string.match(data, "^HIDDEN_DEVICES=([^\n]*)")
  local show_details = string.match(data, "\nSHOW_DETAILS=([^\n]+)") or string.match(data, "^SHOW_DETAILS=([^\n]+)")
  local details_align = string.match(data, "\nDETAILS_ALIGN=([^\n]+)") or string.match(data, "^DETAILS_ALIGN=([^\n]+)")
  local art_location = string.match(data, "\nART_LOCATION=([^\n]+)") or string.match(data, "^ART_LOCATION=([^\n]+)")
  local hdd_fs = string.match(data, "\nHDD_FS=([^\n]+)") or string.match(data, "^HDD_FS=([^\n]+)")
  local cover_art = string.match(data, "\nCOVER_ART=([^\n]+)") or string.match(data, "^COVER_ART=([^\n]+)")
  local gamelist_cache = string.match(data, "\nGAMELIST_CACHE=([^\n]+)") or string.match(data, "^GAMELIST_CACHE=([^\n]+)")
  local boot_sound = string.match(data, "\nBOOT_SOUND=([^\n]+)") or string.match(data, "^BOOT_SOUND=([^\n]+)")
  local overscan = string.match(data, "\nOVERSCAN=([^\n]+)") or string.match(data, "^OVERSCAN=([^\n]+)")
  local bdma_adaptive = string.match(data, "\nBDMA_ADAPTIVE=([^\n]+)") or string.match(data, "^BDMA_ADAPTIVE=([^\n]+)")
  local language = string.match(data, "\nLANGUAGE=([^\n]+)") or string.match(data, "^LANGUAGE=([^\n]+)")
  -- POPSTARTER_PATH: empty/missing = Automatic. Legacy .pldrs migration
  -- (2026-07-13 profiles drop): old files persisted an EMPTY POPSTARTER_PATH
  -- and carried the chosen preset only in PROFILE=N -- the old loader
  -- materialized that preset's absolute path. The Automatic ladder does NOT
  -- probe everything the presets pointed at (the hdd0:__common presets only
  -- resolve for HDD-policy launches -- but HDD POPSTARTER + removable game is
  -- the supported D-14 setup -- and cross-device removable presets likewise),
  -- so an empty path + a legacy PROFILE=N in the mapping table loads as that
  -- preset's path here: it then behaves as an explicit custom path -- tried
  -- first, ladder fall-through -- exactly the old effective behavior
  -- (adversarial-review finding). PROFILE=1 (relative default) and the
  -- mc?:/POPS presets map to Automatic. The legacy keys are never written
  -- back: the next save persists the migrated path and drops them.
  if popstarter_path ~= nil then
    PLDR.POPSTARTER_PATH = tostring(popstarter_path)
  end
  if tostring(PLDR.POPSTARTER_PATH or "") == "" then
    local legacy_profile = tonumber(string.match(data, "\nPROFILE=([^\n]+)") or string.match(data, "^PROFILE=([^\n]+)"))
    local legacy_path = legacy_profile ~= nil and LEGACY_PROFILE_PRESET_PATHS[legacy_profile] or nil
    if legacy_path ~= nil then
      PLDR.POPSTARTER_PATH = legacy_path
    end
  end
  if dkwdrv_path ~= nil and dkwdrv_path ~= "" then
    PLDR.DKWDRV_PATH = dkwdrv_path
  end
  local strict_gate_enabled = ParseBooleanSetting(strict_hdd_preexec_gate)
  if strict_gate_enabled ~= nil then
    PLDR.STRICT_HDD_PREEXEC_GATE = strict_gate_enabled == true
  end
  if video_standard ~= nil and video_standard ~= "" then
    PLDR.VIDEO_STANDARD = NormalizeVideoStandard(video_standard)
  else
    PLDR.VIDEO_STANDARD = NormalizeVideoStandard(PLDR.VIDEO_STANDARD)
  end
  if keyboard_layout ~= nil and keyboard_layout ~= "" then
    PLDR.KEYBOARD_LAYOUT = NormalizeKeyboardLayout(keyboard_layout)
  else
    PLDR.KEYBOARD_LAYOUT = NormalizeKeyboardLayout(PLDR.KEYBOARD_LAYOUT)
  end
  if language ~= nil and language ~= "" then
    PLDR.LANGUAGE = NormalizeLanguage(language)
  else
    PLDR.LANGUAGE = NormalizeLanguage(PLDR.LANGUAGE)
  end
  if boot_page ~= nil and boot_page ~= "" then
    PLDR.BOOT_PAGE = NormalizeBootPage(boot_page)
  else
    PLDR.BOOT_PAGE = NormalizeBootPage(PLDR.BOOT_PAGE)
  end
  local mdc = ParseBooleanSetting(multidisc_collapse)
  if mdc ~= nil then
    PLDR.COLLAPSE_MULTIDISC = mdc == true
  end
  local gh = ParseBooleanSetting(global_hide)
  if gh ~= nil then
    PLDR.GLOBAL_HIDE = gh == true
  end
  local mcf = ParseBooleanSetting(popstarter_mc_folder)
  if mcf ~= nil then
    PLDR.POPSTARTER_MC_FOLDER = mcf == true
  end
  local sd = ParseBooleanSetting(show_details)
  if sd ~= nil then
    PLDR.SHOW_DETAILS = sd == true
  end
  if details_align ~= nil then
    PLDR.DETAILS_ALIGN = (details_align == "center" or details_align == "right") and details_align or "left"
  end
  if art_location ~= nil then
    PLDR.ART_LOCATION = (art_location == "pops" or art_location == "art") and art_location or "pops_art"
  end
  if hdd_fs ~= nil then
    PLDR.HDD_FS = PLDR.NormalizeHddFs(hdd_fs)
  end
  local ca = ParseBooleanSetting(cover_art)
  if ca ~= nil then
    PLDR.COVER_ART = ca == true
  end
  local glc = ParseBooleanSetting(gamelist_cache)
  if glc ~= nil then
    PLDR.GAMELIST_CACHE = glc == true
  end
  local bs = ParseBooleanSetting(boot_sound)
  if bs ~= nil then
    PLDR.BOOT_SOUND = bs == true
  end
  -- Parsed BEFORE the BDMA reconcile below: the reconcile's marker-override is
  -- gated on this flag, so it must reflect the sidecar by the time it runs.
  local ba = ParseBooleanSetting(bdma_adaptive)
  if ba ~= nil then
    PLDR.BDMA_ADAPTIVE = ba == true
  end
  local ov = tonumber(overscan)
  if ov ~= nil then
    PLDR.OVERSCAN = math.floor(ov)
    if type(Screen) == "table" and type(Screen.setOverscan) == "function" then pcall(Screen.setOverscan, PLDR.OVERSCAN) end
  end
  if hidden_devices ~= nil then
    PLDR.HIDDEN_DEVICES = PLDR.NormalizeHiddenDevices(hidden_devices)
  else
    PLDR.HIDDEN_DEVICES = PLDR.NormalizeHiddenDevices(PLDR.HIDDEN_DEVICES)
  end
  if type(PLDR.SmbParse) == "function" then
    PLDR.SMB = PLDR.SmbParse(data)
  end
  local smb_modules = string.match(data, "\nSMB_MODULES=([^\n]+)") or string.match(data, "^SMB_MODULES=([^\n]+)")
  local smb_modules_enabled = ParseBooleanSetting(smb_modules)
  if smb_modules_enabled ~= nil then
    PLDR.SMB_MODULES = smb_modules_enabled == true
  end
  PLDR.BDMA_MODE_KEY = NormalizeBdmaModeKey(bdma_mode) or PLDR.BDMA_MODE_KEY
  PLDR.ReconcileBdmaModeWithEffectiveState()
  -- Invariant: BDMA/SMB modules live in mc:/POPSTARTER, so enabled BDMA *or* installed
  -- SMB modules REQUIRE the folder. Never honor an inconsistent saved state -- force the
  -- POPSTARTER folder on (it can only be disabled while BDMA = FAT32/None AND SMB off).
  if (PLDR.BDMA_MODE_KEY ~= nil and PLDR.BDMA_MODE_KEY ~= "FAT32") or (PLDR.SMB_MODULES == true) then
    PLDR.POPSTARTER_MC_FOLDER = true
  end
  PLDR.ApplyVideoStandardRuntime(PLDR.VIDEO_STANDARD)
  if type(UI) == "table" then
    local hide_text_enabled = ParseBooleanSetting(hide_text)
    if type(UI.SetHideTextMode) == "function" then
      UI.SetHideTextMode(hide_text_enabled == true, false)
    else
      UI.HideTextMode = (hide_text_enabled == true)
    end
    if type(UI.SetCoverPreview) == "function" then
      UI.SetCoverPreview(PLDR.COVER_ART ~= false)
    else
      UI.CoverPreviewEnabled = (PLDR.COVER_ART ~= false)
    end
  end
  return true
end

function PLDR.CommitSettingsChanges(opts)
  opts = opts or {}
  local on_stage = opts.on_stage
  local function EmitStage(stage, message)
    if type(on_stage) == "function" then
      pcall(on_stage, stage, message)
    end
  end
  local prev = SnapshotSettingsState()
  if type(opts.prev_hide_text) == "boolean" then
    prev.hide_text = opts.prev_hide_text
  end
  local next_collapse = (prev.multidisc_collapse == true)
  if type(opts.multidisc_collapse) == "boolean" then next_collapse = opts.multidisc_collapse end
  local next_global_hide = (prev.global_hide == true)
  if type(opts.global_hide) == "boolean" then next_global_hide = opts.global_hide end
  local next_show_details = (prev.show_details == true)
  if type(opts.show_details) == "boolean" then next_show_details = opts.show_details end
  local next_details_align = (prev.details_align == "center" or prev.details_align == "right") and prev.details_align or "left"
  if opts.details_align == "left" or opts.details_align == "center" or opts.details_align == "right" then next_details_align = opts.details_align end
  local next_art_location = (prev.art_location == "pops" or prev.art_location == "art") and prev.art_location or "pops_art"
  if opts.art_location == "pops" or opts.art_location == "pops_art" or opts.art_location == "art" then next_art_location = opts.art_location end
  local next_hdd_fs = PLDR.NormalizeHddFs(prev.hdd_fs)
  if opts.hdd_fs ~= nil then next_hdd_fs = PLDR.NormalizeHddFs(opts.hdd_fs) end
  -- Default-ON boolean, so the fallback is `~= false` (mirrors next_boot_sound).
  local next_cover_art = (prev.cover_art ~= false)
  if type(opts.cover_art) == "boolean" then next_cover_art = opts.cover_art end
  local next_gamelist_cache = (prev.gamelist_cache == true)
  if type(opts.gamelist_cache) == "boolean" then next_gamelist_cache = opts.gamelist_cache end
  local next_boot_sound = (prev.boot_sound ~= false)
  if type(opts.boot_sound) == "boolean" then next_boot_sound = opts.boot_sound end
  local next_bdma_adaptive = (prev.bdma_adaptive == true)
  if type(opts.bdma_adaptive) == "boolean" then next_bdma_adaptive = opts.bdma_adaptive end
  local next_overscan = math.floor(tonumber(prev.overscan) or 0)
  if type(opts.overscan) == "number" then next_overscan = math.floor(opts.overscan) end
  -- Explicit boolean check, NOT `(type==boolean) and opts.x or prev.x`: that
  -- idiom collapses a legitimate `false` to prev (Lua and/or short-circuit), so
  -- Hide-Text could never be toggled OFF through a settings save. Mirrors the
  -- next_collapse pattern directly above.
  local next_hide_text = (prev.hide_text == true)
  if type(opts.hide_text) == "boolean" then next_hide_text = opts.hide_text end
  -- Same explicit-boolean rule as next_hide_text above: the `and/or` idiom would
  -- collapse a legitimate `false` to prev, so SMB modules could never toggle OFF.
  local next_smb_modules = (prev.smb_modules == true)
  if type(opts.smb_modules) == "boolean" then next_smb_modules = opts.smb_modules end
  local next_state = {
    -- "" is a real value (Automatic), so only nil falls back to prev -- and ""
    -- is truthy in Lua, so the or-chain preserves a deliberate clear.
    popstarter_path = tostring(opts.popstarter_path or prev.popstarter_path or ""),
    bdma_mode = NormalizeBdmaModeKey(opts.bdma_mode) or prev.bdma_mode,
    bdma_adaptive = next_bdma_adaptive,
    -- Empty means "restore default", both live and persisted -- matching the
    -- loader (which ignores an empty DKWDRV_PATH= line and falls to the default).
    -- Without this, clearing the field left "" live for the session ("No DKWDRV
    -- found") but silently reverted to the default after a reboot.
    dkwdrv_path = ((opts.dkwdrv_path ~= nil and opts.dkwdrv_path ~= "") and tostring(opts.dkwdrv_path))
                  or ((prev.dkwdrv_path ~= nil and prev.dkwdrv_path ~= "") and prev.dkwdrv_path)
                  or tostring(PLDR.DKWDRV_DEFAULT_PATH),
    video_standard = NormalizeVideoStandard(opts.video_standard or prev.video_standard),
    hide_text = next_hide_text,
    keyboard_layout = NormalizeKeyboardLayout(opts.keyboard_layout or prev.keyboard_layout),
    language = NormalizeLanguage(opts.language or prev.language),
    boot_page = NormalizeBootPage(opts.boot_page or prev.boot_page),
    multidisc_collapse = next_collapse,
    global_hide = next_global_hide,
    show_details = next_show_details,
    details_align = next_details_align,
    art_location = next_art_location,
    hdd_fs = next_hdd_fs,
    cover_art = next_cover_art,
    gamelist_cache = next_gamelist_cache,
    boot_sound = next_boot_sound,
    overscan = next_overscan,
    hidden_devices = PLDR.NormalizeHiddenDevices(opts.hidden_devices or prev.hidden_devices),
    smb = (type(opts.smb) == "table") and PLDR.SmbCopy(opts.smb) or prev.smb,
    smb_modules = next_smb_modules
  }
  local apply_bdma = opts.apply_bdma == true
  local bdma_token = opts.bdma_token

  EmitStage("prepare", "Preparing settings")
  ApplySettingsState(next_state)
  EmitStage("save", "Saving settings")
  if not PLDR.SaveSettingsAtomic() then
    ApplySettingsState(prev)
    return false, "save_failed"
  end

  if (((prev.multidisc_collapse == true) ~= (next_collapse == true))
      or ((prev.global_hide == true) ~= (next_global_hide == true)))
     and type(PLDR.HDD) == "table" and type(PLDR.HDD.WipeCache) == "function" then
    pcall(PLDR.HDD.WipeCache)
  end

  if apply_bdma then
    EmitStage("apply_bdma", "Applying BDMA mode")
    local applied = true
    if type(PLDR.ApplyBdmaModeOnce) == "function" then
      applied = PLDR.ApplyBdmaModeOnce(next_state.bdma_mode, bdma_token)
    else
      applied = PLDR.ApplyBdmaMode(next_state.bdma_mode)
    end
    if not applied then
      ApplySettingsState({
        profile = next_state.profile,
        popstarter_path = next_state.popstarter_path,
        popstarter_mode = next_state.popstarter_mode,
        bdma_mode = prev.bdma_mode,
        dkwdrv_path = next_state.dkwdrv_path,
        video_standard = next_state.video_standard,
        smb_modules = prev.smb_modules   -- BDMA failed before the apply_smb block ran, so SMB was never (un)installed; keep the flag matching the untouched card
      })
      -- The sidecar was already written with the NEW bdma_mode above; the apply
      -- just failed and we rolled bdma_mode back to prev in memory. Re-persist so
      -- the disk BDMA= field matches the rolled-back (effective) state instead of
      -- a mode that never took. (The bdma_mode.txt marker is still the runtime
      -- source of truth via ReconcileBdmaModeWithEffectiveState; this just keeps
      -- the sidecar honest.)
      PLDR.SaveSettingsAtomic()
      PLDR.ReconcileBdmaModeWithEffectiveState()
      return false, "bdma_apply_failed"
    end
  end

  -- Adaptive BDMA ON->OFF transition: while adaptive was on, bdma_mode.txt
  -- tracked the LAST LAUNCH, not the chosen mode -- and with the flag now off,
  -- the finalize/boot reconcile adopts the marker again. Without a restage,
  -- turning adaptive off silently flips the saved BDMA Mode to whatever
  -- launched last (clobbering e.g. an exFAT-USB preference). Re-assert the
  -- chosen mode on the card; the equipped check keeps this zero-write when the
  -- card already matches (including when apply_bdma above just staged it).
  -- Best-effort: settings are saved either way; a failure surfaces and leaves
  -- the marker-adopt behavior, which at least reflects what is on the card.
  if prev.bdma_adaptive == true and next_bdma_adaptive == false then
    if type(PLDR.IsBdmaModeEquipped) == "function"
       and not PLDR.IsBdmaModeEquipped(next_state.bdma_mode) then
      EmitStage("apply_bdma", "Restoring BDMA mode")
      local restaged = PLDR.ApplyBdmaModeOnce(next_state.bdma_mode, PLDR.NextBdmaApplyToken())
      if not restaged and UI ~= nil and UI.Notif_queue ~= nil then
        UI.Notif_queue.add(PLDR.L("Couldn't restore BDMA mode").." "..tostring(next_state.bdma_mode).."\n"..PLDR.L("re-select it under Settings > Storage to restage"), "warn")
      end
    end
  end

  if opts.apply_smb == true then
    EmitStage("apply_smb", "Applying SMB modules")
    -- next_state was already applied above, so PLDR.SMB / PLDR.SMB_MODULES hold the
    -- DESIRED state: ApplySmbModules reads PLDR.SMB for the .DAT, smb_modules picks
    -- install vs remove. On failure, roll the flag back to prev + re-persist so the
    -- sidecar matches the effective (rolled-back) state, mirroring the BDMA rollback.
    local smb_ok
    if next_state.smb_modules == true then
      smb_ok = PLDR.ApplySmbModules(function(i, n, name)
        EmitStage("apply_smb", PLDR.L("Applying SMB modules").." ("..tostring(i).."/"..tostring(n)..") "..tostring(name))
      end)
    else
      smb_ok = PLDR.RemoveSmbModules()
    end
    if not smb_ok then
      -- A FAILED FRESH INSTALL cleans its partial pack off the card: a mid-stage
      -- failure otherwise strands smbman.irx there, and SyncSmbDat's
      -- "smbman.irx exists" probe then treats the broken pack as installed on
      -- every later commit. Only for fresh installs -- ApplySmbModules also
      -- re-runs to refresh the .DATs on an ALREADY-installed pack, and cleaning
      -- up on a transient refresh failure would delete a working pack.
      if next_state.smb_modules == true and prev.smb_modules ~= true then
        pcall(PLDR.RemoveSmbModules)
      end
      PLDR.SMB_MODULES = (prev.smb_modules == true)
      PLDR.SaveSettingsAtomic()
      return false, "smb_apply_failed"
    end
  end

  -- Backfill / refresh the in-game SMB .DAT on every commit: if the pack is installed but
  -- the config files are missing or stale, regenerate them from the saved settings. Cheap
  -- no-op when SMB isn't installed. Best-effort -- settings are already persisted, so a
  -- .DAT write hiccup must never fail the commit.
  pcall(PLDR.SyncSmbDat)

  EmitStage("finalize", "Finalizing settings")
  PLDR.ReconcileBdmaModeWithEffectiveState()
  return true, nil
end

function PLDR.ParseMassIndexFromPath(path)
  local source = NormalizeDirPath(path or APP_DIR_NORM)
  local index = string.match(source, "^mass(%d+):/")
  if index ~= nil then
    return tonumber(index)
  end
  if string.match(source, "^mass:/") then
    return 0
  end
  return nil
end

function PLDR.GetMassDriverName(index)
  if index == nil then return nil end
  local cached = PLDR.MASS.CACHE[index]
  if cached ~= nil and cached.driver ~= nil then
    return cached.driver
  end
  if type(System) == "table" then
    if type(System.getMassDriverName) == "function" then
      local ok, driver = pcall(System.getMassDriverName, index)
      if ok and type(driver) == "string" and driver ~= "" then
        return string.lower(driver)
      end
    end
    if type(System.getMassDriver) == "function" then
      local ok, driver = pcall(System.getMassDriver, index)
      if ok and type(driver) == "string" and driver ~= "" then
        return string.lower(driver)
      end
    end
  end
  return nil
end


function PLDR.GetMassMountDriver(root)
  if type(System) == "table" and type(System.getMassMountDriver) == "function" then
    local ok, driver = pcall(System.getMassMountDriver, root)
    if ok and type(driver) == "string" and driver ~= "" then
      return string.lower(driver)
    end
  end

  local index = PLDR.ParseMassIndexFromPath(root)
  if index == nil then
    return nil
  end

  local driver = PLDR.GetMassDriverName(index)
  if type(driver) == "string" and driver ~= "" then
    return string.lower(driver)
  end

  return nil
end

local function ExtractMassRootFromPath(path)
  local index = PLDR.ParseMassIndexFromPath(path)
  if index == nil then
    return nil
  end
  if index == 0 then
    return "mass:/"
  end
  return "mass"..tostring(index)..":/"
end

local function AddUniqueStartupPath(out, seen, path)
  local candidate = tostring(path or "")
  if candidate == "" then
    return
  end
  if seen[candidate] == true then
    return
  end
  seen[candidate] = true
  table.insert(out, candidate)
end

local function NormalizeMassRoot(root)
  if type(root) ~= "string" or root == "" then
    return nil
  end
  if root == "mass0:/" then
    return "mass:/"
  end
  return root
end

local function AddUniqueMassRoot(out, seen, root)
  local normalized = NormalizeMassRoot(root)
  if normalized == nil or normalized == "" then
    return
  end
  if seen[normalized] == true then
    return
  end
  seen[normalized] = true
  table.insert(out, normalized)
end

local function CollectStartupBackendTargets()
  local targets = {
    usb = false,
    mmce = false,
    mx4sio = false,
    hdd = false,
    hdd_paths = {},
    mass_probe_needed = false,
    mass_roots = {},
    boot_name = nil
  }

  local paths = {}
  local seen_paths = {}
  local seen_hdd_paths = {}
  local seen_roots = {}
  local boot_name = select(1, DetectBootDevice())
  local explicit_ata_session = type(PLDR.IsExplicitATASession) == "function" and PLDR.IsExplicitATASession()
  targets.boot_name = boot_name

  if boot_name == "USB" then
    targets.usb = true
  elseif boot_name == "MMCE" then
    targets.mmce = true
  elseif boot_name == "MX4SIO" then
    targets.mx4sio = true
  elseif boot_name == "HDD" and not explicit_ata_session then
    targets.hdd = true
  end

  AddUniqueStartupPath(paths, seen_paths, BOOT_ARGV0_RAW)
  AddUniqueStartupPath(paths, seen_paths, BOOT_PATH_RAW)
  AddUniqueStartupPath(paths, seen_paths, APP_DIR_RAW)
  AddUniqueStartupPath(paths, seen_paths, APP_DIR_LOCAL)
  AddUniqueStartupPath(paths, seen_paths, PLDR.POPSTARTER_PATH)
  AddUniqueStartupPath(paths, seen_paths, PLDR.DKWDRV_PATH)

  for i = 1, #paths do
    local raw = tostring(paths[i] or "")
    local normalized = string.lower(NormalizeFsPathRaw(paths[i]))
    if string.match(normalized, "^mx4sio%d*:/") ~= nil then
      targets.mx4sio = true
    elseif string.match(normalized, "^mmce%d*:/") ~= nil then
      targets.mmce = true
    elseif not explicit_ata_session and (string.match(normalized, "^pfs%d*:/") ~= nil or string.match(normalized, "^hdd%d:") ~= nil) then
      targets.hdd = true
      AddUniqueStartupPath(targets.hdd_paths, seen_hdd_paths, paths[i])
    elseif not explicit_ata_session and targets.boot_name == "HDD" and (IsDefaultRelativePopstarterPath(raw) or IsLegacyDefaultPopstarterPath(raw)) then
      targets.hdd = true
      AddUniqueStartupPath(targets.hdd_paths, seen_hdd_paths, raw)
    else
      AddUniqueMassRoot(targets.mass_roots, seen_roots, ExtractMassRootFromPath(normalized))
    end
  end

  return targets
end

local function EnsureBootHddMountReady()
  SeedBootHddMountState()

  local boot_slot = nil
  local boot_slot_candidates = {
    BOOT_ARGV0_RAW,
    BOOT_PATH_RAW,
    APP_DIR_LOCAL
  }
  for i = 1, #boot_slot_candidates do
    local prefix = NormalizePfsPrefix(boot_slot_candidates[i])
    if prefix ~= nil then
      boot_slot = ParsePfsSlot(prefix)
    end
    if boot_slot ~= nil then
      break
    end
  end
  if boot_slot == nil then
    boot_slot = GetBootHddMountSlot()
  end
  if boot_slot == nil then
    return nil
  end

  local boot_mount_part = ParseHddPartitionMount(rawget(_G, "BOOT_HDD_MOUNTPART"))
  if boot_mount_part ~= nil then
    local mounted, prefix = MountHddPartitionTracked(boot_mount_part, boot_slot, FIO_MT_RDONLY)
    if mounted and prefix ~= nil then
      return prefix
    end
  end

  local candidates = {
    BOOT_ARGV0_RAW,
    APP_DIR_RAW,
    APP_DIR_LOCAL
  }
  for i = 1, #candidates do
    local mount_part = ParseHddPartitionMount(candidates[i])
    if mount_part ~= nil then
      local mounted, prefix = MountHddPartitionTracked(mount_part, boot_slot, FIO_MT_RDONLY)
      if mounted and prefix ~= nil then
        return prefix
      end
    end
  end
  return nil
end

-- Defined BEFORE ClassifyStartupMassTargets so the closure correctly
-- captures the local. Lua's `local function f()` is sugar for
-- `local f; f = function()...end` -- the local doesn't exist in scope
-- until its declaration line, so a caller above can't capture it as an
-- upvalue and falls through to a global lookup (nil) at call time.
-- Hardware regression 2026-05-28: rolling-release crashed on Enceladus
-- boot with `attempt to call a nil value (global 'ClassifyMassRootDriver')`
-- because this was declared further down the file.
local function ClassifyMassRootDriver(driver)
  local value = string.lower(tostring(driver or ""))
  if value == "" then
    return "unknown"
  end
  if string.find(value, "mx4", 1, true) ~= nil or string.find(value, "sdc", 1, true) ~= nil then
    return "mx4sio"
  end
  -- EXACT "ata", mirroring OPL bdmsupport.c (the ata_bd block driver reports the
  -- name "ata" exactly). NOT a substring test -- that would mis-catch "sata"/"atad"
  -- and risk leaking ata into the usb bucket below. usb/mx4sio keep their proven
  -- substring matches so their working detection is unchanged.
  if value == "ata" then
    return "ata"
  end
  return "usb"
end

local function ClassifyStartupMassTargets(targets)
  if type(targets) ~= "table" or type(targets.mass_roots) ~= "table" then
    return
  end

  for i = 1, #targets.mass_roots do
    local root = targets.mass_roots[i]
    local driver = PLDR.GetMassMountDriver(root)
    if type(driver) == "string" and driver ~= "" then
      local kind = ClassifyMassRootDriver(driver)
      if kind == "mx4sio" then
        targets.mx4sio = true
      else
        targets.usb = true
      end
    else
      targets.mass_probe_needed = true
    end
  end
end

local function WarmStartupHddTargetPaths(paths)
  if type(paths) ~= "table" then
    return
  end

  for i = 1, #paths do
    local candidate = tostring(paths[i] or "")
    local normalized = string.lower(NormalizeFsPathRaw(candidate))
    if candidate ~= "" then
      if IsDefaultRelativePopstarterPath(candidate) or IsLegacyDefaultPopstarterPath(candidate) then
        ResolveHddBootSidecarPopstarter()
      elseif string.match(normalized, "^pfs%d*:/") ~= nil or string.match(normalized, "^hdd%d:") ~= nil then
        ResolveHddReadablePath(candidate)
      end
    end
  end
end

function PLDR.AutoInitStartupBackends()
  local targets = CollectStartupBackendTargets()
  ClassifyStartupMassTargets(targets)

  -- USB stays USB-only. MX4SIO gets initialized below only when
  -- CollectStartupBackendTargets/driver identity already set targets.mx4sio.
  if targets.usb or targets.mass_probe_needed then
    if type(PLDR.EnsureUsbMassReadyOnce) == "function" then
      pcall(PLDR.EnsureUsbMassReadyOnce)
    end
    if type(PLDR.RefreshMassBackends) == "function" then
      pcall(PLDR.RefreshMassBackends)
    end
    targets.mass_probe_needed = false
    ClassifyStartupMassTargets(targets)
  end

  -- MX4SIO is a BDM mass device, not a special boot device. Only bring it up at
  -- boot when we actually BOOTED from it (card present, settings live there).
  -- Never touch it speculatively just because a config path mentions mx4sio: --
  -- the mass list surfaces it on demand when the user opens the MX4SIO page.
  if targets.mx4sio and targets.boot_name == "MX4SIO"
     and type(PLDR.InitMX4SIOPopsRoot) == "function" then
    pcall(PLDR.InitMX4SIOPopsRoot)
  end
  if targets.mmce and type(PLDR.DetectMMCESlot) == "function" then
    pcall(PLDR.DetectMMCESlot, true)
  end
  if targets.hdd then
    if type(PLDR.LoadHDDModules) == "function" then
      pcall(PLDR.LoadHDDModules)
    else
      pcall(EnsureHddRuntimeReadyForExec)
    end
    if targets.boot_name == "HDD" then
      EnsureBootHddMountReady()
    end
    WarmStartupHddTargetPaths(targets.hdd_paths)
  end

  if type(UI) == "table" then
    local refreshed_boot = select(1, DetectBootDevice())
    if refreshed_boot ~= nil then
      UI.boot_device_label = refreshed_boot
    end
  end

  return targets
end

function PLDR.RefreshMassBackends()
  if type(System) == "table" and type(System.refreshMassBackends) == "function" then
    local ok, res = pcall(System.refreshMassBackends)
    return ok and (res == nil or res == true)
  end
  return true
end

function PLDR.EnsureUsbMassReadyOnce()
  if PLDR._usb_mass_ready then
    return true
  end

  if type(System) == "table" and type(System.ensureUsbMass) == "function" then
    pcall(System.ensureUsbMass)
  end
  if type(PLDR.RefreshMassBackends) == "function" then
    pcall(PLDR.RefreshMassBackends)
  end

  PLDR._usb_mass_ready = true
  return true
end

-- One vsync-paced frame for the scan poll loops below. A BARE Screen.flip
-- repaints NOTHING between swaps, so the two framebuffers alternate with stale
-- content -- the "severe visual corruption while the ATA page loads" (maintainer,
-- EXP25 MC-boot test). When the busy overlay is up, re-issue it (ShowSavingOverlay
-- draws the full frame, ticks the spinner, and flips -- same vsync pacing, so the
-- N*60 frame-count timeouts stay honest). Outside an overlay context (boot-time
-- backend init, headless harness) fall back to the plain flip/sleep.
local function PaceScanFrame()
  if type(UI) == "table" and UI.SavingActive == true and type(UI.ShowSavingOverlay) == "function" then
    local ok = pcall(UI.ShowSavingOverlay, UI.SavingMessage, UI.SavingProgress)
    if ok then return end
  end
  if type(Screen) == "table" and type(Screen.flip) == "function" then
    pcall(Screen.flip)
  elseif type(System) == "table" and type(System.sleep) == "function" then
    pcall(System.sleep, 0)
  end
end

-- EXP32: the reference-parity dispatcher. Returns TRUE when the mode's
-- transport is ready to ENUMERATE, false when it is not -- and a caller that
-- gets false must NOT sweep (NHDDL's rule: never probe a device class whose
-- driver isn't up; the sweep's fileXio RPCs against a half-registered core
-- were one of the wedge channels). No branch here loads a module on the UI
-- thread, ever, beyond the LAZY first-engagement load: usbmass_bd is boot-
-- resident, mx4sio_bd loads on first engagement (quick, detection async on
-- its own IOP thread), and ata loads only on its worker (do_boot_init kicks
-- it for exFAT installs; page entry is a bounded status poll, never a load).
local function EnsureMassBackendsReady(mode)
  if mode == "mx4sio" then
    -- CASCADE BOUND: the ata worker loads its modules through the SAME IOP
    -- module loader a page-entry initMX4SIO uses. If that load is in flight
    -- (exFAT boot kick still running, or another page kicked it), wait
    -- screen-alive -- BOUNDED -- instead of queueing a synchronous load
    -- behind a possibly-wedged loader (the one-wedge-two-pages class). Still
    -- running after the budget -> report not-ready; the next entry retries.
    -- (Lazy loading re-opened this window; rev1's boot-time load had closed
    -- it, so the bound returns with the laziness.)
    if type(System) == "table" and type(System.initATAStatus) == "function" then
      local ok_st, st = pcall(System.initATAStatus)
      if ok_st and st == 1 then
        for _ = 1, (10 * 60) do
          PaceScanFrame()
          local ok2, s2 = pcall(System.initATAStatus)
          if ok2 and type(s2) == "number" and s2 ~= 1 then st = s2 break end
        end
        if st == 1 then return false end
      end
    end
    -- LAZY load on first engagement (maintainer directive; OPL loads
    -- transports at first BDM init, R3Z loads stacks when engaged). NO
    -- MMCE<->MX4SIO gate (maintainer, 2026-07-21): official OPL runs mmceman
    -- and mx4sio_bd resident together in the field and it works; we carry the
    -- same freesio2 bus manager OPL does (EXP31). [Recorded tradeoff: R3Z3N
    -- advises gating -- the adapters tie the memcard port's /ACK differently
    -- -- and R3Z full-IOP-resets between the stacks; the maintainer weighed
    -- OPL's field evidence and chose coexistence.] A failed load never
    -- latches -- the next entry retries (OPL's success-only latch rule).
    -- Latched no-op once loaded.
    if type(System) == "table" and type(System.initMX4SIO) == "function" then
      local ok_c, loaded = pcall(System.initMX4SIO)
      return ok_c and loaded ~= false
    end
    return true
  end

  if mode == "ata" then
    -- ata_bd loads on the EE worker, kicked at BOOT by do_boot_init when the
    -- Internal-HDD setting includes exFAT -- into the same near-empty IOP as
    -- the EXP22 build, the only arrangement hardware-proven on the SCPH-30004
    -- class (identical bytes wedged when loaded mid-session onto a full IOP).
    -- Entering the page before the worker finishes (or when the boot kick was
    -- skipped -- setting just changed this session) polls BOUNDED and ONCE:
    -- OPL's 10s ATA budget, screen alive. Still running after that -> report
    -- not-ready; the worker keeps going and the next page entry usually finds
    -- it done. NEVER a synchronous load here -- the old sync fallback was the
    -- historically-freezing configuration.
    local S = System
    if type(S) ~= "table" or type(S.initATAAsync) ~= "function"
       or type(S.initATAStatus) ~= "function" then
      return false
    end
    local st = -1
    pcall(function() st = S.initATAAsync() end)
    -- st: -1 spawn-failed, 1 running, 2 done-ok (a done-fail re-spawns inside
    -- initATAAsync, so a bad early probe stays retryable -- RiptOPL's rule).
    if st == 2 then return true end
    if type(st) ~= "number" or st < 0 then return false end
    for _ = 1, (10 * 60) do
      PaceScanFrame()
      local ok2, s2 = pcall(S.initATAStatus)
      if ok2 and type(s2) == "number" then
        st = s2
        if st ~= 1 then break end
      end
    end
    return st == 2
  end

  if type(PLDR) == "table" and type(PLDR.EnsureUsbMassReadyOnce) == "function" then
    pcall(PLDR.EnsureUsbMassReadyOnce)
  end
  return true
end

local function WaitMassProbeRetry(attempt, max_attempts)
  if attempt >= max_attempts then
    return
  end
  if type(PLDR.RefreshMassBackends) == "function" then
    pcall(PLDR.RefreshMassBackends)
  end
end

-- `report(msg)` is OPTIONAL and exists for ONE reason: the internal-exFAT freeze.
-- A hung IOP call never returns, so the only evidence a tester can give us is the
-- message that was ALREADY on screen when it stopped. Every step below is therefore
-- painted BEFORE the call it names. This is the EXP11 numbered-step channel, which
-- the EXP32 device-layer rebuild dropped -- without it a failed sAGA round tells us
-- nothing, which is exactly what happened on EXP38/39/40.
local function BuildMassRootIdentity(mode, report)
  local function step(msg)
    if type(report) == "function" then pcall(report, msg) end
  end
  step("exFAT step 1: starting the drive")
  local ready = EnsureMassBackendsReady(mode)

  local identity = {
    usb = {},
    mx4sio = {},
    ata = {},
    present_roots = {},
    -- EXP41 diagnostics. `drivers` is the raw GET_DRIVERNAME string per mounted
    -- root; `bdm_devices` is what the block layer says is connected. Together
    -- they answer "the page is empty / wrong -- which half is lying?" without a
    -- serial cable, which is the question that has cost the most test cycles.
    drivers = {},
    bdm_devices = {}
  }

  -- Not ready = do NOT sweep (NHDDL: never probe a class whose driver isn't
  -- up). Return the empty identity plus the flag so callers can distinguish
  -- "drive still starting" from "no device found".
  if ready == false then
    return identity, false
  end
  local seen_present = {}
  local seen_usb = {}
  local seen_mx4 = {}
  local seen_ata = {}

  local function record(normalized, kind)
    if normalized == nil then return end
    if seen_present[normalized] ~= true then
      seen_present[normalized] = true
      table.insert(identity.present_roots, normalized)
    end
    if kind == "mx4sio" then
      if seen_mx4[normalized] ~= true then seen_mx4[normalized] = true; table.insert(identity.mx4sio, normalized) end
    elseif kind == "ata" then
      if seen_ata[normalized] ~= true then seen_ata[normalized] = true; table.insert(identity.ata, normalized) end
    else
      if seen_usb[normalized] ~= true then seen_usb[normalized] = true; table.insert(identity.usb, normalized) end
    end
  end

  -- EXP41: `parId` IS NOT A MASS UNIT. EXP36 mapped each enumerated BDM device to
  -- a slot with `mass<parId>:/`, on the stated premise that "each connected block
  -- device already carries its own mass unit (parId)". That premise is false, and
  -- it is the MX4SIO-page-shows-ATA-files bug.
  --
  -- What parId actually is, in ps2sdk:
  --   ps2atad.c:361            g_ata_bd[i].parId  = 0x00   (whole disk)
  --   usbmass_bd/scsi.c:336    g_scsi_bd[i].parId = 0x00   (whole disk)
  --   IEEE1394_bd/scsi.c:354   g_scsi_bd[i].parId = 0x00   (whole disk)
  --   mx4sio spi_sdcard_driver.c:56           0x00         (whole disk)
  --   part_driver_mbr.c:126    parId = the MBR PARTITION-TYPE byte (0x07, 0x0B...)
  --   part_driver_gpt.c:146    parId = 0
  -- So parId is 0 for every whole-disk device and every GPT partition, and a
  -- filesystem-type byte for MBR partitions. It is never an index.
  --
  -- The consequence was deterministic, not flaky: ATA and MX4SIO both report
  -- parId 0, so BOTH resolved to "mass:/" and BOTH were recorded -- ATA into
  -- identity.ata and MX4SIO into identity.mx4sio. mass:/ is slot 0, i.e. whatever
  -- connected first. Boot from MC with the internal drive present and slot 0 is
  -- ATA, so GetMX4SIOMassRootNow returned mass:/ and the MX4SIO page listed the
  -- ATA drive's games. Re-scanning could never help: parId is 0 every time.
  -- (On an MBR drive it also mapped a FAT32 partition to "mass12:/", which does
  -- not exist, so that device silently vanished instead.)
  --
  -- There is NO correct BDM-device -> massN mapping available to us: bdm_get_bd
  -- exposes BDM's own mount order, which mixes whole-disk devices with partition
  -- pseudo-devices and is unrelated to bdmfs_fatfs's volume index. So we ask the
  -- slot itself what it is, which is authoritative by construction.
  --
  -- EXP36's real goal -- don't stall the carousel on a mid-bringup ATA slot -- is
  -- preserved by the doesFolderExist() gate below: an absent or not-yet-mounted
  -- slot is skipped WITHOUT the ioctl, so we only pay a devctl for slots that are
  -- actually mounted (a handful), never for the flaky/absent ones that caused the
  -- stall. The BDM enumeration is kept, but only to record what the block layer
  -- believes exists, for the diagnostic -- never to derive a slot number.
  for slot = 0, 9 do
    local root = (slot == 0) and "mass:/" or ("mass"..tostring(slot)..":/")
    local normalized = NormalizeMassRoot(root)
    -- Painted before the dopen: a slot backed by a wedged drive hangs HERE, and
    -- the slot number on screen is then the whole diagnosis.
    step("exFAT step 2."..tostring(slot)..": checking "..tostring(root))
    if normalized ~= nil and doesFolderExist(normalized) then
      step("exFAT step 3."..tostring(slot)..": identifying "..tostring(root))
      local driver = PLDR.GetMassMountDriver(normalized)
      identity.drivers[normalized] = (type(driver) == "string" and driver ~= "") and driver or "(none)"
      record(normalized, ClassifyMassRootDriver(driver))
    end
  end

  -- Diagnostic only: what the BDM layer says is connected, independent of which
  -- mass slot each one landed on. A device that appears here but in no slot above
  -- is enumerated-but-not-mounted, which is the single most useful thing to know
  -- when a page comes up empty.
  step("exFAT step 4: reading the device list")
  if type(System) == "table" and type(System.bdmList) == "function" then
    local ok, list = pcall(System.bdmList)
    if ok and type(list) == "table" then
      for i = 1, #list do
        local d = list[i]
        if type(d) == "table" and d.name ~= nil then
          table.insert(identity.bdm_devices, tostring(d.name))
        end
      end
    end
  end

  return identity, true
end

-- Turn System.getUsbDiag()'s raw IRX return codes into one short line for the
-- USB error toast. Deliberately NOT translated: these are numbers for us, and a
-- tester photographing the screen is the only channel we have.
-- The whole point is to split "a module failed to load" from "the modules are up
-- but no drive enumerated" -- indistinguishable until now, which is why two
-- shipped fixes for this bug were aimed at the wrong half.
-- One line summarising where boot time went: the total, and the single most
-- expensive stage. main.cpp runs the ENTIRE IRX block before initGraphics(), so
-- every millisecond here is black screen. Shown on the Credits screen because a
-- tester can photograph it; BootStamp itself has always existed but only ever fed
-- a DPRINTF, which is compiled out of release builds.
-- Deliberately reports the biggest DELTA, not the biggest absolute stamp: the
-- stamps are cumulative, so the gap between consecutive stamps is the cost of the
-- module that sits between them.
function PLDR.GetBootProfileText()
  if type(System) ~= "table" or type(System.getBootProfile) ~= "function" then
    return nil
  end
  local ok, prof = pcall(System.getBootProfile)
  if not ok or type(prof) ~= "table" then
    return nil
  end
  local n = 0
  for _ in pairs(prof) do n = n + 1 end
  if n < 1 then return nil end

  local total, prev = 0, 0
  local worst_name, worst_delta = nil, -1
  for i = 1, n do
    local e = prof[i]
    if type(e) == "table" and type(e.ms) == "number" then
      local d = e.ms - prev
      if d > worst_delta then
        worst_delta = d
        worst_name = tostring(e.stage or "?")
      end
      prev = e.ms
      total = e.ms
    end
  end
  if worst_name == nil then return nil end
  -- Defensive clamp (oldman63: the line ran off the Credits screen). The whole
  -- line must fit ~63 SFONT chars on a 640px screen; the scaffolding + two ms
  -- values eat ~28, so cap the stage name -- the "+Nms" payload at the END is
  -- the part a truncated line would otherwise lose. Stage labels are ASCII.
  if #worst_name > 20 then
    worst_name = string.sub(worst_name, 1, 18)..".."
  end
  return "boot "..tostring(total).."ms (slowest: "..worst_name.." +"..tostring(worst_delta).."ms)"
end

function PLDR.GetUsbDiagText()
  if type(System) ~= "table" or type(System.getUsbDiag) ~= "function" then
    return nil
  end
  local ok, d = pcall(System.getUsbDiag)
  if not ok or type(d) ~= "table" then
    return nil
  end
  local function bad(id, ret)
    -- -999 = never attempted. A load is good when both id and ret are >= 0.
    if id == -999 then return true end
    return not (type(id) == "number" and type(ret) == "number" and id >= 0 and ret >= 0)
  end
  -- Report the FIRST broken link in the chain; everything after it is a
  -- meaningless cascade.
  local chain = {
    {"usbd", d.usbd_id, d.usbd_ret},
    {"bdm", d.bdm_id, d.bdm_ret},
    {"bdmfs_fatfs", d.bdmfs_id, d.bdmfs_ret},
    {"usbmass_bd", d.usbmass_id, d.usbmass_ret},
  }
  for _, m in ipairs(chain) do
    if bad(m[2], m[3]) then
      if m[2] == -999 then
        return m[1].." never loaded"
      end
      return m[1].." failed (id "..tostring(m[2])..", rc "..tostring(m[3])..")"
    end
  end
  -- Every module loaded. Now split the four ways this can still fail, because
  -- "modules OK, no drive seen" conflates all of them and that ambiguity has cost
  -- this bug three tester cycles.
  --   bdm=0  -> usbmass_bd never published a block device: it died in probe /
  --             connect / SET_CONFIGURATION / SCSI warm-up, or in bd_cache_create's
  --             UNCHECKED 128 KiB alloc.
  --   bdm>0  -> BDM has the drive but bdmfs_fatfs never mounted it as massN:
  --             (f_mount failed, or the GPT handler's alloc-failure-returns-0 bug
  --             made BDM stop trying other filesystem handlers).
  -- iop128k=no is the smoking gun for the cache-alloc theory: POPSLoader loads far
  -- more IOP modules than OPL/wLaunchELF, so we may simply be out of contiguous IOP
  -- RAM by the time BDM wants its cache. That is OUR footprint, not the user's drive.
  local parts = {}
  local n = -1
  if type(System.bdmList) == "function" then
    local ok_l, l = pcall(System.bdmList)
    if ok_l and type(l) == "table" then
      n = 0
      for _ in pairs(l) do n = n + 1 end
    end
  end
  parts[#parts + 1] = "bdm=" .. ((n >= 0) and tostring(n) or "?")

  if type(System.iopHeapProbe) == "function" then
    local ok_h, h = pcall(System.iopHeapProbe)
    if ok_h and type(h) == "table" then
      if h.can_alloc_128k then
        parts[#parts + 1] = "iop128k=ok"
      else
        parts[#parts + 1] = "iop128k=NO(" .. tostring(h.largest or "?") .. ")"
      end
    end
  end

  if n == 0 then
    return "no block device published, " .. table.concat(parts, " ")
  elseif n > 0 then
    return "drive found but not mounted, " .. table.concat(parts, " ")
  end
  return "modules OK, no drive seen, " .. table.concat(parts, " ")
end

-- How long to keep looking for a USB drive before giving up.
-- Was 3 (~2s). wLaunchELF_R3Z -- which browses the SAME drive fine on the SAME
-- console that reports "No USB backend detected" to us -- never gives up at all:
-- scanUsbMassDevices (filer.c:903) re-runs loadUsbModules() + re-stats usb0..N on
-- every UI tick, and its 5s throttle is gated on USB_mass_scanned, which is only
-- set once a drive is FOUND. So while nothing is found R3Z rescans continuously,
-- forever, for as long as you sit in the browser. We looked for two seconds and
-- quit permanently. A drive that enumerates at t=6s is found by R3Z and is
-- invisible to us no matter how many times the tester retries.
-- We cannot literally loop forever (this is a blocking scan on page entry, not a
-- UI loop), so bound it. EXP37: a REASONABLE bound (3), not 12 -- a present USB
-- returns on attempt 1 and pays nothing, so the only thing the old 12 did was make
-- a NO-USB page hang ~12s (progress crawling 38%..44%) before failing (maintainer:
-- "shouldn't have to look for usb 12 fucking times... reasonable try and gracefully
-- fail"). 3 attempts (matches the ata/default settle budget) still covers a slow
-- enumerate but fails fast and clean when there is simply no drive.
local USB_PROBE_ATTEMPTS = 3

local function BuildUsbIdentityDeferred(progress)
  local attempts = 0
  local identity = nil
  while attempts < USB_PROBE_ATTEMPTS do
    attempts = attempts + 1
    -- BuildMassRootIdentity -> EnsureMassBackendsReady("usb") -> EnsureUsbMassReadyOnce
    -- re-attempts the module load every pass. EnsureUsbMass only latches on
    -- SUCCESS, so a failed load is retried here the way R3Z retries it.
    identity = BuildMassRootIdentity("usb")
    if type(identity) == "table" and type(identity.usb) == "table" and #identity.usb > 0 then
      return identity
    end
    local hook = progress
    if type(hook) ~= "function" and type(PLDR.UsbProbeProgress) == "function" then
      hook = PLDR.UsbProbeProgress
    end
    if type(hook) == "function" then
      pcall(hook, attempts, USB_PROBE_ATTEMPTS)
    end
    WaitMassProbeRetry(attempts, USB_PROBE_ATTEMPTS)
    if attempts < USB_PROBE_ATTEMPTS and type(System) == "table" and type(System.sleep) == "function" then
      pcall(System.sleep, 1)
    end
  end
  return identity or BuildMassRootIdentity("usb")
end

-- EXP32: ONE bounded deferred builder for the lazily-loaded transports
-- (mx4sio, ata) -- one settle-retry MECHANISM replacing the two divergent
-- ladder implementations, with a per-mode BUDGET where hardware demanded it
-- (see the budget note inside). A pass is just cheap opendir+ioctl sweeps.
-- The old ladders' WaitMassProbeRetry re-poke (a bdm_query RPC that could
-- land mid-module-registration -- one of the wedge channels) is gone from
-- these paths. Second return distinguishes "transport not ready" (worker
-- still starting / load declined or failed) from "swept clean, nothing
-- there", so the page can say the truthful thing instead of a generic
-- no-device toast. (USB keeps its own builder unchanged above: its attempt
-- ladder + diag flow is HW-confirmed since the #508 fix, no freeze channel.)
local function BuildBoundedIdentityDeferred(mode, report)
  -- ONE mechanism (settle-retry sweep), per-mode BUDGET where hardware
  -- demanded it: mx4sio keeps its 6 passes -- the SD-over-SPI bridge is the
  -- slowest/flakiest to mount, the budget was raised 3->6 precisely because
  -- FifthFox hit intermittent "not detected" at 3 on real hardware, and the
  -- maintainer reports zero misses since (2026-07-21: "I haven't had a no
  -- MX4SIO detected in a long time"). The settle exists because mx4sio_bd
  -- self-detects the card on its own IOP thread AFTER the IRX loads; an
  -- immediate sweep races the still-mounting volume (the old two-entries-to-
  -- see-the-card quirk). ata keeps 3: its worker completes detection before
  -- enumeration is allowed at all, so passes only cover FS-mount lag.
  local budget = (mode == "mx4sio") and 6 or 3
  local identity, ready
  local attempts = 0
  while attempts < budget do
    attempts = attempts + 1
    if type(report) == "function" and attempts > 1 then
      pcall(report, "exFAT: retrying (pass "..tostring(attempts).." of "..tostring(budget)..")")
    end
    identity, ready = BuildMassRootIdentity(mode, report)
    if ready == false then
      return identity, false
    end
    if type(identity) == "table" and type(identity[mode]) == "table" and #identity[mode] > 0 then
      return identity, true
    end
    if attempts < budget and type(System) == "table" and type(System.sleep) == "function" then
      pcall(System.sleep, 1)
    end
  end
  -- Return the LAST attempt's result -- re-sweeping here would be a redundant
  -- extra pass of the same probes (review finding on the EXP32 PR).
  return identity, ready
end

-- Both Now-getters return (root|nil, status): "ready" with a root, or nil with
-- "notready" (transport still starting -- ata worker mid-probe) / "nodevice"
-- (swept, nothing present). Callers that ignore the second value keep working.
function PLDR.GetMX4SIOMassRootNow()
  local identity, ready = BuildBoundedIdentityDeferred("mx4sio")
  if type(identity) == "table" and type(identity.mx4sio) == "table" and identity.mx4sio[1] ~= nil then
    return identity.mx4sio[1], "ready"
  end
  return nil, (ready == false) and "notready" or "nodevice"
end

function PLDR.GetATAMassRootNow(report)
  local identity, ready = BuildBoundedIdentityDeferred("ata", report)
  if type(identity) == "table" and type(identity.ata) == "table" and identity.ata[1] ~= nil then
    return identity.ata[1], "ready"
  end
  return nil, (ready == false) and "notready" or "nodevice"
end

function PLDR.GetRootsByType(kind, _mass_snapshot)
  local wanted = string.lower(tostring(kind or ""))
  if wanted == "mx4sio" then
    local identity = BuildBoundedIdentityDeferred("mx4sio")
    return identity.mx4sio
  end
  if wanted == "ata" then
    local identity = BuildBoundedIdentityDeferred("ata")
    return identity.ata
  end

  local identity = BuildUsbIdentityDeferred()
  return identity.usb
end

function PLDR.EnsureBackendForAppDir()
  local path = APP_DIR_NORM
  if path == nil then return false end
  if string.match(path, "^host:/") then
    return true
  end
  if string.match(path, "^mmce%d*:/") then
    if type(System) == "table" and type(System.initMMCE) == "function" then
      local ok = pcall(System.initMMCE)
      return ok
    end
    return true
  end
  if string.match(path, "^mx4sio%d*:/") then
    -- (EXP32: the dead _G.ensureMx4sioInit fallback is gone -- nothing has
    -- defined it since the PR #476 era; System.initMX4SIO is the one path.)
    if type(System) == "table" and type(System.initMX4SIO) == "function" then
      local ok = pcall(System.initMX4SIO)
      return ok
    end
    return true
  end
  if string.match(path, "^mass%d*:/") then
    local mass_index = PLDR.ParseMassIndexFromPath(path)
    local mass_root = nil
    if mass_index == 0 then
      mass_root = "mass:/"
    elseif type(mass_index) == "number" and mass_index > 0 and mass_index <= 9 then
      mass_root = "mass"..tostring(mass_index)..":/"
    end

    local driver = nil
    if mass_root ~= nil then
      driver = PLDR.GetMassMountDriver(mass_root)
    end
    local is_mx4_mass_path = type(driver) == "string" and driver ~= ""
      and (string.find(driver, "sdc", 1, true) ~= nil or string.find(driver, "mx4", 1, true) ~= nil)

    if is_mx4_mass_path then
      if type(System) == "table" and type(System.initMX4SIO) == "function" then
        local ok = pcall(System.initMX4SIO)
        if ok then return true end
      end
    else
      if type(System) == "table" and type(System.initUSB) == "function" then
        local ok = pcall(System.initUSB)
        if ok then return true end
      end
    end
    return true
  end
  return true
end

local function WriteBdmaModeMarker(mode_key, launch_fast)
  -- launch_fast (adaptive launch staging): direct write. A torn marker cannot
  -- match any target, so the next launch just re-stages -- self-healing.
  if launch_fast == true then
    local ok = WriteBytesDirectBounded(tostring(mode_key or ""), BDMA_MODE_MARKER_PATH)
    return ok == true
  end
  return WriteAtomic(BDMA_MODE_MARKER_PATH, tostring(mode_key or ""))
end

local function DeleteIfExists(path)
  local exists = false
  local ok_exists, file_exists = pcall(doesFileExist, path)
  if ok_exists and file_exists == true then
    exists = true
  end
  if not exists then
    local ok_open, fd = pcall(System.openFile, path, FREAD)
    if ok_open and type(fd) == "number" and fd >= 0 then
      exists = true
      pcall(System.closeFile, fd)
    end
  end
  if not exists then
    return true
  end
  local ok_remove = pcall(System.removeFile, path)
  if not ok_remove then
    return false
  end
  local ok_post_exists, post_exists = pcall(doesFileExist, path)
  if ok_post_exists and post_exists == true then
    return false
  end
  return true
end

function PLDR.NextBdmaApplyToken()
  PLDR._bdma_apply_seq = (tonumber(PLDR._bdma_apply_seq) or 0) + 1
  return "bdma:"..tostring(PLDR._bdma_apply_seq)
end

function PLDR.ApplyBdmaModeOnce(mode_key, token, launch_fast)
  if PLDR._bdma_apply_guard.in_progress then
    return false, "busy"
  end
  if token ~= nil and PLDR._bdma_apply_guard.last_token == token then
    return true
  end

  PLDR._bdma_apply_guard.in_progress = true
  local ok, res, err = xpcall(function()
    local aok, aerr = PLDR.ApplyBdmaMode(mode_key, launch_fast)
    return aok, aerr
  end, function(e)
    return false, tostring(e)
  end)
  PLDR._bdma_apply_guard.in_progress = false

  if ok and res == true then
    PLDR._bdma_apply_guard.last_token = token
    return true
  end
  return false, err or res or "apply failed"
end

-- launch_fast=true is the ADAPTIVE LAUNCH path (maintainer's EXP24 spec: "a
-- simple paste of 2 files from the embed"): embeds only (no APP_DIR override
-- probing, so no EnsureBackendForAppDir device init -- with the ATA drive
-- resident those mass-slot probes can wait on a disk spin-up), and direct
-- single-pass writes (the atomic tmp/.bak dance costs ~3x the payload on a
-- memory card). The manual Settings apply keeps the original behavior:
-- external overrides honored, atomic writes, no launch on the line.
function PLDR.ApplyBdmaMode(mode_key, launch_fast)
  local selected = mode_key or "FAT32"
  if not PLDR.EnsurePopstarterDir() then
    if UI ~= nil and UI.Notif_queue ~= nil then
      UI.Notif_queue.add(PLDR.L("Cannot access").." "..tostring(PLDR.POPSTARTER_DIR))
    end
    return false
  end

  if selected == "FAT32" then
    for i = 1, #BDMA_FAT32_REMOVE_FILES do
      if not DeleteIfExists(BDMA_FAT32_REMOVE_FILES[i]) then
        if UI ~= nil and UI.Notif_queue ~= nil then
          UI.Notif_queue.add("Failed to apply FAT32 BDMA")
        end
        return false
      end
    end
    WriteBdmaModeMarker(selected)
    return true
  end

  if not PLDR.EnsurePopstarterUiAssets() then
    return false
  end

  local suffix = BDMA_SUFFIX[selected]
  if suffix == nil then
    if UI ~= nil and UI.Notif_queue ~= nil then
      UI.Notif_queue.add(PLDR.L("Unknown BDMA mode:").." "..tostring(selected))
    end
    return false
  end

  if launch_fast == true then
    -- Launch staging: two embed pastes, nothing else. No backend init, no
    -- external probing, no tmp/.bak. Self-healing: the marker goes last, so
    -- any failure leaves marker ~= target and the next launch re-stages.
    for i = 1, #BDMA_COPY_FILES do
      local name = BDMA_COPY_FILES[i]
      local rel = name..suffix
      local bytes = nil
      if type(System) == "table" and type(System.getEmbeddedAsset) == "function" then
        local ok_embedded, embedded = pcall(System.getEmbeddedAsset, rel)
        if ok_embedded and embedded ~= nil then
          bytes = embedded
        end
      end
      if bytes == nil then
        if UI ~= nil and UI.Notif_queue ~= nil then
          UI.Notif_queue.add(PLDR.L("Missing BDMA source (tried):").."\n"..rel)
        end
        return false
      end
      local dest = POPSTARTER_PACK_ROOT.."/"..name
      local ok_write, wrote = pcall(WriteBytesDirectBounded, bytes, dest)
      if not ok_write or not wrote then
        return false
      end
    end
    if not WriteBdmaModeMarker(selected, true) then
      return false
    end
    return true
  end

  if not PLDR.EnsureBackendForAppDir() then
    if UI ~= nil and UI.Notif_queue ~= nil then
      UI.Notif_queue.add(PLDR.L("BDMA source backend not ready:").."\n"..APP_DIR_NORM)
    end
    return false
  end

  for i = 1, #BDMA_COPY_FILES do
    local name = BDMA_COPY_FILES[i]
    local rel = name..suffix
    local paths = PLDR.BdmaSourceCandidates(rel)
    local fd, source = PLDR.TryOpenFirst(paths)
    if fd ~= nil and (type(fd) ~= "number" or fd >= 0) then
      System.closeFile(fd)
    end
    if source == nil then
      local bytes = nil
      if type(System) == "table" and type(System.getEmbeddedAsset) == "function" then
        local ok_embedded, embedded = pcall(System.getEmbeddedAsset, rel)
        if ok_embedded and embedded ~= nil then
          bytes = embedded
        end
      end
      if bytes == nil then
        if UI ~= nil and UI.Notif_queue ~= nil then
          UI.Notif_queue.add(PLDR.L("Missing BDMA source (tried):").."\n"..table.concat(paths, "\n"))
        end
        return false
      end
      local dest = POPSTARTER_PACK_ROOT.."/"..name
      local ok_write, wrote = pcall(WriteBytesAtomicBounded, bytes, dest)
      if not ok_write or not wrote then
        return false
      end
    else
      local dest = POPSTARTER_PACK_ROOT.."/"..name
      local src_size = GetFileSizeSafe(source)
      local ok, copied = pcall(CopyExternalAtomicBounded, source, dest, src_size)
      if not ok or not copied then
        return false
      end
    end
  end
  WriteBdmaModeMarker(selected)
  return true
end

-- ============================================================================
-- Adaptive BDMA (issue #509): with the manual global BDMA Mode, a user playing
-- from BOTH e.g. MMCE and FAT32-USB must flip Settings between launches (the
-- staged variant serves one device and breaks the other). When BDMA_ADAPTIVE is
-- on, the variant for the LAUNCHED game's device is staged at launch time --
-- and, per the design ask, only after an equipped check so an already-correct
-- card takes ZERO memory-card writes.

function PLDR.ResolveAdaptiveBdmaTarget(ui_scene, device_page)
  -- exFAT internal HDD launches masquerade as USB (mass:) by design; the scene
  -- is the only reliable discriminator, so check it first.
  if type(UI) == "table" and type(UI.SCENES) == "table" and ui_scene == UI.SCENES.GBDMHDD then
    return "ATA"
  end
  if device_page == "MX4SIO" then return "MX4SIO" end
  if device_page == "MMCE" or device_page == "SMB/MMCE" then return "MMCE" end
  if device_page == "USB" then
    -- FAT32-vs-exFAT USB is not detectable from here (identical driver name),
    -- so honor the user's saved USB-family preference: a user whose drive needs
    -- the exFAT modules has BDMA Mode = exFAT-USB saved (it never worked any
    -- other way). Any other saved mode says their USB drive is FAT32 -> remove
    -- the modules so POPStarter's built-in USB stack takes over.
    if NormalizeBdmaModeKey(PLDR.BDMA_MODE_KEY) == "USBEXFAT" then
      return "USBEXFAT"
    end
    return "FAT32"
  end
  -- HDD (PFS), net-SMB, DKWDRV, unknown: POPStarter doesn't consume the BDMA
  -- pair for these; leave whatever is staged alone.
  return nil
end

-- "Equipped proper" = the on-card reality matches the target, checked BEFORE
-- any write: for FAT32 both modules must be absent; for the others both files
-- must exist AND the bdma_mode.txt marker (written only after a fully
-- successful stage) must name the same variant.
function PLDR.IsBdmaModeEquipped(mode_key)
  local target = NormalizeBdmaModeKey(mode_key)
  if target == nil then
    return false
  end
  local have_all = true
  local have_none = true
  for i = 1, #BDMA_COPY_FILES do
    local exists = false
    pcall(function() exists = (doesFileExist(POPSTARTER_PACK_ROOT.."/"..BDMA_COPY_FILES[i]) == true) end)
    if exists then have_none = false else have_all = false end
  end
  if target == "FAT32" then
    return have_none
  end
  if not have_all then
    return false
  end
  return ResolveEffectiveBdmaMode() == target
end

function PLDR.MaybeApplyAdaptiveBdma(ui_scene, device_page)
  if PLDR.BDMA_ADAPTIVE ~= true then return true end
  -- POPSTARTER folder off: modules can't live on the card, and the load-time
  -- invariant keeps effective BDMA at FAT32 in that state. Nothing to stage.
  if PLDR.POPSTARTER_MC_FOLDER == false then return true end
  local target = PLDR.ResolveAdaptiveBdmaTarget(ui_scene, device_page)
  if target == nil then return true end
  if PLDR.IsBdmaModeEquipped(target) then return true end
  -- Staging writes several driver files to the memory card -- the slowest
  -- unpainted step in a launch (maintainer: an ATA launch sat "a very long time
  -- on a frozen state"). ui.lua installs PLDR.LaunchProgress before the launch;
  -- best-effort, never load-bearing. IsBdmaModeEquipped above means an
  -- already-correct card pays nothing and paints nothing.
  if type(PLDR.LaunchProgress) == "function" then
    pcall(PLDR.LaunchProgress, PLDR.L("Staging drivers for this device").." ("..tostring(target)..")", 0.65)
  end
  -- launch_fast=true: embeds-only + direct writes (see ApplyBdmaMode) -- the
  -- launch stall was the atomic dance + the APP_DIR backend init, not the 63KB.
  local ok, why = PLDR.ApplyBdmaModeOnce(target, PLDR.NextBdmaApplyToken(), true)
  if ok and type(PLDR.LaunchProgress) == "function" then
    pcall(PLDR.LaunchProgress, PLDR.L("Starting the game..."), 0.85)
  end
  -- No success toast: a successful launch execs POPStarter and never returns to
  -- the UI loop, so nothing queued here could ever render. The tester-visible
  -- success signal is the launch itself (and bdma_mode.txt naming the variant).
  if not ok and UI ~= nil and UI.Notif_queue ~= nil then
    -- The caller CANCELS the launch on false, returning to the menu loop --
    -- which is the only place this warn can actually be seen.
    UI.Notif_queue.add(PLDR.L("Adaptive BDMA couldn't stage").." "..tostring(target).." "..PLDR.L("-- launch cancelled").."\n("..tostring(why or "apply failed")..") "..PLDR.L("check the memory card, or turn Adaptive BDMA off"), "warn")
  end
  return ok
end

-- ============================================================================
-- SMB-modules install/remove. Mirrors ApplyBdmaMode's copy/delete pattern, but:
--   * the source-of-truth is the .pldrs SMB_MODULES=1/0 line (no on-card marker,
--     no boot reconcile -- unlike BDMA's bdma_mode.txt);
--   * the 2 .DAT files are GENERATED from PLDR.SMB, not copied;
--   * SMB-OFF deletes ONLY the 8 SMB-exclusive files (never RemovePopstarterMcFolder).
-- All hardware-only-verifiable: the exact .DAT byte format is grounded in the
-- recovered POPStarter docs but only a real PS2 + this smbman.irx confirm it.
-- ============================================================================

-- IPCONFIG.DAT body, or nil when DHCP (caller deletes any stale file instead).
-- Format: "<PS2_IP> <NETMASK> <GATEWAY>" (single line, no trailing newline).
function PLDR.RenderSmbIpconfig(cfg)
  if cfg.DHCP == true then return nil end
  return tostring(cfg.PS2_IP or "").." "..tostring(cfg.NETMASK or "").." "..tostring(cfg.GATEWAY or "")
end

-- SMBCONFIG.DAT body. Line 1 = "<SERVER>[:<PORT>] <SHARE>" (the colon-port only
-- when PORT != 445; the colon binds to the server, never the share). Lines 2/3
-- (CRLF-separated) carry USER then plaintext PASS, omitted entirely for guest.
function PLDR.RenderSmbConfig(cfg)
  local server = tostring(cfg.SERVER or "")
  -- Canonicalize PORT numerically so "0445"/" 445 "/non-numeric all collapse to the
  -- default (no :port emitted), keeping the .DAT and the C connect path in agreement.
  local pnum = tonumber(cfg.PORT)
  local portpart = (pnum ~= nil and pnum ~= 445) and (":"..tostring(pnum)) or ""
  local line1 = server..portpart.." "..tostring(cfg.SHARE or "")
  local user = tostring(cfg.USER or "")
  local pass = tostring(cfg.PASS or "")
  -- Credential gate matches the C connect path (lua_smb_connect authenticates
  -- whenever PASS is non-empty, with whatever USER holds -- even empty). A
  -- password-with-blank-User config must reach POPStarter too, or the menu
  -- browses fine while in-game streaming silently lacks the proven-needed
  -- credentials. Both-blank stays guest (line 1 only).
  if user ~= "" or pass ~= "" then
    return line1.."\r\n"..user.."\r\n"..pass
  end
  return line1
end

-- ON: install the SMB pack into mc:/POPSTARTER. Stages the 6 IRX (filesystem
-- override -> embedded fallback, exactly like ApplyBdmaMode) and generates the
-- 2 .DAT from the current PLDR.SMB. Idempotent (atomic overwrites), so it is safe
-- to re-run whenever an SMB field changes to regenerate the .DAT.
function PLDR.ApplySmbModules(progress)
  if not PLDR.EnsurePopstarterDir() then
    if UI ~= nil and UI.Notif_queue ~= nil then UI.Notif_queue.add(PLDR.L("Cannot access").." "..tostring(PLDR.POPSTARTER_DIR)) end
    return false
  end
  -- Per-file progress (maintainer report: the save overlay sat on one static
  -- "Applying SMB modules" through 8 slow memory-card writes -- long enough
  -- that a normal user reads it as a crash). progress(i, total, name) fires
  -- before each write; the caller repaints. Best-effort, never load-bearing.
  local total = #PLDR.SMB_IRX_FILES + 2  -- the 6 IRX + IPCONFIG.DAT + SMBCONFIG.DAT
  local function step(i, name)
    if type(progress) == "function" then pcall(progress, i, total, name) end
  end
  local cfg = PLDR.SmbCopy(PLDR.SMB)
  for i = 1, #PLDR.SMB_IRX_FILES do
    local name = PLDR.SMB_IRX_FILES[i]
    step(i, name)
    local dest = POPSTARTER_PACK_ROOT.."/"..name
    local paths = PLDR.BdmaSourceCandidates(name)
    local fd, source = PLDR.TryOpenFirst(paths)
    if fd ~= nil and (type(fd) ~= "number" or fd >= 0) then
      System.closeFile(fd)
    end
    -- Resolve what SHOULD be there before writing anything.
    local bytes, want_size = nil, nil
    if source == nil then
      bytes = GetEmbeddedAssetBytes(name)
      if bytes == nil then
        if UI ~= nil and UI.Notif_queue ~= nil then UI.Notif_queue.add(PLDR.L("Missing SMB module (tried):").."\n"..table.concat(paths, "\n")) end
        return false
      end
      want_size = #bytes
    else
      want_size = GetFileSizeSafe(source)
    end
    -- Skip files already installed (maintainer: "it shouldn't be pasting the
    -- files unless they aren't there already"). These 6 IRX are static build
    -- artifacts, so a byte-size match means the right file is on the card --
    -- the same staleness test IsBdmaModeEquipped uses to avoid rewriting a
    -- correct card. Turns a re-save from 8 slow memory-card writes into 2
    -- (only the settings-bearing .DATs below always regenerate). A missing
    -- dest gives GetFileSizeSafe nil, so a fresh install still writes all 6.
    local have_size = GetFileSizeSafe(dest)
    if have_size ~= nil and want_size ~= nil and have_size == want_size and have_size > 0 then
      -- already present and the right size: leave it alone
    elseif bytes ~= nil then
      if not WriteBytesAtomicBounded(bytes, dest) then return false end
    else
      if not CopyExternalAtomicBounded(source, dest, want_size) then return false end
    end
  end
  -- IPCONFIG.DAT: write the static line, or delete any stale file when on DHCP.
  step(#PLDR.SMB_IRX_FILES + 1, "IPCONFIG.DAT")
  local ip_dest = POPSTARTER_PACK_ROOT.."/IPCONFIG.DAT"
  local ip_body = PLDR.RenderSmbIpconfig(cfg)
  if ip_body == nil then
    if not DeleteIfExists(ip_dest) then return false end
  else
    if not WriteBytesAtomicBounded(ip_body, ip_dest) then return false end
  end
  -- SMBCONFIG.DAT: always generated from the current settings.
  step(total, "SMBCONFIG.DAT")
  if not WriteBytesAtomicBounded(PLDR.RenderSmbConfig(cfg), POPSTARTER_PACK_ROOT.."/SMBCONFIG.DAT") then
    return false
  end
  return true
end

-- OFF: delete ONLY the 8 SMB-exclusive files from mc:/POPSTARTER, trying them all
-- (so a partial/never-installed pack still cleans up). Leaves icon.sys / *.icn and
-- the BDMA usbd/usbhdfsd modules intact. NEVER calls RemovePopstarterMcFolder.
function PLDR.RemoveSmbModules()
  if not PLDR.EnsurePopstarterDir() then
    if UI ~= nil and UI.Notif_queue ~= nil then UI.Notif_queue.add(PLDR.L("Cannot access").." "..tostring(PLDR.POPSTARTER_DIR)) end
    return false
  end
  local ok = true
  for i = 1, #PLDR.SMB_IRX_FILES do
    if not DeleteIfExists(POPSTARTER_PACK_ROOT.."/"..PLDR.SMB_IRX_FILES[i]) then ok = false end
  end
  if not DeleteIfExists(POPSTARTER_PACK_ROOT.."/IPCONFIG.DAT") then ok = false end
  if not DeleteIfExists(POPSTARTER_PACK_ROOT.."/SMBCONFIG.DAT") then ok = false end
  if not ok and UI ~= nil and UI.Notif_queue ~= nil then
    UI.Notif_queue.add("Failed to remove some SMB modules")
  end
  return ok
end

-- Keep the in-game SMB config (the IPCONFIG.DAT / SMBCONFIG.DAT POPStarter reads) in
-- sync with PLDR.SMB whenever the SMB pack is installed (smbman.irx present): GENERATE
-- them if missing, UPDATE if the network settings changed, drop a stale IPCONFIG.DAT on
-- DHCP. No-op if the pack isn't installed (so it's safe to call unconditionally). Write-
-- if-changed to spare the memory card. Called on every settings commit so the .DAT always
-- track the saved settings -- even if the modules were installed or the files removed out
-- of band (the install/remove path itself still owns the full pack via Apply/RemoveSmbModules).
function PLDR.SyncSmbDat()
  if not doesFileExist(POPSTARTER_PACK_ROOT.."/smbman.irx") then
    return false
  end
  local cfg = PLDR.SmbCopy(PLDR.SMB)
  local function write_if_changed(dest, body)
    if body == nil then
      return DeleteIfExists(dest)        -- DHCP: no static IPCONFIG.DAT should exist
    end
    if ReadWholeFile(dest) == body then
      return true                        -- already current; skip the mc write
    end
    return WriteBytesAtomicBounded(body, dest)
  end
  local ok = true
  if not write_if_changed(POPSTARTER_PACK_ROOT.."/IPCONFIG.DAT", PLDR.RenderSmbIpconfig(cfg)) then ok = false end
  if not write_if_changed(POPSTARTER_PACK_ROOT.."/SMBCONFIG.DAT", PLDR.RenderSmbConfig(cfg)) then ok = false end
  return ok
end

function PLDR.EnsurePopstarterUiAssets()
  -- Folder OFF: never recreate it. EnsurePopstarterDir no-ops (returns true) when OFF, so
  -- without this guard the asset copies below would rebuild the folder + icons. Defensive:
  -- the BDMA interlock already blocks the only current caller (ApplyBdmaMode) while OFF.
  if PLDR.POPSTARTER_MC_FOLDER == false then return true end
  if not PLDR.EnsurePopstarterDir() then
    if UI ~= nil and UI.Notif_queue ~= nil then
      UI.Notif_queue.add(PLDR.L("Cannot access").." "..tostring(PLDR.POPSTARTER_DIR))
    end
    return false
  end

  if not PLDR.EnsureBackendForAppDir() then
    if UI ~= nil and UI.Notif_queue ~= nil then
      UI.Notif_queue.add(PLDR.L("BDMA source backend not ready:").."\n"..APP_DIR_NORM)
    end
    return false
  end

  for i = 1, #BDMA_UI_FILES do
    local asset = BDMA_UI_FILES[i]
    local dest = POPSTARTER_PACK_ROOT.."/"..asset.dst

    if not doesFileExist(dest) then
      local paths = PLDR.BdmaSourceCandidates(asset.src)
      local fd, source = PLDR.TryOpenFirst(paths)
      if fd ~= nil and (type(fd) ~= "number" or fd >= 0) then
        System.closeFile(fd)
      end

      if source == nil then
        local bytes = nil
        if type(System) == "table" and type(System.getEmbeddedAsset) == "function" then
          local ok_embedded, embedded = pcall(System.getEmbeddedAsset, asset.src)
          if ok_embedded and embedded ~= nil then
            bytes = embedded
          end
        end
        if bytes == nil then
          if UI ~= nil and UI.Notif_queue ~= nil then
            UI.Notif_queue.add(PLDR.L("Missing BDMA UI source (tried):").."\n"..table.concat(paths, "\n"))
          end
          return false
        end
        local ok_write, wrote = pcall(WriteBytesAtomicBounded, bytes, dest)
        if not ok_write or not wrote then
          return false
        end
      else
        local src_size = GetFileSizeSafe(source)
        local ok_copy, copied = pcall(CopyExternalAtomicBounded, source, dest, src_size)
        if not ok_copy or not copied then
          return false
        end
      end
    end
  end

  return true
end

function PLDR.DetectMMCESlot(force_refresh)
  if PLDR.MMCE.PROBED and not force_refresh then
    return PLDR.MMCE.PREFIX
  end
  if type(PLDR.EnsureMmceReadyOnce) == "function" then
    pcall(PLDR.EnsureMmceReadyOnce)
  end
  PLDR.MMCE.PROBED = true
  PLDR.MMCE.SLOTS = {}
  PLDR.MMCE.INDEX = 1
  PLDR.MMCE.PREFIX = nil
  local candidates = {"mmce0:/", "mmce1:/"}
  for i = 1, #candidates do
    local candidate = candidates[i]
    if doesFolderExist(candidate) or doesFolderExist(candidate.."POPS/") then
      table.insert(PLDR.MMCE.SLOTS, candidate)
    end
  end
  if #PLDR.MMCE.SLOTS > 0 then
    PLDR.MMCE.PREFIX = PLDR.MMCE.SLOTS[PLDR.MMCE.INDEX]
    return PLDR.MMCE.PREFIX
  end
  return nil
end

function PLDR.GetMMCESlots()
  if not PLDR.MMCE.PROBED then
    PLDR.DetectMMCESlot()
  end
  return PLDR.MMCE.SLOTS
end

function PLDR.SetMMCESlot(index)
  local slots = PLDR.GetMMCESlots()
  if #slots < 1 then
    return nil
  end
  if index < 1 then index = #slots end
  if index > #slots then index = 1 end
  PLDR.MMCE.INDEX = index
  PLDR.MMCE.PREFIX = slots[index]
  return PLDR.MMCE.PREFIX
end


function Font.ftPrintMultiLineAligned(font, x, y, spacing, width, height, text, color)
  local internal_y = y
  local COL = 128
  if type(color) == "number" then COL = color end
  for line in text:gmatch("([^\n]*)\n?") do
    Font.ftPrint(font, x, internal_y, 8, width, height, line, COL)
    internal_y = internal_y+spacing
  end
end

-- Multi-disc collapse: a VCD is a SECONDARY disc if its name carries a DELIMITED
-- disc marker with N>=2 -- opened by "(" or "[":  (Disc N) / [Disc N] / (Disk N)
-- / (CD N) / (CD2) / (Disc N of M). This is the Redump/No-Intro convention.
-- A BARE "... Disc N" / "... CD N" suffix (no brackets) is deliberately NOT
-- matched: real standalone discs end that way -- magazine demo discs ("... Demo
-- CD 47"), music-creation software ("Music 2000 CD 2"), compilation volumes
-- ("Net Yaroze Official CD 2") -- and would be wrongly hidden. Missing a bare
-- "Disc 2" only shows an extra row; hiding a launchable game is far worse.
-- Used to hide disc 2+ from the list when PLDR.COLLAPSE_MULTIDISC is on (disc 1 /
-- unmarked games always show); it never runs when collapse is off (the `and`
-- short-circuits before this is called). The user's VMC disk-swap handles
-- changing discs in-game from the disc-1 entry.
local function IsSecondaryDisc(name)
  if type(name) ~= "string" then return false end
  local lower = string.lower(name)
  local n = string.match(lower, "[%(%[]%s*disc%s*(%d+)")
        or string.match(lower, "[%(%[]%s*disk%s*(%d+)")
        or string.match(lower, "[%(%[]%s*cd%s*(%d+)")
  return n ~= nil and (tonumber(n) or 0) >= 2
end

-- Per-game hide layer: a "<name>.hide" sidecar next to "<name>.VCD" (like the
-- "<name>.png" cover) marks a game hidden. It is read for free from the same
-- directory listing during the scan. With PLDR.GLOBAL_HIDE on, hidden games are
-- filtered out of the list; with it off they are kept and shown DIMMED so they
-- can be managed (L3 toggles hide/unhide). PLDR.HIDDEN is a set keyed by the
-- exact PLDR.GAMES entry string for the current device.
PLDR.HIDDEN = PLDR.HIDDEN or {}

local function HideBasenameOf(vcd_name)
  return (string.gsub(string.lower(tostring(vcd_name or "")), "%.vcd$", ""))
end

local function CollectHideBasenames(DIR)
  local set = {}
  if type(DIR) ~= "table" then return set end
  for i = 1, #DIR do
    local e = DIR[i]
    if type(e) == "table" and not e.directory and type(e.name) == "string"
       and string.lower(string.sub(e.name, -5)) == ".hide" then
      set[string.lower(string.sub(e.name, 1, -6))] = true
    end
  end
  return set
end

function PLDR.IsGameHidden(entry)
  return type(PLDR.HIDDEN) == "table" and entry ~= nil and PLDR.HIDDEN[entry] == true
end

-- Write/remove the "<name>.hide" sidecar given a game's resolved .VCD path.
-- NON-HDD only -- the bundled ps2hdd-osd.irx cannot reliably write PFS, so the
-- UI gates HDD games out before calling this.
function PLDR.SetGameHidden(entry, vcd_path, hide_bool)
  if type(vcd_path) ~= "string" or vcd_path == "" then return false, "no_path" end
  local hide_path = string.gsub(vcd_path, "%.[Vv][Cc][Dd]$", ".hide")
  if hide_path == vcd_path then hide_path = vcd_path..".hide" end
  if type(PLDR.HIDDEN) ~= "table" then PLDR.HIDDEN = {} end
  if hide_bool then
    local ok = pcall(function()
      local fd = System.openFile(hide_path, FCREATE)
      if type(fd) == "number" and fd >= 0 then System.closeFile(fd) end
    end)
    if not ok or not doesFileExist(hide_path) then return false, "write_failed" end
    PLDR.HIDDEN[entry] = true
  else
    if doesFileExist(hide_path) then
      if not pcall(System.removeFile, hide_path) then return false, "remove_failed" end
    end
    PLDR.HIDDEN[entry] = nil
  end
  return true
end

-- HDD counterpart to SetGameHidden: write/remove the <game>.hide sidecar on the
-- game's OWN __.POPS partition (RW remount), so HDD game hiding now works in-app
-- like every other device. `entry` is the encoded HDD entry; the partition comes
-- from PLDR.HDD.GAMEPARTS, the filename from the entry. Returns true / false,reason.
function PLDR.SetHddGameHidden(entry, hide_bool)
  if type(entry) ~= "string" or entry == "" then return false, "no_entry" end
  local partition = nil
  if type(PLDR.HDD) == "table" and type(PLDR.HDD.GAMEPARTS) == "table" then
    partition = PLDR.HDD.GAMEPARTS[entry]
  end
  local filename = string.match(entry, "^[^|]+|(.+)$")
  if partition == nil or filename == nil or filename == "" then return false, "unresolved" end
  local hide_rel = string.gsub(filename, "%.[Vv][Cc][Dd]$", ".hide")
  if hide_rel == filename then hide_rel = filename..".hide" end
  if type(PLDR.HIDDEN) ~= "table" then PLDR.HIDDEN = {} end
  local ok, reason = PLDR.HDD.WriteGamePartitionFile(partition, hide_rel, hide_bool and "" or nil)
  if not ok then return false, reason end
  PLDR.HIDDEN[entry] = hide_bool and true or nil
  -- Keep the in-session memo (ApplyCachedList rehydrates PLDR.HIDDEN from this on an
  -- HDD-page re-entry) and, when the opt-in disk cache is on, hdd_gamecache.txt in
  -- sync -- otherwise the memo reverts this hide on the next re-entry (even cache-OFF).
  if type(PLDR.HDDCACHE_HIDDEN) ~= "table" then PLDR.HDDCACHE_HIDDEN = {} end
  PLDR.HDDCACHE_HIDDEN[entry] = hide_bool and true or nil
  if PLDR.GAMELIST_CACHE == true and type(PLDR.HDD) == "table"
     and type(PLDR.HDD.CreateCache) == "function" then
    pcall(PLDR.HDD.CreateCache, true)  -- re-emit the H-lines from the live PLDR.HIDDEN
  end
  return true
end

function PLDR.GetPS1GameLists(path, updating, on_progress)
  local RET = {}
  local found_smth = false
  if path ~= nil then PLDR.GAMEPATH = path end
  if not updating then PLDR.HIDDEN = {} end
  local DIR = System.listDirectory(PLDR.GAMEPATH)
  if DIR ~= nil then
    local hide_set = CollectHideBasenames(DIR)
    for i = 1, #DIR do
      if not DIR[i].directory then -- not a folder
        if string.lower(string.sub(DIR[i].name,-4)) == ".vcd"
           and not (PLDR.COLLAPSE_MULTIDISC and IsSecondaryDisc(DIR[i].name)) then
          local is_hidden = hide_set[HideBasenameOf(DIR[i].name)] == true
          if not (PLDR.GLOBAL_HIDE and is_hidden) then
            found_smth = true
            if is_hidden then PLDR.HIDDEN[DIR[i].name] = true end
            if updating then
              table.insert(PLDR.GAMES, DIR[i].name)
            else
              table.insert(RET, DIR[i].name)
            end
          end
        end
      end
      if type(on_progress) == "function" and #DIR > 0 then
        pcall(on_progress, i / #DIR)
      end
    end
  else
  end
  if type(on_progress) == "function" then
    pcall(on_progress, 1.0)
  end
  if found_smth then
    if not updating then
      PLDR.GAMES = RET
    end
    table.sort(PLDR.GAMES)
    return PLDR.GAMES
  else
    return nil
  end
end

function PLDR.InitMX4SIOPopsRoot()
  PLDR.MX4SIO.READY = false
  PLDR.MX4SIO.ROOT = nil
  PLDR.MX4SIO.MASSINDX = nil
  PLDR.MX4SIO.IS_MASS_ALIAS = false
  -- MX4SIO is a BDM mass device, listed like USB. GetMX4SIOMassRootNow loads the
  -- driver (idempotent; System.initMX4SIO pulls usbmass first, then the SD
  -- driver, which self-detects a card on its OWN IOP thread -- OPL-style) and
  -- enumerates the mass list with a bounded, PASSIVE retry. NO EE-side card
  -- probe / System.sleep re-poke loop / _G.ensureMx4sioInit: that synchronous
  -- card-hunting is exactly what stalled a no-card MX4SIO on PCSX2. With no card
  -- this just returns nil (empty list) instead of blocking.
  local root, status = PLDR.GetMX4SIOMassRootNow()
  if type(root) == "string" and root ~= "" then
    PLDR.SetMX4SIORoot(root)
    return root.."POPS/"
  end
  return nil, status
end

function PLDR.InitATAPopsRoot(report)
  -- HDD (exFAT) is a BDM mass device read via ata_bd. It enumerates under the
  -- mass: namespace with ioctl driver-name "ata" (NOT ata0:/). EXP32: the
  -- worker is kicked in the BOOT window (do_boot_init) for exFAT installs;
  -- page entry polls it BOUNDED (EnsureMassBackendsReady "ata", 10s max,
  -- screen alive, never a synchronous load) and then runs the bounded sweep.
  -- Second return: "notready" while the drive is still starting, "nodevice"
  -- after a clean empty sweep -- the page toasts accordingly.
  local root, status = PLDR.GetATAMassRootNow(report)
  if type(root) == "string" and root ~= "" then
    return root.."POPS/"
  end
  return nil, status
end

-- Menu-side SMB (Increment 1). LAZY: brings up the network + connects/opens the share
-- HERE (never at boot), then returns the cwd-relative games root device:/[PATH/]POPS/.
-- Returns nil + an error code (NO_LINK/DHCP_FAIL/CONN_FAIL/LOGON_FAIL/ECHO_FAIL/
-- SHARE_FAIL/IRX_LOAD_FAIL) for the UI to map to a message. Mirrors InitATAPopsRoot.
function PLDR.InitSMBPopsRoot(report)
  if type(System) ~= "table" or type(System.connectSMB) ~= "function" then
    return nil, "IRX_LOAD_FAIL"
  end
  if type(report) ~= "function" then report = function() end end
  pcall(report, "Loading network modules...", 0.22)
  if type(System.initSMB) == "function" and not System.initSMB() then
    return nil, "IRX_LOAD_FAIL"
  end
  -- Interface bring-up as its own phase (System.smbNetUp) so the overlay can say
  -- WHICH long wait is happening (link vs DHCP take up to 30 s each) -- one frozen
  -- "Connecting..." frame through the whole bring-up read as a hang and invited a
  -- power-cycle. The handshake (connectSMB) then attributes its own failures.
  if type(System.smbNetUp) == "function" then
    pcall(report, (type(PLDR.SMB) == "table" and PLDR.SMB.DHCP == true)
                  and "Waiting for link + DHCP lease..." or "Waiting for network link...", 0.3)
    local up_ok, up_err = System.smbNetUp(PLDR.SMB)
    if not up_ok then
      return nil, tostring(up_err or "NO_LINK")
    end
  end
  pcall(report, "Logging on to the share...", 0.42)
  local ok, dev_or_err, extra = System.connectSMB(PLDR.SMB)
  if not ok then
    -- connectSMB does LOGON+ECHO BEFORE the share check, so a post-LOGON failure
    -- (ECHO_FAIL / NO_SHARE / SHARE_FAIL) returns with a session already logged on. Tear
    -- it down here -- the BACK-hook disconnect only fires once GSMBNET is entered, which a
    -- failed connect never reaches, so without this a blank-Share (NO_SHARE) attempt would
    -- leak a half-open session every time (caught by the wg6dhihar review). disconnectSMB
    -- is idempotent + smb_irx_loaded-gated, so it's a harmless no-op for pre-LOGON failures
    -- (NO_LINK / DHCP_FAIL / NETBIOS_NA / IRX_LOAD_FAIL). Covers both callers of this fn.
    if type(System.disconnectSMB) == "function" then
      pcall(System.disconnectSMB)
    end
    -- extra carries the comma-separated share list when dev_or_err == "NO_SHARE".
    return nil, tostring(dev_or_err or "CONN_FAIL"), extra
  end
  -- dev_or_err = the mounted device handle ("smb0:"). PLDR.SMB.PATH is an optional
  -- cwd-relative subfolder UNDER the share (blank = share root), then POPS/. Forward
  -- slashes keep it consistent with IsDevicePath (^%a+%d*:/) + the rest of the loader.
  -- NOTE [HW]: smb0: path-separator acceptance is hardware-only-verifiable -- if the
  -- share connects but lists nothing, the separator / leading-slash is the suspect.
  local dev = tostring(dev_or_err or "smb0:")
  local sub = tostring((type(PLDR.SMB) == "table" and PLDR.SMB.PATH) or "")
  sub = string.gsub(sub, "\\", "/")
  sub = string.gsub(sub, "^/+", "")
  sub = string.gsub(sub, "/+$", "")
  -- Forgive the natural mistake: POPS/ is ALWAYS appended below, so a user whose
  -- games live at <share>/PS1/POPS will type "PS1/POPS" -- without this, the scan
  -- root became smb0:/PS1/POPS/POPS/ and the list came up empty with no hint.
  sub = string.gsub(sub, "/?[Pp][Oo][Pp][Ss]$", "")
  local root = dev.."/"
  if sub ~= "" then root = root..sub.."/" end
  return root.."POPS/"
end

function PLDR.BuildMassGameListByType(kind, mass_snapshot, on_progress)
  PLDR.CleanupGameList()
  PLDR.HIDDEN = {}
  local roots = PLDR.GetRootsByType(kind, mass_snapshot)
  local found_any = false
  local total_roots = #roots
  for i = 1, total_roots do
    local pops_root = roots[i].."POPS/"
    if doesFolderExist(pops_root) then
      local DIR = System.listDirectory(pops_root)
      if DIR ~= nil then
        local hide_set = CollectHideBasenames(DIR)
        local dir_total = #DIR
        for j = 1, dir_total do
          local entry = DIR[j]
          if not entry.directory and string.lower(string.sub(entry.name, -4)) == ".vcd"
             and not (PLDR.COLLAPSE_MULTIDISC and IsSecondaryDisc(entry.name)) then
            local is_hidden = hide_set[HideBasenameOf(entry.name)] == true
            if not (PLDR.GLOBAL_HIDE and is_hidden) then
              found_any = true
              local enc = pops_root.."|"..entry.name
              if is_hidden then PLDR.HIDDEN[enc] = true end
              table.insert(PLDR.GAMES, enc)
            end
          end
          if type(on_progress) == "function" then
            local ratio = i / math.max(total_roots, 1)
            if dir_total > 0 then
              ratio = ((i - 1) + (j / dir_total)) / math.max(total_roots, 1)
            end
            pcall(on_progress, ratio)
          end
        end
      elseif type(on_progress) == "function" then
        pcall(on_progress, i / math.max(total_roots, 1))
      end
    elseif type(on_progress) == "function" then
      pcall(on_progress, i / math.max(total_roots, 1))
    end
  end
  if type(on_progress) == "function" then
    pcall(on_progress, 1.0)
  end
  if found_any then
    table.sort(PLDR.GAMES)
    return PLDR.GAMES
  end
  return nil
end

local function EncodeHddGameEntry(partition, relpath)
  if partition == nil or relpath == nil then
    return nil
  end
  return partition.."|"..relpath
end

local function GetOrderedHddPopsPartitions()
  return PLDR.HDD.POPS_PARTITIONS or {}
end

local function AppendHddGameList(partition, list_path, on_progress, partition_index, partition_total)
  if list_path == nil then
    return
  end
  local DIR = System.listDirectory(list_path)
  if DIR == nil then
    -- The partition mounted but its root would not list: surface it instead of
    -- silently showing "No games found" (dir-read faults were invisible before).
    pcall(UI.Notif_queue.add, PLDR.L("HDD dir read failed:")..string.format(" %s (%s)", tostring(list_path), tostring(partition)))
    if type(on_progress) == "function" then
      pcall(on_progress, (tonumber(partition_index) or 1) / math.max(tonumber(partition_total) or 1, 1))
    end
    return
  end
  local hide_set = CollectHideBasenames(DIR)
  local total_entries = #DIR
  -- EXP33 diag: raw counts so a zero-games scan can report "N files, M VCD"
  -- (mounted-but-empty vs had-VCDs-but-all-filtered) -- see BuildGameList.
  if type(PLDR.HDD.SCAN_DIAG) == "table" then
    PLDR.HDD.SCAN_DIAG.entries = (PLDR.HDD.SCAN_DIAG.entries or 0) + total_entries
  end
  for i = 1, #DIR do
    if not DIR[i].directory then
      local is_vcd_file = string.lower(string.sub(DIR[i].name, -4)) == ".vcd"
      local diag = (type(PLDR.HDD.SCAN_DIAG) == "table") and PLDR.HDD.SCAN_DIAG or nil
      if is_vcd_file and diag then
        diag.vcds = (diag.vcds or 0) + 1
      end
      if is_vcd_file then
        -- EXP34: count WHY a counted VCD becomes zero games -- collapsed (multi-disc)
        -- vs hidden (Global Hide) -- so the "no games" toast can say so instead of
        -- reading as a device fault (the FifthFox/APA "hidden by accident" case).
        if PLDR.COLLAPSE_MULTIDISC and IsSecondaryDisc(DIR[i].name) then
          if diag then diag.collapsed = (diag.collapsed or 0) + 1 end
        else
          local is_hidden = hide_set[HideBasenameOf(DIR[i].name)] == true
          if PLDR.GLOBAL_HIDE and is_hidden then
            if diag then diag.hidden = (diag.hidden or 0) + 1 end
          else
            local encoded = EncodeHddGameEntry(partition, DIR[i].name)
            if encoded ~= nil then
              if is_hidden then PLDR.HIDDEN[encoded] = true end
              table.insert(PLDR.GAMES, encoded)
              PLDR.HDD.GAMEPARTS[encoded] = "hdd0:"..partition
            end
          end
        end
      end
    end
    if type(on_progress) == "function" then
      local ratio = (tonumber(partition_index) or 1) / math.max(tonumber(partition_total) or 1, 1)
      if total_entries > 0 then
        ratio = (((tonumber(partition_index) or 1) - 1) + (i / total_entries)) / math.max(tonumber(partition_total) or 1, 1)
      end
      pcall(on_progress, ratio)
    end
  end
end

-- ============================================================================
-- Partition-installed POPS games (HDDOSD / PSBBN style): ONE APA/PFS partition
-- per game, named "PP.<name>" (browser-visible) or "__.<name>" (hidden), with
-- the disc image always at the partition root as IMAGE0.VCD (uppercase). The
-- game's identity is the PARTITION NAME, never the VCD filename; POPStarter
-- launches one via the argv0 basename "PP.<partition>.ELF" (it mounts the
-- partition by its own name and boots pfs:/IMAGE0.VCD). Source: recovered
-- POPStarter wiki (hdd-mode) + R3Z3N. HW-UNVERIFIED: the current r13 beta has
-- a documented old-launch-type bug around __common/POPS assets (VMC/cheats
-- scope unclear) -- listing/launching still works per the wiki contract.

-- A "game candidate" partition name: exactly the 3-char "PP." / "__." prefix
-- with a non-empty tail, EXCLUDING the named-VCD container whitelist
-- (__.POPS, __.POPS0..9) which the classic scan below owns. Reserved system
-- partitions (__system, __common, ...) have no dot at position 3, so the
-- prefix test alone excludes them.
function PLDR.HDD.IsPartitionGameCandidateName(name)
  if type(name) ~= "string" or #name <= 3 then return false end
  local prefix = string.sub(name, 1, 3)
  if prefix ~= "PP." and prefix ~= "__." then return false end
  if string.match(name, "^__%.POPS%d?$") then return false end
  return true
end

-- An encoded HDD game entry ("PART|rel") that denotes a partition-installed
-- game: candidate partition name + the fixed IMAGE0.VCD payload.
function PLDR.IsPartitionInstalledHddEntry(partition, relpath)
  if type(partition) ~= "string" or type(relpath) ~= "string" then return false end
  if string.upper(relpath) ~= "IMAGE0.VCD" then return false end
  return PLDR.HDD.IsPartitionGameCandidateName(partition)
end

-- Sort key for HDD game entries: the DISPLAYED name (lowercased), not the raw
-- "PART|rel" encoding -- raw order put every "PP.*" entry ahead of every
-- "__.POPS*" entry ('P' < '_' in ASCII) even though the list shows neither
-- prefix, breaking alphabetical browsing on mixed drives.
function PLDR.HDD.GameEntryDisplayKey(entry)
  local e = tostring(entry or "")
  local part, rel = string.match(e, "^([^|]+)|(.+)$")
  if rel ~= nil then
    if PLDR.IsPartitionInstalledHddEntry(part, rel) then
      return string.lower(string.sub(part, 4))
    end
    local base = string.match(rel, "([^/]+)$") or rel
    return string.lower((string.gsub(base, "%.[Vv][Cc][Dd]$", "")))
  end
  return string.lower(e)
end

-- Comparator for table.sort over PLDR.GAMES on the HDD page; ties break on the
-- raw entry so the order stays deterministic.
function PLDR.HDD.CompareGameEntriesByDisplay(a, b)
  local ka = PLDR.HDD.GameEntryDisplayKey(a)
  local kb = PLDR.HDD.GameEntryDisplayKey(b)
  if ka ~= kb then return ka < kb end
  return tostring(a or "") < tostring(b or "")
end

-- Enumerate the APA table (HDD.ListPartitions, read-only) and mount-probe each
-- candidate for a root IMAGE0.VCD -- name alone is a proven false-positive trap
-- (HDDOSD apps ship as PP.* partitions too, e.g. CodeBreaker). Fills
-- PLDR.HDD.PARTGAMES = { {partition=..., hidden=...}, ... } and flips FOUNDANY
-- so a PP.-only library still opens the page. Runs under the same
-- HAS_CHECKED gate as the classic probe (its caller).
function PLDR.HDD.DiscoverPartitionGames(on_progress)
  PLDR.HDD.PARTGAMES = {}
  if type(HDD) ~= "table" or type(HDD.ListPartitions) ~= "function" then return end
  local ok, parts = pcall(HDD.ListPartitions)
  if not ok or type(parts) ~= "table" then return end
  local candidates = {}
  for i = 1, #parts do
    if PLDR.HDD.IsPartitionGameCandidateName(parts[i]) then
      candidates[#candidates + 1] = parts[i]
    end
  end
  table.sort(candidates)
  for i = 1, #candidates do
    local partition = candidates[i]
    local mounted, prefix, slot = MountHddGamePartitionTracked("hdd0:"..partition, FIO_MT_RDONLY)
    if mounted and prefix ~= nil then
      local has_image = false
      pcall(function() has_image = (doesFileExist(prefix.."IMAGE0.VCD") == true) end)
      if has_image then
        -- Same .hide sidecar convention as every other device: IMAGE0.hide
        -- next to the VCD on the game's own partition (L3 writes it there).
        local is_hidden = false
        pcall(function() is_hidden = (doesFileExist(prefix.."IMAGE0.hide") == true) end)
        PLDR.HDD.PARTGAMES[#PLDR.HDD.PARTGAMES + 1] = { partition = partition, hidden = is_hidden }
        PLDR.HDD.FOUNDANY = true
      end
      if slot ~= nil then
        UMountHddPartitionTracked(slot)
      end
    end
    if type(on_progress) == "function" then
      pcall(on_progress, i / math.max(#candidates, 1))
    end
  end
end

function PLDR.HDD.CheckAvailableHddPopsParts(on_progress)
  if not PLDR.HDD.HAS_CHECKED then --HDD is checked only once since it cannot be removed/replaced without damaging the console
    PLDR.HDD.FOUNDANY = false
    PLDR.HDD.AVAILABLE = {}
    PLDR.HDD.GAME_SLOT = nil
    PLDR.HDD.LAST_MOUNT_RC = nil
    local ordered_partitions = GetOrderedHddPopsPartitions()
    local total_partitions = #ordered_partitions
    for i = 1, total_partitions do
      local partition = ordered_partitions[i]
      local mounted, _, slot, mount_rc = MountHddGamePartitionTracked("hdd0:"..partition, FIO_MT_RDONLY)
      PLDR.HDD.AVAILABLE[partition] = mounted == true
      if mounted == true then
        PLDR.HDD.FOUNDANY = true
        if slot ~= nil then
          UMountHddPartitionTracked(slot)
        end
      elseif mount_rc ~= nil then
        -- Breadcrumb for the "empty list from a non-HDD boot" class: keep the
        -- last raw mount rc so the page can say WHY nothing mounted.
        PLDR.HDD.LAST_MOUNT_RC = mount_rc
      end
      if type(on_progress) == "function" then
        -- Scaled to 0..0.6: the partition-game discovery below owns 0.6..1.0,
        -- keeping this phase's progress monotonic (it used to jump backwards).
        pcall(on_progress, (i / math.max(total_partitions, 1)) * 0.6)
      end
    end
    -- Partition-installed games ride the same once-per-boot check. pcall'd:
    -- a discovery fault must never take the classic __.POPS scan down with it.
    local disco_progress = nil
    if type(on_progress) == "function" then
      disco_progress = function(r) pcall(on_progress, 0.6 + (tonumber(r) or 0) * 0.4) end
    end
    pcall(PLDR.HDD.DiscoverPartitionGames, disco_progress)
    PLDR.HDD.HAS_CHECKED = true
  end
  if type(on_progress) == "function" then
    pcall(on_progress, 1.0)
  end
end

function PLDR.HDD.BuildGameList(on_progress)
  -- Pure scanner: always mounts each available __.POPS partition and lists it.
  -- Cache handling lives in PLDR.HDD.EnsureGameList. Seeding PLDR.GAMES from the
  -- cache here double-counted entries (it then appended a fresh scan) and left
  -- GAMEPARTS empty, which is why USECACHE used to be disabled.
  PLDR.GAMES = {}
  PLDR.HIDDEN = {}
  PLDR.HDD.GAMEPARTS = {}
  PLDR.HDD.FROM_CACHE = false
  -- EXP33: scan diagnostics. When the scan yields zero games on a drive whose
  -- __.POPS partitions DID mount in pass 1 (the "partitions are empty" report),
  -- these counters let the page say WHY -- a silent pass-2 re-mount failure vs a
  -- mounted-but-empty listing vs everything filtered -- so the next hardware
  -- report is self-diagnosing instead of opaque. (entries/vcds are added by
  -- AppendHddGameList.)
  PLDR.HDD.SCAN_DIAG = { avail = 0, remounted = 0, remount_fail = 0,
                         last_fail_part = nil, last_fail_rc = nil,
                         entries = 0, vcds = 0, hidden = 0, collapsed = 0 }
  PLDR.GAMEPATH = BuildMountedPfsPrefix(GetActiveHddGameSlot())
  if not PLDR.HDD.FOUNDANY then return end
  local ordered_partitions = GetOrderedHddPopsPartitions()
  local total_partitions = #ordered_partitions
  for i = 1, total_partitions do
    local partition = ordered_partitions[i]
    if PLDR.HDD.AVAILABLE[partition] == true then
      PLDR.HDD.SCAN_DIAG.avail = PLDR.HDD.SCAN_DIAG.avail + 1
      local mounted, prefix, slot, mrc = MountHddGamePartitionTracked("hdd0:"..partition, FIO_MT_RDONLY)
      -- Retry ONCE: this partition mounted in pass 1, so a pass-2 miss is
      -- transient (the warm single-attempt mount -- hdd_spinup_waited latched --
      -- lost a race with the coexisting BDM/exFAT stack on the same drive). This
      -- is a leading suspect for the silent-zero-games report. Scoped to
      -- AVAILABLE partitions ONLY, so it can never reintroduce the
      -- absent-partition scan stall the single-attempt mode exists to prevent.
      if not (mounted and prefix ~= nil) then
        if type(System) == "table" and type(System.sleep) == "function" then pcall(System.sleep, 1) end
        mounted, prefix, slot, mrc = MountHddGamePartitionTracked("hdd0:"..partition, FIO_MT_RDONLY)
      end
      if mounted and prefix ~= nil then
        PLDR.HDD.SCAN_DIAG.remounted = PLDR.HDD.SCAN_DIAG.remounted + 1
        PLDR.GAMEPATH = prefix
        AppendHddGameList(partition, prefix, on_progress, i, total_partitions)
        if slot ~= nil then
          UMountHddPartitionTracked(slot)
        end
      else
        PLDR.HDD.SCAN_DIAG.remount_fail = PLDR.HDD.SCAN_DIAG.remount_fail + 1
        PLDR.HDD.SCAN_DIAG.last_fail_part = partition
        PLDR.HDD.SCAN_DIAG.last_fail_rc = mrc
        if type(on_progress) == "function" then
          pcall(on_progress, i / math.max(total_partitions, 1))
        end
      end
    elseif type(on_progress) == "function" then
      pcall(on_progress, i / math.max(total_partitions, 1))
    end
  end
  -- Partition-installed games (PP./__. one-partition-per-game): discovered by
  -- DiscoverPartitionGames under the same HAS_CHECKED gate; encoded like every
  -- HDD entry so caching / hiding / launch routing flow through unchanged.
  -- Multi-disc collapse applies to the partition-derived DISPLAY name, same as
  -- every other list source (a per-disc install shape is "PP.Game (Disc 2)").
  local partgames = PLDR.HDD.PARTGAMES or {}
  for i = 1, #partgames do
    local pg = partgames[i]
    if type(pg) == "table" and type(pg.partition) == "string" then
      local is_hidden = pg.hidden == true
      if not (PLDR.GLOBAL_HIDE and is_hidden)
         and not (PLDR.COLLAPSE_MULTIDISC and IsSecondaryDisc(string.sub(pg.partition, 4))) then
        local encoded = EncodeHddGameEntry(pg.partition, "IMAGE0.VCD")
        if encoded ~= nil then
          if is_hidden then PLDR.HIDDEN[encoded] = true end
          table.insert(PLDR.GAMES, encoded)
          PLDR.HDD.GAMEPARTS[encoded] = "hdd0:"..pg.partition
        end
      end
    end
  end
  if type(on_progress) == "function" then
    pcall(on_progress, 1.0)
  end
  table.sort(PLDR.GAMES, PLDR.HDD.CompareGameEntriesByDisplay)
end

function PLDR.LoadHDDModules()
  -- EXP33 cascade bound: the boot-time ata worker (do_boot_init's initATAAsync
  -- kick, fired every boot where Internal HDD includes exFAT) and this APA path
  -- BOTH call the native EnsureAtaBdm. Before EXP33 they raced the load-once
  -- latches -> double ata_bd load, whose 2nd _start re-resets the live ATA bus
  -- (CosmicScale APA-Jail 42% class; a leading suspect for the fresh-boot
  -- "APA lists no games" report). Wait screen-alive for the worker to finish so
  -- HDD.Initialize's EnsureAtaBdm runs AFTER it (then it's a latched no-op). A
  -- native mutex (EnsureAtaBdm sema) backs this up if the wait ever times out.
  if type(System) == "table" and type(System.initATAStatus) == "function" then
    local ok_st, st = pcall(System.initATAStatus)
    if ok_st and st == 1 then
      for _ = 1, (10 * 60) do
        PaceScanFrame()
        local ok2, s2 = pcall(System.initATAStatus)
        if ok2 and type(s2) == "number" and s2 ~= 1 then break end
      end
    end
  end
  local ID, RET, SUCCESS, MODULE
  if PLDR.HDD.LOADSTATE == 0 then
    SUCCESS, MODULE, ID, RET = HDD.Initialize()
    if not SUCCESS then
      PLDR.HDD.LOADSTATE = -1
      UI.Notif_queue.add(string.format("failed to load %s.IRX\nid:%d, ret:%d", MODULE, ID, RET))
      return
    end
    HDD_EXEC_INIT_DONE = true
    SUCCESS = HDD.GetHDDStatus()
    PLDR.HDD.STATUS = SUCCESS
    if SUCCESS ~= 0 then
      PLDR.HDD.LOADSTATE = -1
      if SUCCESS == 1 then
        UI.Notif_queue.add("WARNING: HDD has no APA format")
      elseif SUCCESS == 2 then
        UI.Notif_queue.add("ERROR: HDD is not accessible")
      elseif SUCCESS == 3 then
        UI.Notif_queue.add("WARNING: No HDD detected")
      elseif SUCCESS == -19 then
        UI.Notif_queue.add("ERROR: Hardware issue detected\nCheck your HDD, network adapter and connection")
      end
    end
    if PLDR.HDD.LOADSTATE ~= -1 then
      PLDR.HDD.LOADSTATE = 1
    end
  elseif PLDR.HDD.LOADSTATE == -1 and HDD_EXEC_INIT_DONE then
    -- The IRX stack loaded but the FIRST status probe latched -1 forever. A
    -- mechanically cold drive can report not-ready on the first page open and
    -- be fine seconds later, so re-probe the status (a cheap devctl; no IRX is
    -- ever reloaded) on each visit instead of staying dead until reboot.
    SUCCESS = HDD.GetHDDStatus()
    PLDR.HDD.STATUS = SUCCESS
    if SUCCESS == 0 then
      PLDR.HDD.LOADSTATE = 1
      UI.Notif_queue.add("HDD is ready now (status recovered)")
    end
  end
end

function PLDR.CleanupGameList()
  local count = #PLDR.GAMES
  for i=0, count do PLDR.GAMES[i]=nil end
end

-- ============================================================================
-- Per-device persistent game-list cache (plain text, loadfile-FREE).
-- Lets USB / MMCE / MX4SIO skip the "Building game list..." rescan on every boot:
-- the scanned list is written next to the games (<root>POPS/.gamecache) and read
-- back on the next page-open; R1 (Refresh) forces a fresh scan + rewrite. Matters
-- on large libraries.
--
-- Format (one record per line; entries never contain newlines):
--   PLDRGC1            -- magic/version
--   G <entry>          -- one per game, the EXACT PLDR.GAMES[i] string, verbatim
--   H <entry>          -- one per PLDR.HIDDEN key (preserves dimmed/hidden state)
--
-- The device GAME PATH is NOT stored: the caller passes the LIVE path to Apply,
-- so a card/drive that re-enumerates to a different slot still resolves (MMCE /
-- MX4SIO entries are bare names + the live PLDR.GAMEPATH; USB entries embed their
-- own root). NEVER loadfile/load/dofile -- they are nil in the embedded runtime
-- (the landmine that disabled the old HDD cache); pure string parsing only.
-- ============================================================================
-- Signature of the scan-affecting settings (Global Hide + multi-disc collapse).
-- Stored in the cache; a mismatch on load forces a rescan, so toggling those
-- settings takes effect without a manual R1 (the HDD path WipeCache's on change;
-- on-device caches can't be deleted at settings-time, so we self-invalidate here).
function PLDR.GameListCacheSignature()
  return "gh"..((PLDR.GLOBAL_HIDE == true) and "1" or "0")
        .."md"..((PLDR.COLLAPSE_MULTIDISC == true) and "1" or "0")
end

function PLDR.SaveGameListCache(cache_path, games, hidden)
  if PLDR.GAMELIST_CACHE ~= true then return false end  -- opt-in; OFF by default -> never writes a cache file
  if type(cache_path) ~= "string" or cache_path == "" then return false end
  if type(games) ~= "table" then return false end
  local lines = { "PLDRGC1", "S "..PLDR.GameListCacheSignature() }
  for i = 1, #games do lines[#lines + 1] = "G "..tostring(games[i]) end
  if type(hidden) == "table" then
    for k, v in pairs(hidden) do
      if v == true then lines[#lines + 1] = "H "..tostring(k) end
    end
  end
  local ok_cat, data = pcall(table.concat, lines, "\n")
  if not ok_cat then return false end
  local ok_w, saved = pcall(WriteAtomic, cache_path, data)  -- pcall: device may be full/RO
  return ok_w and saved == true
end

-- Returns games(table), hidden(table) on success; nil on a miss or ANY parse
-- problem (the caller then falls through to a fresh scan -- never throws).
function PLDR.LoadGameListCache(cache_path)
  if PLDR.GAMELIST_CACHE ~= true then return nil end  -- opt-in; OFF by default -> always a miss -> live scan
  if type(cache_path) ~= "string" or cache_path == "" then return nil end
  if not doesFileExist(cache_path) then return nil end
  local sz = GetFileSizeSafe(cache_path)
  if type(sz) == "number" and sz > 4*1024*1024 then return nil end  -- corrupt/huge -> miss -> live scan (Codex F5)
  local data = ReadWholeFile(cache_path)
  if type(data) ~= "string" or data == "" then return nil end
  local games, hidden = {}, {}
  local first, sig_ok = true, false
  local want_sig = PLDR.GameListCacheSignature()
  for line in string.gmatch(data .. "\n", "([^\n]*)\n") do
    line = string.gsub(line, "\r$", "")
    if first then
      first = false
      if line ~= "PLDRGC1" then return nil end  -- not our format / corrupt
    elseif string.sub(line, 1, 2) == "S " then
      if string.sub(line, 3) ~= want_sig then return nil end  -- built under different settings -> rescan
      sig_ok = true
    elseif string.sub(line, 1, 2) == "G " then
      games[#games + 1] = string.sub(line, 3)
    elseif string.sub(line, 1, 2) == "H " then
      hidden[string.sub(line, 3)] = true
    end
  end
  if not sig_ok or #games == 0 then return nil end
  return games, hidden
end

-- Rebuild the live list from a loaded cache, exactly as a fresh scan leaves it
-- (PLDR.GAMES reassigned + sorted, PLDR.GAMEPATH = the LIVE device path, PLDR.HIDDEN
-- rehydrated) so render / cover / launch behave identically to a real scan.
function PLDR.ApplyGameListCache(games, gamepath, hidden)
  if type(games) ~= "table" then return false end
  PLDR.GAMES = {}
  for i = 1, #games do PLDR.GAMES[i] = games[i] end
  table.sort(PLDR.GAMES)
  PLDR.GAMEPATH = gamepath or ""
  PLDR.HIDDEN = {}
  if type(hidden) == "table" then
    for k, v in pairs(hidden) do if v == true then PLDR.HIDDEN[k] = true end end
  end
  return true
end

function PLDR.HDD.CreateCache(reuse_current_list)
  if PLDR.GAMELIST_CACHE ~= true then return end  -- opt-in; OFF -> no cross-boot cache
  local cache_source = PLDR.GAMES
  if reuse_current_list ~= true then
    PLDR.HDD.BuildGameList()
    cache_source = PLDR.GAMES
  end
  if type(cache_source) ~= "table" then
    cache_source = {}
  end
  -- Plain-text PLDRGC1 (loadfile-FREE), same family as the per-device cache. Entries
  -- are the EXACT "partition|relpath" PLDR.GAMES strings; ApplyCachedList rebuilds
  -- GAMEPARTS from each entry's prefix on load. The hide set is persisted so dimming
  -- (Global Hide off) survives a cold-boot hit. The settings signature lets a load
  -- under different scan-affecting settings self-reject (belt-and-suspenders -- the
  -- HDD path also WipeCache's on those toggles).
  local lines = { "PLDRGC1", "S "..PLDR.GameListCacheSignature() }
  for i = 1, #cache_source do lines[#lines + 1] = "G "..tostring(cache_source[i]) end
  if type(PLDR.HIDDEN) == "table" then
    for i = 1, #cache_source do
      if PLDR.HIDDEN[cache_source[i]] == true then lines[#lines + 1] = "H "..tostring(cache_source[i]) end
    end
  end
  local ok_cat, data = pcall(table.concat, lines, "\n")
  if not ok_cat then return end
  -- On an HDD boot the cache lives on the boot partition (where settings save), which
  -- the launcher mounted read-only -- take it RW first (idempotent; a no-op once a
  -- settings save already did). On an MC/USB boot ResolveWritablePath is already
  -- writable. Every step is pcall-guarded: a full/RO device just skips the cache (the
  -- live scan still works), never throwing out of EnsureGameList.
  if PLDR.SETTINGS_HDD_PARTITION ~= nil and type(PLDR.HDD.EnsureBootPartitionWritable) == "function" then
    pcall(PLDR.HDD.EnsureBootPartitionWritable)
  end
  local C = ResolveWritablePath("hdd_gamecache.txt")  -- .txt = plain text (old .lua is dead)
  pcall(function()
    local fd = System.openFile(C, FCREATE)
    if fd ~= nil and not (type(fd) == "number" and fd < 0) then
      local wrote = System.writeFile(fd, data, #data)  -- raw write(): short/-1, no throw
      System.closeFile(fd)
      if type(wrote) ~= "number" or wrote ~= #data then
        pcall(System.removeFile, C)  -- partial write -> drop the truncated cache (rescan next) (Codex F1)
      end
    end
  end)
  PLDR.HDD.HAS_CHECKED = true
end

function PLDR.HDD.ReadCache()
  if PLDR.GAMELIST_CACHE ~= true then return end  -- opt-in; OFF -> always a miss -> live scan
  local C = ResolveWritablePath("hdd_gamecache.txt")
  if not doesFileExist(C) then return end
  local sz = GetFileSizeSafe(C)
  if type(sz) == "number" and sz > 4*1024*1024 then return end  -- corrupt/huge -> miss -> live scan (Codex F5)
  local data = ReadWholeFile(C)
  if type(data) ~= "string" or data == "" then return end
  -- Plain-text parse (NEVER loadfile/load/dofile -- nil in the embedded runtime, the
  -- landmine that broke the old cache). On magic / sig mismatch or 0 games, leave
  -- PLDR.HDDCACHE unset so EnsureGameList falls through to a fresh scan (never throws).
  local games, hidden = {}, {}
  local first, sig_ok = true, false
  local want_sig = PLDR.GameListCacheSignature()
  for line in string.gmatch(data .. "\n", "([^\n]*)\n") do
    line = string.gsub(line, "\r$", "")
    if first then
      first = false
      if line ~= "PLDRGC1" then return end  -- not our format / corrupt
    elseif string.sub(line, 1, 2) == "S " then
      if string.sub(line, 3) ~= want_sig then return end  -- built under different settings
      sig_ok = true
    elseif string.sub(line, 1, 2) == "G " then
      games[#games + 1] = string.sub(line, 3)
    elseif string.sub(line, 1, 2) == "H " then
      hidden[string.sub(line, 3)] = true
    end
  end
  if not sig_ok or #games == 0 then return end
  PLDR.HDDCACHE = games
  PLDR.HDDCACHE_HIDDEN = hidden
  PLDR.HDD.HAS_CHECKED = true
end

function PLDR.HDD.WipeCache(CACHE)
  -- Invalidate BOTH cache tiers. Clearing only the on-disk file left the
  -- in-session memo (PLDR.HDDCACHE + PLDR.HDD.LIST_BUILT) intact, so a
  -- multi-disc-collapse toggle had no visible effect until a reboot or a
  -- manual R1 rescan -- EnsureGameList(force=false) returned the stale memo.
  PLDR.HDDCACHE = nil
  PLDR.HDDCACHE_HIDDEN = nil
  PLDR.HDD.LIST_BUILT = false
  -- Remove the plain-text cache (and any stale old .lua); pcall in case the boot
  -- partition is read-only -- a leftover stale file is harmless (rejected on load by
  -- its magic/signature).
  for _, name in ipairs({ "hdd_gamecache.txt", "hdd_gamecache.lua" }) do
    local C = ResolveWritablePath(name)
    if doesFileExist(C) then pcall(System.removeFile, C) end
  end
  PLDR.HDD.HAS_CHECKED = false
end

-- Rebuild PLDR.GAMES + PLDR.HDD.GAMEPARTS from the cached list (PLDR.HDDCACHE,
-- a flat list of "partition|relpath" entries) WITHOUT mounting/scanning any
-- partition. GAMEPARTS is derived from each entry's partition prefix, which is
-- all RunPOPStarterGame needs to mount the right partition at launch time.
function PLDR.HDD.ApplyCachedList()
  PLDR.GAMES = {}
  PLDR.HDD.GAMEPARTS = {}
  PLDR.HIDDEN = {}
  if type(PLDR.HDDCACHE_HIDDEN) == "table" then
    for k, v in pairs(PLDR.HDDCACHE_HIDDEN) do if v == true then PLDR.HIDDEN[k] = true end end
  end
  if type(PLDR.HDDCACHE) == "table" then
    for i = 1, #PLDR.HDDCACHE do
      local enc = PLDR.HDDCACHE[i]
      if type(enc) == "string" and enc ~= "" then
        table.insert(PLDR.GAMES, enc)
        local part = string.match(enc, "^([^|]+)|")
        if part ~= nil and part ~= "" then
          PLDR.HDD.GAMEPARTS[enc] = "hdd0:"..part
        end
      end
    end
  end
  table.sort(PLDR.GAMES, PLDR.HDD.CompareGameEntriesByDisplay)
  PLDR.HDD.FROM_CACHE = true
  if #PLDR.GAMES > 0 then
    PLDR.HDD.FOUNDANY = true
  end
end

-- Single entry point for resolving the HDD game list, fastest source first:
--   1. in-session memo - already scanned/loaded this boot (HDD content cannot
--      change while powered on, so reusing it is always safe and instant)
--   2. on-disk cache    - hdd_gamecache.lua written on a previous boot
--   3. full scan        - mount every __.POPS partition and list it, then
--      refresh both the in-memory and on-disk caches
-- `force` (manual Refresh / R1) skips every cache and rescans from scratch.
-- Returns the source used: "memo" | "disk" | "scan".
function PLDR.HDD.EnsureGameList(partition_progress, game_progress, force)
  if force then
    if type(PLDR.HDD.WipeCache) == "function" then PLDR.HDD.WipeCache() end
    PLDR.HDDCACHE = nil
    PLDR.HDD.LIST_BUILT = false
    PLDR.HDD.HAS_CHECKED = false
  end

  if PLDR.HDD.LIST_BUILT and not force and type(PLDR.HDDCACHE) == "table" then
    PLDR.HDD.ApplyCachedList()
    if type(game_progress) == "function" then pcall(game_progress, 1.0) end
    return "memo"
  end

  if PLDR.GAMELIST_CACHE == true and not force then
    if type(PLDR.HDD.ReadCache) == "function" then PLDR.HDD.ReadCache() end
    if type(PLDR.HDDCACHE) == "table" and #PLDR.HDDCACHE > 0 then
      PLDR.HDD.ApplyCachedList()
      PLDR.HDD.LIST_BUILT = true
      if type(game_progress) == "function" then pcall(game_progress, 1.0) end
      return "disk"
    end
  end

  -- cache miss (or forced): full mount+scan, then refresh both caches.
  -- Graceful degrade (F-01): the two scan steps are pcall-wrapped so a faulting
  -- partition surfaces a notice and aborts the scan cleanly (no error thrown out
  -- of EnsureGameList) instead of black-screening the device page.
  PLDR.HDD.HAS_CHECKED = false
  local _hdd_diag = function(where, err)
    if type(UI) == "table" and type(UI.Notif_queue) == "table" then
      -- F-5: surface the REAL scan error + which step faulted, not a bare generic.
      -- The 3-month loadfile blindness was exactly this swallow class one level up
      -- (RunBusyTask); EnsureGameList catches the scan error itself, so RunBusyTask
      -- never sees it -- it has to be surfaced HERE or it stays undebuggable.
      local detail = tostring(err)
      if #detail > 180 then detail = string.sub(detail, 1, 180).."..." end
      UI.Notif_queue.add("Failed to load HDD ["..tostring(where).."]\n"..detail, "error")
    end
    PLDR.HDD.LIST_BUILT = false
  end
  local check_ok, check_err = pcall(PLDR.HDD.CheckAvailableHddPopsParts, partition_progress)
  if not check_ok then _hdd_diag("CheckParts", check_err) return "scan" end
  local build_ok, build_err = pcall(PLDR.HDD.BuildGameList, game_progress)
  if not build_ok then
    local gslot = PLDR.HDD.GAME_SLOT
    local boot_slot = nil
    if type(GetBootHddMountSlot) == "function" then boot_slot = GetBootHddMountSlot() end
    if gslot ~= nil and gslot ~= boot_slot then UMountHddPartitionTracked(gslot) end
    _hdd_diag("BuildList", build_err)
    return "scan"
  end
  PLDR.HDD.LIST_BUILT = true
  PLDR.HDDCACHE = {}
  for i = 1, #PLDR.GAMES do
    PLDR.HDDCACHE[i] = PLDR.GAMES[i]
  end
  PLDR.HDDCACHE_HIDDEN = {}
  if type(PLDR.HIDDEN) == "table" then
    for k, v in pairs(PLDR.HIDDEN) do if v == true then PLDR.HDDCACHE_HIDDEN[k] = true end end
  end
  if PLDR.GAMELIST_CACHE == true and type(PLDR.HDD.CreateCache) == "function" then
    PLDR.HDD.CreateCache(true)
  end
  return "scan"
end

local function NormalizeBootBasename(basename, desired_prefix)
  if basename == nil or basename == "" then
    return ""
  end
  local cleaned = basename
  if desired_prefix ~= nil and desired_prefix ~= "" then
    if string.upper(string.sub(cleaned, 1, #desired_prefix)) ~= string.upper(desired_prefix) then
      cleaned = desired_prefix..cleaned
    end
  end
  return cleaned
end

local function ExtractVcdFilename(path)
  if path == nil or path == "" then
    return ""
  end
  local basename = string.match(path, "([^/]+)$") or path
  local without_device = string.match(basename, "^[%a]+%d*:(.+)$")
  if without_device ~= nil and without_device ~= "" then
    return without_device
  end
  return basename
end

local function StripVcdExtension(filename)
  if filename == nil or filename == "" then
    return ""
  end
  local without_ext = string.gsub(filename, "%.[Vv][Cc][Dd]$", "")
  return without_ext
end

local function SanitizeGameName(name)
  if name == nil or name == "" then
    return ""
  end
  local sanitized = string.gsub(name, "[%z\1-\31]", "")
  sanitized = string.gsub(sanitized, "\"", "")
  sanitized = string.gsub(sanitized, "%s+", " ")
  sanitized = string.gsub(sanitized, "%s+$", "")
  return sanitized
end

local function TrimTrailingWhitespace(value)
  if value == nil or value == "" then
    return ""
  end
  return string.gsub(value, "%s+$", "")
end

local function BuildLiteralElfName(value)
  if value == nil or value == "" then
    return ""
  end
  local trimmed = TrimTrailingWhitespace(value)
  if trimmed == "" then
    return ""
  end
  if string.match(trimmed, "%.[Ee][Ll][Ff]$") then
    return trimmed
  end
  return trimmed..".ELF"
end

local function SelectPopstarterSelectorPrefix(device_page)
  if device_page == "SMB" then
    return "SB."   -- net-SMB selector prefix (POPStarter SMB-stream mode)
  end
  if device_page == "USB" or device_page == "MMCE" or device_page == "SMB/MMCE" or device_page == "MX4SIO" then
    return "XX."
  end
  if device_page == "HDD" then
    return ""
  end
  return "XX."
end

local function BuildPopstarterSelectorPath(device_page, game_name)
  if game_name == nil or game_name == "" then
    return ""
  end
  if device_page == "SMB" then
    -- Net-SMB argv0 (this becomes POPSTARTER.ELF's argv[0]). POPStarter parses the
    -- basename "SB.<name>.ELF" -> SMB-stream mode + <name>, then reads <name>.VCD from
    -- its own smb:/POPS/ mount (mc:/POPSTARTER/SMBCONFIG.DAT). ⚠ HARDWARE-ONLY: both the
    -- device prefix (smb:/ here, pattern-matching the USB mass:/POPS/ form) AND whether
    -- POPStarter reads the SB. prefix from argv0 are PS2-confirm-only -- if the share
    -- connects but a game won't boot, the first fallbacks to try are
    -- "mass:/POPS/SB."..game_name..".ELF" then "mass:/SB."..game_name..".ELF".
    return "smb:/POPS/SB."..game_name..".ELF"
  end
  if device_page == "HDD" then
    return BuildLiteralElfName(game_name)
  end
  if device_page == "USB" or device_page == "MMCE" or device_page == "SMB/MMCE" then
    return "mass:/POPS/XX."..game_name..".ELF"
  end
  if device_page == "MX4SIO" then
    local root = PLDR and PLDR.MX4SIO and PLDR.MX4SIO.ROOT or "mx4sio:/"
    return root.."POPS/XX."..game_name..".ELF"
  end
  return game_name..".ELF"
end

local function DeriveGameNameFromSelection(raw_selection)
  local vcd_filename = ExtractVcdFilename(raw_selection or "")
  return SanitizeGameName(StripVcdExtension(vcd_filename))
end

local function HasBootPrefix(basename, desired_prefix)
  if basename == nil or basename == "" or desired_prefix == nil or desired_prefix == "" then
    return false
  end
  return string.upper(string.sub(basename, 1, #desired_prefix)) == string.upper(desired_prefix)
end

local function BuildPopstarterBootString(source_mode, pops_root, basename)
  local prefix = ""
  if source_mode == "pfs" then
    prefix = ""
  elseif source_mode == "smb" then
    prefix = "SB."
  else
    prefix = "XX."
  end
  if pops_root == nil then
    pops_root = ""
  end
  local normalized_root = EnsureTrailingSlash(pops_root)
  local normalized_basename = NormalizeBootBasename(basename, prefix)
  local prefix_added = normalized_basename ~= basename
  return normalized_root..normalized_basename, prefix, normalized_basename, prefix_added
end

local function GetDevicePrefix(path)
  if path == nil then
    return nil
  end
  return string.match(path, "^([%a]+%d*):")
end

local function NormalizeIsraPath(path, device_prefix)
  if path == nil then
    return path
  end
  if string.match(path, "^isra:") then
    return device_prefix..":/"..string.sub(path, 6)
  end
  return path
end

local function TranslateMMCEPathForPopStarter(path)
  if path == nil then
    return path
  end
  return string.gsub(path, "^mmce%d:/", "mass:/")
end

local function BuildLaunchPolicy(name, mode, isra_prefix, handoff_transform)
  return {
    name = name,
    mode = mode,
    isra_prefix = isra_prefix,
    normalize = function (path)
      return NormalizeIsraPath(path, isra_prefix)
    end,
    handoff = function (path)
      local normalized = NormalizeIsraPath(path, isra_prefix)
      if handoff_transform ~= nil then
        return handoff_transform(normalized)
      end
      return normalized
    end
  }
end

local function ParseHddGameEntry(entry)
  if entry == nil or entry == "" then
    return nil, nil
  end
  local partition, relpath = string.match(entry, "^([^|]+)|(.+)$")
  return partition, relpath
end

local function NormalizeHddRelpath(relpath)
  if relpath == nil then
    return ""
  end
  local cleaned = string.gsub(relpath, "^pfs%d:/", "")
  cleaned = string.gsub(cleaned, "^/+", "")
  return cleaned
end

local function GetBootOccupiedPfsSlot()
  local candidates = {
    BOOT_ARGV0_RAW,
    BOOT_PATH_RAW,
    APP_DIR_LOCAL
  }
  for i = 1, #candidates do
    local slot = ExtractLaunchPfsSlot(candidates[i])
    if slot ~= nil then
      return slot
    end
  end
  return nil
end

local LaunchState = {
  PHASE_VALIDATE = "LAUNCH_VALIDATE",
  PHASE_FADEOUT = "LAUNCH_FADEOUT",
  PHASE_EXEC = "LAUNCH_EXEC",
  PHASE_FAILED = "LAUNCH_FAILED",
  phase = "IDLE",
  watchdog_ms = 3000,   -- real milliseconds (elapsed is divided from us at the post-exec annotation)
  fade_timer = nil,
  fade_start = 0
}

local function SetLaunchPhase(phase)
  LaunchState.phase = phase
end

local function HostAltPath(path)
  if path == nil then
    return nil
  end
  if string.match(path, "^host:/") then
    return "host:"..string.sub(path, 7)
  end
  return nil
end

local function TryOpenForLaunch(path)
  local ok, fd_or_err = pcall(System.openFile, path, FREAD)
  if (not ok or type(fd_or_err) ~= "number" or fd_or_err < 0) and IsMassPath(path) and type(PLDR) == "table" and type(PLDR.EnsureUsbMassReadyOnce) == "function" then
    pcall(PLDR.EnsureUsbMassReadyOnce)
    ok, fd_or_err = pcall(System.openFile, path, FREAD)
  end
  if not ok or type(fd_or_err) ~= "number" or fd_or_err < 0 then
    local alt = HostAltPath(path)
    if alt ~= nil then
      local alt_ok, alt_fd = pcall(System.openFile, alt, FREAD)
      if alt_ok and type(alt_fd) == "number" and alt_fd >= 0 then
        local size = System.sizeFile(alt_fd)
        System.closeFile(alt_fd)
        if type(size) ~= "number" or size < 0 then
          return false, size, "stat", "sizeFile", alt
        end
        return true, size, "stat", "open(host_alt)", alt
      end
    end
    return false, fd_or_err, "open", "open", path
  end
  local size = System.sizeFile(fd_or_err)
  System.closeFile(fd_or_err)
  if type(size) ~= "number" or size < 0 then
    return false, size, "stat", "sizeFile", path
  end
  return true, size, "stat", "open", path
end

local function BuildLaunchDiagnosticsLines(diag)
  if type(diag) ~= "table" then
    return nil
  end
  local function v(x)
    if x == nil then
      return "nil"
    end
    local out = tostring(x)
    if out == "" then
      return "\"\""
    end
    return out
  end
  local lines = {
    "Diag route="..v(diag.route).." src="..v(diag.source_pfs_slot),
    "Diag cfg="..v(diag.configured_path),
    "Diag cfg_reason="..v(diag.configured_path_reason),
    "Diag eff="..v(diag.normalized_profile_selected_path),
    "Diag eff_reason="..v(diag.normalized_profile_selected_path_reason),
    "Diag exec="..v(diag.final_resolved_exec_path),
    "Diag partctx="..v(diag.derived_partition_context),
    "Diag part_reason="..v(diag.derived_partition_context_reason)
  }
  return table.concat(lines, "\n")
end

local function BlockLaunchFailure(rc, popstarter, device_page, argv0, game_path, app_dir, open_rc, open_api, exec_path, launch_route, hdd_preexec_gate_mode, context)
  SetLaunchPhase(LaunchState.PHASE_FAILED)
  UI.LAUNCHING = false
  local display_exec_path = exec_path
  if type(display_exec_path) ~= "string" or display_exec_path == "" then
    display_exec_path = popstarter
  end
  local diag_lines = BuildLaunchDiagnosticsLines(context and context.launch_diagnostics or nil)
  local diag_block = ""
  if type(diag_lines) == "string" and diag_lines ~= "" then
    diag_block = "\n"..diag_lines
  end
  local on_hdd_flag = (context and context.popstarter_on_hdd) and "y" or "n"
  local reboot_flag = (context and context.reboot_iop ~= nil) and tostring(context.reboot_iop) or "?"
  local partition_ctx_disp = (context and type(context.exec_partition_context) == "string" and context.exec_partition_context ~= "")
    and context.exec_partition_context or "nil"
  local api_used = (context and type(context.exec_partition_context) == "string" and context.exec_partition_context ~= "")
    and "loadELFWithPartition" or "loadELF"
  local cold_launch_flag = (context and context.cold_external_launch == true) and "y" or "n"
  local boot_disp = (context and type(context.boot_path) == "string" and context.boot_path ~= "")
    and context.boot_path or "?"
  local boot_label_disp = (context and type(context.boot_device_label) == "string" and context.boot_device_label ~= "")
    and context.boot_device_label or "?"
  local body = string.format(
    "LAUNCH RETURNED\nrc=%s\nDev:%s Rt:%s\nGate:%s Open:%s/%s\nPOP:%s\nCfg:%s (%s)\nEff:%s (%s)\nExec:%s\nAPP:%s\nBoot:%s [%s]\nPath:Hdd=%s Reboot=%s Cold=%s API:%s\nCtx:%s\nArg0:%s\nGame:%s%s\nPress X/O to continue.",
    tostring(rc),
    tostring(device_page),
    tostring(launch_route or "default"),
    tostring(hdd_preexec_gate_mode or "n/a"),
    tostring(open_rc),
    tostring(open_api),
    tostring(popstarter),
    tostring(context and context.launch_diagnostics and context.launch_diagnostics.configured_path or nil),
    tostring(context and context.launch_diagnostics and context.launch_diagnostics.configured_path_reason or nil),
    tostring(context and context.launch_diagnostics and context.launch_diagnostics.normalized_profile_selected_path or nil),
    tostring(context and context.launch_diagnostics and context.launch_diagnostics.normalized_profile_selected_path_reason or nil),
    tostring(context and context.launch_diagnostics and context.launch_diagnostics.final_resolved_exec_path or display_exec_path),
    tostring(app_dir),
    boot_disp,
    boot_label_disp,
    on_hdd_flag,
    reboot_flag,
    cold_launch_flag,
    api_used,
    partition_ctx_disp,
    tostring(argv0),
    tostring(game_path),
    diag_block
  )
  while true do
    UI.BottomDraw.Play()
    Font.ftPrintMultiLineAligned(LFONT, UI.SCR.X_MID, 120, 20, UI.SCR.X, UI.SCR.Y, "LAUNCH FAILED", UI.CCOL.YELLOW)
    Font.ftPrintMultiLineAligned(BFONT, UI.SCR.X_MID, 170, 18, UI.SCR.X, UI.SCR.Y, body, UI.CCOL.GREY)
    Input_GetEvent()
    if UI.Pad.Events.CONFIRM or UI.Pad.Events.BACK or UI.Pad.Events.EXIT then
      break
    end
    UI.flip()
  end
  UI.SceneChange(UI.SCENES.MMAIN)
end

local function LaunchEngine(popstarter, argv, reboot_iop, context)
  local app_dir = EnsureTrailingSlash(APP_DIR_LOCAL)
  local boot_path = EnsureTrailingSlash(System.currentDirectory())
  local argv0 = argv and argv[1] or nil
  local unpack_fn = table.unpack or unpack
  SetLaunchPhase(LaunchState.PHASE_VALIDATE)
  if not PLDR.PopstarterProbeWithEnsure(popstarter) then
    BlockLaunchFailure(
      "popstarter missing",
      popstarter,
      context and context.device_page or "unknown",
      argv and argv[1] or nil,
      context and context.vcd_path or nil,
      app_dir,
      nil,
      nil,
      nil,
      context and context.launch_route,
      context and context.hdd_preexec_gate_mode,
      context
    )
    return
  end
  local open_ok, open_rc, open_stage, open_api, open_path = TryOpenForLaunch(popstarter)
  if not open_ok then
    BlockLaunchFailure(
      "popstarter "..tostring(open_stage).." failed: "..tostring(open_rc),
      popstarter,
      context and context.device_page or "unknown",
      argv and argv[1] or nil,
      context and context.vcd_path or nil,
      app_dir,
      open_rc,
      open_api,
      nil,
      context and context.launch_route,
      context and context.hdd_preexec_gate_mode,
      context
    )
    return
  end
  if open_path ~= nil and open_path ~= popstarter then
    popstarter = open_path
  end
  local exec_path = popstarter
  if context ~= nil and type(context.exec_path) == "string" and context.exec_path ~= "" then
    exec_path = context.exec_path
  end
  local launch_cwd = popstarter
  if context ~= nil and context.launch_cwd == false then
    launch_cwd = nil
  elseif context ~= nil and type(context.launch_cwd) == "string" and context.launch_cwd ~= "" then
    launch_cwd = context.launch_cwd
  end
  local previous_cwd = nil
  if type(launch_cwd) == "string" and launch_cwd ~= "" then
    previous_cwd = SetLaunchWorkingDirectory(launch_cwd)
  end
  local exec_args = argv or {}
  SetLaunchPhase(LaunchState.PHASE_FADEOUT)
  UI.LAUNCHING = true
  LaunchState.fade_timer = Timer.new()
  LaunchState.fade_start = Timer.getTime(LaunchState.fade_timer)
  Screen.clear(Color.new(0, 0, 0))
  Screen.flip()
  -- (Removed) A pre-exec "launch timeout" watchdog used to sit here. It
  -- captured fade_start (above), ran ONE Screen.flip, then aborted the launch
  -- if Timer.getTime - fade_start >= watchdog_ms. With no loop the real budget
  -- is a single vblank, and Timer.getTime returns raw clock() ticks
  -- (luatimer.cpp) that are documented-unstable right after Screen.setMode
  -- (see ui.lua) -- so it could ONLY false-trip and abort good launches before
  -- loadELF was ever reached (GitHub #497, USB "crash"). The genuine
  -- "exec returned without transferring control" case is still detected below,
  -- AFTER loadELF, via the post-exec elapsed annotation + BlockLaunchFailure.
  SetLaunchPhase(LaunchState.PHASE_EXEC)
  if context ~= nil and context.cold_external_launch == true and type(PLDR) == "table" and type(PLDR.PrepareForColdExternalELFLaunch) == "function" then
    pcall(PLDR.PrepareForColdExternalELFLaunch)
  else
    PrepareForExternalELFLaunch(
      popstarter,
      context and context.keep_hdd_slots or nil,
      context and context.keep_hdd_slots_after_load or nil,
      context and context.exec_pfs_slot or nil
    )
  end
  local rc
  local exec_partition_context = nil
  if context ~= nil and type(context.exec_partition_context) == "string" and context.exec_partition_context ~= "" then
    exec_partition_context = context.exec_partition_context
  end
  local use_partition_api = exec_partition_context ~= nil
    and reboot_iop ~= 0
    and type(System.loadELFWithPartition) == "function"
  if exec_args ~= nil and #exec_args > 0 and unpack_fn ~= nil then
    if use_partition_api then
      rc = System.loadELFWithPartition(exec_path, reboot_iop, exec_partition_context, unpack_fn(exec_args))
    else
      rc = System.loadELF(exec_path, reboot_iop, unpack_fn(exec_args))
    end
  elseif exec_args ~= nil and #exec_args == 1 then
    if use_partition_api then
      rc = System.loadELFWithPartition(exec_path, reboot_iop, exec_partition_context, exec_args[1])
    else
      rc = System.loadELF(exec_path, reboot_iop, exec_args[1])
    end
  else
    if use_partition_api then
      rc = System.loadELFWithPartition(exec_path, reboot_iop, exec_partition_context)
    else
      rc = System.loadELF(exec_path, reboot_iop)
    end
  end
  -- Timer.getTime() is MICROSECONDS (raw clock() ticks, CLOCKS_PER_SEC=1e6); divide to
  -- real ms so both the watchdog_ms threshold and the printed figure read correctly.
  local elapsed_ms = (Timer.getTime(LaunchState.fade_timer) - LaunchState.fade_start) / 1000
  if elapsed_ms >= LaunchState.watchdog_ms then
    -- math.floor: Lua 5.4 '/' yields a float, and a non-integral float into %d raises
    -- "number has no integer representation" -- which would crash the diagnostic
    -- screen on exactly the slow-failure path this annotation exists for.
    rc = string.format("%s (returned after %d ms)", tostring(rc), math.floor(elapsed_ms))
  end
  RestoreWorkingDirectory(previous_cwd)
  BlockLaunchFailure(
    rc,
    popstarter,
    context and context.device_page or "unknown",
    argv0,
    argv0,
    app_dir,
    nil,
    nil,
    exec_path,
    context and context.launch_route,
    context and context.hdd_preexec_gate_mode,
    context
  )
end

local function ResolveLaunchPolicy(gamelocation, ui_scene)
  local current_scene = ui_scene or (UI and UI.CURSCENE or "unknown")
  if current_scene == UI.SCENES.GHDD then
    return BuildLaunchPolicy("HDD", "pfs", "pfs", nil), "HDD"
  end
  if current_scene == UI.SCENES.GMX4SIO then
    return BuildLaunchPolicy("MX4SIO", "mx4sio", "mx4sio", nil), "MX4SIO"
  end
  if current_scene == UI.SCENES.GBDMHDD then
    -- HDD (exFAT) is a BDM mass device (ata_bd). POPStarter reads it as mass:
    -- via the .ata BDMA drivers, so the launch is identical to USB (XX. on mass:).
    return BuildLaunchPolicy("USB", "mass", "mass", nil), "USB"
  end
  if string.match(gamelocation, "^mx4sio") then
    return BuildLaunchPolicy("MX4SIO", "mx4sio", "mx4sio", nil), "MX4SIO"
  end
  if string.match(gamelocation, "^mass") then
    return BuildLaunchPolicy("USB", "mass", "mass", nil), "USB"
  end
  if string.match(gamelocation, "^mmce") then
    local mmce_prefix = PLDR.MMCE.PREFIX or "mmce0:/"
    local mmce_device = string.match(mmce_prefix, "^([%a]+%d*)") or "mmce0"
    return BuildLaunchPolicy("MMCE", "mass", mmce_device, TranslateMMCEPathForPopStarter), "MMCE"
  end
  if string.match(gamelocation, "^pfs") then
    local prefix = GetDevicePrefix(gamelocation) or "pfs"
    return BuildLaunchPolicy("HDD", prefix, prefix, nil), "HDD"
  end
  if UI.IsUsbScene(current_scene) then
    return BuildLaunchPolicy("USB", "mass", "mass", nil), "USB"
  end
  if current_scene == UI.SCENES.GSMB then
    local mmce_prefix = PLDR.MMCE.PREFIX or "mmce0:/"
    local mmce_device = string.match(mmce_prefix, "^([%a]+%d*)") or "mmce0"
    return BuildLaunchPolicy("MMCE", "mass", mmce_device, TranslateMMCEPathForPopStarter), "SMB/MMCE"
  end
  if current_scene == UI.SCENES.GSMBNET then
    -- Net-SMB launch (Increment 2). The menu device is smb0:, but POPStarter mounts
    -- its OWN smb:/ namespace via mc:/POPSTARTER/SMBCONFIG.DAT. A distinct policy
    -- name + device_page "SMB" (NOT MMCE-SMB's "SMB/MMCE") routes the selector
    -- builders to the SB. argv0 (smb:/POPS/SB.<name>.ELF). No path transform: the
    -- bare-name selection passes straight through.
    return BuildLaunchPolicy("SMB", "smb", "smb", nil), "SMB"
  end
  return BuildLaunchPolicy("unknown", "mass", "mass", nil), "unknown"
end

local function BuildHddPopstarterSelectorPathForPartition(game_name, hdd_selector_mode, hdd_partition_label)
  local selector_name = BuildLiteralElfName(game_name)
  if selector_name == "" then
    return ""
  end
  if hdd_selector_mode == "full_hdd_pfs0" then
    local partition = tostring(hdd_partition_label or "")
    if partition ~= "" then
      return "hdd0:"..partition..":pfs0:/"..selector_name
    end
    return "pfs0:/"..selector_name
  end
  return selector_name
end

local function ResolveHddPopstarterSelectorRoute(game_name, hdd_selector_mode, hdd_partition_label, popstarter_on_hdd)
  if not popstarter_on_hdd then
    return BuildLiteralElfName(game_name), "non_hdd_exec"
  end

  local partition = tostring(hdd_partition_label or "")
  if hdd_selector_mode == "full_hdd_pfs0" and partition ~= "" then
    return BuildHddPopstarterSelectorPathForPartition(game_name, hdd_selector_mode, partition), "hdd_partition_scoped"
  end

  return BuildLiteralElfName(game_name), "hdd_legacy_selector"
end

local function BuildPopstarterLaunchCommand(policy_name, device_page, game_name, hdd_selector_mode, hdd_partition_label, popstarter_on_hdd)
  local argv0_selector = BuildPopstarterSelectorPath(device_page, game_name)
  local launch_route = "default"
  if policy_name == "HDD" then
    argv0_selector, launch_route = ResolveHddPopstarterSelectorRoute(game_name, hdd_selector_mode, hdd_partition_label, popstarter_on_hdd)
  end
  local argv = {argv0_selector}
  local reboot_iop = PLDR.REBOOT_IOP_WHILE_LOADING_POPSTARTER
  if popstarter_on_hdd then
    reboot_iop = 1
  elseif policy_name == "HDD" then
    reboot_iop = 0
  end
  return {
    elf_path = nil,
    argv = argv,
    argv0_selector = argv0_selector,
    launch_route = launch_route,
    reboot_iop = reboot_iop
  }
end

function PLDR.RunPOPStarterGame(gamelocation, game, ui_scene, launch_options)
  local policy, device_page = ResolveLaunchPolicy(gamelocation, ui_scene)
  local selected_entry = tostring(game or "")
  local hdd_partition_label = nil
  local hdd_relpath = nil
  if policy.name == "HDD" then
    hdd_partition_label, hdd_relpath = ParseHddGameEntry(selected_entry)
    hdd_relpath = NormalizeHddRelpath(hdd_relpath or selected_entry)
  end
  local persisted_popstarter_path = PLDR and PLDR.POPSTARTER_PATH or nil
  local persisted_popstarter_path_reason = persisted_popstarter_path == nil and "cfg_nil" or nil
  -- "" = Automatic (no user path; the ladder resolves) -- profiles dropped.
  local configured_popstarter = tostring(persisted_popstarter_path or "")
  local configured_popstarter_reason = configured_popstarter == "" and "automatic" or nil
  local launch_diagnostics = {
    route = nil,
    persisted_popstarter_path = persisted_popstarter_path,
    normalized_profile_selected_path = configured_popstarter,
    normalized_profile_selected_path_reason = configured_popstarter_reason,
    configured_path = persisted_popstarter_path,
    configured_path_reason = persisted_popstarter_path_reason,
    effective_path = nil,
    final_resolved_exec_path = nil,
    derived_partition_context = nil,
    derived_partition_context_reason = nil,
    source_pfs_slot = nil
  }
  local failure_context = {
    launch_diagnostics = launch_diagnostics
  }
  local popstarter = PLDR.ResolveLaunchPopstarterPath(gamelocation, configured_popstarter, policy.name)
  launch_diagnostics.effective_path = popstarter
  local popstarter_on_hdd = IsHddExecContextPath(popstarter)
  local popstarter_partition_context = nil
  if popstarter_on_hdd then
    popstarter_partition_context = ResolvePopstarterPartitionContext(configured_popstarter, popstarter, hdd_partition_label)
  end
  local configured_partition_context = nil
  if popstarter_on_hdd and IsHddExecContextPath(configured_popstarter) then
    configured_partition_context = select(1, BuildHddPartitionContext(configured_popstarter))
  end
  if configured_partition_context ~= nil and configured_partition_context ~= "" then
    popstarter_partition_context = configured_partition_context
  end
  local use_minimal_hdd_popstarter_exec = false
  if use_minimal_hdd_popstarter_exec then
    popstarter_partition_context = nil
    configured_partition_context = nil
    launch_diagnostics.derived_partition_context_reason = "minimal_hdd_legacy_exec"
  elseif popstarter_partition_context == nil and popstarter_on_hdd then
    launch_diagnostics.derived_partition_context_reason = "partition_unresolved"
  end
  local popstarter_exec_path = popstarter
  local popstarter_exec_info = BuildPartitionScopedExecInfo(popstarter, popstarter_partition_context)
  local popstarter_source_slot = popstarter_exec_info.source_pfs_slot
  local popstarter_keep_slot = popstarter_source_slot
  local popstarter_original_slot = popstarter_source_slot
  local use_pfs_exec_fallback_without_partition_context = false
  local strict_hdd_preexec_gate = PLDR.STRICT_HDD_PREEXEC_GATE == true
  local hdd_preexec_gate_mode = strict_hdd_preexec_gate and "strict-hard-fail" or "fallback-mounted-pfs"
  if use_minimal_hdd_popstarter_exec then
    hdd_preexec_gate_mode = "minimal-legacy-load"
  end
  local launch_route_pfs_fallback = "mounted-pfs-fallback"
  local normalized_popstarter_exec = string.lower(tostring(popstarter or ""))
  local normalized_game_location = string.lower(tostring(gamelocation or ""))
  local is_hdd_device_route = policy.name == "HDD"
  local popstarter_is_mounted_pfs_exec = string.match(normalized_popstarter_exec, "^pfs%d*:/") ~= nil
  local selected_game_is_hdd_derived = is_hdd_device_route and (
    (hdd_partition_label ~= nil and hdd_partition_label ~= "")
    or string.match(normalized_game_location, "^pfs%d*:/") ~= nil
    or string.match(normalized_game_location, "^hdd%d:") ~= nil
  )
  if (not strict_hdd_preexec_gate)
    and not use_minimal_hdd_popstarter_exec
    and popstarter_partition_context == nil
    and popstarter_is_mounted_pfs_exec
    and popstarter_on_hdd
    and is_hdd_device_route
    and selected_game_is_hdd_derived
  then
    -- Controlled fallback: keep mounted pfsN:/ exec path and skip
    -- partition-aware embedded-loader contract only for this explicit case.
    use_pfs_exec_fallback_without_partition_context = true
  end
  if popstarter_partition_context ~= nil and popstarter_partition_context ~= "" then
    local normalized_exec_path = popstarter_exec_info.exec_path
    if normalized_exec_path ~= nil then
      popstarter_exec_path = normalized_exec_path
    end
  end
  local normalized_exec_slot = ExtractLaunchPfsSlot(popstarter_exec_path)
  if popstarter_original_slot == nil then
    popstarter_original_slot = normalized_exec_slot
  end
  if popstarter_keep_slot == nil then
    popstarter_keep_slot = normalized_exec_slot
  end
  local hdd_selector_mode = nil
  if type(launch_options) == "table" then
    hdd_selector_mode = tostring(launch_options.hdd_selector_mode or "")
    if hdd_selector_mode == "" then
      hdd_selector_mode = nil
    end
  elseif type(launch_options) == "string" and launch_options ~= "" then
    hdd_selector_mode = launch_options
  end
  if selected_entry == "" then
    BlockLaunchFailure(
      "Invalid game selection",
      popstarter,
      device_page,
      gamelocation,
      nil,
      APP_DIR_LOCAL,
      nil,
      nil,
      nil,
      nil,
      nil,
      failure_context
    )
    return
  end
  local hdd_init = nil
  local normalized_gamelocation = policy.normalize(gamelocation)
  local handoff_gamelocation = policy.handoff(normalized_gamelocation)
  local source_mode = policy.mode
  local raw_source_mode = source_mode
  local vcd_path = normalized_gamelocation..selected_entry
  local pops_root = normalized_gamelocation
  local boot_source_mode = source_mode
  local device_mode = "unknown"
  local mmce_prefix = nil
  if string.match(source_mode, "^pfs") then
    pops_root = normalized_gamelocation
    boot_source_mode = "pfs"
    device_mode = "pfs"
  elseif string.match(normalized_gamelocation, "^mx4sio") then
    pops_root = normalized_gamelocation
    boot_source_mode = "mx4sio"
    device_mode = normalized_gamelocation
  elseif string.match(normalized_gamelocation, "^mmce%d:/") then
    mmce_prefix = PLDR.MMCE.PREFIX or string.match(normalized_gamelocation, "^(mmce%d:/)")
    if mmce_prefix == nil then
      mmce_prefix = "mmce0:/"
    end
    pops_root = mmce_prefix.."POPS/"
    boot_source_mode = "mass"
    device_mode = mmce_prefix
  elseif string.match(normalized_gamelocation, "^smb%d*:/") or device_page == "SMB/MMCE" or device_page == "SMB" then
    pops_root = "smb:/POPS/"
    boot_source_mode = "smb"
    device_mode = "smb"
  else
    pops_root = "mass:/POPS/"
    boot_source_mode = "mass"
    device_mode = "mass"
  end
  if policy.name == "HDD" then
    vcd_path = ""
    pops_root = ""
    boot_source_mode = "pfs"
    device_mode = "pfs"
    handoff_gamelocation = ""
  end
  local bootparam = nil
  local prefix = ""
  local normalized_basename = ""
  local prefix_added = false
  local bootparam_exists = false
  local fallback_bootparam = nil
  local fallback_exists = false
  local bootparam_basename_used = ""
  local prefix_used = ""
  if policy.name == "HDD" then
    normalized_basename = ""
    bootparam = ""
    bootparam_basename_used = ""
    if hdd_partition_label == nil or hdd_relpath == "" then
      BlockLaunchFailure(
        "Invalid HDD game entry",
        popstarter,
        device_page,
        nil,
        selected_entry,
        APP_DIR_LOCAL,
        nil,
        nil,
        nil,
        nil,
        nil,
        failure_context
      )
      return
    end
    vcd_path = hdd_relpath
  else
    bootparam, prefix, normalized_basename, prefix_added = BuildPopstarterBootString(
      boot_source_mode,
      pops_root,
      selected_entry
    )
    bootparam_exists = doesFileExist(bootparam)
    bootparam_basename_used = normalized_basename
    prefix_used = HasBootPrefix(normalized_basename, prefix) and prefix or ""
  end
  local selection_for_name = selected_entry
  if policy.name == "HDD" then
    selection_for_name = NormalizeHddRelpath(hdd_relpath or selected_entry)
  end
  local game_name = DeriveGameNameFromSelection(selection_for_name)
  if policy.name == "HDD" and type(PLDR.IsPartitionInstalledHddEntry) == "function"
     and PLDR.IsPartitionInstalledHddEntry(hdd_partition_label, hdd_relpath) then
    -- Partition-installed game: POPStarter's selector is the PARTITION name,
    -- never "IMAGE0" -- the argv0 basename "PP.<partition>.ELF" tells it to
    -- mount hdd0:PP.<partition> and boot pfs:/IMAGE0.VCD. The label is used
    -- LITERALLY (no SanitizeGameName): partition names are case-sensitive and
    -- must match the APA label exactly.
    game_name = TrimTrailingWhitespace(hdd_partition_label)
  end
  local vcd_basename_raw = selected_entry
  if policy.name == "HDD" then
    vcd_basename_raw = NormalizeHddRelpath(hdd_relpath or selected_entry)
  end
  if policy.name == "HDD" then
    normalized_basename = game_name
    bootparam = BuildLiteralElfName(game_name)
    bootparam_exists = bootparam ~= ""
    bootparam_basename_used = game_name
  end
  if game_name == "" or string.upper(game_name) == "POPSTARTER" then
    BlockLaunchFailure(
      "GameName derivation failed",
      popstarter,
      device_page,
      nil,
      vcd_basename_raw,
      APP_DIR_LOCAL,
      nil,
      nil,
      nil,
      nil,
      nil,
      failure_context
    )
    return
  end
  -- Adaptive BDMA (issue #509): stage the launched device's module variant.
  -- Runs AFTER the cheap launch validations above (a blocked launch must not
  -- cost memory-card writes) and before the exec; nothing in between reads the
  -- staged modules. Zero card writes when the right variant is already
  -- equipped. On a staging FAILURE the launch is CANCELLED: the card may hold
  -- the wrong (or half-written) modules and the game would just black-screen
  -- inside POPStarter with no diagnostics -- aborting returns to the menu
  -- loop, the only place the queued warn toast can actually render. pcall'd:
  -- an unexpected staging ERROR falls through to a normal launch instead of
  -- taking the whole launch path down.
  local adaptive_ok, adaptive_res = pcall(PLDR.MaybeApplyAdaptiveBdma, ui_scene, device_page)
  if adaptive_ok and adaptive_res == false then
    return
  end
  local selector_prefix = SelectPopstarterSelectorPrefix(device_page)
  local launch_cmd = BuildPopstarterLaunchCommand(
    policy.name,
    device_page,
    game_name,
    hdd_selector_mode,
    hdd_partition_label,
    popstarter_on_hdd
  )
  launch_cmd.elf_path = popstarter_exec_path
  launch_diagnostics.route = launch_cmd.launch_route
  local argv0_selector = launch_cmd.argv0_selector
  local argv = launch_cmd.argv
  if type(argv) ~= "table" then
    argv = {}
    launch_cmd.argv = argv
  end
  if type(argv0_selector) ~= "string" or argv0_selector == "" then
    argv0_selector = BuildLiteralElfName(game_name)
    launch_cmd.argv0_selector = argv0_selector
  end
  if type(argv[1]) ~= "string" or argv[1] == "" then
    argv[1] = argv0_selector
  end
  if selector_prefix == "" and string.upper(game_name) == "POPSTARTER" then
    BlockLaunchFailure(
      "Internal error: game_base derived as POPSTARTER; refusing to launch.",
      popstarter,
      device_page,
      nil,
      vcd_basename_raw,
      APP_DIR_LOCAL,
      nil,
      nil,
      nil,
      nil,
      nil,
      failure_context
    )
    return
  end
  if boot_source_mode == "mass" and prefix_added and not bootparam_exists then
    fallback_bootparam = EnsureTrailingSlash(pops_root)..selected_entry
    fallback_exists = doesFileExist(fallback_bootparam)
    if fallback_exists then
      bootparam = fallback_bootparam
      bootparam_basename_used = selected_entry
      bootparam_exists = true
      prefix_used = ""
    end
  end
  launch_diagnostics.final_resolved_exec_path = popstarter_exec_path
  launch_diagnostics.derived_partition_context = popstarter_partition_context
  if popstarter_partition_context ~= nil and popstarter_partition_context ~= "" then
    launch_diagnostics.derived_partition_context_reason = nil
  end
  launch_diagnostics.source_pfs_slot = popstarter_source_slot

  local keep_slots = {}
  if popstarter_original_slot == nil then
    popstarter_original_slot = ExtractLaunchPfsSlot(popstarter_exec_path)
  end
  if popstarter_keep_slot ~= nil then
    keep_slots[#keep_slots + 1] = popstarter_keep_slot
  end
  if popstarter_original_slot ~= nil and popstarter_original_slot ~= popstarter_keep_slot then
    keep_slots[#keep_slots + 1] = popstarter_original_slot
  end
  local keep_slots_after_load = nil
  if popstarter_on_hdd and not use_minimal_hdd_popstarter_exec then
    keep_slots_after_load = {}
    for i = 1, #keep_slots do
      keep_slots_after_load[#keep_slots_after_load + 1] = keep_slots[i]
    end
  end
  local context = {
    device_page = device_page,
    device_mode = device_mode,
    ui_scene = ui_scene or (UI and UI.CURSCENE or "unknown"),
    source_mode = source_mode,
    raw_source_mode = raw_source_mode,
    gamelocation = gamelocation,
    handoff_gamelocation = handoff_gamelocation,
    game = vcd_basename_raw,
    vcd_path = vcd_path,
    bootparam = bootparam,
    bootparam_prefix_required = prefix,
    bootparam_prefix_used = prefix_used,
    bootparam_prefix_added = prefix_added,
    bootparam_root = pops_root,
    bootparam_basename_raw = vcd_basename_raw,
    bootparam_basename_prefixed = normalized_basename,
    bootparam_basename = bootparam_basename_used,
    argv0_selector = argv0_selector,
    launch_route = launch_cmd.launch_route,
    game_name = game_name,
    bootparam_source = boot_source_mode,
    hdd_init = hdd_init,
    keep_hdd_slots = #keep_slots > 0 and keep_slots or nil,
    keep_hdd_slots_after_load = keep_slots_after_load,
    launch_cwd = popstarter_on_hdd and false or nil,
    cold_external_launch = popstarter_partition_context ~= nil and popstarter_partition_context ~= "",
    exec_path = popstarter_exec_path,
    exec_partition_context = popstarter_partition_context,
    exec_partition_context_authoritative = popstarter_partition_context,
    exec_partition_context_configured = configured_partition_context,
    exec_mounted_path = popstarter_exec_info.mounted_exec_path,
    exec_original_slot = popstarter_original_slot,
    exec_pfs_slot = popstarter_original_slot,
    source_pfs_slot = popstarter_source_slot,
    popstarter_on_hdd = popstarter_on_hdd,
    reboot_iop = launch_cmd.reboot_iop,
    boot_path = (type(System) == "table" and type(System.currentDirectory) == "function") and tostring(System.currentDirectory() or "") or "",
    boot_device_label = UI and UI.boot_device_label or nil,
    launch_diagnostics = launch_diagnostics
  }
  local fallback_succeeded = false
  if use_pfs_exec_fallback_without_partition_context then
    local fallback_exec_path, fallback_exec_reason, fallback_partition = ResolveFallbackMountedPfsExecPath(popstarter_exec_path, hdd_partition_label)
    if fallback_exec_path ~= nil then
      popstarter_exec_path = fallback_exec_path
      launch_cmd.elf_path = popstarter_exec_path
      if fallback_partition == nil then
        fallback_partition = NormalizeHddPartitionLabelForMount(hdd_partition_label)
      end
      if fallback_partition ~= nil then
        -- BuildHddPartitionContext / ResolvePopstarterPartitionContext store
        -- partition_context in "hdd0:PART:" form (with trailing colon); match
        -- that convention here so the C-side is_partition_context_arg
        -- validator in lua_loadELFWithPartition accepts it.
        popstarter_partition_context = fallback_partition..":"
        popstarter_exec_info = BuildPartitionScopedExecInfo(popstarter_exec_path, popstarter_partition_context)
        popstarter_source_slot = popstarter_exec_info.source_pfs_slot
        popstarter_keep_slot = popstarter_source_slot
        popstarter_original_slot = popstarter_source_slot
      end
      fallback_succeeded = true
      -- Refresh context fields that LaunchEngine consumes. The context table
      -- was built above from the pre-fallback locals; without this sync,
      -- exec_path/partition_context/slot/cold-launch flags would all be
      -- stale and the C side would receive the original mounted-PFS path
      -- with no partition context, defeating the fallback's purpose.
      context.exec_path = popstarter_exec_path
      context.exec_partition_context = popstarter_partition_context
      context.exec_partition_context_authoritative = popstarter_partition_context
      context.exec_mounted_path = popstarter_exec_info.mounted_exec_path
      context.exec_original_slot = popstarter_original_slot
      context.exec_pfs_slot = popstarter_original_slot
      context.source_pfs_slot = popstarter_source_slot
      context.cold_external_launch = popstarter_partition_context ~= nil and popstarter_partition_context ~= ""
      local refreshed_keep_slots = {}
      if popstarter_keep_slot ~= nil then
        refreshed_keep_slots[#refreshed_keep_slots + 1] = popstarter_keep_slot
      end
      if popstarter_original_slot ~= nil and popstarter_original_slot ~= popstarter_keep_slot then
        refreshed_keep_slots[#refreshed_keep_slots + 1] = popstarter_original_slot
      end
      context.keep_hdd_slots = #refreshed_keep_slots > 0 and refreshed_keep_slots or nil
      if popstarter_on_hdd then
        local after_load = {}
        for i = 1, #refreshed_keep_slots do
          after_load[#after_load + 1] = refreshed_keep_slots[i]
        end
        context.keep_hdd_slots_after_load = after_load
      end
      launch_diagnostics.final_resolved_exec_path = popstarter_exec_path
      launch_diagnostics.derived_partition_context = popstarter_partition_context
      launch_diagnostics.source_pfs_slot = popstarter_source_slot
      if popstarter_partition_context ~= nil and popstarter_partition_context ~= "" then
        launch_diagnostics.derived_partition_context_reason = nil
      end
      context.launch_route = launch_route_pfs_fallback
      launch_diagnostics.route = launch_route_pfs_fallback
    elseif strict_hdd_preexec_gate then
      BlockLaunchFailure(
        "POPSTARTER HDD pre-exec fallback reconstruction failed: "..tostring(fallback_exec_reason or "unknown error"),
        popstarter,
        device_page,
        argv and argv[1] or nil,
        vcd_basename_raw,
        APP_DIR_LOCAL,
        nil,
        nil,
        nil,
        context and context.launch_route or nil,
        hdd_preexec_gate_mode,
        context
      )
      return
    end
  end

  if popstarter_on_hdd and not use_minimal_hdd_popstarter_exec then
    -- Skip the gate only when the fallback actually reconstructed a
    -- partition-aware exec path. If the fallback failed in non-strict mode,
    -- let the gate run so its own partition-recovery logic can fire (or
    -- fail loudly), instead of silently launching with stale context.
    local should_run_gate = not fallback_succeeded
    if should_run_gate then
      local gate_ok, gate_err = ValidateHddPopstarterExecGate(popstarter_exec_path, popstarter_partition_context, popstarter_source_slot)
      if not gate_ok then
        BlockLaunchFailure(
          "POPSTARTER HDD pre-exec gate failed: "..tostring(gate_err or "unknown error"),
          popstarter,
          device_page,
          argv and argv[1] or nil,
          vcd_basename_raw,
          APP_DIR_LOCAL,
          nil,
          nil,
          nil,
          context and context.launch_route or nil,
          hdd_preexec_gate_mode,
          context
        )
        return
      end
    end
  end

  local reboot_iop = launch_cmd.reboot_iop
  if UI ~= nil and UI.CoverCache ~= nil and UI.CoverCache.Clear ~= nil then
    UI.CoverCache:Clear()
  end
  context.hdd_preexec_gate_mode = hdd_preexec_gate_mode
  LaunchEngine(popstarter, argv, reboot_iop, context)
end

function Touch(FILE)
  if not doesFileExist(FILE) then
    local FD = System.openFile(FILE, FCREATE)
    System.closeFile(FD)
    return true
  else
    return false
  end
end

-- NHDDL-style auto-launch from -page=<kind> -game=<selector>. Both args
-- must be set; if either is missing, behavior is unchanged. Page selects
-- the target device backend and scene; game is the device-specific
-- selector that PLDR.RunPOPStarterGame already understands:
--   page=hdd    game=<PARTITION>|<relpath>   e.g. __.POPS|SLUS_007.42.RAMPAGE.VCD
--   page=usb    game=<FILE.VCD>              relative to mass:/POPS
--   page=mmce   game=<FILE.VCD>              relative to mmce0:/POPS
--   page=mx4sio game=<FILE.VCD>              relative to mx4sio:/POPS
-- On success the function never returns (ExecPS2 hands off to POPSTARTER).
-- On failure it returns false and the welcome screen + main menu run
-- normally with an error toast queued for the user.
function PLDR.AutoLaunchFromLaunchArgs()
  if type(PLDR.LAUNCH_ARGS) ~= "table" then return false end
  local page = PLDR.LAUNCH_ARGS.page
  local game = PLDR.LAUNCH_ARGS.game
  if type(page) ~= "string" or page == "" then return false end
  if type(game) ~= "string" or game == "" then return false end
  if type(UI) ~= "table" or type(UI.SCENES) ~= "table" then return false end

  local scene, gamelocation
  if page == "HDD" and UI.SCENES.GHDD ~= nil then
    scene = UI.SCENES.GHDD
    gamelocation = ""
    if type(PLDR.LoadHDDModules) == "function" then
      pcall(PLDR.LoadHDDModules)
    end
  elseif page == "USB" and UI.SCENES.GUSBFAT ~= nil then
    scene = UI.SCENES.GUSBFAT
    gamelocation = "mass:/POPS"
    if type(PLDR.EnsureUsbMassReadyOnce) == "function" then
      pcall(PLDR.EnsureUsbMassReadyOnce)
    end
  elseif page == "MX4SIO" and UI.SCENES.GMX4SIO ~= nil then
    scene = UI.SCENES.GMX4SIO
    gamelocation = "mx4sio:/POPS"
    if type(PLDR.InitMX4SIOPopsRoot) == "function" then
      pcall(PLDR.InitMX4SIOPopsRoot)
    end
  elseif (page == "EXFAT" or page == "ATA") and UI.SCENES.GBDMHDD ~= nil then
    scene = UI.SCENES.GBDMHDD
    local ata_root = nil
    if type(PLDR.InitATAPopsRoot) == "function" then
      local ok_root, root = pcall(PLDR.InitATAPopsRoot)
      if ok_root and type(root) == "string" and root ~= "" then
        ata_root = root
      end
    end
    if ata_root == nil then
      if type(UI.Notif_queue) == "table" and type(UI.Notif_queue.add) == "function" then
        UI.Notif_queue.add("No exFAT HDD detected\nformat the internal drive exFAT (BDMA Mode = ATA)", "warn")
      end
      return false
    end
    gamelocation = ata_root
  elseif page == "MMCE" and UI.SCENES.GSMB ~= nil then
    scene = UI.SCENES.GSMB
    if type(PLDR.DetectMMCESlot) == "function" then
      pcall(PLDR.DetectMMCESlot, true)
    end
    local mmce_prefix = (type(PLDR.MMCE) == "table" and PLDR.MMCE.PREFIX) or "mmce0:/"
    gamelocation = mmce_prefix.."POPS"
  else
    if type(UI.Notif_queue) == "table" and type(UI.Notif_queue.add) == "function" then
      UI.Notif_queue.add("Auto-launch page not supported: "..tostring(page), "warn")
    end
    return false
  end

  -- UI.CURSCENE carries a __newindex write-guard (ui.lua tail) that drops
  -- the assignment unless UI.Transition.allowSceneWrite is raised -- and it
  -- stays false until after WelcomeDraw. Raise it for this one write so the
  -- scene context is real (BlockLaunchFailure/back-nav read it after a
  -- failed auto-launch). The launch itself never depended on this: the
  -- scene is passed to RunPOPStarterGame as an argument.
  local scene_gate = type(UI.Transition) == "table" and UI.Transition or nil
  local prev_scene_write = scene_gate ~= nil and scene_gate.allowSceneWrite or nil
  if scene_gate ~= nil then
    scene_gate.allowSceneWrite = true
  end
  UI.CURSCENE = scene
  if scene_gate ~= nil then
    scene_gate.allowSceneWrite = prev_scene_write
  end
  if UI.LASTSCENE == nil then
    UI.LASTSCENE = scene
  end

  -- Pre-flight the -game file (non-HDD pages only: HDD entries resolve through
  -- partition context and are untouched). A missing file used to exec POPStarter
  -- anyway and fail on ITS screen (or a black screen) with none of POPSLoader's
  -- launch diagnostics -- easy to hit, since the game list displays multi-disc
  -- names with the " (Disc N)" suffix trimmed. Probes the page root and its
  -- mass:/mass0: alias twin (the same swap RunPOPStarterGame's fallback does);
  -- only a miss on BOTH fails, so a working launch can't be false-blocked.
  if gamelocation ~= nil and gamelocation ~= "" then
    local base = EnsureTrailingSlash(gamelocation)
    local raw_path = base..game
    local exists = false
    pcall(function() exists = (doesFileExist(raw_path) == true) end)
    if not exists then
      local alt = nil
      if string.match(base, "^[Mm][Aa][Ss][Ss]:/") then
        alt = string.gsub(base, "^[Mm][Aa][Ss][Ss]:/", "mass0:/", 1)
      elseif string.match(base, "^[Mm][Aa][Ss][Ss]0:/") then
        alt = string.gsub(base, "^[Mm][Aa][Ss][Ss]0:/", "mass:/", 1)
      end
      if alt ~= nil then
        pcall(function() exists = (doesFileExist(alt..game) == true) end)
      end
    end
    if not exists then
      if type(UI.Notif_queue) == "table" and type(UI.Notif_queue.add) == "function" then
        UI.Notif_queue.add("-game not found:\n"..raw_path, "error")
      end
      return false
    end
  end

  local ok, err = pcall(PLDR.RunPOPStarterGame, gamelocation, game, scene, nil)
  if not ok and type(UI.Notif_queue) == "table" and type(UI.Notif_queue.add) == "function" then
    UI.Notif_queue.add("Auto-launch failed: "..tostring(err), "error")
  end
  return ok
end

-- Debug consumer: when -debug is passed, surface the resolved boot context
-- and launch args as a toast so the user can verify how POPSLoader classified
-- its environment without rebuilding with DPRINTF enabled. Visible on the
-- main menu if no -game= is passed, or on the main menu after an auto-launch
-- failure if both -debug and -game= are passed.
function PLDR.SurfaceLaunchArgsDebug()
  if type(PLDR.LAUNCH_ARGS) ~= "table" or PLDR.LAUNCH_ARGS.debug ~= true then
    return
  end
  if type(UI) ~= "table" or type(UI.Notif_queue) ~= "table"
     or type(UI.Notif_queue.add) ~= "function" then
    return
  end
  local lines = {"[debug] boot context"}
  local ctx = (type(PLDR.GetBootContext) == "function") and PLDR.GetBootContext() or nil
  if type(ctx) == "table" then
    lines[#lines+1] = "kind: "..tostring(ctx.kind or "<nil>")
    lines[#lines+1] = "boot_path: "..tostring(ctx.boot_path or "<nil>")
    lines[#lines+1] = "sidecar: "..tostring(ctx.sidecar_path or "<nil>")
  end
  lines[#lines+1] = "settings: "..tostring(PLDR.SETTINGS_PATH or "<nil>")
  if type(UI.VIDEO_READBACK) == "string" then
    lines[#lines+1] = "video: "..UI.VIDEO_READBACK
  end
  lines[#lines+1] = "args.page: "..tostring(PLDR.LAUNCH_ARGS.page or "<nil>")
  lines[#lines+1] = "args.game: "..tostring(PLDR.LAUNCH_ARGS.game or "<nil>")
  UI.Notif_queue.add(table.concat(lines, "\n"), "info")
end

-- Boot recovery (mirrors OPL's "hold to skip config"): hold START while
-- POPSLoader boots to force a SAFE display mode (Auto = console region),
-- ignoring the saved Video Standard. Recovers a user who locked themselves out
-- with e.g. NTSC on a PAL-only display -- they get a visible UI to fix it. Poll
-- a few times since a single pad read at boot can miss a held button.
local boot_start_held = false
if type(Pads) == "table" and type(Pads.get) == "function" and type(PAD_START) == "number" then
  for _ = 1, 16 do
    local ok_pad, gp = pcall(Pads.get)
    if ok_pad and type(gp) == "number" and (gp & PAD_START) ~= 0 then
      boot_start_held = true
      break
    end
  end
end

-- do_boot_init runs the SLOW device bring-up, handed to UI.WelcomeDraw.Play as
-- boot_init_fn: the welcome splash paints FIRST, then this work runs under it (it
-- freezes on the splash frame), so the old boot BLACK screen is now the splash.
-- NOTE: settings load + the video-mode apply happen BEFORE the splash (just above
-- the WelcomeDraw.Play call) so the splash is centered from frame one and a held-
-- START recovery is viewable immediately; only the slow device init is under the
-- splash. The START-held poll ABOVE also stays pre-splash (boot_start_held is read
-- below as an upvalue). Inner block kept at its original indentation for a clean diff.
local function do_boot_init()
PLDR.AutoInitStartupBackends()
-- EXP38: bring the internal exFAT block stack (ata_bd) up HERE, SYNCHRONOUSLY,
-- under the welcome splash -- the REFERENCE model. OPL, wLaunchELF_R3Z and NHDDL
-- all load their whole block-device stack together in ONE serial window under a
-- loading screen, before anything else touches the bus. POPSLoader diverged into
-- lazy per-page loading, and THAT divergence is the exFAT freeze: ata_bd loaded
-- late (mid-session, onto a busy IOP) OR async (a worker racing other IOP traffic)
-- wedges its own bring-up (EXP24: "the IOP census at load time IS the variable;
-- no reference loads BDM-atad late onto a full IOP").
--
-- This is the EXP22 arrangement sAGA confirmed reads his 4TB GPT drive ("works
-- just fine"), with the two reasons it was reverted BOTH removed:
--   * NO black screen -- do_boot_init runs UNDER the splash (graphics already up),
--     so the seconds ata_bd needs show the frozen splash, not a black panel. That
--     is exactly why the "slow device bring-up" belongs here (see the header note).
--   * NO async race -- the EXP32/35 kick used initATAAsync (a WORKER) that kept
--     running past do_boot_init and wedged the splash->menu transition on sAGA's
--     drive (the 2026-07-22 black screen the EXP35 gate was chasing). A SYNCHRONOUS
--     load blocks do_boot_init and finishes BEFORE the transition: serial, no
--     concurrent bus traffic, exactly the EXP22 condition that worked.
--
-- Gated on exFAT actually being enabled (Internal HDD = EXFAT/BOTH, or a -page=ata
-- session) so PFS-only installs pay nothing; and ata_bd self-exits fast when SPD
-- reports no ATA device, so a driveless console barely notices. ata_bd is dev9-only
-- -- this does NOT load or touch mmceman/SIO2 (MMCE) or the MX4SIO stack, and it
-- shares the load-once EnsureAtaBdm with the APA/PFS boot path. The exFAT PAGE then
-- finds the stack already up (initATA is load-once) and just reads it.
do
  local want_ata_boot = (type(PLDR.WantExfatBootBringup) == "function")
                        and (PLDR.WantExfatBootBringup() == true)
  if want_ata_boot and type(System) == "table" and type(System.initATA) == "function" then
    pcall(System.initATA)
  end
end
-- One-time hygiene: clear a leftover crash-marker file from marker-era builds
-- (the marker system is gone in EXP32; see ClearLegacyMx4sioMarker).
if type(PLDR.ClearLegacyMx4sioMarker) == "function" then
  pcall(PLDR.ClearLegacyMx4sioMarker)
end
-- LATE START re-poll: the pre-splash poll above covers wired port-0 pads (pad_init
-- blocks until stable), but DS3/DS4 over ds34usb/ds34bt enumerate asynchronously
-- over seconds -- a user holding START on such a pad through boot was MISSED by
-- the early poll, so the recovery never fired in the exact unbootable-config
-- scenario it exists for. Seconds have now passed under the splash (backend
-- init), so BT/USB pads are enumerated; re-poll and re-apply the safe video mode
-- when this late poll is the one that catches the hold. (No sleeps: System.sleep
-- takes integer seconds only and pre-splash delays would regress splash-first boot.)
if not boot_start_held and type(Pads) == "table" and type(Pads.get) == "function"
   and type(PAD_START) == "number" then
  for _ = 1, 16 do
    local ok_pad, gp = pcall(Pads.get)
    if ok_pad and type(gp) == "number" and (gp & PAD_START) ~= 0 then
      boot_start_held = true
      PLDR.VIDEO_STANDARD = PLDR.VIDEO_STANDARD_AUTO
      if type(PLDR.ApplyVideoStandardRuntime) == "function" then
        pcall(PLDR.ApplyVideoStandardRuntime, PLDR.VIDEO_STANDARD_AUTO)
      end
      break
    end
  end
end
-- Auto-launch BEFORE surfacing the debug toast: Notif_queue keeps only the
-- 2 newest toasts, so queueing the debug toast last guarantees it survives
-- an auto-launch failure toast instead of being evicted by it. (On
-- auto-launch success control never returns, so the order is moot.)
-- Recovery: holding START at boot must land on the plain carousel, so suppress
-- the explicit -game auto-launch too (the block above already reset video +
-- Boot Page). Otherwise a launcher chaining -page/-game would whisk the user
-- straight past the recovery UI -- the very thing START-held is meant to escape.
if not boot_start_held then
  PLDR.AutoLaunchFromLaunchArgs()
end
PLDR.SurfaceLaunchArgsDebug()

-- Persisted Boot Page: on a NORMAL boot (no -page launch arg; and no auto-launch
-- happened above -- that never returns on success), land the carousel on the
-- user's chosen device and auto-ENTER its game list. Reuses the SAME OPT/carousel
-- write-guard dance + PendingAutoEnter as the -page handler; no -game is involved,
-- so this only enters the device list (never auto-launches a game). PLDR.BOOT_PAGE
-- is already normalized by LoadSettingsNonFatal; "Carousel" (or any unmapped value)
-- leaves the default MMCE-at-index-1 carousel behavior untouched.
if type(PLDR.LAUNCH_ARGS) ~= "table"
   or type(PLDR.LAUNCH_ARGS.page) ~= "string" or PLDR.LAUNCH_ARGS.page == "" then
  local boot_to_opt = { MMCE = 1, MX4SIO = 2, EXFAT = 3, HDD = 4, USB = 5 }
  local opt = boot_to_opt[tostring(PLDR.BOOT_PAGE or "Carousel")]
  -- If the chosen Boot Page device has been hidden from the carousel, don't
  -- auto-enter it -- fall back to the normal carousel instead. Toast WHY (this
  -- also fires when Internal HDD flipped PFS<->exFAT and stranded the saved HDD
  -- Boot Page): a silent fallback reads as "Boot Page is broken".
  if opt ~= nil and type(PLDR.IsDeviceHidden) == "function"
     and type(PLDR.CAROUSEL_DEVICE_KEYS) == "table"
     and PLDR.IsDeviceHidden(PLDR.CAROUSEL_DEVICE_KEYS[opt]) then
    opt = nil
    if type(UI) == "table" and type(UI.Notif_queue) == "table" then
      UI.Notif_queue.add("Boot Page device is hidden -- landed on the carousel.\nCheck Settings > Boot Page / Internal HDD.", "warn")
    end
  end
  -- EXP32: the MX4SIO crash-loop boot guard is gone with the marker system --
  -- page entry no longer loads drivers (boot does), so there is no unbounded
  -- probe for a marker to bound. Auto-enter proceeds for every device alike.
  if opt ~= nil and type(UI) == "table" and type(UI.MainMenu) == "table" then
    local carousel = type(UI.MainMenu.Carousel) == "table" and UI.MainMenu.Carousel or nil
    if carousel ~= nil then carousel.allowOptWrite = true end
    UI.MainMenu.OPT = opt
    if carousel ~= nil then
      carousel.allowOptWrite = false
      carousel.currentIndex = opt
      carousel.targetIndex = opt
      carousel.scrollPos = opt + 0.0
    end
    UI.MainMenu.PendingAutoEnter = true
  end
end
end -- do_boot_init

---MAIN PROGRAM BEHAVIOUR BEGINS
local initial_scene = UI.SCENES.MMAIN
local show_boot_credits = true
-- Load settings + apply the video mode BEFORE the splash paints. The first video
-- apply force-recenters the raster (on PAL the boot image sat top-aligned with a
-- bottom bar otherwise), so doing it here centers the splash from frame one instead
-- of snapping mid-fade; and a held-START recovery shows a viewable picture at once
-- rather than fading in behind the broken mode. Settings load is cheap -- only the
-- SLOW device bring-up stays under the splash (do_boot_init). This restores the
-- START-held video + Boot-Page recovery that used to live at the top of
-- do_boot_init. (#501 splash centering)
-- When a -page flag selects a device, its settings READ+WRITE to THAT device's POPS
-- folder instead of the boot cwd (CosmicScale 2026-06-25: "when a flag is used, read and
-- write to the selected device"). So a launcher booted from an APA HDD with -page=ata
-- keeps its .pldrs on the exFAT drive (mass:/POPS/.pldrs) -- self-contained, travels with
-- the drive. Override the sidecar HERE -- AFTER InitATAPopsRoot is defined and the ata BDM
-- is up (boot.lua's HDD mount already ran EnsureAtaBdm), and BEFORE the single
-- LoadSettingsNonFatal below -- so its existing probe / mass-mount-settle / migrate /
-- atomic-write logic targets the device unchanged (read correct video from frame one, no
-- post-splash re-apply flicker). The FALLBACK is pointed at the prior cwd sidecar so an
-- existing cwd/HDD config MIGRATES onto the device on the first boot (read from cwd, then
-- pinned to the device; next save lands on the device). ATA is the only -page target wired
-- here: it is the exFAT case asked for and the only device with a boot-callable root
-- resolver (USB/MMCE resolve their root only inside the ui.lua entry handlers); every other
-- -page target keeps the cwd sidecar.
if type(PLDR.LAUNCH_ARGS) == "table" and type(PLDR.LAUNCH_ARGS.page) == "string"
   and type(PLDR.InitATAPopsRoot) == "function" then
  local flag_page = string.upper(PLDR.LAUNCH_ARGS.page)
  if flag_page == "ATA" or flag_page == "EXFAT" then
    local games_root = PLDR.InitATAPopsRoot()  -- "mass:/POPS/" (settles via the deferred probe), or nil if no exFAT
    if type(games_root) == "string" and games_root ~= "" then
      local prior_sidecar = PLDR.SETTINGS_PATH_SIDECAR
      if type(prior_sidecar) == "string" and prior_sidecar ~= "" then
        PLDR.SETTINGS_PATH_FALLBACK = prior_sidecar  -- migrate a prior cwd/HDD config onto the device on first boot
      end
      PLDR.SETTINGS_PATH_SIDECAR = games_root..".pldrs"  -- e.g. mass:/POPS/.pldrs
      PLDR.SETTINGS_PATH = PLDR.SETTINGS_PATH_SIDECAR
      PLDR.SETTINGS_HDD_PARTITION = nil  -- exFAT writes go through the per-device sidecar branch, not the HDD takeover
      PLDR.SETTINGS_HDD_RELPATH = nil
    end
  end
end
PLDR.LoadSettingsNonFatal()
-- Ensure the MC POPSTARTER folder ONLY AFTER settings load, so the saved
-- POPSTARTER_MC_FOLDER is honored. EnsurePopstarterDir self-guards: ON -> create (the
-- folder + OSD icons appear on boot as before); OFF -> no-op (stays deleted, fixing the
-- every-boot recreation provato reported). This is the only LoadSettingsNonFatal call site.
pcall(PLDR.EnsurePopstarterDir)
-- Boot-time heal for the in-game SMB .DATs: the rolling zip ships TEMPLATE
-- SMBCONFIG.DAT/IPCONFIG.DAT ("SMBip:SMBport..." placeholders) in its POPSTARTER/
-- folder, and a user who copies that onto the card AFTER configuring SMB in-app
-- would stream against the placeholders until the next settings save. SyncSmbDat
-- is already guarded (no-op unless smbman.irx is staged) and write-if-changed.
pcall(PLDR.SyncSmbDat)
if boot_start_held then
  PLDR.VIDEO_STANDARD = PLDR.VIDEO_STANDARD_AUTO
  if type(PLDR.ApplyVideoStandardRuntime) == "function" then
    PLDR.ApplyVideoStandardRuntime(PLDR.VIDEO_STANDARD_AUTO)
  end
  -- Also drop the persisted Boot Page (and any -page auto-enter) so a device whose
  -- probe can stall -- e.g. MX4SIO with no card -- can't auto-enter and wedge the
  -- boot. Holding START thus always lands on the plain carousel, where the user can
  -- change Boot Page / Video Standard in Settings.
  PLDR.BOOT_PAGE = "Carousel"
  if type(UI) == "table" and type(UI.MainMenu) == "table" then
    UI.MainMenu.PendingAutoEnter = false
  end
  if type(UI) == "table" and type(UI.Notif_queue) == "table" then
    UI.Notif_queue.add("Start held at boot: display reset to Auto, Boot Page reset to Carousel.\nAdjust them in Settings if needed.", "warn")
  end
end
-- Splash-first: paint the welcome splash, then run do_boot_init (slow device
-- bring-up) UNDER it (see the boot_init_fn call in UI.WelcomeDraw.Play), so the
-- boot black screen is covered.
UI.WelcomeDraw.Play(initial_scene, show_boot_credits, do_boot_init)
if UI.Transition ~= nil then
  UI.Transition.allowSceneWrite = true
end
UI.CURSCENE = initial_scene
UI.LASTSCENE = initial_scene
if UI.Transition ~= nil then
  UI.Transition.allowSceneWrite = false
end

while true do
  UI.BottomDraw.Play()
  if UI.CURSCENE == UI.SCENES.MMAIN then
    UI.MainMenu.Play()
  elseif UI.CURSCENE == UI.SCENES.MPROFILE then
    UI.ProfileQuery.Play()
  elseif UI.IsGameScene(UI.CURSCENE) then
    UI.GameList.Play()
  elseif UI.CURSCENE == UI.SCENES.CREDITS then
    UI.Credits.Play()
  end
  UI.flip()
end
