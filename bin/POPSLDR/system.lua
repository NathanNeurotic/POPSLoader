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
    return false
  end
  if string.match(candidate, "^hdd%d:/+[^/]+/.+") ~= nil then
    return true
  end
  return string.match(candidate, "^hdd%d:[^:/]+/.+") ~= nil
end

local function IsEmbeddedHddMountPath(path)
  local candidate = NormalizeFsPathRaw(tostring(path or ""))
  candidate = string.lower(candidate)
  return string.match(candidate, "^hdd%d:[^:]+:[%a]+%d*:/") ~= nil
end

local function ResolveAppDirLocal()
  local current_dir = EnsureTrailingSlashNormRaw(System.currentDirectory() or "")
  local app_dir = APP_DIR or System.currentDirectory() or ""
  if IsPfsMountedPath(current_dir) and (IsRawHddPartitionPath(app_dir) or IsEmbeddedHddMountPath(app_dir)) then
    return current_dir
  end
  return EnsureTrailingSlashNormRaw(app_dir)
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

local APP_DIR_RAW = EnsureTrailingSlashNormRaw(APP_DIR or System.currentDirectory() or "")
local APP_DIR_LOCAL = ResolveAppDirLocal()
APP_DIR_NORM = APP_DIR_LOCAL
local SELECTOR_MODE = "basename"

local function GetPreferredPopstarterBaseDir()
  local boot_dir = EnsureTrailingSlashNormRaw(BOOT_PATH_RAW or System.currentDirectory() or "")
  if IsPfsMountedPath(boot_dir) then
    return boot_dir
  end

  local local_dir = EnsureTrailingSlashNormRaw(APP_DIR_LOCAL or "")
  if local_dir ~= "/" and local_dir ~= "" then
    return local_dir
  end

  local raw_dir = EnsureTrailingSlashNormRaw(APP_DIR_RAW or "")
  if raw_dir ~= "/" and raw_dir ~= "" then
    return raw_dir
  end

  return boot_dir
end

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
  if IsRawHddPartitionPath(path) then
    return true
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

local HDD_SLOT_BOOT = 0
local HDD_SLOT_GAME = 1
local HDD_SLOT_COMMON = 2
local HDD_SLOT_POPSTARTER = 3

local HDD_MOUNT_STATE = {
  slots = {},
  partitions = {}
}

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

local function GetRecordedHddMountPrefix(partition)
  local normalized_partition = ParseHddPartitionMount(partition)
  if normalized_partition == nil then
    return nil
  end
  return HDD_MOUNT_STATE.partitions[normalized_partition]
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
  if not EnsureHddRuntimeReadyForExec() then
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

local function EnsureHddExecPathReady(path)
  return ResolveHddReadablePath(path) ~= nil
end

local function ResolveHddExecMountedPath(path)
  return ResolveHddReadablePath(path)
end

local function ResolveDirectHddExecPath(path)
  local candidate = tostring(path or "")
  if candidate == "" or string.match(string.lower(candidate), "^hdd%d:") == nil then
    return nil
  end
  if not EnsureHddRuntimeReadyForExec() then
    return nil
  end
  if ProbePathExists(candidate) then
    return candidate
  end
  return nil
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
  else
    local extra_slot = tonumber(extra_keep_slots)
    if extra_slot ~= nil then
      keep[extra_slot] = true
    end
  end
  return keep
end

local IsHddExecContextPath

local function PreserveBootPfsSlotsDuringElfLoad(path, keep_slots)
  if ExtractLaunchPfsSlot(path) == nil and not IsHddExecContextPath(path) then
    return keep_slots
  end
  if string.match(string.lower(tostring(path or "")), "^hdd%d:") ~= nil then
    return keep_slots
  end
  local boot_candidates = {
    BOOT_ARGV0_RAW,
    BOOT_PATH_RAW,
    APP_DIR_LOCAL
  }
  for i = 1, #boot_candidates do
    local boot_slot = ExtractLaunchPfsSlot(boot_candidates[i])
    if boot_slot ~= nil then
      keep_slots[boot_slot] = true
    end
  end
  return keep_slots
end

local function PrepareForExternalELFLaunch(path, extra_keep_slots)
  if type(HDD) ~= "table" or type(HDD.UMountPartition) ~= "function" then
    return
  end
  local keep_slots = CollectHddKeepSlots(path, extra_keep_slots)
  keep_slots = PreserveBootPfsSlotsDuringElfLoad(path, keep_slots)
  for slot = 0, 3 do
    if keep_slots[slot] ~= true then
      UMountHddPartitionTracked(slot)
    end
  end
end

local function PrepareForExactHddPfsExecLaunch(keep_slots)
  if type(HDD) ~= "table" or type(HDD.UMountPartition) ~= "function" then
    return
  end
  local keep = {}
  if type(keep_slots) == "table" then
    for i = 1, #keep_slots do
      local slot = tonumber(keep_slots[i])
      if slot ~= nil then
        keep[slot] = true
      end
    end
  else
    local slot = tonumber(keep_slots)
    if slot ~= nil then
      keep[slot] = true
    end
  end
  for slot = 0, 3 do
    if keep[slot] ~= true then
      UMountHddPartitionTracked(slot)
    end
  end
end

local function PrepareForRawHddExecLaunch()
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

  if type(_G.ensureMmceInit) == "function" then
    pcall(_G.ensureMmceInit)
  end
  if type(System) == "table" and type(System.initMMCE) == "function" then
    pcall(System.initMMCE)
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

IsHddExecContextPath = function(path)
  local candidate = string.lower(tostring(path or ""))
  if candidate == "" then
    return false
  end
  if string.match(candidate, "^hdd%d:") ~= nil then
    return true
  end
  return string.match(candidate, "^pfs%d*:/") ~= nil
end

local function IsPfsExecPath(path)
  return string.match(string.lower(tostring(path or "")), "^pfs%d*:/") ~= nil
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

local function NormalizeHddExecRelpath(relpath)
  local cleaned = string.gsub(tostring(relpath or ""), "^[Pp][Ff][Ss]%d*:/", "")
  cleaned = string.gsub(cleaned, "^/+", "")
  return cleaned
end

