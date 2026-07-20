from pathlib import Path

root = Path(__file__).resolve().parent.parent
boot_path = root/'etc/boot.lua'
sys_path = root/'bin/POPSLDR/system.lua'

boot = boot_path.read_text()
start = boot.index('-- First-entry storage hardening.')
end = boot.index('if string.find(ARGV0, "^hdd0:") then', start)
boot = boot[:start] + boot[end:]

old_scan = '''  if type(System) == "table" and type(System.initMX4SIO) == "function" then
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
'''
new_scan = '''  if type(System) == "table" and type(System.initMX4SIO) == "function" then
    pcall(System.initMX4SIO)
  end
  -- mx4sio_bd publishes the BDM device asynchronously. Let the first registration
  -- pass complete before consulting the lock-free BDM table; later misses retain
  -- the existing bounded retry below.
  if type(System) == "table" and type(System.sleep) == "function" then
    pcall(System.sleep, 1)
  end
  local function scan_for_mx4sio_root()
    if type(System) == "table" and type(System.refreshMassBackends) == "function" then
      pcall(System.refreshMassBackends)
    end
    if type(System) ~= "table" or type(System.bdmList) ~= "function" then
      return nil, "no_bdm_list"
    end
    local ok, list = pcall(System.bdmList)
    if not ok or type(list) ~= "table" then
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
'''
assert old_scan in boot
boot = boot.replace(old_scan, new_scan, 1)
old_clear = '''  -- The boot-time scan does not consume the ten-probe page-sweep budget.
  -- Clear it so unrelated mass-root checks before page entry retain normal semantics.
  mx4_mass_root_probe_budget = 0
  mx4_mass_root_driver_slot = nil
  invalidate_bdm_snapshot()
'''
assert old_clear in boot
boot = boot.replace(old_clear, '', 1)
boot_path.write_text(boot)

s = sys_path.read_text()
old_mmce = '''function PLDR.EnsureMmceReadyOnce()
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
'''
new_mmce = '''local function IsAnyMmceRootReady()
  local candidates = {"mmce0:/", "mmce1:/"}
  for i = 1, #candidates do
    local root = candidates[i]
    local ok_root, has_root = pcall(doesFolderExist, root)
    if ok_root and has_root == true then
      return true
    end
    local ok_pops, has_pops = pcall(doesFolderExist, root.."POPS/")
    if ok_pops and has_pops == true then
      return true
    end
  end
  return false
end

function PLDR.EnsureMmceReadyOnce()
  if PLDR._mmce_ready then
    return true
  end

  -- Module load success is not filesystem readiness. On non-MMCE boots the IRX
  -- is loaded lazily, and real hardware can expose mmce0:/ or mmce1:/ shortly
  -- after SifExecModuleBuffer returns. Keep those states separate so a transient
  -- first miss is retryable instead of being permanently latched as ready.
  if type(System) == "table" and type(System.ensureMmceman) == "function" then
    local ok_load, loaded = pcall(System.ensureMmceman)
    if not ok_load or loaded ~= true then
      return false
    end
  end

  -- mmceman shares SIO2 with the controller. Re-open the pad once after the
  -- successful module load, before waiting for the card roots to appear.
  if not PLDR._mmce_pad_reinitialized then
    if type(System) == "table" and type(System.reinitPad) == "function" then
      pcall(System.reinitPad)
    end
    PLDR._mmce_pad_reinitialized = true
  end

  for attempt = 1, 5 do
    if IsAnyMmceRootReady() then
      PLDR._mmce_ready = true
      return true
    end
    if attempt < 5 and type(System) == "table" and type(System.sleep) == "function" then
      pcall(System.sleep, 1)
    end
  end

  -- No card yet (or a slow/failed mount): do not poison later page entry, launch
  -- preflight, hot-plug, or R1 refresh attempts with a false ready latch.
  return false
end
'''
assert old_mmce in s
s = s.replace(old_mmce, new_mmce, 1)

