DEBUG_BUILD = DEBUG_BUILD or false

function LOG(...)
  print_uart(...)
end
function LOGF(S, ...)
  print_uart(string.format(S, ...))
end

local function joinPath(root, rel)
  local base = tostring(root or "")
  local extra = tostring(rel or "")

  if extra ~= "" and string.find(extra, ":") then
    return extra:gsub("//+", "/"):gsub(":(/+)", ":/")
  end

  if base == "" then
    return extra:gsub("//+", "/")
  end

  base = base:gsub("//+", "/"):gsub(":(/+)", ":/")
  if extra == "" then
    return base
  end

  base = base:gsub("/+$", "")
  extra = extra:gsub("^/+", "")
  return (base.."/"..extra):gsub("//+", "/"):gsub(":(/+)", ":/")
end

JoinPath = joinPath

local DEVICE_READY_TIMEOUT_MS = 2000
local DEVICE_READY_SLEEP_MS = 100
local OPEN_RETRY_COUNT = 3
local OPEN_RETRY_SLEEP_MS = 100

local function emit_fatal(message)
  LOG(message)
  System.dprintf(message)
  print(message)
  if Screen and Screen.clear then
    Screen.clear()
  end
  pcall(function()
    Font.ftInit()
    Font.fmLoad()
    Font.fmPrint(20, 20, 0.6, message)
  end)
  if Screen and Screen.flip then
    Screen.flip()
  end
  while true do
    System.sleep(1)
  end
end

local function wait_for_ready(path, timeout_ms)
  local elapsed = 0
  local last_ret = nil
  while elapsed <= timeout_ms do
    local stat_ret = System.fileXioGetStat(path)
    if stat_ret == 0 then
      return true, 0
    end
    local dopen_ret = System.fileXioDopen(path)
    if dopen_ret >= 0 then
      System.fileXioDclose(dopen_ret)
      return true, 0
    end
    last_ret = (dopen_ret < 0) and dopen_ret or stat_ret
    System.sleepMs(DEVICE_READY_SLEEP_MS)
    elapsed = elapsed + DEVICE_READY_SLEEP_MS
  end
  return false, last_ret
end

local function open_with_retry(path, flags)
  local last_ret = nil
  for attempt = 1, OPEN_RETRY_COUNT do
    local fd = System.fileXioOpen(path, flags)
    LOGF("fileXioOpen attempt %d ret: %d", attempt, fd)
    if fd >= 0 then
      return fd, 0
    end
    last_ret = fd
    System.sleepMs(OPEN_RETRY_SLEEP_MS)
  end
  return -1, last_ret
end

local boot_path = tostring(System.GetArgv0() or System.currentDirectory() or "")
local current_bootpath = boot_path
local deps_base_dir = System.deriveBaseDir(current_bootpath)

local ready_ok, ready_ret = wait_for_ready(deps_base_dir, DEVICE_READY_TIMEOUT_MS)
if not ready_ok then
  emit_fatal("FATAL: base_dir not ready\n\n\tboot_path: "..current_bootpath.."\n\tdeps_base_dir: "..deps_base_dir.."\n\tlast_ret: "..tostring(ready_ret))
end

local base_stat_ret, _ = System.fileXioGetStat(deps_base_dir)
LOGF("base_dir stat ret: %d", base_stat_ret)

BOOT_PATH = deps_base_dir

local function find_pops_device()
  local roots = {}
  local mmce_devices = {"mmce1:/", "mmce0:/"}
  local mass_devices = {"mass:/", "mass0:/", "mass1:/", "mass2:/", "mass3:/"}
  local mass_retry_devices = {"mass:/", "mass0:/"}

  for _ = 1, 2 do
    for _, dev in ipairs(mmce_devices) do
      table.insert(roots, dev)
    end
  end
  for _, dev in ipairs(mass_devices) do
    table.insert(roots, dev)
  end
  for _, dev in ipairs(mass_retry_devices) do
    table.insert(roots, dev)
  end
  for _, root in ipairs(roots) do
    local path = root.."POPS/"
    local ready_ok, _ = wait_for_ready(path, DEVICE_READY_TIMEOUT_MS)
    if ready_ok then
      local dopen_ret = System.fileXioDopen(path)
      if dopen_ret >= 0 then
        System.fileXioDclose(dopen_ret)
        return root
      end
    end
  end
  return nil
end

BOOT_DEVICE_ROOT = find_pops_device()

package.path = string.format("%s?.lua", BOOT_PATH)

POPSLDR_VER = "v1.0.0 - rev3"

