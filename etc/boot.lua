local function ensure_dir(path)
  if path == nil or path == "" then return "./" end
  if string.sub(path, -1) ~= "/" then
    return path.."/"
  end
  return path
end

local function path_prefix(path)
  if path == nil then
    return nil
  end
  return string.match(path, "^([%a]+%d*):")
end

local function normalize_root_path(path)
  if path == nil or path == "" then
    return nil
  end

  local normalized = string.gsub(path, "\\", "/")
  if string.find(normalized, "^host:") then
    if string.sub(normalized, 6, 6) ~= "/" and string.sub(normalized, 6, 6) ~= "" then
      normalized = "host:/"..string.sub(normalized, 6)
    end
    normalized = string.gsub(normalized, "^(host:/[A-Za-z]:)([^/])", "%1/%2")
  else
    local first_colon = string.find(normalized, ":", 1, true)
    local second_colon = first_colon and string.find(normalized, ":", first_colon + 1, true) or nil
    if first_colon ~= nil and second_colon == nil then
      local after_colon = string.sub(normalized, first_colon + 1, first_colon + 1)
      if after_colon ~= "/" and after_colon ~= "" then
        normalized = string.sub(normalized, 1, first_colon).."/"..string.sub(normalized, first_colon + 1)
      end
    end
  end

  return ensure_dir(normalized)
end

local function derive_app_root()
  local current_dir = normalize_root_path(System.currentDirectory())
  local app_dir = normalize_root_path(APP_DIR)

  if current_dir ~= nil and app_dir ~= nil then
    local current_prefix = path_prefix(current_dir)
    local app_prefix = path_prefix(app_dir)

    -- Keep launch-device stability when mass aliases can drift between mass:/ and massN:/.
    if current_prefix ~= nil and app_prefix ~= nil and current_prefix ~= app_prefix then
      return app_dir
    end
  end

  if current_dir ~= nil then
    return current_dir
  end
  if app_dir ~= nil then
    return app_dir
  end
  return "./"
end

APP_ROOT = derive_app_root()
local ARGV0_RAW = System.GetArgv0()
package.path = APP_ROOT.."?.lua;"..APP_ROOT.."?/init.lua;"..APP_ROOT.."POPSLDR/?.lua;./?.lua;./POPSLDR/?.lua;mass:/POPSLDR/?.lua;mc0:/POPSLDR/?.lua;mc1:/POPSLDR/?.lua"


local function is_valid_fd(fd)
  return type(fd) == "number" and fd >= 0
end

local function file_exists(path)
  if path == nil or path == "" then
    return false
  end
  local ok, fd = pcall(System.openFile, path, FREAD)
  if not ok or not is_valid_fd(fd) then
    return false
  end
  pcall(System.closeFile, fd)
  return true
end

