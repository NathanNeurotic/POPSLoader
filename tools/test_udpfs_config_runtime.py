"""Execute POPSLoader's real UDPFS IPv4 validator under the host Lua runtime.

Keeps config coverage independent of PS2 IOP hardware and the large menu harness.
Physical device status: Unknown (verify on hardware).
"""
from pathlib import Path
from lupa import lua54

source = (Path(__file__).resolve().parents[1] / "bin/POPSLDR/system.lua").read_text(encoding="utf-8")
start = source.index("local function ParseUdpfsIPv4(value)")
end = source.index("function PLDR.InitUDPFSPopsRoot(report)", start)
lua = lua54.LuaRuntime(unpack_returned_tuples=True)
lua.execute("PLDR = {}\n" + source[start:end])
check = lua.globals().PLDR.UdpfsStaticIp


def evaluate(ip="192.168.1.50", mask="255.255.255.0", gateway="192.168.1.1", dhcp=False):
    lua.globals().PLDR.SMB = lua.table_from({
        "DHCP": dhcp, "PS2_IP": ip, "NETMASK": mask, "GATEWAY": gateway,
    })
    return check()


assert evaluate() == ("192.168.1.50", "255.255.255.0", "192.168.1.1")
assert evaluate("192.168.001.050", "255.255.255.000", "0.0.0.0") == (
    "192.168.1.50", "255.255.255.0", "0.0.0.0"
)
for valid_mask in ("255.0.0.0", "255.255.0.0", "255.255.252.0",
                   "255.255.255.0", "255.255.255.252"):
    assert evaluate(mask=valid_mask)[0] == "192.168.1.50", valid_mask

for invalid_ip in ("999.168.1.50", "192.168.1.256", "192.168.1",
                   "0.1.2.3", "127.0.0.1", "224.0.0.1", "169.254.1.2",
                   "192.168.-1.2"):
    result = evaluate(ip=invalid_ip)
    assert result[0] is None, (invalid_ip, result)

for invalid_mask in ("999.999.999.999", "255.0.255.0", "255.255.255.1",
                     "255.255.254.128", "255.255.255.256",
                     "0.0.0.0", "255.255.255.255", "255.255.255"):
    result = evaluate(mask=invalid_mask)
    assert result[0] is None, (invalid_mask, result)

for invalid_gateway in ("999.168.1.1", "192.168.1", "192.168.1.256"):
    result = evaluate(gateway=invalid_gateway)
    assert result[0] is None, (invalid_gateway, result)

assert evaluate(dhcp=True)[0] is None
print("POPS UDPFS: 26 real-Lua IPv4 configuration scenarios passed")

# Boot the real production Lua chunks with the shared PS2 host mocks, in a fresh
# runtime per scenario. Parse only the literal mocks; do not import/run the full
# harness or inherit state from its unrelated tests.
import ast
ROOT = Path(__file__).resolve().parents[1]
module = ast.parse((ROOT / "tools/host_harness.py").read_text(encoding="utf-8"))
mocks = next(ast.literal_eval(n.value) for n in module.body
             if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "MOCKS" for t in n.targets))
ui_source = (ROOT / "bin/POPSLDR/ui.lua").read_text(encoding="utf-8")
cut = source.index("UI.WelcomeDraw.Play(initial_scene")


def boot(card_slot=0):
    vm = lua54.LuaRuntime(unpack_returned_tuples=True)
    fixture = mocks
    if card_slot == 1:
        fixture = fixture.replace('if path == "mc0:/" or path == "mc0:/POPSTARTER" or path == "mc0:/POPSTARTER/" then return true end', 'if path == "mc1:/" then return true end')
    vm.execute(fixture)
    preload = vm.eval("function(src) return function() return assert(load(src))() end end")
    vm.globals().package.preload["ui"] = preload(ui_source)
    vm.execute(source[:cut] + "\nreturn true\n")
    vm.execute(r"""
      FAKEFS.files = {}; FAKEFS.dirs = { ["mc0:/"] = {}, ["mc0:/POPSTARTER"] = {} }
      System.createDirectory = function(path) FAKEFS.dirs[path] = {}; return 0 end
      PLDR.SMB = { DHCP = false, PS2_IP = "192.168.1.50", NETMASK = "255.255.255.0", GATEWAY = "192.168.1.1" }
      PLDR.POPSTARTER_MC_FOLDER = true
      EMBEDDED["icon.sys.bdma"], EMBEDDED["list.icn.bdma"], EMBEDDED["del.icn.bdma"] = "icon", "list", "del"
      PLDR.BDMA_MODE_KEY = "UDPFS" -- a saved pre-update choice must now equip network-only
      EMBEDDED["usbd.irx.udpfs"] = "network-only-driver"
      EMBEDDED["usbhdfsd.irx.udpfs"] = "companion"
      PLDR.GetRootsByType = function() error("UDPFS must not enumerate USB") end
      NOTICES = {}
      UI.Notif_queue.add = function(message) NOTICES[#NOTICES+1] = message end
    """)
    return vm