local function NormalizeRelativeExecDir(relpath)
  local cleaned = NormalizeHddExecRelpath(relpath)
  cleaned = string.gsub(cleaned, "/+$", "")
  if cleaned == "" then
    return ""
  end
  return cleaned.."/"
end

local function RelativeDirFromExecRelpath(relpath)
  local cleaned = NormalizeHddExecRelpath(relpath)
  if cleaned == "" then
    return ""
  end
  local dirname = string.match(cleaned, "^(.*)/[^/]+$")
  if dirname == nil or dirname == "" then
    return ""
  end
  return NormalizeRelativeExecDir(dirname)
end

local function ParseMountedPfsRelpath(path)
  local candidate = NormalizeFsPathRaw(tostring(path or ""))
  local relpath = string.match(candidate, "^[Pp][Ff][Ss]%d*:/(.+)$")
  if relpath == nil or relpath == "" then
    return nil
  end
  return NormalizeHddExecRelpath(relpath)
end

local function BuildHddBootContext()
  local raw_app_dir = APP_DIR_RAW
  local raw_argv0 = BOOT_ARGV0_RAW
  local current_dir = EnsureTrailingSlashNormRaw(System.currentDirectory() or "")
  local mounted_boot_prefix = NormalizePfsPrefix(current_dir)
  local mounted_boot_slot = ParsePfsSlot(mounted_boot_prefix)
  local boot_partition = nil
  local boot_rel_dir = ""

  local function capture(path, treat_as_dir)
    if boot_partition ~= nil then
      return
    end
    local partition, relpath = ParseHddExecMountAndRelpath(path)
    if partition == nil or relpath == nil or relpath == "" then
      return
    end
    boot_partition = partition
    if treat_as_dir then
      boot_rel_dir = NormalizeRelativeExecDir(relpath)
    else
      boot_rel_dir = RelativeDirFromExecRelpath(relpath)
    end
  end

  capture(raw_argv0, false)
  capture(raw_app_dir, true)

  return {
    is_hdd_boot = boot_partition ~= nil,
    raw_app_dir = raw_app_dir,
    raw_argv0 = raw_argv0,
    boot_partition = boot_partition,
    boot_rel_dir = boot_rel_dir,
    mounted_boot_slot = mounted_boot_slot,
    mounted_boot_prefix = mounted_boot_prefix
  }
end

local function GetHddMountedPartitionForSlot(slot)
  local normalized_slot = tonumber(slot)
  if normalized_slot == nil then
    return nil
  end
  local entry = HDD_MOUNT_STATE.slots[normalized_slot]
  if entry ~= nil and entry.partition ~= nil then
    return entry.partition
  end
  local boot_context = type(PLDR) == "table" and type(PLDR.HDD) == "table" and PLDR.HDD.BOOT_CONTEXT or nil
  if boot_context ~= nil and boot_context.mounted_boot_slot == normalized_slot then
    return boot_context.boot_partition
  end
  return nil
end

local function GetHddPartitionAndRelpathFromExecPath(path)
  local partition, relpath = ParseHddExecMountAndRelpath(path)
  if partition ~= nil and relpath ~= nil and relpath ~= "" then
    return partition, NormalizeHddExecRelpath(relpath)
  end

  local slot = ExtractLaunchPfsSlot(path)
  local mounted_relpath = ParseMountedPfsRelpath(path)
  if slot == nil or mounted_relpath == nil or mounted_relpath == "" then
    return nil, nil
  end

  local mounted_partition = GetHddMountedPartitionForSlot(slot)
  if mounted_partition == nil then
    return nil, nil
  end
  return mounted_partition, mounted_relpath
end

local function BuildEmbeddedHddExecPath(partition, relpath)
  local normalized_partition = ParseHddPartitionMount(partition)
  local clean_relpath = NormalizeHddExecRelpath(relpath or "")
  if normalized_partition == nil or clean_relpath == "" then
    return nil
  end
  return normalized_partition..":pfs:/"..clean_relpath
end

local function ResolveEmbeddedHddExecPath(path)
  local partition, relpath = GetHddPartitionAndRelpathFromExecPath(path)
  if partition == nil or relpath == nil or relpath == "" then
    return nil
  end
  return BuildEmbeddedHddExecPath(partition, relpath)
end

local function ResolveHddBootSidecarPopstarter()
  local mounted_candidates = {}
  local hdd_candidates = {}
  local other_candidates = {}
  local seen = {}
  local function add_candidate(base_path)
    local basedir = DirectoryFromExecPath(base_path)
    if basedir == nil or basedir == "" then
      return
    end
    local sidecar = JoinPath(basedir, "POPSTARTER.ELF")
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

  add_candidate(BOOT_PATH_RAW)
  add_candidate(APP_DIR_LOCAL)
  add_candidate(BOOT_ARGV0_RAW)
  add_candidate(APP_DIR)

  for i = 1, #mounted_candidates do
    if ProbePathExists(mounted_candidates[i]) then
      return mounted_candidates[i]
    end
  end

  for i = 1, #hdd_candidates do
    local resolved_hdd = ResolveHddReadablePath(hdd_candidates[i])
    if resolved_hdd ~= nil then
      return resolved_hdd
    end
    local direct_hdd = ResolveDirectHddExecPath(hdd_candidates[i])
    if direct_hdd ~= nil then
      return direct_hdd
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

local function IsDefaultRelativePopstarterPath(path)
  local candidate = string.lower(string.gsub(tostring(path or ""), "\\", "/"))
  candidate = string.gsub(candidate, "^%./", "")
  return candidate == "" or candidate == "popstarter.elf"
end

local function IsLegacyDefaultPopstarterPath(path)
  local candidate = string.lower(NormalizeFsPathRaw(tostring(path or "")))
  return string.match(candidate, "^mass%d*:/pops/popstarter%.elf$") ~= nil
end

