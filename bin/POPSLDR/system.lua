--[[
  ___  ___  ___  ___ _                 _         
 | _ \/ _ \| _ \/ __| |   ___  __ _ __| |___ _ _ 
 |  _/ (_) |  _/\__ \ |__/ _ \/ _` / _` / -_) '_|
 |_|  \___/|_|  |___/____\___/\__,_\__,_\___|_|  
                                                 

  POPSLoader Main script. dont touch unless you know what youre doing
  to do cosmetic changes, please check the `ui.lua` and `images.lua` files
  to add custom popstarter profiles check `pops_profiles.lua`

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

local function GetProfilePopstarterPath(profile)
  local index = tonumber(profile)
  if index == nil or type(PLDR.PROFILES) ~= "table" or PLDR.PROFILES[index] == nil then
    return ""
  end
  return tostring(PLDR.PROFILES[index].ELF or "")
end

local POPSTARTER_MODE_PROFILE_DEFAULT = "PROFILE_DEFAULT"
local POPSTARTER_MODE_CUSTOM = "CUSTOM"

local function NormalizePopstarterSelectionMode(mode)
  local normalized = string.upper(tostring(mode or ""))
  if normalized == POPSTARTER_MODE_PROFILE_DEFAULT then
    return POPSTARTER_MODE_PROFILE_DEFAULT
  end
  return POPSTARTER_MODE_CUSTOM
end

local function NormalizeSelectedProfilePopstarterPath(profile, path, mode)
  local selected_profile_path = GetProfilePopstarterPath(profile)
  local configured_path = tostring(path or "")
  local selected_mode = NormalizePopstarterSelectionMode(mode or PLDR.POPSTARTER_SELECTION_MODE)

  if selected_mode == POPSTARTER_MODE_PROFILE_DEFAULT then
    if selected_profile_path ~= "" then
      return selected_profile_path
    end
    return configured_path
  end

  if configured_path == "" then
    return ""
  end

  return configured_path
end

local function GetPopstarterStorageBackend(path)
  local candidate = string.lower(tostring(path or ""))
  if string.match(candidate, "^hdd%d:") ~= nil or string.match(candidate, "^pfs%d*:/") ~= nil then
    return "HDD"
  end
  if candidate == "" then
    return "UNKNOWN"
  end
  return "NON_HDD"
end

local function ResolveProfilePopstarterSelection(profile, selected_path, persisted_path, mode)
  local selected_mode = NormalizePopstarterSelectionMode(mode)
  local normalized_selected = NormalizeSelectedProfilePopstarterPath(profile, selected_path, selected_mode)
  local normalized_persisted = NormalizeSelectedProfilePopstarterPath(profile, persisted_path, selected_mode)
  local selected_backend = GetPopstarterStorageBackend(normalized_selected)
  local persisted_backend = GetPopstarterStorageBackend(normalized_persisted)
  local rule = "persisted_wins"
  local effective = normalized_persisted

  if normalized_persisted == "" then
    rule = "selected_wins_missing_persisted"
    effective = normalized_selected
  end

  effective = NormalizeSelectedProfilePopstarterPath(profile, effective, selected_mode)
  return {
    effective_path = effective,
    normalized_selected_path = normalized_selected,
    normalized_persisted_path = normalized_persisted,
    selected_backend = selected_backend,
    persisted_backend = persisted_backend,
    rule = rule,
    mode = selected_mode
  }
end

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
  local active = tonumber(PLDR and PLDR.HDD and PLDR.HDD.GAME_SLOT or nil)
  if active == HDD_SLOT_BOOT or active == HDD_SLOT_GAME then
    if active == HDD_SLOT_BOOT then
      return { HDD_SLOT_BOOT, HDD_SLOT_GAME }
    end
    return { HDD_SLOT_GAME, HDD_SLOT_BOOT }
  end
  return { HDD_SLOT_GAME, HDD_SLOT_BOOT }
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
  local ok, mounted = pcall(HDD.MountPartition, normalized_partition, mount_slot, mount_mode)
  if ok and mounted == true then
    local prefix = BuildMountedPfsPrefix(mount_slot)
    return true, RememberRecordedHddMount(normalized_partition, prefix)
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
  for i = 1, #candidates do
    local slot = candidates[i]
    local mounted, prefix = MountHddPartitionTracked(normalized_partition, slot, mode)
    if mounted and prefix ~= nil then
      if type(PLDR) == "table" and type(PLDR.HDD) == "table" then
        PLDR.HDD.GAME_SLOT = slot
      end
      return true, prefix, slot
    end
  end
  return false, nil, nil
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
-- unmount. Answers whether the bundled ps2hdd-osd driver can write a NON-boot
-- partition (the boot partition pfs1: is known-unwritable: Nuno PR#464, which is
-- why HDD settings save to mc0:). Real settings are unaffected; this only reports
-- via the settings-save toast. Returns: nil = not an HDD boot (skip);
-- true,<partition> = writable; false,<reason> = not.
function PLDR.ProbeHddSettingsWrite()
  if GetBootHddMountSlot() == nil then return nil end
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
          pcall(System.writeFile, fd, "ok", 2)
          pcall(System.closeFile, fd)
          wrote = (doesFileExist(probe_path) == true)
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

function PLDR.GetEffectiveConfiguredPopstarterPath(path, profile)
  local selected_profile = tonumber(profile) or tonumber(PLDR.SELECTED_PROFILE) or tonumber(PLDR.DEFAULT_PROFILE) or 1
  return NormalizeSelectedProfilePopstarterPath(selected_profile, path or PLDR.POPSTARTER_PATH, PLDR.POPSTARTER_SELECTION_MODE)
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
  local sidecar = nil
  if type(APP_DIR_LOCAL) == "string" and APP_DIR_LOCAL ~= "" then
    local lower = string.lower(APP_DIR_LOCAL)
    local is_hdd_backed = string.match(lower, "^hdd%d*:") ~= nil
       or string.match(lower, "^pfs%d*:") ~= nil
       or string.match(lower, "^ata%d*:") ~= nil
       or string.match(lower, "^apa%d*:") ~= nil
    if not is_hdd_backed then
      sidecar = JoinPath(APP_DIR_LOCAL, ".pldrs")
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
        local ID, RET = IOP.loadModule(PATH)
        loaded = true
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
HDD_DIAG_BYPASS = 0
local pldr_defaults = {
  REBOOT_IOP_WHILE_LOADING_POPSTARTER = 0;
  STRICT_HDD_PREEXEC_GATE = false;
  POPSTARTER_PATH = "POPSTARTER.ELF";
  POPSTARTER_SELECTION_MODE = POPSTARTER_MODE_PROFILE_DEFAULT;
  GAMEPATH = ".";
  GAMES = {};
  HDDCACHE = nil;
  PROFILES = {};
  HDD = {
    USECACHE = true;
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
  if key == "hdd" or key == "ata" or key == "pfs" or key == "apa" then
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

PLDR.VIDEO_STANDARD_NTSC = "NTSC"
PLDR.VIDEO_STANDARD_PAL = "PAL"
PLDR.KEYBOARD_LAYOUT_ABC = "ABC"
PLDR.KEYBOARD_LAYOUT_QWERTY = "QWERTY"
PLDR.KEYBOARD_LAYOUT_DVORAK = "DVORAK"

local function NormalizeVideoStandard(value)
  local key = string.upper(tostring(value or ""))
  if key == PLDR.VIDEO_STANDARD_PAL then
    return PLDR.VIDEO_STANDARD_PAL
  end
  return PLDR.VIDEO_STANDARD_NTSC
end

local function NormalizeKeyboardLayout(value)
  local key = string.upper(tostring(value or ""))
  if key == PLDR.KEYBOARD_LAYOUT_QWERTY then
    return PLDR.KEYBOARD_LAYOUT_QWERTY
  end
  if key == PLDR.KEYBOARD_LAYOUT_DVORAK then
    return PLDR.KEYBOARD_LAYOUT_DVORAK
  end
  return PLDR.KEYBOARD_LAYOUT_ABC
end

local function BuildVideoStandardSpec(standard)
  local key = NormalizeVideoStandard(standard)
  if key == PLDR.VIDEO_STANDARD_PAL then
    return {
      key = PLDR.VIDEO_STANDARD_PAL,
      mode = PAL,
      width = 640,
      -- Keep the PAL UI raster aligned with the NTSC-authored artwork.
      height = 448,
      fps = 50
    }
  end
  return {
    key = PLDR.VIDEO_STANDARD_NTSC,
    mode = NTSC,
    width = 640,
    height = 448,
    fps = 60
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
if PLDR.MX4SIO.PREFIX_HINT ~= nil then
end
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

require("pops_profiles")
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
  if boot_name ~= nil then
  else
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
-- HDD launch arg targets the implemented PFS page (index 4); the BDMA
-- (HDD exFAT, index 3) and i.Link (index 6) pages are intentionally not
-- implemented so we don't auto-route to them.
if type(PLDR) == "table" and type(PLDR.LAUNCH_ARGS) == "table"
   and type(PLDR.LAUNCH_ARGS.page) == "string" and PLDR.LAUNCH_ARGS.page ~= "" then
  local page_to_opt = {
    MMCE = 1,
    MX4SIO = 2,
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

PLDR.POPSTARTER_DIR = "mc0:/POPSTARTER"

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
PLDR.SETTINGS_PATH_FALLBACK = "mc0:/POPSTARTER/.pldrs"
PLDR.SETTINGS_PATH_SIDECAR = ResolveBootContext().sidecar_path
PLDR.SETTINGS_PATH = PLDR.SETTINGS_PATH_SIDECAR or PLDR.SETTINGS_PATH_FALLBACK
PLDR.BDMA_MODE_KEY = "FAT32"
PLDR.SELECTED_PROFILE = tonumber(PLDR.DEFAULT_PROFILE) or 1
PLDR.DKWDRV_DEFAULT_PATH = "mc0:/PS1_DKWDRV/DKWDRV.ELF"
PLDR.DKWDRV_PATH = tostring(PLDR.DKWDRV_PATH or PLDR.DKWDRV_DEFAULT_PATH)
PLDR.KEYBOARD_LAYOUT = NormalizeKeyboardLayout(PLDR.KEYBOARD_LAYOUT)

local POPSTARTER_PACK_ROOT = PLDR.POPSTARTER_DIR
local BDMA_MODE_MARKER_PATH = POPSTARTER_PACK_ROOT.."/.pldr_bdma_mode"
local BDMA_COPY_FILES = {
  "usbd.irx",
  "usbhdfsd.irx"
}
local BDMA_FAT32_REMOVE_FILES = {
  "mc0:/POPSTARTER/usbd.irx",
  "mc0:/POPSTARTER/usbhdfsd.irx"
}
local BDMA_UI_FILES = {
  { src = "icon.sys.bdma", dst = "icon.sys" },
  { src = "list.icn.bdma", dst = "list.icn" },
  { src = "del.icn.bdma", dst = "del.icn" }
}
local BDMA_SUFFIX = {
  USBEXFAT = ".usbexfat",
  MX4SIO = ".mx4sio",
  MMCE = ".mmce"
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
    pcall(System.rename, dest, bak)
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
    local ok_write = pcall(System.writeFile, fd, chunk, string.len(chunk))
    if not ok_write then
      pcall(System.closeFile, fd)
      pcall(System.removeFile, tmp)
      return false
    end
    offset = offset + string.len(chunk)
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
  local ok, err = pcall(System.createDirectory, path)
  if not ok then
  end
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
  return EnsurePopstarterPackDir(PLDR.POPSTARTER_DIR)
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

-- Boot Page (persisted landing page after the boot sequence): "Carousel"
-- (default device carousel) or a device key that auto-enters that game list.
local function NormalizeBootPage(value)
  local key = string.upper(tostring(value or ""))
  if key == "MX4SIO" then return "MX4SIO" end
  if key == "USB" then return "USB" end
  if key == "MMCE" then return "MMCE" end
  if key == "HDD" or key == "APAHDD" or key == "APA" or key == "PFS" then return "HDD" end
  return "Carousel"
end

local function EncodeSettings()
  local selected_profile = tonumber(PLDR.SELECTED_PROFILE) or 1
  local selection_mode = NormalizePopstarterSelectionMode(PLDR.POPSTARTER_SELECTION_MODE)
  local configured_popstarter = NormalizeSelectedProfilePopstarterPath(selected_profile, PLDR.POPSTARTER_PATH, selection_mode)
  local persisted_popstarter = configured_popstarter
  if selection_mode == POPSTARTER_MODE_PROFILE_DEFAULT then
    persisted_popstarter = ""
  end
  local lines = {
    "PROFILE="..tostring(selected_profile),
    "POPSTARTER_PATH="..persisted_popstarter,
    "POPSTARTER_MODE="..selection_mode,
    "BDMA="..tostring(PLDR.BDMA_MODE_KEY or "FAT32"),
    "DKWDRV_PATH="..tostring(PLDR.DKWDRV_PATH or PLDR.DKWDRV_DEFAULT_PATH),
    "STRICT_HDD_PREEXEC_GATE="..((PLDR.STRICT_HDD_PREEXEC_GATE == true) and "1" or "0"),
    "VIDEO_STANDARD="..tostring(NormalizeVideoStandard(PLDR.VIDEO_STANDARD)),
    "HIDE_TEXT="..(((type(UI) == "table" and UI.HideTextMode == true) and "1") or "0"),
    "KEYBOARD_LAYOUT="..tostring(NormalizeKeyboardLayout(PLDR.KEYBOARD_LAYOUT)),
    "BOOT_PAGE="..NormalizeBootPage(PLDR.BOOT_PAGE),
    "MULTIDISC_COLLAPSE="..((PLDR.COLLAPSE_MULTIDISC == true) and "1" or "0")
  }
  return table.concat(lines, "\n").."\n"
end

local function NormalizeBdmaModeKey(mode)
  if mode == nil then
    return nil
  end
  local value = string.upper(tostring(mode or ""))
  value = string.gsub(value, "[%s_%-]", "")
  if value == "FAT32" then
    return "FAT32"
  elseif value == "USBEXFAT" or value == "EXFAT" then
    return "USBEXFAT"
  elseif value == "MX4SIO" then
    return "MX4SIO"
  elseif value == "MMCE" then
    return "MMCE"
  end
  return nil
end

local function SnapshotSettingsState()
  local profile = tonumber(PLDR.SELECTED_PROFILE) or tonumber(PLDR.DEFAULT_PROFILE) or 1
  return {
    profile = profile,
    popstarter_path = NormalizeSelectedProfilePopstarterPath(profile, PLDR.POPSTARTER_PATH, PLDR.POPSTARTER_SELECTION_MODE),
    popstarter_mode = NormalizePopstarterSelectionMode(PLDR.POPSTARTER_SELECTION_MODE),
    bdma_mode = NormalizeBdmaModeKey(PLDR.BDMA_MODE_KEY) or "FAT32",
    dkwdrv_path = tostring(PLDR.DKWDRV_PATH or PLDR.DKWDRV_DEFAULT_PATH),
    video_standard = NormalizeVideoStandard(PLDR.VIDEO_STANDARD),
    hide_text = (type(UI) == "table" and UI.HideTextMode == true) or false,
    keyboard_layout = NormalizeKeyboardLayout(PLDR.KEYBOARD_LAYOUT),
    boot_page = NormalizeBootPage(PLDR.BOOT_PAGE),
    multidisc_collapse = (PLDR.COLLAPSE_MULTIDISC == true)
  }
end

local function ApplySettingsState(state)
  if state == nil then
    return
  end
  local profile = tonumber(state.profile)
  if profile ~= nil and PLDR.PROFILES ~= nil and PLDR.PROFILES[profile] ~= nil then
    PLDR.SELECTED_PROFILE = profile
  end
  PLDR.POPSTARTER_SELECTION_MODE = NormalizePopstarterSelectionMode(state.popstarter_mode)
  if state.popstarter_path ~= nil then
    PLDR.POPSTARTER_PATH = NormalizeSelectedProfilePopstarterPath(PLDR.SELECTED_PROFILE, state.popstarter_path, PLDR.POPSTARTER_SELECTION_MODE)
  end
  local bdma = NormalizeBdmaModeKey(state.bdma_mode)
  if bdma ~= nil then
    PLDR.BDMA_MODE_KEY = bdma
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
  if state.boot_page ~= nil then
    PLDR.BOOT_PAGE = NormalizeBootPage(state.boot_page)
  end
  if type(state.multidisc_collapse) == "boolean" then
    PLDR.COLLAPSE_MULTIDISC = state.multidisc_collapse
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
    ReadBdmaModeMarkerCompat(BDMA_MODE_MARKER_PATH),
    ReadBdmaModeMarkerCompat(POPSTARTER_PACK_ROOT.."/.pldr_bdma")
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
  if effective ~= nil then
    PLDR.BDMA_MODE_KEY = effective
  else
    PLDR.BDMA_MODE_KEY = NormalizeBdmaModeKey(PLDR.BDMA_MODE_KEY) or "FAT32"
  end
  return PLDR.BDMA_MODE_KEY
end

function PLDR.SaveSettingsAtomic()
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
      UI.Notif_queue.add("Cannot access mc0:/POPSTARTER")
    end
    return false
  end
  local data = EncodeSettings()
  local ok = WriteAtomic(target, data)
  if not ok and UI ~= nil and UI.Notif_queue ~= nil then
    UI.Notif_queue.add("Failed to save settings")
  end
  return ok
end

function PLDR.LoadSettingsNonFatal()
  local defaults_profile = tonumber(PLDR.DEFAULT_PROFILE) or 1
  PLDR.EnsurePopstarterDir()
  PLDR.SELECTED_PROFILE = defaults_profile
  PLDR.BDMA_MODE_KEY = "FAT32"
  PLDR.POPSTARTER_SELECTION_MODE = POPSTARTER_MODE_PROFILE_DEFAULT
  PLDR.STRICT_HDD_PREEXEC_GATE = false
  PLDR.VIDEO_STANDARD = PLDR.VIDEO_STANDARD_NTSC
  PLDR.DKWDRV_PATH = tostring(PLDR.DKWDRV_DEFAULT_PATH or "mc0:/PS1_DKWDRV/DKWDRV.ELF")
  PLDR.KEYBOARD_LAYOUT = PLDR.KEYBOARD_LAYOUT_ABC
  PLDR.BOOT_PAGE = "Carousel"
  PLDR.COLLAPSE_MULTIDISC = false
  if type(UI) == "table" then
    if type(UI.SetHideTextMode) == "function" then
      UI.SetHideTextMode(false, false)
    else
      UI.HideTextMode = false
    end
  end
  if PLDR.PROFILES ~= nil and PLDR.PROFILES[defaults_profile] ~= nil then
    PLDR.POPSTARTER_PATH = PLDR.PROFILES[defaults_profile].ELF
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
  if sidecar ~= nil and sidecar ~= "" and doesFileExist(sidecar) then
    loaded_path = sidecar
  elseif fallback ~= nil and fallback ~= "" and doesFileExist(fallback) then
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
  if migrate_to_sidecar then
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
  local profile = tonumber(string.match(data, "\nPROFILE=([^\n]+)")) or tonumber(string.match(data, "^PROFILE=([^\n]+)"))
  local popstarter_path = string.match(data, "\nPOPSTARTER_PATH=([^\n]*)") or string.match(data, "^POPSTARTER_PATH=([^\n]*)")
  local popstarter_mode = string.match(data, "\nPOPSTARTER_MODE=([^\n]+)") or string.match(data, "^POPSTARTER_MODE=([^\n]+)")
  local bdma_mode = string.match(data, "\nBDMA=([^\n]+)") or string.match(data, "^BDMA=([^\n]+)") or string.match(data, "\nBDMA_MODE=([^\n]+)") or string.match(data, "^BDMA_MODE=([^\n]+)")
  local dkwdrv_path = string.match(data, "\nDKWDRV_PATH=([^\n]*)") or string.match(data, "^DKWDRV_PATH=([^\n]*)")
  local strict_hdd_preexec_gate = string.match(data, "\nSTRICT_HDD_PREEXEC_GATE=([^\n]+)") or string.match(data, "^STRICT_HDD_PREEXEC_GATE=([^\n]+)")
  local video_standard = string.match(data, "\nVIDEO_STANDARD=([^\n]+)") or string.match(data, "^VIDEO_STANDARD=([^\n]+)")
  local hide_text = string.match(data, "\nHIDE_TEXT=([^\n]+)") or string.match(data, "^HIDE_TEXT=([^\n]+)")
  local keyboard_layout = string.match(data, "\nKEYBOARD_LAYOUT=([^\n]+)") or string.match(data, "^KEYBOARD_LAYOUT=([^\n]+)")
  local boot_page = string.match(data, "\nBOOT_PAGE=([^\n]+)") or string.match(data, "^BOOT_PAGE=([^\n]+)")
  local multidisc_collapse = string.match(data, "\nMULTIDISC_COLLAPSE=([^\n]+)") or string.match(data, "^MULTIDISC_COLLAPSE=([^\n]+)")
  if profile ~= nil and PLDR.PROFILES ~= nil and PLDR.PROFILES[profile] ~= nil then
    PLDR.SELECTED_PROFILE = profile
    PLDR.POPSTARTER_PATH = PLDR.PROFILES[profile].ELF
  end
  local persisted_candidate = ""
  if popstarter_path ~= nil and popstarter_path ~= "" then
    persisted_candidate = popstarter_path
  end
  PLDR.POPSTARTER_SELECTION_MODE = NormalizePopstarterSelectionMode(popstarter_mode)
  local selection = ResolveProfilePopstarterSelection(
    PLDR.SELECTED_PROFILE,
    GetProfilePopstarterPath(PLDR.SELECTED_PROFILE),
    persisted_candidate,
    PLDR.POPSTARTER_SELECTION_MODE
  )
  PLDR.POPSTARTER_PATH = selection.effective_path
  PLDR.POPSTARTER_SELECTION_MODE = selection.mode
  PLDR.SETTINGS_POPSTARTER_SELECTION_RULE = selection.rule
  PLDR.SETTINGS_POPSTARTER_SELECTED_BACKEND = selection.selected_backend
  PLDR.SETTINGS_POPSTARTER_PERSISTED_BACKEND = selection.persisted_backend
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
  if boot_page ~= nil and boot_page ~= "" then
    PLDR.BOOT_PAGE = NormalizeBootPage(boot_page)
  else
    PLDR.BOOT_PAGE = NormalizeBootPage(PLDR.BOOT_PAGE)
  end
  local mdc = ParseBooleanSetting(multidisc_collapse)
  if mdc ~= nil then
    PLDR.COLLAPSE_MULTIDISC = mdc == true
  end
  PLDR.BDMA_MODE_KEY = NormalizeBdmaModeKey(bdma_mode) or PLDR.BDMA_MODE_KEY
  PLDR.ReconcileBdmaModeWithEffectiveState()
  PLDR.ApplyVideoStandardRuntime(PLDR.VIDEO_STANDARD)
  if type(UI) == "table" then
    local hide_text_enabled = ParseBooleanSetting(hide_text)
    if type(UI.SetHideTextMode) == "function" then
      UI.SetHideTextMode(hide_text_enabled == true, false)
    else
      UI.HideTextMode = (hide_text_enabled == true)
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
  local next_profile = tonumber(opts.profile) or prev.profile
  local next_popstarter_mode = NormalizePopstarterSelectionMode(opts.popstarter_mode or prev.popstarter_mode)
  local next_collapse = (prev.multidisc_collapse == true)
  if type(opts.multidisc_collapse) == "boolean" then next_collapse = opts.multidisc_collapse end
  -- Explicit boolean check, NOT `(type==boolean) and opts.x or prev.x`: that
  -- idiom collapses a legitimate `false` to prev (Lua and/or short-circuit), so
  -- Hide-Text could never be toggled OFF through a settings save. Mirrors the
  -- next_collapse pattern directly above.
  local next_hide_text = (prev.hide_text == true)
  if type(opts.hide_text) == "boolean" then next_hide_text = opts.hide_text end
  local next_state = {
    profile = next_profile,
    popstarter_path = NormalizeSelectedProfilePopstarterPath(next_profile, opts.popstarter_path or prev.popstarter_path, next_popstarter_mode),
    popstarter_mode = next_popstarter_mode,
    bdma_mode = NormalizeBdmaModeKey(opts.bdma_mode) or prev.bdma_mode,
    dkwdrv_path = opts.dkwdrv_path or prev.dkwdrv_path,
    video_standard = NormalizeVideoStandard(opts.video_standard or prev.video_standard),
    hide_text = next_hide_text,
    keyboard_layout = NormalizeKeyboardLayout(opts.keyboard_layout or prev.keyboard_layout),
    boot_page = NormalizeBootPage(opts.boot_page or prev.boot_page),
    multidisc_collapse = next_collapse
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

  if (prev.multidisc_collapse == true) ~= (next_collapse == true)
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
        video_standard = next_state.video_standard
      })
      PLDR.ReconcileBdmaModeWithEffectiveState()
      return false, "bdma_apply_failed"
    end
  end

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
  targets.boot_name = boot_name

  if boot_name == "USB" then
    targets.usb = true
  elseif boot_name == "MMCE" then
    targets.mmce = true
  elseif boot_name == "MX4SIO" then
    targets.mx4sio = true
  elseif boot_name == "HDD" then
    targets.hdd = true
  end

  AddUniqueStartupPath(paths, seen_paths, BOOT_ARGV0_RAW)
  AddUniqueStartupPath(paths, seen_paths, BOOT_PATH_RAW)
  AddUniqueStartupPath(paths, seen_paths, APP_DIR_RAW)
  AddUniqueStartupPath(paths, seen_paths, APP_DIR_LOCAL)
  AddUniqueStartupPath(paths, seen_paths, PLDR.POPSTARTER_PATH)
  AddUniqueStartupPath(paths, seen_paths, PLDR.DKWDRV_PATH)
  if type(PLDR.PROFILES) == "table" then
    local selected = tonumber(PLDR.SELECTED_PROFILE)
    if selected ~= nil and PLDR.PROFILES[selected] ~= nil then
      AddUniqueStartupPath(paths, seen_paths, PLDR.PROFILES[selected].ELF)
    end
  end

  for i = 1, #paths do
    local raw = tostring(paths[i] or "")
    local normalized = string.lower(NormalizeFsPathRaw(paths[i]))
    if string.match(normalized, "^mx4sio%d*:/") ~= nil then
      targets.mx4sio = true
    elseif string.match(normalized, "^mmce%d*:/") ~= nil then
      targets.mmce = true
    elseif string.match(normalized, "^pfs%d*:/") ~= nil or string.match(normalized, "^hdd%d:") ~= nil then
      targets.hdd = true
      AddUniqueStartupPath(targets.hdd_paths, seen_hdd_paths, paths[i])
    elseif targets.boot_name == "HDD" and (IsDefaultRelativePopstarterPath(raw) or IsLegacyDefaultPopstarterPath(raw)) then
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

  if targets.mx4sio and type(PLDR.InitMX4SIOPopsRoot) == "function" then
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

local function EnsureMassBackendsReady(mode)
  if mode == "mx4sio" then
    if type(System) == "table" and type(System.initMX4SIO) == "function" then
      pcall(System.initMX4SIO)
    end
    return
  end

  if type(PLDR) == "table" and type(PLDR.EnsureUsbMassReadyOnce) == "function" then
    pcall(PLDR.EnsureUsbMassReadyOnce)
    return
  end

end

local function WaitMassProbeRetry(attempt, max_attempts)
  if attempt >= max_attempts then
    return
  end
  if type(PLDR.RefreshMassBackends) == "function" then
    pcall(PLDR.RefreshMassBackends)
  end
end

local function BuildMassRootIdentity(mode)
  EnsureMassBackendsReady(mode)

  local identity = {
    usb = {},
    mx4sio = {},
    present_roots = {}
  }
  local seen_present = {}
  local seen_usb = {}
  local seen_mx4 = {}

  for slot = 0, 9 do
    local root = (slot == 0) and "mass:/" or ("mass"..tostring(slot)..":/")
    local normalized = NormalizeMassRoot(root)
    if normalized ~= nil and doesFolderExist(normalized) then
      if seen_present[normalized] ~= true then
        seen_present[normalized] = true
        table.insert(identity.present_roots, normalized)
      end

      -- Only classify mounted roots. Probing absent slots can be slow and can
      -- produce unstable driver readings on some hardware.
      local driver = PLDR.GetMassMountDriver(normalized)
      local kind = ClassifyMassRootDriver(driver)
      if kind == "mx4sio" then
        if seen_mx4[normalized] ~= true then
          seen_mx4[normalized] = true
          table.insert(identity.mx4sio, normalized)
        end
      else
        if seen_usb[normalized] ~= true then
          seen_usb[normalized] = true
          table.insert(identity.usb, normalized)
        end
      end
    end
  end

  return identity
end

local function BuildUsbIdentityDeferred()
  -- Bounded retry masks the first-entry USB probe quirk without requiring
  -- the user to leave and re-enter the page.
  local attempts = 0
  local identity = nil
  while attempts < 3 do
    attempts = attempts + 1
    identity = BuildMassRootIdentity("usb")
    if type(identity) == "table" and type(identity.usb) == "table" and #identity.usb > 0 then
      return identity
    end
    WaitMassProbeRetry(attempts, 3)
    if attempts < 3 and type(System) == "table" and type(System.sleep) == "function" then
      pcall(System.sleep, 1)
    end
  end
  return identity or BuildMassRootIdentity("usb")
end

local function BuildMX4IdentityDeferred()
  -- Bounded retry masks first-entry quirk without exposing a second manual attempt.
  local attempts = 0
  while attempts < 3 do
    attempts = attempts + 1
    local identity = BuildMassRootIdentity("mx4sio")
    if type(identity) == "table" and type(identity.mx4sio) == "table" and #identity.mx4sio > 0 then
      return identity
    end
    WaitMassProbeRetry(attempts, 3)
  end
  return BuildMassRootIdentity("mx4sio")
end

function PLDR.GetMX4SIOMassRootNow()
  local identity = BuildMX4IdentityDeferred()
  if type(identity) == "table" and type(identity.mx4sio) == "table" then
    return identity.mx4sio[1] or nil
  end
  return nil
end

function PLDR.GetRootsByType(kind, _mass_snapshot)
  local wanted = string.lower(tostring(kind or ""))
  if wanted == "mx4sio" then
    local identity = BuildMX4IdentityDeferred()
    return identity.mx4sio
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
    if type(_G.ensureMx4sioInit) == "function" then
      local ok = pcall(_G.ensureMx4sioInit)
      if ok then return true end
    end
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
      if type(_G.ensureMx4sioInit) == "function" then
        local ok = pcall(_G.ensureMx4sioInit)
        if ok then return true end
      end
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

local function WriteBdmaModeMarker(mode_key)
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

function PLDR.ApplyBdmaModeOnce(mode_key, token)
  if PLDR._bdma_apply_guard.in_progress then
    return false, "busy"
  end
  if token ~= nil and PLDR._bdma_apply_guard.last_token == token then
    return true
  end

  PLDR._bdma_apply_guard.in_progress = true
  local ok, res, err = xpcall(function()
    local aok, aerr = PLDR.ApplyBdmaMode(mode_key)
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

function PLDR.ApplyBdmaMode(mode_key)
  local selected = mode_key or "FAT32"
  if not PLDR.EnsurePopstarterDir() then
    if UI ~= nil and UI.Notif_queue ~= nil then
      UI.Notif_queue.add("Cannot access mc0:/POPSTARTER")
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
      UI.Notif_queue.add("Unknown BDMA mode: "..tostring(selected))
    end
    return false
  end

  if not PLDR.EnsureBackendForAppDir() then
    if UI ~= nil and UI.Notif_queue ~= nil then
      UI.Notif_queue.add("BDMA source backend not ready:\n"..APP_DIR_NORM)
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
          UI.Notif_queue.add("Missing BDMA source (tried):\n"..table.concat(paths, "\n"))
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

function PLDR.EnsurePopstarterUiAssets()
  if not PLDR.EnsurePopstarterDir() then
    if UI ~= nil and UI.Notif_queue ~= nil then
      UI.Notif_queue.add("Cannot access mc0:/POPSTARTER")
    end
    return false
  end

  if not PLDR.EnsureBackendForAppDir() then
    if UI ~= nil and UI.Notif_queue ~= nil then
      UI.Notif_queue.add("BDMA source backend not ready:\n"..APP_DIR_NORM)
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
            UI.Notif_queue.add("Missing BDMA UI source (tried):\n"..table.concat(paths, "\n"))
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

-- Multi-disc collapse: a VCD is a SECONDARY disc if its name carries a
-- (Disc N)/(Disk N)/(CD N) marker with N>=2. Used to hide disc 2+ from the game
-- list when PLDR.COLLAPSE_MULTIDISC is on (disc 1 / unmarked games always show).
-- The user's VMC disk-swap handles changing discs in-game from the disc-1 entry.
local function IsSecondaryDisc(name)
  if type(name) ~= "string" then return false end
  local lower = string.lower(name)
  local n = string.match(lower, "%(disc%s*(%d+)%)")
        or string.match(lower, "%(disk%s*(%d+)%)")
        or string.match(lower, "%(cd%s*(%d+)%)")
  return n ~= nil and (tonumber(n) or 0) >= 2
end

function PLDR.GetPS1GameLists(path, updating, on_progress)
  local RET = {}
  local found_smth = false
  if path ~= nil then PLDR.GAMEPATH = path end
  local DIR = System.listDirectory(PLDR.GAMEPATH)
  if DIR ~= nil then
    for i = 1, #DIR do
      if not DIR[i].directory then -- not a folder
        if string.lower(string.sub(DIR[i].name,-4)) == ".vcd"
           and not (PLDR.COLLAPSE_MULTIDISC and IsSecondaryDisc(DIR[i].name)) then
          found_smth = true
          if updating then
            table.insert(PLDR.GAMES, DIR[i].name)
          else
            table.insert(RET, DIR[i].name)
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
  if type(PLDR.EnsureUsbMassReadyOnce) == "function" then
    pcall(PLDR.EnsureUsbMassReadyOnce)
  end

  for attempt = 1, 3 do
    if type(System) == "table" and type(System.ensureUsbMass) == "function" then
      pcall(System.ensureUsbMass)
    end
    if type(_G.ensureMx4sioInit) == "function" then
      pcall(_G.ensureMx4sioInit)
    end
    if type(System) == "table" and type(System.initMX4SIO) == "function" then
      pcall(System.initMX4SIO)
    end
    if type(PLDR.RefreshMassBackends) == "function" then
      pcall(PLDR.RefreshMassBackends)
    end

    local root = PLDR.GetMX4SIOMassRootNow()
    if root ~= nil then
      PLDR.SetMX4SIORoot(root)
      return root.."POPS/"
    end
    if attempt < 3 and type(System) == "table" and type(System.sleep) == "function" then
      pcall(System.sleep, 1)
    end
  end

  return nil
end

function PLDR.BuildMassGameListByType(kind, mass_snapshot, on_progress)
  PLDR.CleanupGameList()
  local roots = PLDR.GetRootsByType(kind, mass_snapshot)
  local found_any = false
  local total_roots = #roots
  for i = 1, total_roots do
    local pops_root = roots[i].."POPS/"
    if doesFolderExist(pops_root) then
      local DIR = System.listDirectory(pops_root)
      if DIR ~= nil then
        local dir_total = #DIR
        for j = 1, dir_total do
          local entry = DIR[j]
          if not entry.directory and string.lower(string.sub(entry.name, -4)) == ".vcd"
             and not (PLDR.COLLAPSE_MULTIDISC and IsSecondaryDisc(entry.name)) then
            found_any = true
            table.insert(PLDR.GAMES, pops_root.."|"..entry.name)
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
    if type(on_progress) == "function" then
      pcall(on_progress, (tonumber(partition_index) or 1) / math.max(tonumber(partition_total) or 1, 1))
    end
    return
  end
  local total_entries = #DIR
  for i = 1, #DIR do
    if not DIR[i].directory then
      if string.lower(string.sub(DIR[i].name, -4)) == ".vcd"
         and not (PLDR.COLLAPSE_MULTIDISC and IsSecondaryDisc(DIR[i].name)) then
        local encoded = EncodeHddGameEntry(partition, DIR[i].name)
        if encoded ~= nil then
          table.insert(PLDR.GAMES, encoded)
          PLDR.HDD.GAMEPARTS[encoded] = "hdd0:"..partition
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

function PLDR.HDD.CheckAvailableHddPopsParts(on_progress)
  if not PLDR.HDD.HAS_CHECKED then --HDD is checked only once since it cannot be removed/replaced without damaging the console
    PLDR.HDD.FOUNDANY = false
    PLDR.HDD.AVAILABLE = {}
    PLDR.HDD.GAME_SLOT = nil
    local ordered_partitions = GetOrderedHddPopsPartitions()
    local total_partitions = #ordered_partitions
    for i = 1, total_partitions do
      local partition = ordered_partitions[i]
      local mounted, _, slot = MountHddGamePartitionTracked("hdd0:"..partition, FIO_MT_RDONLY)
      PLDR.HDD.AVAILABLE[partition] = mounted == true
      if mounted == true then
        PLDR.HDD.FOUNDANY = true
        if slot ~= nil then
          UMountHddPartitionTracked(slot)
        end
      end
      if type(on_progress) == "function" then
        pcall(on_progress, i / math.max(total_partitions, 1))
      end
    end
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
  PLDR.HDD.GAMEPARTS = {}
  PLDR.HDD.FROM_CACHE = false
  PLDR.GAMEPATH = BuildMountedPfsPrefix(GetActiveHddGameSlot())
  if not PLDR.HDD.FOUNDANY then return end
  local ordered_partitions = GetOrderedHddPopsPartitions()
  local total_partitions = #ordered_partitions
  for i = 1, total_partitions do
    local partition = ordered_partitions[i]
    if PLDR.HDD.AVAILABLE[partition] == true then
      local mounted, prefix, slot = MountHddGamePartitionTracked("hdd0:"..partition, FIO_MT_RDONLY)
      if mounted and prefix ~= nil then
        PLDR.GAMEPATH = prefix
        AppendHddGameList(partition, prefix, on_progress, i, total_partitions)
        if slot ~= nil then
          UMountHddPartitionTracked(slot)
        end
      end
    elseif type(on_progress) == "function" then
      pcall(on_progress, i / math.max(total_partitions, 1))
    end
  end
  if type(on_progress) == "function" then
    pcall(on_progress, 1.0)
  end
  table.sort(PLDR.GAMES)
end

function PLDR.LoadHDDModules()
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
  end
end

function PLDR.CleanupGameList()
  local count = #PLDR.GAMES
  for i=0, count do PLDR.GAMES[i]=nil end
end

function PLDR.HDD.CreateCache(reuse_current_list)
  if not PLDR.HDD.USECACHE then return end
  local C = ResolveWritablePath("hdd_gamecache.lua")
  local temp = "PLDR.HDDCACHE = {\n"
  local cache_source = PLDR.GAMES
  if reuse_current_list ~= true then
    PLDR.HDD.BuildGameList()
    cache_source = PLDR.GAMES
  end
  if type(cache_source) ~= "table" then
    cache_source = {}
  end
  for i = 1, #cache_source do
    temp = temp..("  %q,\n"):format(cache_source[i])
  end
  temp = temp.."\n}\n"
  -- Guard the cache write: on an MC/USB boot the cache lands on mc0:/usb, which
  -- can be full or read-only. An unguarded openFile/writeFile would throw out of
  -- EnsureGameList and resurface as "Failed to load HDD" even after a clean scan.
  pcall(function()
    local fd = System.openFile(C, FCREATE)
    System.writeFile(fd, temp, temp:len())
    System.closeFile(fd)
  end)
  PLDR.HDD.HAS_CHECKED = true
end

function PLDR.HDD.ReadCache()
  local C = ResolveWritablePath("hdd_gamecache.lua")
  if doesFileExist(C) then
    local loader, load_err = loadfile(C)
    if loader == nil then
      System.removeFile(C)
      PLDR.HDD.HAS_CHECKED = false
      return
    end
    local ok, run_err = pcall(loader)
    if not ok then
      System.removeFile(C)
      PLDR.HDD.HAS_CHECKED = false
      return
    end
    PLDR.HDD.HAS_CHECKED = true
  end
end

function PLDR.HDD.WipeCache(CACHE)
  -- Invalidate BOTH cache tiers. Clearing only the on-disk file left the
  -- in-session memo (PLDR.HDDCACHE + PLDR.HDD.LIST_BUILT) intact, so a
  -- multi-disc-collapse toggle had no visible effect until a reboot or a
  -- manual R1 rescan -- EnsureGameList(force=false) returned the stale memo.
  PLDR.HDDCACHE = nil
  PLDR.HDD.LIST_BUILT = false
  local C = ResolveWritablePath("hdd_gamecache.lua")
  if doesFileExist(C) then
    System.removeFile(C)
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
  table.sort(PLDR.GAMES)
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

  if PLDR.HDD.USECACHE and not force then
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
      UI.Notif_queue.add("Failed to load HDD", "error")
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
  if PLDR.HDD.USECACHE and type(PLDR.HDD.CreateCache) == "function" then
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

local function BuildDisplayNameFromEntry(entry)
  if entry == nil or entry == "" then
    return ""
  end
  local display_name = entry
  local hdd_relpath = string.match(display_name, "^[^|]+|(.+)$")
  if hdd_relpath ~= nil then
    display_name = string.match(hdd_relpath, "([^/]+)$") or hdd_relpath
  end
  return string.gsub(display_name, "%.[Vv][Cc][Dd]$", "")
end

local function SelectPopstarterSelectorPrefix(device_page)
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
  watchdog_ms = 3000,
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
    "Diag prf="..v(diag.selected_profile_id).." route="..v(diag.route).." src="..v(diag.source_pfs_slot),
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
    "LAUNCH RETURNED\nrc=%s\nDev:%s Prf:%s Rt:%s\nGate:%s Open:%s/%s\nPOP:%s\nCfg:%s (%s)\nEff:%s (%s)\nExec:%s\nAPP:%s\nBoot:%s [%s]\nPath:Hdd=%s Reboot=%s Cold=%s API:%s\nCtx:%s\nArg0:%s\nGame:%s%s\nPress X/O to continue.",
    tostring(rc),
    tostring(device_page),
    tostring(context and context.launch_diagnostics and context.launch_diagnostics.selected_profile_id or nil),
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
  if (Timer.getTime(LaunchState.fade_timer) - LaunchState.fade_start) >= LaunchState.watchdog_ms then
    BlockLaunchFailure(
      "Launch timeout: exec did not transfer control",
      popstarter,
      context and context.device_page or "unknown",
      argv0,
      argv0,
      app_dir,
      nil,
      nil,
      nil,
      context and context.launch_route,
      context and context.hdd_preexec_gate_mode,
      context
    )
    RestoreWorkingDirectory(previous_cwd)
    return
  end
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
  local elapsed_ms = Timer.getTime(LaunchState.fade_timer) - LaunchState.fade_start
  if elapsed_ms >= LaunchState.watchdog_ms then
    rc = string.format("%s (returned after %d ms)", tostring(rc), elapsed_ms)
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
  local selected_profile_id = tonumber(PLDR.SELECTED_PROFILE) or tonumber(PLDR.DEFAULT_PROFILE) or 1
  local persisted_popstarter_path = PLDR and PLDR.POPSTARTER_PATH or nil
  local persisted_popstarter_path_reason = persisted_popstarter_path == nil and "cfg_nil" or nil
  local configured_popstarter = NormalizeSelectedProfilePopstarterPath(selected_profile_id, persisted_popstarter_path)
  local configured_popstarter_reason = configured_popstarter == "" and "eff_nil" or nil
  local launch_diagnostics = {
    selected_profile_id = selected_profile_id,
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
  local popstarter = ResolvePopstarterPath(configured_popstarter)
  launch_diagnostics.effective_path = popstarter
  local popstarter_partition_context = ResolvePopstarterPartitionContext(configured_popstarter, popstarter, hdd_partition_label)
  local configured_partition_context = nil
  if IsHddExecContextPath(configured_popstarter) then
    configured_partition_context = select(1, BuildHddPartitionContext(configured_popstarter))
  end
  if configured_partition_context ~= nil and configured_partition_context ~= "" then
    popstarter_partition_context = configured_partition_context
  end
  local popstarter_on_hdd = IsHddExecContextPath(popstarter)
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
  elseif string.match(normalized_gamelocation, "^smb:/") or device_page == "SMB/MMCE" then
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
  lines[#lines+1] = "args.page: "..tostring(PLDR.LAUNCH_ARGS.page or "<nil>")
  lines[#lines+1] = "args.game: "..tostring(PLDR.LAUNCH_ARGS.game or "<nil>")
  UI.Notif_queue.add(table.concat(lines, "\n"), "info")
end

PLDR.LoadSettingsNonFatal()
PLDR.AutoInitStartupBackends()
-- Auto-launch BEFORE surfacing the debug toast: Notif_queue keeps only the
-- 2 newest toasts, so queueing the debug toast last guarantees it survives
-- an auto-launch failure toast instead of being evicted by it. (On
-- auto-launch success control never returns, so the order is moot.)
PLDR.AutoLaunchFromLaunchArgs()
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
  local boot_to_opt = { MMCE = 1, MX4SIO = 2, HDD = 4, USB = 5 }
  local opt = boot_to_opt[tostring(PLDR.BOOT_PAGE or "Carousel")]
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

---MAIN PROGRAM BEHAVIOUR BEGINS
local initial_scene = UI.SCENES.MMAIN
local show_boot_credits = true
UI.WelcomeDraw.Play(initial_scene, show_boot_credits)
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