scenarios = {
    "no USB: generate MC SYS-CONF from menu IP": r"""
      assert(PLDR.PrepareUdpfsConfig())
      assert(FAKEFS.files["mc0:/SYS-CONF/IPCONFIG.DAT"] == "192.168.1.50 255.255.255.0 192.168.1.1\n")
      assert(FAKEFS.files["mc0:/SYS-CONF/UDPFSCONFIG.DAT"] == nil) -- discovery
    """,
    "MC1 existing configs win independently": r"""
      FAKEFS.files["mc1:/SYS-CONF/IPCONFIG.DAT"] = "192.168.1.50 255.255.255.0"
      FAKEFS.files["mc0:/SYS-CONF/UDPFSCONFIG.DAT"] = "192.168.1.99"
      FAKEFS.files["udpfs:/POPS/UDPFSCONFIG.DAT"] = "192.168.1.88"
      assert(PLDR.PrepareUdpfsConfig())
      assert(FAKEFS.files["mc0:/SYS-CONF/IPCONFIG.DAT"] == nil)
      assert(FAKEFS.files["mc0:/SYS-CONF/UDPFSCONFIG.DAT"] == "192.168.1.99")
    """,
    "MC0 IP wins; preserve conflict instead of shadowing it": r"""
      FAKEFS.files["mc0:/SYS-CONF/IPCONFIG.DAT"] = "192.168.1.10 255.255.255.0"
      FAKEFS.files["mc1:/SYS-CONF/IPCONFIG.DAT"] = "192.168.1.50 255.255.255.0"
      assert(not PLDR.PrepareUdpfsConfig())
      assert(FAKEFS.files["mc0:/SYS-CONF/IPCONFIG.DAT"] == "192.168.1.10 255.255.255.0")
      assert(NOTICES[#NOTICES]:find("conflicts", 1, true))
    """,
    "optional server IP copied only when absent on both cards": r"""
      FAKEFS.files["udpfs:/POPS/UDPFSCONFIG.DAT"] = "192.168.1.88\n"
      assert(PLDR.PrepareUdpfsConfig())
      assert(FAKEFS.files["mc0:/SYS-CONF/UDPFSCONFIG.DAT"] == "192.168.1.88\n")
    """,
    "empty server config fails visibly": r"""
      FAKEFS.files["udpfs:/POPS/UDPFSCONFIG.DAT"] = ""
      assert(not PLDR.PrepareUdpfsConfig())
    """,
    "oversized server config fails before copying": r"""
      FAKEFS.files["udpfs:/POPS/UDPFSCONFIG.DAT"] = string.rep("x", 121)
      assert(not PLDR.PrepareUdpfsConfig())
      assert(FAKEFS.files["mc0:/SYS-CONF/UDPFSCONFIG.DAT"] == nil)
    """,
    "full memory card blocks launch configuration": r"""
      System.writeFile = function() return -1 end
      assert(not PLDR.PrepareUdpfsConfig())
    """,
    "mkdir error return is detected": r"""
      System.createDirectory = function() return -1 end
      assert(not PLDR.PrepareUdpfsConfig())
    """,
    "config write corruption caught by readback": r"""
      local write = System.writeFile
      System.writeFile = function(fd, data, size) write(fd, string.rep("x", size), size); return size end
      assert(not PLDR.PrepareUdpfsConfig())
    """,
    "stale Alpha pair plus matching UDPFS marker is restaged": r"""
      FAKEFS.files["mc0:/POPSTARTER/usbd.irx"] = "alpha"
      FAKEFS.files["mc0:/POPSTARTER/usbhdfsd.irx"] = "companion"
      FAKEFS.files["mc0:/POPSTARTER/bdma_mode.txt"] = "UDPFS"
      assert(not PLDR.IsBdmaModeEquipped("UDPFS"))
      assert(PLDR.ApplyBdmaModeOnce("UDPFS", PLDR.NextBdmaApplyToken(), true))
      assert(PLDR.IsBdmaModeEquipped("UDPFS"))
      assert(FAKEFS.files["mc0:/POPSTARTER/usbd.irx"] == "network-only-driver")
    """,
    "torn network pair never counts as equipped": r"""
      assert(PLDR.ApplyBdmaModeOnce("UDPFS", PLDR.NextBdmaApplyToken(), true))
      FAKEFS.files["mc0:/POPSTARTER/usbhdfsd.irx"] = "damaged"
      assert(not PLDR.IsBdmaModeEquipped("UDPFS"))
    """,
}
for name, script in scenarios.items():
    vm = boot()
    vm.execute(script)
    print("PASS UDPFS:", name)