local function add_unique(list, seen, value)
  if value == nil or value == "" then
    return
  end
  if seen[value] then
    return
  end
  seen[value] = true
  list[#list + 1] = value
end

local function extract_dir(path)
  if path == nil or path == "" then
    return nil
  end
  local dir = string.match(path, "^(.*[/\\])")
  if dir ~= nil and dir ~= "" then
    return normalize_root_path(dir)
  end
  local device = string.match(path, "^([%a]+%d*:)")
  if device ~= nil then
    return ensure_dir(device)
  end
  return normalize_root_path(path)
end

local function normalize_colon_variants(path)
  local variants = {}
  local seen = {}
  local normalized = normalize_root_path(path)
  add_unique(variants, seen, normalized)
  if normalized == nil then
    return variants
  end

  local first_colon = string.find(normalized, ":", 1, true)
  if first_colon ~= nil then
    local after_colon = string.sub(normalized, first_colon + 1, first_colon + 1)
    if after_colon == "/" then
      add_unique(variants, seen, ensure_dir(string.sub(normalized, 1, first_colon)..string.sub(normalized, first_colon + 2)))
    else
      add_unique(variants, seen, ensure_dir(string.sub(normalized, 1, first_colon).."/"..string.sub(normalized, first_colon + 1)))
    end
  end

  return variants
end

local function add_mass_alias_variants(out, seen, root)
  local normalized = normalize_root_path(root)
  if normalized == nil then
    return
  end

  local prefix, suffix = string.match(normalized, "^([%a]+%d*):(.*)$")
  if prefix == nil then
    add_unique(out, seen, normalized)
    return
  end

  if prefix == "mass" or string.find(prefix, "^mass%d+$") then
    for i = 0, 3 do
      for _, candidate in ipairs(normalize_colon_variants("mass"..i..":"..suffix)) do
        add_unique(out, seen, candidate)
      end
    end
    for _, candidate in ipairs(normalize_colon_variants("mass:"..suffix)) do
      add_unique(out, seen, candidate)
    end
    return
  end

  for _, candidate in ipairs(normalize_colon_variants(normalized)) do
    add_unique(out, seen, candidate)
  end
end

local function boot_roots()
  local roots = {}
  local seen = {}
  add_mass_alias_variants(roots, seen, APP_ROOT)
  add_mass_alias_variants(roots, seen, System.currentDirectory())
  add_mass_alias_variants(roots, seen, APP_DIR)
  add_mass_alias_variants(roots, seen, extract_dir(ARGV0_RAW))
  return roots
end

local function resolve_boot_script(rel)
  local resolved = System.resolveAsset(rel)
  if file_exists(resolved) then
    return resolved
  end

  local roots = boot_roots()
  for _, root in ipairs(roots) do
    local modern = root..rel
    if file_exists(modern) then
      return modern
    end

    local legacy = root.."POPSLDR/"..rel
    if file_exists(legacy) then
      return legacy
    end
  end

  return nil
end
function LOG(...)
  print_uart(...)
end
function LOGF(S, ...)
  print_uart(string.format(S, ...))
end

BOOT_PROF = {
  timer = Timer.new(),
  stamp = function (label)
    local now = Timer.getTime(BOOT_PROF.timer)
    LOGF("BOOT: %s %d", label, now)
  end
}
BOOT_PROF.stamp("Lua init start")

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


local ARGV0 = ARGV0_RAW
if ARGV0 ~= nil and string.find(ARGV0, "^hdd0:") then
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
      if HDD.MountPartition(MNTPART, 1) then -- mount to "pfs1:" and NEVER USE IT FOR ANYTHING ELSE
        BOOTPATH, _, _ = string.match(BOOTPATH, "(.-)([^/]-([^%.]+))$")
        System.currentDirectory(BOOTPATH)
        LOGF("new bootpath: '%s'\n", BOOTPATH)
      end
    end
  end
end
GPAD = 0
Font.ftInit()
BFONT = Font.LoadBuiltinFont()
SFONT = Font.LoadBuiltinFont()
LFONT = Font.LoadBuiltinFont()
Font.ftSetCharSize(BFONT, 800, 800)
Font.ftSetCharSize(SFONT, 600, 600)
BOOT_PROF.stamp("UI assets init (fonts)")
function STOP() LOG("PROGRAM STOP") Screen.clear(Color.new(255,0,0)) Screen.flip() while true do end end

local function ReadWholeFile(path)
  local ok_open, fd = pcall(System.openFile, path, FREAD)
  if not ok_open or not is_valid_fd(fd) then
    return nil, "open failed"
  end
  local chunks = {}
  while true do
    local ok_read, buffer = pcall(System.readFile, fd, 4096)
    if not ok_read then
      pcall(System.closeFile, fd)
      return nil, "read failed"
    end
    if buffer == nil or buffer == "" then
      break
    end
    chunks[#chunks + 1] = buffer
  end
  local ok_close = pcall(System.closeFile, fd)
  if not ok_close then
    return nil, "close failed"
  end
  return table.concat(chunks)
end

local function LoadLuaFile(path)
  local loader, load_err = loadfile(path)
  if loader ~= nil then
    return loader
  end
  LOG("Lua load failed:", load_err)
  local data, read_err = ReadWholeFile(path)
  if data == nil then
    return nil, read_err
  end
  if string.byte(data, 1) == 0xEF and string.byte(data, 2) == 0xBB and string.byte(data, 3) == 0xBF then
    data = string.sub(data, 4)
  end
  return loadstring(data, "@"..path)
end

function RunScript(S)
  local loader, load_err = LoadLuaFile(S)
  if loader == nil then
    error(load_err)
  end
  local ok, run_err = pcall(loader)
  if not ok then
    error(run_err)
  end
end

local function build_boot_candidates(rel)
  local out = {}
  local seen = {}
  add_unique(out, seen, System.resolveAsset(rel))
  local roots = boot_roots()
  for _, root in ipairs(roots) do
    add_unique(out, seen, root..rel)
    add_unique(out, seen, root.."POPSLDR/"..rel)
  end
  return out
end

local function RunScriptWithFallback(rel)
  local candidates = build_boot_candidates(rel)
  local last_err = nil
  for _, candidate in ipairs(candidates) do
    local loader, load_err = LoadLuaFile(candidate)
    if loader ~= nil then
      local ok, run_err = pcall(loader)
      if ok then
        return true, candidate
      end
      LOG("Boot script runtime failed:", tostring(candidate), tostring(run_err))
      return false, run_err, candidates
    end
    last_err = load_err
    LOG("Boot script probe failed:", tostring(candidate), tostring(load_err))
  end
  return false, last_err, candidates
end

local ok_boot, loaded_from_or_err, attempted = RunScriptWithFallback("system.lua")
if not ok_boot then
  error(
    "Cant access POPSLDR/system.lua"
    .."\n\n\tcurrent_bootpath: "..System.currentDirectory()
    .."\n\tapp_root: "..APP_ROOT
    .."\n\tapp_dir: "..tostring(APP_DIR)
    .."\n\targv0: "..tostring(ARGV0_RAW)
    .."\n\tattempted: "..table.concat(attempted or {}, ", ")
    .."\n\tlast_error: "..tostring(loaded_from_or_err)
  )
end
LOG("Boot script loaded from:", tostring(loaded_from_or_err))