--- Processes a HDD full path into its components. (eg: `hdd0:__system:pfs:/osd110/hosdsys.elf`)
---@param PATH string
---@return string mountpart: will return partition path for mounting (`hdd0:__system`)
---@return string pfsindx: will return pfs index (`pfs:`)
---@return string filepath: will return path to file when partition gets mounted (`pfs:/osd110/hosdsys.elf`)
function GetMountData(PATH)
  local CNT = 0
  local TBL = {}
  for i in string.gmatch(PATH, "[^:]*") do
    table.insert(TBL, i)
    CNT = CNT+1
  end
  local mountpart = ""
  local pfsindx   = ""
  local filepath  = ""
  if CNT == 4 then
    mountpart = string.format("%s:%s", TBL[1], TBL[2])
    pfsindx   = string.format("%s:", TBL[3])
    filepath  = string.format("%s:%s", TBL[3], TBL[4])
  end
  return mountpart, pfsindx, filepath
end


local ARGV0 = System.GetArgv0()
if string.find(ARGV0, "^hdd0:") then
  LOG("Booting from HDD!", ARGV0)
  local MNTPART
  BOOTPATH = nil
  MNTPART, _, BOOTPATH = GetMountData(ARGV0)
  if string.find(BOOTPATH, "^pfs") then
    SUCCESS, MODULE, ID, RET = HDD.Initialize()
    if not SUCCESS then
      LOG("ERROR", MODULE..".IRX", ID, RET)
    else
      System.sleep(2) -- lets give it time to get ready
      if HDD.MountPartition(MNTPART, 0) then -- mount to "pfs3:" and NEVER USE IT FOR ANYTHING ELSE
        BOOTPATH, _, _ = string.match(BOOTPATH, "(.-)([^/]-([^%.]+))$")
        System.currentDirectory(BOOTPATH)
        LOGF("new bootpath: '%s'\n", BOOTPATH)
      end
    end
  end
end
GPAD = 0
Font.ftInit()
local function loadBuiltinFont()
  local font = Font.LoadBuiltinFont()
  if font == nil and doesFileExist(BOOT_PATH.."builtin_font.ttf") then
    font = Font.ftLoad(BOOT_PATH.."builtin_font.ttf")
  end
  return font
end

BFONT = loadBuiltinFont()
SFONT = loadBuiltinFont()
LFONT = loadBuiltinFont()
if BFONT == nil or SFONT == nil or LFONT == nil then
  error("Failed to load builtin font (missing embedded font and builtin_font.ttf)")
end
Font.ftSetCharSize(BFONT, 800, 800)
Font.ftSetCharSize(SFONT, 600, 600)
function STOP() LOG("PROGRAM STOP") Screen.clear(Color.new(255,0,0)) Screen.flip() while true do end end
function RunScript(S)
  dofile(S)
end

RUNTIME_ROOT = BOOT_PATH
POPSTARTER_PATH = BOOT_PATH.."POPSTARTER.ELF"

local system_path = System.resolveLocal(deps_base_dir, "system.lua")
local system_stat_ret, system_stat_size = System.fileXioGetStat(system_path)
LOGF("system.lua stat ret: %d size: %d", system_stat_ret, system_stat_size)
if system_stat_ret ~= 0 then
  emit_fatal("Cant access system.lua\n\n\tboot_path: "..current_bootpath.."\n\tdeps_base_dir: "..deps_base_dir.."\n\tsystem_path: "..system_path.."\n\tstat_ret: "..tostring(system_stat_ret))
end
local function read_filexio_exact(fd, total_size)
  if total_size <= 0 then
    return nil, 0
  end
  local chunks = {}
  local read_total = 0
  local zero_reads = 0
  while read_total < total_size do
    local remaining = total_size - read_total
    local chunk_size = remaining
    if chunk_size > 16384 then
      chunk_size = 16384
    end
    local data, ret = System.fileXioRead(fd, chunk_size)
    if data == nil then
      return nil, ret
    end
    if ret == 0 then
      zero_reads = zero_reads + 1
      if zero_reads >= 5 then
        return nil, ret
      end
      System.sleepMs(OPEN_RETRY_SLEEP_MS)
      data = nil
    else
      zero_reads = 0
    end
    if data ~= nil then
      table.insert(chunks, data)
      read_total = read_total + ret
    end
  end
  return table.concat(chunks), read_total
end

local function has_invalid_control_chars(text)
  for i = 1, #text do
    local b = string.byte(text, i)
    if b < 32 and b ~= 9 and b ~= 10 and b ~= 13 then
      return true, b
    end
  end
  return false, nil
end

local function has_non_ascii(text)
  for i = 1, #text do
    local b = string.byte(text, i)
    if b >= 128 then
      return true, b
    end
  end
  return false, nil
end