old_mx_ensure = '''  if mode == "mx4sio" then
    if type(System) == "table" and type(System.initMX4SIO) == "function" then
      pcall(System.initMX4SIO)
    end
    return
  end
'''
new_mx_ensure = '''  if mode == "mx4sio" then
    local initialized = false
    if type(System) == "table" and type(System.initMX4SIO) == "function" then
      local ok, ready = pcall(System.initMX4SIO)
      initialized = ok and ready == true
    end
    -- The block device registers asynchronously after the IRX load. Settle once
    -- before the first lock-free BDM-table read; later misses use the existing
    -- six-attempt retry loop and its one-second spacing.
    if initialized and not PLDR._mx4_initial_settle_done then
      if type(System) == "table" and type(System.sleep) == "function" then
        pcall(System.sleep, 1)
      end
      PLDR._mx4_initial_settle_done = true
    end
    return
  end
'''
assert old_mx_ensure in s
s = s.replace(old_mx_ensure, new_mx_ensure, 1)

anchor = '''local function ClassifyStartupMassTargets(targets)
'''
helper = '''local function BuildBdmMassIdentity()
  local identity = {
    usb = {},
    mx4sio = {},
    ata = {},
    present_roots = {}
  }
  if type(System) ~= "table" or type(System.bdmList) ~= "function" then
    return identity
  end

  local ok, list = pcall(System.bdmList)
  if not ok or type(list) ~= "table" then
    return identity
  end

  local seen_present = {}
  local seen_usb = {}
  local seen_mx4 = {}
  local seen_ata = {}
  for _, info in pairs(list) do
    if type(info) == "table" then
      local slot = tonumber(info.parId)
      if slot ~= nil and slot >= 0 and slot <= 9 then
        local root = (slot == 0) and "mass:/" or ("mass"..tostring(slot)..":/")
        root = NormalizeMassRoot(root)
        if root ~= nil then
          if seen_present[root] ~= true then
            seen_present[root] = true
            table.insert(identity.present_roots, root)
          end
          local kind = ClassifyMassRootDriver(info.name)
          if kind == "mx4sio" then
            if seen_mx4[root] ~= true then
              seen_mx4[root] = true
              table.insert(identity.mx4sio, root)
            end
          elseif kind == "ata" then
            if seen_ata[root] ~= true then
              seen_ata[root] = true
              table.insert(identity.ata, root)
            end
          else
            if seen_usb[root] ~= true then
              seen_usb[root] = true
              table.insert(identity.usb, root)
            end
          end
        end
      end
    end
  end
  return identity
end

'''
assert anchor in s
s = s.replace(anchor, helper + anchor, 1)

needle = '''  local try_txt = (attempt ~= nil) and (" (try "..tostring(attempt).." of 4)") or ""
'''
insert = '''  -- MX4SIO identity is available directly from bdm_query (driver name + parId).
  -- Do not open mass:/ through mass9:/ merely to discover which slot belongs to
  -- sdc/mx4: fileXioDopen can block forever while bdmfs_fatfs owns its mount lock,
  -- preventing the surrounding retry loop from ever reaching attempt two.
  if mode == "mx4sio" then
    return BuildBdmMassIdentity()
  end

'''
assert needle in s
s = s.replace(needle, insert + needle, 1)

old_detect = '''function PLDR.DetectMMCESlot(force_refresh)
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
'''
new_detect = '''function PLDR.DetectMMCESlot(force_refresh)
  if PLDR.MMCE.PROBED and not force_refresh then
    return PLDR.MMCE.PREFIX
  end

  PLDR.MMCE.PROBED = false
  PLDR.MMCE.SLOTS = {}
  PLDR.MMCE.INDEX = 1
  PLDR.MMCE.PREFIX = nil

  if type(PLDR.EnsureMmceReadyOnce) == "function" then
    local ok_ready, ready = pcall(PLDR.EnsureMmceReadyOnce)
    if not ok_ready or ready ~= true then
      return nil
    end
  end

  local candidates = {"mmce0:/", "mmce1:/"}
  for i = 1, #candidates do
    local candidate = candidates[i]
    if doesFolderExist(candidate) or doesFolderExist(candidate.."POPS/") then
      table.insert(PLDR.MMCE.SLOTS, candidate)
    end
  end
  if #PLDR.MMCE.SLOTS > 0 then
    PLDR.MMCE.PROBED = true
    PLDR.MMCE.PREFIX = PLDR.MMCE.SLOTS[PLDR.MMCE.INDEX]
    return PLDR.MMCE.PREFIX
  end

  -- A negative probe can be transient during lazy mount or hot-plug. Keep it
  -- retryable instead of caching an empty slot list for the rest of the session.
  return nil
end
'''
assert old_detect in s
s = s.replace(old_detect, new_detect, 1)