# Execute RunPOPStarterGame itself; replace only the final native exec boundary.
# A thrown sentinel distinguishes a reached handoff from an early return.
for failure in (None, "config", "stage", "folder", "already-equipped"):
    vm = boot()
    vm.execute(r"""
      PLDR.POPSTARTER_PATH = "mc0:/POPSTARTER/POPSTARTER.ELF"
      FAKEFS.files[PLDR.POPSTARTER_PATH] = "elf"
      FAKEFS.files["udpfs:/POPS/Game.VCD"] = "vcd"
      UI.NET_TRANSPORT = "UDPFS"
      -- Native launch validation requires a numeric fd; shared read mocks use
      -- Lua handles. Adapt only the ELF probe, leaving config/module I/O real.
      local open, size = System.openFile, System.sizeFile
      System.openFile = function(path, mode)
        if path == PLDR.POPSTARTER_PATH and mode == FREAD then return 900 end
        return open(path, mode)
      end
      System.sizeFile = function(fd) if fd == 900 then return 3 end; return size(fd) end
      EXECS = 0
      System.loadELF = function(...) EXECS = EXECS + 1; error("EXEC_BOUNDARY") end
      System.loadELFKeepIOP = function() error("UDPFS must not use SMB KeepIOP") end
    """)
    if failure == "config":
        vm.execute('FAKEFS.files["mc0:/SYS-CONF/IPCONFIG.DAT"] = "192.168.1.10 255.255.255.0"')
    elif failure == "stage":
        vm.execute('EMBEDDED["usbd.irx.udpfs"] = nil')
    elif failure == "folder":
        vm.execute('PLDR.POPSTARTER_MC_FOLDER = false')
    elif failure == "already-equipped":
        vm.execute('assert(PLDR.ApplyBdmaModeOnce("UDPFS", PLDR.NextBdmaApplyToken(), true))')
        vm.execute('PLDR.ApplyBdmaModeOnce = function() error("already equipped must not write drivers") end')
    try:
        vm.execute('PLDR.RunPOPStarterGame("udpfs:/POPS/", "Game.VCD", UI.SCENES.GSMBNET)')
    except Exception as error:
        assert "EXEC_BOUNDARY" in str(error), str(error)
    assert vm.globals().EXECS == (1 if failure in (None, "already-equipped") else 0), (failure, list(vm.globals().NOTICES.values()))
    if failure in (None, "already-equipped"):
        assert vm.eval('FAKEFS.files["mc0:/SYS-CONF/IPCONFIG.DAT"] ~= nil')
    print("PASS UDPFS production launch:", failure or "network-only without USB")

vm = boot(card_slot=1)
vm.execute(r"""
  assert(PLDR.POPSTARTER_DIR == "mc1:/POPSTARTER")
  assert(PLDR.PrepareUdpfsConfig())
  assert(FAKEFS.files["mc1:/SYS-CONF/IPCONFIG.DAT"] ~= nil)
  assert(FAKEFS.files["mc0:/SYS-CONF/IPCONFIG.DAT"] == nil)
""")
print("PASS UDPFS: MC1-only configuration destination")

vm = boot()
vm.execute(r"""
  PLDR.EnsureBackendForAppDir = function() error("manual UDPFS must use embeds") end
  PLDR.BdmaSourceCandidates = function() error("must not install external Alpha overrides") end
  assert(PLDR.ApplyBdmaMode("UDPFS", false))
  assert(PLDR.IsBdmaModeEquipped("UDPFS"))
""")
print("PASS UDPFS: Settings apply cannot reinstall an external Alpha override")

for cleanup_fails in (False, True):
    vm = boot()
    vm.execute(r"""
      FAKEFS.files["udpfs:/POPS/UDPFSCONFIG.DAT"] = "192.168.1.88\n"
      local write = System.writeFile
      ORIGINAL_WRITE = write
      System.writeFile = function(fd, body, size)
        if fd.path:find("UDPFSCONFIG.DAT", 1, true) then
          write(fd, string.rep("x", size), size); return size
        end
        return write(fd, body, size)
      end
    """)
    if cleanup_fails:
        vm.execute('ORIGINAL_REMOVE = System.removeFile; System.removeFile = function() return -1 end')
    vm.execute('assert(not PLDR.PrepareUdpfsConfig()); System.writeFile = ORIGINAL_WRITE')
    if cleanup_fails:
        vm.execute('assert(not PLDR.PrepareUdpfsConfig(), "failed cleanup must block retry")')
        vm.execute('System.removeFile = ORIGINAL_REMOVE; assert(PLDR.PrepareUdpfsConfig())')
        vm.execute('assert(FAKEFS.files["mc0:/SYS-CONF/UDPFSCONFIG.DAT"] == "192.168.1.88\\n")')
    else:
        vm.execute(r"""
          assert(FAKEFS.files["mc0:/SYS-CONF/UDPFSCONFIG.DAT"] == nil, "bad destination must be removed")
          assert(PLDR.PrepareUdpfsConfig())
          assert(FAKEFS.files["mc0:/SYS-CONF/UDPFSCONFIG.DAT"] == "192.168.1.88\n")
        """)
    print("PASS UDPFS: corrupt config retry; cleanup failure =", cleanup_fails)

vm = boot()
vm.execute(r"""
  FAKEFS.files["udpfs:/POPS/UDPFSCONFIG.DAT.example"] = "192.168.1.11\n"
  assert(PLDR.PrepareUdpfsConfig())
  assert(FAKEFS.files["mc0:/SYS-CONF/UDPFSCONFIG.DAT"] == nil)
""")
print("PASS UDPFS: unedited kit example leaves server discovery enabled")