local function ResolvePopstarterPath(path)
  local raw_path = tostring(path or "")
  if IsDefaultRelativePopstarterPath(raw_path) or IsLegacyDefaultPopstarterPath(raw_path) then
    local sidecar = ResolveHddBootSidecarPopstarter()
    if sidecar ~= nil then
      return sidecar
    end
  end

  local preferred_base = GetPreferredPopstarterBaseDir()
  local chosen = path
  if chosen == nil or chosen == "" then
    chosen = JoinPath(preferred_base, "POPSTARTER.ELF")
  elseif not IsAbsoluteDevicePath(chosen) then
    chosen = JoinPath(preferred_base, chosen)
  end

  if string.match(string.lower(chosen), "^hdd%d:") ~= nil then
    local resolved_hdd = ResolveHddExecMountedPath(chosen)
    if resolved_hdd ~= nil then
      return resolved_hdd
    end
    local direct_hdd = ResolveDirectHddExecPath(chosen)
    if direct_hdd ~= nil then
      return direct_hdd
    end
  end
  local resolved = ResolvePathWithEnsure(chosen)
  if resolved ~= nil then
    return resolved
  end

  local fallbacks = {
    JoinPath(preferred_base, "POPSTARTER.ELF"),
    JoinPath(APP_DIR_LOCAL, "POPSTARTER.ELF"),
    JoinPath(APP_DIR_RAW, "POPSTARTER.ELF"),
    JoinPath(BOOT_PATH_RAW or System.currentDirectory() or "", "POPSTARTER.ELF"),
    "mc0:/POPSTARTER/POPSTARTER.ELF",
    "mc1:/POPSTARTER/POPSTARTER.ELF"
  }
  for i = 1, #fallbacks do
    local candidate = fallbacks[i]
    local resolved_fallback = nil
    if string.match(string.lower(candidate), "^hdd%d:") ~= nil then
      resolved_fallback = ResolveHddReadablePath(candidate)
      if resolved_fallback == nil then
        resolved_fallback = ResolveDirectHddExecPath(candidate)
      end
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

local function ResolveIrx(name)
  return System.resolveAssetType(name, ASSET_IRX) or JoinPath(APP_DIR_LOCAL, name)
end

function PLDR.ResolvePopstarterPath(path)
  return ResolvePopstarterPath(path)
end

function PLDR.ResolveHddReadablePath(path)
  return ResolveHddReadablePath(path)
end

function PLDR.ResolveHddPartitionReadablePath(partition, relpath, mounted_prefix_hint, slot)
  return ResolveHddPartitionReadablePath(partition, relpath, mounted_prefix_hint, slot)
end

function PLDR.PrepareForExternalELFLaunch(path, extra_keep_slots)
  return PrepareForExternalELFLaunch(path, extra_keep_slots)
end