sys_path.write_text(s)

# Add regression tests for the two validated failure classes.
p=root/'tools/host_harness.py'
s=p.read_text()
anchor="""print()\nfails = [r for r in results if not r[1]]\n"""
insert=r"""# ---------------------------------------------------------------------------
# T21 MMCE readiness is truthful and retryable. A successful mmceman IRX load
# must not permanently latch ready when mmce0:/mmce1:/ have not appeared yet.
t21 = E('''function()
  local raw_exists = doesFolderExist
  local raw_ensure = System.ensureMmceman
  local raw_reinit = System.reinitPad
  local phase = 0
  local pad_reinits = 0
  doesFolderExist = function(path)
    if phase == 1 and path == "mmce0:/" then return true end
    return false
  end
  System.ensureMmceman = function() return true end
  System.reinitPad = function() pad_reinits = pad_reinits + 1; return true end
  PLDR._mmce_ready = nil
  PLDR._mmce_pad_reinitialized = nil
  PLDR.MMCE.PROBED = false
  PLDR.MMCE.SLOTS = {}
  PLDR.MMCE.PREFIX = nil

  local first = PLDR.DetectMMCESlot(true)
  local first_retryable = first == nil and PLDR._mmce_ready ~= true
                       and PLDR.MMCE.PROBED == false and PLDR.MMCE.PREFIX == nil

  phase = 1
  local second = PLDR.DetectMMCESlot(true)
  local second_ready = second == "mmce0:/" and PLDR._mmce_ready == true
                    and PLDR.MMCE.PROBED == true and PLDR.MMCE.PREFIX == "mmce0:/"
  local pad_once = pad_reinits == 1

  doesFolderExist = raw_exists
  System.ensureMmceman = raw_ensure
  System.reinitPad = raw_reinit
  return first_retryable and second_ready and pad_once
end''')()
check("T21 MMCE timeout stays retryable; later root appearance succeeds without double pad reinit", t21)

# T22 MX4SIO identity discovery must use bdmList and never open all ten mass
# filesystems merely to learn which parId belongs to the sdc/mx4 driver.
t22 = E('''function()
  local raw_list = System.bdmList
  local raw_init = System.initMX4SIO
  local raw_refresh = System.refreshMassBackends
  local raw_mount_driver = System.getMassMountDriver
  local raw_exists = doesFolderExist
  local fs_root_probes = 0
  local native_driver_probes = 0

  System.bdmList = function()
    return {
      { name = "usb", parId = 0 },
      { name = "sdc", parId = 3 }
    }
  end
  System.initMX4SIO = function() return true end
  System.refreshMassBackends = function() return true end
  System.getMassMountDriver = function(root)
    native_driver_probes = native_driver_probes + 1
    return nil
  end
  doesFolderExist = function(path)
    if string.match(tostring(path), "^mass%d*:/$") then
      fs_root_probes = fs_root_probes + 1
    end
    return false
  end
  PLDR._mx4_initial_settle_done = nil

  local root = PLDR.GetMX4SIOMassRootNow()

  System.bdmList = raw_list
  System.initMX4SIO = raw_init
  System.refreshMassBackends = raw_refresh
  System.getMassMountDriver = raw_mount_driver
  doesFolderExist = raw_exists
  return root == "mass3:/" and fs_root_probes == 0 and native_driver_probes == 0
end''')()
check("T22 MX4SIO root identity comes from lock-free BDM table (no mass0-9 filesystem sweep)", t22)

"""
assert anchor in s
p.write_text(s.replace(anchor, insert+anchor,1))