local function checksum_bytes(text)
  local sum = 0
  for i = 1, #text do
    sum = (sum + string.byte(text, i)) % 4294967296
  end
  return sum
end

local function load_system_lua()
  local loader = loadstring or load
  if loader == nil then
    emit_fatal("Cant load system.lua\n\n\tboot_path: "..current_bootpath.."\n\tdeps_base_dir: "..deps_base_dir.."\n\tsystem_path: "..system_path.."\n\terr: loader unavailable")
  end

  local last_read_ret = nil
  local last_parse_err = nil
  for attempt = 1, OPEN_RETRY_COUNT do
    local system_fd, system_open_ret = open_with_retry(system_path, FREAD)
    if system_fd < 0 then
      emit_fatal("Cant open system.lua\n\n\tboot_path: "..current_bootpath.."\n\tdeps_base_dir: "..deps_base_dir.."\n\tsystem_path: "..system_path.."\n\topen_ret: "..tostring(system_open_ret))
    end

    local system_size = System.fileXioLseek(system_fd, 0, END)
    if system_size <= 0 then
      LOG("WARNING: system.lua size invalid, retrying. size:"..tostring(system_size))
      System.fileXioClose(system_fd)
      System.sleepMs(OPEN_RETRY_SLEEP_MS)
    else
      System.fileXioLseek(system_fd, 0, SET)
      local system_data, system_read_ret = read_filexio_exact(system_fd, system_size)
      last_read_ret = system_read_ret
      LOGF("system.lua read ret: %d", system_read_ret)
      local system_close_ret = System.fileXioClose(system_fd)
      LOGF("system.lua close ret: %d", system_close_ret)
      if system_close_ret ~= 0 then
        LOG("WARNING: Failed to close system.lua, ret: "..tostring(system_close_ret))
      end
      if system_data == nil then
        LOG("WARNING: system.lua read failed, retrying. ret:"..tostring(system_read_ret))
        System.sleepMs(OPEN_RETRY_SLEEP_MS)
      else
        local invalid_char, invalid_code = has_invalid_control_chars(system_data)
        if invalid_char then
          last_parse_err = "invalid control char: "..tostring(invalid_code)
          LOG("WARNING: system.lua invalid control char, retrying. code:"..tostring(invalid_code))
          System.sleepMs(OPEN_RETRY_SLEEP_MS)
        else
          local non_ascii, non_ascii_code = has_non_ascii(system_data)
          if non_ascii then
            last_parse_err = "non-ascii byte: "..tostring(non_ascii_code)
            LOG("WARNING: system.lua non-ascii byte, retrying. code:"..tostring(non_ascii_code))
            System.sleepMs(OPEN_RETRY_SLEEP_MS)
          else
            local checksum_first = checksum_bytes(system_data)
            local verify_fd, verify_open_ret = open_with_retry(system_path, FREAD)
            if verify_fd < 0 then
              emit_fatal("Cant re-open system.lua\n\n\tboot_path: "..current_bootpath.."\n\tdeps_base_dir: "..deps_base_dir.."\n\tsystem_path: "..system_path.."\n\topen_ret: "..tostring(verify_open_ret))
            end
            local verify_size = System.fileXioLseek(verify_fd, 0, END)
            System.fileXioLseek(verify_fd, 0, SET)
            local verify_data, verify_read_ret = read_filexio_exact(verify_fd, verify_size)
            System.fileXioClose(verify_fd)
            if verify_data == nil or verify_read_ret ~= system_read_ret then
              last_parse_err = "re-read mismatch"
              LOG("WARNING: system.lua re-read mismatch, retrying. ret:"..tostring(verify_read_ret))
              System.sleepMs(OPEN_RETRY_SLEEP_MS)
            else
              local checksum_second = checksum_bytes(verify_data)
              if checksum_first ~= checksum_second then
                last_parse_err = "checksum mismatch"
                LOG("WARNING: system.lua checksum mismatch, retrying.")
                System.sleepMs(OPEN_RETRY_SLEEP_MS)
              else
                local system_chunk, system_err = loader(verify_data, "@"..system_path)
                if system_chunk == nil then
                  last_parse_err = system_err
                  LOG("WARNING: system.lua parse failed, retrying. err:"..tostring(system_err))
                  System.sleepMs(OPEN_RETRY_SLEEP_MS)
                else
                  return system_chunk
                end
              end
            end
          end
        end
      end
    end
  end

  emit_fatal("Cant load system.lua\n\n\tboot_path: "..current_bootpath.."\n\tdeps_base_dir: "..deps_base_dir.."\n\tsystem_path: "..system_path.."\n\tread_ret: "..tostring(last_read_ret).."\n\terr: "..tostring(last_parse_err))
end

local system_chunk = load_system_lua()
system_chunk()