local function DetectBootDevice()
  local boot_path = NormalizeDirPath(BOOT_PATH_RAW or "")
  local prefix = string.match(boot_path, "^([%a]+%d*):")
  if prefix == nil then
    return nil, boot_path, prefix
  end
  if string.match(prefix, "^mmce%d*$") then
    return "MMCE", boot_path, prefix
  end
  if string.match(prefix, "^mx4sio%d*$") then
    return "MX4SIO", boot_path, prefix
  end
  if string.match(prefix, "^mass%d*$") then
    local mx_marker = JoinPath(APP_DIR_LOCAL, ".boot_mx4sio")
    local usb_marker = JoinPath(APP_DIR_LOCAL, ".boot_usb")
    if doesFileExist(mx_marker) then
      return "MX4SIO", boot_path, prefix
    end
    if doesFileExist(usb_marker) then
      return "USB", boot_path, prefix
    end
  end
  return nil, boot_path, prefix
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
  POPSTARTER_PATH = "POPSTARTER.ELF";
  CHECK_POPSTARTER_FILES = false;
  GAMEPATH = ".";
  GAMES = {};
  HDDCACHE = nil;
  PROFILES = {};
  HDD = {
    USECACHE = false;
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
PLDR.HDD.BOOT_CONTEXT = BuildHddBootContext()
if type(PLDR.HDD.POPS_PARTITIONS) ~= "table" or #PLDR.HDD.POPS_PARTITIONS < 1 then
  PLDR.HDD.POPS_PARTITIONS = {}
  for i = 1, #DEFAULT_HDD_POPS_PARTITIONS do
    PLDR.HDD.POPS_PARTITIONS[i] = DEFAULT_HDD_POPS_PARTITIONS[i]
  end
end
PLDR.HDD.GAMEPARTS = PLDR.HDD.GAMEPARTS or {}

PLDR.VIDEO_STANDARD_NTSC = "NTSC"
PLDR.VIDEO_STANDARD_PAL = "PAL"

local function NormalizeVideoStandard(value)
  local key = string.upper(tostring(value or ""))
  if key == PLDR.VIDEO_STANDARD_PAL then
    return PLDR.VIDEO_STANDARD_PAL
  end
  return PLDR.VIDEO_STANDARD_NTSC
end

local function BuildVideoStandardSpec(standard)
  local key = NormalizeVideoStandard(standard)
  if key == PLDR.VIDEO_STANDARD_PAL then
    return {
      key = PLDR.VIDEO_STANDARD_PAL,
      mode = PAL,
      width = 640,
      height = 512,
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

function PLDR.GetVideoStandardSpec(standard)
  return BuildVideoStandardSpec(standard)
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
-- MMCE/HDD probing is page-driven; do not pre-seed runtime slot/status state at boot.
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
  UI.boot_locks = {}
  if boot_name == "MX4SIO" then
    UI.boot_device = UI.DEVLOCK.MX4SIO
    UI.boot_locks[UI.DEVLOCK.USB] = true
    UI.boot_locks[UI.DEVLOCK.MMCE] = true
  elseif boot_name == "USB" then
    UI.boot_device = UI.DEVLOCK.USB
    UI.boot_locks[UI.DEVLOCK.MX4SIO] = true
  elseif boot_name == "MMCE" then
    UI.boot_device = UI.DEVLOCK.MMCE
    UI.boot_locks[UI.DEVLOCK.MX4SIO] = true
  end
  if boot_name ~= nil then
  else
  end
end
require("images")

PLDR.POPSTARTER_DIR = "mc0:/POPSTARTER"
PLDR.SETTINGS_PATH = "mc0:/POPSTARTER/.pldrs"
PLDR.BDMA_MODE_KEY = "FAT32"
PLDR.SELECTED_PROFILE = tonumber(PLDR.DEFAULT_PROFILE) or 1
PLDR.DKWDRV_DEFAULT_PATH = "mc0:/PS1_DKWDRV/DKWDRV.ELF"
PLDR.DKWDRV_PATH = tostring(PLDR.DKWDRV_PATH or PLDR.DKWDRV_DEFAULT_PATH)

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
  if doesFileExist(dest) then
    pcall(System.removeFile, dest)
  end
  local ok = pcall(System.rename, tmp, dest)
  if not ok then
    pcall(System.removeFile, tmp)
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

  if doesFileExist(dest) then
    pcall(System.removeFile, dest)
  end
  local ok_rename = pcall(System.rename, tmp, dest)
  if not ok_rename then
    pcall(System.removeFile, tmp)
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

  if doesFileExist(dest) then
    pcall(System.removeFile, dest)
  end
  local ok_rename = pcall(System.rename, tmp, dest)
  if not ok_rename then
    pcall(System.removeFile, tmp)
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

function PLDR.EnsurePopstarterDir()
  if not EnsureDirectory(PLDR.POPSTARTER_DIR) then
    return false
  end
  for i = 1, #BDMA_UI_FILES do
    local asset = BDMA_UI_FILES[i]
    local dest = POPSTARTER_PACK_ROOT.."/"..asset.dst
    if not doesFileExist(dest) then
      local bytes = nil
      if type(System) == "table" and type(System.getEmbeddedAsset) == "function" then
        local ok_embedded, embedded = pcall(System.getEmbeddedAsset, asset.src)
        if ok_embedded and embedded ~= nil then
          bytes = embedded
        end
      end
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

local function EncodeSettings()
  local selected_profile = tonumber(PLDR.SELECTED_PROFILE) or 1
  local configured_popstarter = tostring(PLDR.POPSTARTER_PATH or "")
  local profile_popstarter = ""
  if PLDR.PROFILES ~= nil and PLDR.PROFILES[selected_profile] ~= nil then
    profile_popstarter = tostring(PLDR.PROFILES[selected_profile].ELF or "")
  end
  local persisted_popstarter = configured_popstarter
  if configured_popstarter ~= "" and NormalizeFsPathRaw(configured_popstarter) == NormalizeFsPathRaw(profile_popstarter) then
    persisted_popstarter = ""
  end
  local lines = {
    "PROFILE="..tostring(selected_profile),
    "POPSTARTER_PATH="..persisted_popstarter,
    "BDMA="..tostring(PLDR.BDMA_MODE_KEY or "FAT32"),
    "DKWDRV_PATH="..tostring(PLDR.DKWDRV_PATH or PLDR.DKWDRV_DEFAULT_PATH),
    "VIDEO_STANDARD="..tostring(NormalizeVideoStandard(PLDR.VIDEO_STANDARD))
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
  return {
    profile = tonumber(PLDR.SELECTED_PROFILE) or tonumber(PLDR.DEFAULT_PROFILE) or 1,
    popstarter_path = tostring(PLDR.POPSTARTER_PATH or ""),
    bdma_mode = NormalizeBdmaModeKey(PLDR.BDMA_MODE_KEY) or "FAT32",
    dkwdrv_path = tostring(PLDR.DKWDRV_PATH or PLDR.DKWDRV_DEFAULT_PATH),
    video_standard = NormalizeVideoStandard(PLDR.VIDEO_STANDARD)
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
  if state.popstarter_path ~= nil then
    PLDR.POPSTARTER_PATH = tostring(state.popstarter_path)
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
  PLDR.ApplyVideoStandardRuntime(PLDR.VIDEO_STANDARD)
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
  if not PLDR.EnsurePopstarterDir() then
    if UI ~= nil and UI.Notif_queue ~= nil then
      UI.Notif_queue.add("Cannot access mc0:/POPSTARTER")
    end
    return false
  end
  local data = EncodeSettings()
  local ok = WriteAtomic(PLDR.SETTINGS_PATH, data)
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
  PLDR.VIDEO_STANDARD = PLDR.VIDEO_STANDARD_NTSC
  PLDR.DKWDRV_PATH = tostring(PLDR.DKWDRV_DEFAULT_PATH or "mc0:/PS1_DKWDRV/DKWDRV.ELF")
  if PLDR.PROFILES ~= nil and PLDR.PROFILES[defaults_profile] ~= nil then
    PLDR.POPSTARTER_PATH = PLDR.PROFILES[defaults_profile].ELF
  end
  if not doesFileExist(PLDR.SETTINGS_PATH) then
    PLDR.ReconcileBdmaModeWithEffectiveState()
    PLDR.ApplyVideoStandardRuntime(PLDR.VIDEO_STANDARD)
    return false
  end
  local data = ReadWholeFile(PLDR.SETTINGS_PATH)
  if data == nil then
    PLDR.ReconcileBdmaModeWithEffectiveState()
    PLDR.ApplyVideoStandardRuntime(PLDR.VIDEO_STANDARD)
    return false
  end
  local profile = tonumber(string.match(data, "\nPROFILE=([^\n]+)")) or tonumber(string.match(data, "^PROFILE=([^\n]+)"))
  local popstarter_path = string.match(data, "\nPOPSTARTER_PATH=([^\n]*)") or string.match(data, "^POPSTARTER_PATH=([^\n]*)")
  local bdma_mode = string.match(data, "\nBDMA=([^\n]+)") or string.match(data, "^BDMA=([^\n]+)") or string.match(data, "\nBDMA_MODE=([^\n]+)") or string.match(data, "^BDMA_MODE=([^\n]+)")
  local dkwdrv_path = string.match(data, "\nDKWDRV_PATH=([^\n]*)") or string.match(data, "^DKWDRV_PATH=([^\n]*)")
  local video_standard = string.match(data, "\nVIDEO_STANDARD=([^\n]+)") or string.match(data, "^VIDEO_STANDARD=([^\n]+)")
  if profile ~= nil and PLDR.PROFILES ~= nil and PLDR.PROFILES[profile] ~= nil then
    PLDR.SELECTED_PROFILE = profile
    PLDR.POPSTARTER_PATH = PLDR.PROFILES[profile].ELF
  end
  if popstarter_path ~= nil and popstarter_path ~= "" then
    PLDR.POPSTARTER_PATH = popstarter_path
  end
  if dkwdrv_path ~= nil and dkwdrv_path ~= "" then
    PLDR.DKWDRV_PATH = dkwdrv_path
  end
  if video_standard ~= nil and video_standard ~= "" then
    PLDR.VIDEO_STANDARD = NormalizeVideoStandard(video_standard)
  else
    PLDR.VIDEO_STANDARD = NormalizeVideoStandard(PLDR.VIDEO_STANDARD)
  end
  PLDR.BDMA_MODE_KEY = NormalizeBdmaModeKey(bdma_mode) or PLDR.BDMA_MODE_KEY
  PLDR.ReconcileBdmaModeWithEffectiveState()
  PLDR.ApplyVideoStandardRuntime(PLDR.VIDEO_STANDARD)
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
  local next_state = {
    profile = tonumber(opts.profile) or prev.profile,
    popstarter_path = opts.popstarter_path or prev.popstarter_path,
    bdma_mode = NormalizeBdmaModeKey(opts.bdma_mode) or prev.bdma_mode,
    dkwdrv_path = opts.dkwdrv_path or prev.dkwdrv_path,
    video_standard = NormalizeVideoStandard(opts.video_standard or prev.video_standard)
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
  elseif type(System) == "table" and type(System.initUSBMass) == "function" then
    pcall(System.initUSBMass)
  end
  if type(System) == "table" and type(System.initUSB) == "function" then
    pcall(System.initUSB)
  end
  if type(PLDR.RefreshMassBackends) == "function" then
    pcall(PLDR.RefreshMassBackends)
  end

  PLDR._usb_mass_ready = true
  return true
end

local function EnsureMassBackendsReady(mode)
  if mode == "mx4sio" then
    if type(_G) == "table" and type(_G.ensureMx4sioInit) == "function" then
      pcall(_G.ensureMx4sioInit)
    end
    if type(System) == "table" and type(System.initMX4SIO) == "function" then
      pcall(System.initMX4SIO)
    end
    return
  end

  if type(PLDR) == "table" and type(PLDR.EnsureUsbMassReadyOnce) == "function" then
    pcall(PLDR.EnsureUsbMassReadyOnce)
    return
  end

  if type(System) == "table" and type(System.initUSBMass) == "function" then
    pcall(System.initUSBMass)
  end
  if type(System) == "table" and type(System.initUSB) == "function" then
    pcall(System.initUSB)
  end
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
    if normalized ~= nil then
      local driver = PLDR.GetMassMountDriver(normalized)
      local kind = ClassifyMassRootDriver(driver)
      local present = doesFolderExist(normalized)
      local detected = (kind ~= "unknown") or present
      if detected and seen_present[normalized] ~= true then
        seen_present[normalized] = true
        table.insert(identity.present_roots, normalized)
      end
      if kind == "mx4sio" then
        if seen_mx4[normalized] ~= true then
          seen_mx4[normalized] = true
          table.insert(identity.mx4sio, normalized)
        end
      elseif detected then
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
  local attempts = 0
  local identity = nil
  while attempts < 3 do
    attempts = attempts + 1
    identity = BuildMassRootIdentity("usb")
    if type(identity) == "table" and type(identity.usb) == "table" and #identity.usb > 0 then
      return identity
    end
    WaitMassProbeRetry(attempts, 3)
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
    local is_mx4_mass_path = type(driver) == "string" and driver ~= "" and string.find(driver, "sdc", 1, true) ~= nil

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

function PLDR.CheckPOPStarterDEPS(device)
  if not PLDR.CHECK_POPSTARTER_FILES then return true, true, true end
  if UI.IsUsbScene(device) then
    return doesFileExist("mass:/POPS/POPS_IOX.PAK")
  elseif device == UI.SCENES.GHDD then
    local a, prefix = MountHddPartitionTracked("hdd0:__common", HDD_SLOT_COMMON, FIO_MT_RDONLY)
    if a and prefix ~= nil then
      return a,
        doesFileExist(BuildMountedReadablePath(prefix, "POPS/POPS.ELF")),
        doesFileExist(BuildMountedReadablePath(prefix, "POPS/IOPRP252.IMG"))
    else
      return a, false, false
    end
  end
end

function PLDR.GetPS1GameLists(path, updating)
  local RET = {}
  local found_smth = false
  if path ~= nil then PLDR.GAMEPATH = path end
  local DIR = System.listDirectory(PLDR.GAMEPATH)
  if DIR ~= nil then
    for i = 1, #DIR do
      if not DIR[i].directory then -- not a folder
        if string.lower(string.sub(DIR[i].name,-4)) == ".vcd" then
          found_smth = true
          if updating then
            table.insert(PLDR.GAMES, DIR[i].name)
          else
            table.insert(RET, DIR[i].name)
          end
        end
      end
    end
  else
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

function PLDR.BuildMassGameListByType(kind, mass_snapshot)
  PLDR.CleanupGameList()
  local roots = PLDR.GetRootsByType(kind, mass_snapshot)
  local found_any = false
  for i = 1, #roots do
    local pops_root = roots[i].."POPS/"
    if doesFolderExist(pops_root) then
      local DIR = System.listDirectory(pops_root)
      if DIR ~= nil then
        for j = 1, #DIR do
          local entry = DIR[j]
          if not entry.directory and string.lower(string.sub(entry.name, -4)) == ".vcd" then
            found_any = true
            table.insert(PLDR.GAMES, pops_root.."|"..entry.name)
          end
        end
      end
    end
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

local function AppendHddGameList(partition, list_path)
  if list_path == nil then
    return
  end
  local DIR = System.listDirectory(list_path)
  if DIR == nil then
    return
  end
  for i = 1, #DIR do
    if not DIR[i].directory then
      if string.lower(string.sub(DIR[i].name, -4)) == ".vcd" then
        local encoded = EncodeHddGameEntry(partition, DIR[i].name)
        if encoded ~= nil then
          table.insert(PLDR.GAMES, encoded)
          PLDR.HDD.GAMEPARTS[encoded] = "hdd0:"..partition
        end
      end
    end
  end
end

function PLDR.HDD.CheckAvailableHddPopsParts()
  if not PLDR.HDD.HAS_CHECKED then --HDD is checked only once since it cannot be removed/replaced without damaging the console
    PLDR.HDD.FOUNDANY = false
    PLDR.HDD.AVAILABLE = {}
    PLDR.HDD.GAME_SLOT = nil
    for i = 1, #GetOrderedHddPopsPartitions() do
      local partition = GetOrderedHddPopsPartitions()[i]
      local mounted, _, slot = MountHddGamePartitionTracked("hdd0:"..partition, FIO_MT_RDONLY)
      PLDR.HDD.AVAILABLE[partition] = mounted == true
      if mounted == true then
        PLDR.HDD.FOUNDANY = true
        if slot ~= nil then
          UMountHddPartitionTracked(slot)
        end
      end
    end
    PLDR.HDD.HAS_CHECKED = true
  end
end

function PLDR.HDD.BuildGameList()
  PLDR.GAMES = {}
  if type(PLDR.HDDCACHE) == "table" and PLDR.HDD.USECACHE then PLDR.GAMES = PLDR.HDDCACHE end
  PLDR.HDD.GAMEPARTS = {}
  PLDR.GAMEPATH = BuildMountedPfsPrefix(GetActiveHddGameSlot())
  if not PLDR.HDD.FOUNDANY then return end
  for i = 1, #GetOrderedHddPopsPartitions() do
    local partition = GetOrderedHddPopsPartitions()[i]
    if PLDR.HDD.AVAILABLE[partition] == true then
      local mounted, prefix, slot = MountHddGamePartitionTracked("hdd0:"..partition, FIO_MT_RDONLY)
      if mounted and prefix ~= nil then
        PLDR.GAMEPATH = prefix
        AppendHddGameList(partition, prefix)
        if slot ~= nil then
          UMountHddPartitionTracked(slot)
        end
      end
    end
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
    SUCCESS = HDD.GetHDDStatus()
    PLDR.HDD.STATUS = SUCCESS
    if SUCCESS ~= 0 then
      PLDR.HDD.LOADSTATE = -1
      if SUCCESS == 1 then
        UI.Notif_queue.add(string.format("WARNING: HDD has no APA format", MODULE, ID, RET))
      elseif SUCCESS == 2 then
        UI.Notif_queue.add(string.format("ERROR: HDD is not accessible", MODULE, ID, RET))
      elseif SUCCESS == 3 then
        UI.Notif_queue.add(string.format("WARNING: No HDD detected", MODULE, ID, RET))
      elseif SUCCESS == -19 then
        UI.Notif_queue.add(string.format("ERROR: Hardware issue detected\nCheck your HDD, network adapter and connection", MODULE, ID, RET))
      end
    end
    PLDR.HDD.LOADSTATE = 1
    PLDR.HDD.CheckAvailableHddPopsParts()
    PLDR.HDD.CreateCache()
  end
end

function PLDR.CleanupGameList()
  local count = #PLDR.GAMES
  for i=0, count do PLDR.GAMES[i]=nil end
end

function PLDR.HDD.CreateCache()
  if not PLDR.HDD.USECACHE then return end
  local C = ResolveWritablePath("hdd_gamecache.lua")
  local temp = "PLDR.HDDCACHE = {\n"
  PLDR.HDD.BuildGameList()
  for i = 1, #PLDR.GAMES do
    temp = temp..("  %q,\n"):format(PLDR.GAMES[i])
  end
  temp = temp.."\n}\n"
  local fd = System.openFile(C, FCREATE)
  System.writeFile(fd, temp, temp:len())
  System.closeFile(fd)
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
  local C = ResolveWritablePath("hdd_gamecache.lua")
  if doesFileExist(C) then
    System.removeFile(C)
    PLDR.HDD.HAS_CHECKED = false
  end
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
  return NormalizeHddExecRelpath(relpath)
end

local function BuildIsraBootPathFromMountedVcd(path)
  local mounted_path = tostring(path or "")
  if mounted_path == "" then
    return ""
  end
  local relpath = string.gsub(mounted_path, "^[%a]+%d*:/", "")
  relpath = string.gsub(relpath, "%.[Vv][Cc][Dd]$", ".ELF")
  if not string.match(relpath, "%.[Ee][Ll][Ff]$") then
    relpath = relpath..".ELF"
  end
  relpath = string.gsub(relpath, "^/+", "")
  if relpath == "" then
    return ""
  end
  return "isra:/"..relpath
end

local function PreparePopstarterExec(path)
  local preferred_base = GetPreferredPopstarterBaseDir()
  local candidate = tostring(path or "")
  if candidate == "" then
    candidate = JoinPath(preferred_base, "POPSTARTER.ELF")
  elseif not IsAbsoluteDevicePath(candidate) then
    candidate = JoinPath(preferred_base, candidate)
  end

  local partition, relpath = GetHddPartitionAndRelpathFromExecPath(candidate)
  if partition == nil or relpath == nil or relpath == "" then
    local resolved = ResolvePathWithEnsure(candidate) or candidate
    return {
      exec_path = resolved,
      exec_dir = DirectoryFromExecPath(resolved),
      exec_slot = ExtractLaunchPfsSlot(resolved),
      reused_boot_mount = false,
      canonical_hdd = false
    }
  end

  local boot_context = PLDR.HDD and PLDR.HDD.BOOT_CONTEXT or {}
  local prefer_dedicated_mount = boot_context.is_hdd_boot == true
  if not prefer_dedicated_mount and boot_context.boot_partition == partition and boot_context.mounted_boot_prefix ~= nil then
    local boot_exec_path = BuildMountedReadablePath(boot_context.mounted_boot_prefix, relpath)
    if boot_exec_path ~= nil and ProbePathExists(boot_exec_path) then
      RememberRecordedHddMount(partition, boot_context.mounted_boot_prefix)
      return {
        exec_path = boot_exec_path,
        exec_dir = DirectoryFromExecPath(boot_exec_path),
        exec_slot = boot_context.mounted_boot_slot,
        reused_boot_mount = true,
        canonical_hdd = true
      }
    end
  end

  UMountHddPartitionTracked(HDD_SLOT_POPSTARTER)
  local mounted, mounted_prefix = MountHddPartitionTracked(partition, HDD_SLOT_POPSTARTER, FIO_MT_RDONLY)
  if mounted and mounted_prefix ~= nil then
    local mounted_exec_path = BuildMountedReadablePath(mounted_prefix, relpath)
    if mounted_exec_path ~= nil and ProbePathExists(mounted_exec_path) then
      return {
        exec_path = mounted_exec_path,
        exec_dir = DirectoryFromExecPath(mounted_exec_path),
        exec_slot = HDD_SLOT_POPSTARTER,
        reused_boot_mount = false,
        canonical_hdd = true
      }
    end
  end

  if boot_context.boot_partition == partition and boot_context.mounted_boot_prefix ~= nil then
    local boot_exec_path = BuildMountedReadablePath(boot_context.mounted_boot_prefix, relpath)
    if boot_exec_path ~= nil and ProbePathExists(boot_exec_path) then
      RememberRecordedHddMount(partition, boot_context.mounted_boot_prefix)
      return {
        exec_path = boot_exec_path,
        exec_dir = DirectoryFromExecPath(boot_exec_path),
        exec_slot = boot_context.mounted_boot_slot,
        reused_boot_mount = true,
        canonical_hdd = true
      }
    end
  end

  return {
    exec_path = nil,
    exec_dir = nil,
    exec_slot = HDD_SLOT_POPSTARTER,
    reused_boot_mount = false,
    canonical_hdd = true,
    requested_path = candidate,
    partition = partition,
    relpath = relpath
  }
end

local function BuildRawHddExecPath(partition, relpath)
  local normalized_partition = ParseHddPartitionMount(partition)
  local clean_relpath = NormalizeHddExecRelpath(relpath)
  if normalized_partition == nil or clean_relpath == "" then
    return nil
  end
  return normalized_partition.."/"..clean_relpath
end

local function PrepareRawHddPopstarterExec(path)
  local preferred_base = GetPreferredPopstarterBaseDir()
  local candidate = tostring(path or "")
  if candidate == "" then
    candidate = JoinPath(preferred_base, "POPSTARTER.ELF")
  elseif not IsAbsoluteDevicePath(candidate) then
    candidate = JoinPath(preferred_base, candidate)
  end

  local partition, relpath = GetHddPartitionAndRelpathFromExecPath(candidate)
  local raw_candidate = nil
  if partition ~= nil and relpath ~= nil and relpath ~= "" then
    raw_candidate = BuildRawHddExecPath(partition, relpath)
  elseif string.match(string.lower(candidate), "^hdd%d:") ~= nil then
    raw_candidate = candidate
  end

  if raw_candidate == nil then
    return {
      exec_path = nil,
      is_raw_hdd = false,
      requested_path = candidate
    }
  end

  local resolved = ResolveDirectHddExecPath(raw_candidate)
  if resolved == nil then
    return {
      exec_path = nil,
      is_raw_hdd = true,
      requested_path = raw_candidate
    }
  end

  return {
    exec_path = resolved,
    is_raw_hdd = true,
    requested_path = raw_candidate
  }
end

function PLDR.HDD.PreparePopstarterExec(path)
  return PreparePopstarterExec(path)
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

local function SelectHddLaunchGameSlot(popstarter)
  local reserved = {}
  local boot_slot = GetBootOccupiedPfsSlot()
  if boot_slot ~= nil then
    reserved[boot_slot] = true
  end
  local popstarter_slot = ExtractLaunchPfsSlot(popstarter)
  if popstarter_slot ~= nil then
    reserved[popstarter_slot] = true
  end
  local preferred_slots = {
    HDD_SLOT_BOOT,
    HDD_SLOT_GAME,
    HDD_SLOT_COMMON
  }
  for i = 1, #preferred_slots do
    local slot = preferred_slots[i]
    if reserved[slot] ~= true then
      return slot
    end
  end
  return HDD_SLOT_GAME
end

local function EnsureHDDReadyForLaunch(game, partition_override, slot_override)
  local result = {
    init_ok = false,
    status = nil,
    mount_partition = nil,
    mount_ok = nil,
    mount_prefix = nil,
    mount_slot = nil
  }
  PLDR.LoadHDDModules()
  result.status = PLDR.HDD.STATUS
  result.init_ok = PLDR.HDD.LOADSTATE == 1
  if not result.init_ok or result.status ~= 0 then
    return result
  end
  local partition = partition_override or PLDR.HDD.GAMEPARTS[game] or "hdd0:__.POPS"
  local mount_slot = tonumber(slot_override)
  if mount_slot == nil then
    mount_slot = HDD_SLOT_GAME
  end
  result.mount_partition = partition
  result.mount_slot = mount_slot
  UMountHddPartitionTracked(mount_slot)
  local mounted, prefix = MountHddPartitionTracked(partition, mount_slot, FIO_MT_RDONLY)
  result.mount_ok = mounted == true
  result.mount_prefix = prefix
  if result.mount_ok and type(PLDR) == "table" and type(PLDR.HDD) == "table" then
    PLDR.HDD.GAME_SLOT = mount_slot
  end
  return result
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

local function BlockLaunchFailure(rc, popstarter, device_page, argv0, game_path, app_dir, open_rc, open_api)
  SetLaunchPhase(LaunchState.PHASE_FAILED)
  UI.LAUNCHING = false
  local body = string.format(
    "LAUNCH RETURNED\nrc=%s\nDevice: %s\nPOPSTARTER: %s\nOpen/stat rc: %s\nOpen API: %s\nAPP_DIR: %s\nargv[0]: %s\nGame arg: %s\nPress X/O to continue.",
    tostring(rc),
    tostring(device_page),
    tostring(popstarter),
    tostring(open_rc),
    tostring(open_api),
    tostring(app_dir),
    tostring(argv0),
    tostring(game_path)
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
  local argv0 = argv and argv[1] or nil
  local unpack_fn = table.unpack or unpack
  local exec_popstarter = context and context.exec_popstarter or popstarter
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
      nil
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
      open_api
    )
    return
  end
  if open_path ~= nil and open_path ~= popstarter then
    popstarter = open_path
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
      nil
    )
    return
  end
  SetLaunchPhase(LaunchState.PHASE_EXEC)
  PrepareForExternalELFLaunch(popstarter, context and context.keep_hdd_slots or nil)
  local rc
  if exec_args ~= nil and #exec_args > 0 and unpack_fn ~= nil then
    rc = System.loadELF(exec_popstarter, reboot_iop, unpack_fn(exec_args))
  elseif exec_args ~= nil and #exec_args == 1 then
    rc = System.loadELF(exec_popstarter, reboot_iop, exec_args[1])
  else
    rc = System.loadELF(exec_popstarter, reboot_iop)
  end
  if (Timer.getTime(LaunchState.fade_timer) - LaunchState.fade_start) >= LaunchState.watchdog_ms then
    BlockLaunchFailure(
      "Launch timeout: exec did not transfer control",
      popstarter,
      context and context.device_page or "unknown",
      argv0,
      argv0,
      app_dir,
      nil,
      nil
    )
    return
  end
  BlockLaunchFailure(
    rc,
    popstarter,
    context and context.device_page or "unknown",
    argv0,
    argv0,
    app_dir,
    nil,
    nil
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

function PLDR.RunPOPStarterGame(gamelocation, game, ui_scene)
  local policy, device_page = ResolveLaunchPolicy(gamelocation, ui_scene)
  local selected_entry = tostring(game or "")
  local popstarter = ResolvePopstarterPath(PLDR.POPSTARTER_PATH)
  local boot_context = PLDR.HDD and PLDR.HDD.BOOT_CONTEXT or nil
  if selected_entry == "" then
    BlockLaunchFailure(
      "Invalid game selection",
      popstarter,
      device_page,
      gamelocation,
      nil,
      APP_DIR_LOCAL,
      nil,
      nil
    )
    return
  end
  local hdd_init = nil
  local hdd_partition_label = nil
  local hdd_relpath = nil
  local hdd_partition = nil
  local hdd_vcd_path = nil
  local hdd_launch_slot = nil
  local hdd_boot_sidecar_handoff = false
  if policy.name == "HDD" then
    hdd_partition_label, hdd_relpath = ParseHddGameEntry(selected_entry)
    hdd_relpath = NormalizeHddRelpath(hdd_relpath or selected_entry)
    hdd_boot_sidecar_handoff = boot_context ~= nil and boot_context.is_hdd_boot == true and GetHddPartitionAndRelpathFromExecPath(popstarter) ~= nil
    if hdd_boot_sidecar_handoff and hdd_partition_label ~= nil then
      hdd_partition = "hdd0:"..hdd_partition_label
    end
  end
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
  if policy.name == "HDD" and hdd_boot_sidecar_handoff then
    normalized_basename = ""
    bootparam = ""
    bootparam_basename_used = ""
    if hdd_partition == nil or hdd_relpath == "" then
      BlockLaunchFailure(
        "Invalid HDD game entry",
        popstarter,
        device_page,
        nil,
        selected_entry,
        APP_DIR_LOCAL,
        nil,
        nil
      )
      return
    end
    hdd_launch_slot = SelectHddLaunchGameSlot(popstarter)
    hdd_init = EnsureHDDReadyForLaunch(selected_entry, hdd_partition, hdd_launch_slot)
    if hdd_init == nil or hdd_init.mount_ok ~= true then
      BlockLaunchFailure(
        "HDD game mount failed",
        popstarter,
        device_page,
        nil,
        selected_entry,
        APP_DIR_LOCAL,
        nil,
        nil
      )
      return
    end
    local mount_prefix = hdd_init.mount_prefix or BuildMountedPfsPrefix(hdd_init.mount_slot or hdd_launch_slot or HDD_SLOT_GAME)
    if mount_prefix ~= nil then
      hdd_vcd_path = BuildMountedReadablePath(mount_prefix, hdd_relpath)
    end
    bootparam = BuildIsraBootPathFromMountedVcd(hdd_vcd_path)
    if bootparam == nil or bootparam == "" then
      BlockLaunchFailure(
        "Invalid HDD boot argument",
        popstarter,
        device_page,
        nil,
        selected_entry,
        APP_DIR_LOCAL,
        nil,
        nil
      )
      return
    end
    bootparam_exists = hdd_vcd_path ~= nil and doesFileExist(hdd_vcd_path)
    vcd_path = hdd_vcd_path
  elseif policy.name == "HDD" then
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
        nil
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
  if policy.name == "HDD" and hdd_boot_sidecar_handoff then
    normalized_basename = game_name
    bootparam_basename_used = game_name
  elseif policy.name == "HDD" then
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
      nil
    )
    return
  end
  local selector_prefix = SelectPopstarterSelectorPrefix(device_page)
  local argv0_selector = BuildPopstarterSelectorPath(device_page, game_name)
  if hdd_boot_sidecar_handoff then
    argv0_selector = bootparam
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
      nil
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
  local argv = {argv0_selector}
  local keep_hdd_slots = nil
  local exec_popstarter = popstarter
  if hdd_boot_sidecar_handoff then
    argv = {bootparam, "--nr"}
    keep_hdd_slots = {hdd_init and hdd_init.mount_slot or hdd_launch_slot or HDD_SLOT_GAME}
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
    game_name = game_name,
    bootparam_source = boot_source_mode,
    hdd_init = hdd_init,
    keep_hdd_slots = keep_hdd_slots,
    exec_popstarter = exec_popstarter
  }
  local reboot_iop = PLDR.REBOOT_IOP_WHILE_LOADING_POPSTARTER
  if policy.name == "HDD" or IsHddExecContextPath(popstarter) then
    reboot_iop = 0
    if string.match(string.lower(tostring(popstarter or "")), "^hdd%d:") ~= nil then
      local embedded_hdd_exec = ResolveEmbeddedHddExecPath(popstarter)
      if embedded_hdd_exec ~= nil then
        exec_popstarter = embedded_hdd_exec
        context.exec_popstarter = exec_popstarter
      end
    end
  end
  if UI ~= nil and UI.CoverCache ~= nil and UI.CoverCache.Clear ~= nil then
    UI.CoverCache:Clear()
  end
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

PLDR.LoadSettingsNonFatal()
PLDR.EnsureUsbMassReadyOnce()

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
