"""Regression gate for bundled UDPFS blobs and POPSLoader's network-mode wiring.

Runs without the PS2 SDK and protects against publishing an incomplete binary
pair or accidentally routing a network VCD through POPSTARTER's SMB selector.
Hardware status: Unknown (verify on hardware).
"""
from hashlib import sha1, sha256
import json, sys, zipfile
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
BLOBS = {
    "bin/POPSLDR/usbd.irx.udpfs": ("a004de7a35a8433c22e63a33286b576e624e36e3", 51029),
    "bin/POPSLDR/usbhdfsd.irx.udpfs": ("e7a9baa6fd2fd35ac92b4f6d6545b033e195f51f", 34508),
    "iop/embed/udpfs_net_smap.irx": ("a8ad1bf35a0ab57c4119dce82ee5ca39402cd3aa", 8081),
    "iop/embed/udpfs_ministack.irx": ("7696096abf3df9fe56ec7ef0f28d27b3d533985e", 5025),
    "iop/embed/udpfs_ioman.irx": ("638f0ab4527ee5b806ee5fe3f965922a27959015", 11633),
}
for path, (sha, length) in BLOBS.items():
    binary = (ROOT / path).read_bytes()
    assert len(binary) == length, (path, len(binary), length)
    git_blob_sha = sha1(b"blob " + str(len(binary)).encode() + b"\0" + binary).hexdigest()
    assert git_blob_sha == sha, (path, git_blob_sha)
    assert binary[:4] == b"\x7fELF", f"not a valid ELF: {path}"
    assert binary[5] == 1, f"not little-endian: {path}"
    assert struct.unpack_from("<H", binary, 18)[0] == 8, f"not MIPS: {path}"

ui = (ROOT / "bin/POPSLDR/ui.lua").read_text(encoding="utf-8")
system = (ROOT / "bin/POPSLDR/system.lua").read_text(encoding="utf-8")
cpp = (ROOT / "src/luasystem.cpp").read_text(encoding="utf-8")
assets = (ROOT / "src/embed_assets.cpp").read_text(encoding="utf-8")
make = (ROOT / "Makefile").read_text(encoding="utf-8")

assert "UI.RunNetworkModePicker()" in ui
assert 'UI.RunSharePicker({ "SMBv1", "UDPFS" }' in ui
assert "UI.NET_TRANSPORT == \"UDPFS\"" in ui
assert "UI.RunSmbConnectFlow()" in ui
assert "UI.RunUdpfsConnectFlow()" in ui
assert 'UI.NET_TRANSPORT ~= "UDPFS"' in ui  # SMB-only launch and disconnect gates
assert 'PLDR.InitUDPFSPopsRoot(report)' in ui
assert 'UI.NET_TRANSPORT = "UDPFS"' in ui
assert 'resolve_location = "mass:/POPS/"' in ui  # preflight matches the launch root
assert 'dir..name.."_COV.png"' in ui  # UDPFS-only POPS-side artwork fallback
assert 'PLDR.ResolveLaunchPopstarterPath(resolve_location, configured_popstarter_path)' in ui
assert 'PLDR.SaveGameListCache(' not in ui[ui.index("function UI.RunUdpfsConnectFlow()"):
                                  ui.index("function UI.RunNetworkModePicker()")]

assert 'if device_page == "UDPFS" then' in system
assert 'return "mass:/POPS/XX."..game_name..".ELF"' in system
assert 'PLDR.PrepareUdpfsConfig()' in system
assert 'PLDR.IsBdmaModeEquipped("UDPFS")' in system
assert 'PLDR.ApplyBdmaModeOnce("UDPFS"' in system
assert 'local adaptive_ok, adaptive_res = pcall(PLDR.MaybeApplyAdaptiveBdma' in system
assert 'return "udpfs:/POPS/"' in system
assert "UDPFS needs a static PS2 address" in system
assert "local function ParseUdpfsIPv4(value)" in system
assert "local function IsUdpfsContiguousMask(octets)" in system
assert 'mask == "0.0.0.0"' in system
assert 'mask == "255.255.255.255"' in system
assert "GetRootsByType" not in system[system.index("function PLDR.PrepareUdpfsConfig()"):system.index("function PLDR.InitSMBPopsRoot(report)")]
assert "WriteBytesAtomicBounded(body, dest)" in system

assert '"initUDPFS",              lua_udpfs_init' in cpp
assert '"udpfsState",              lua_udpfs_state' in cpp
assert "net_stack_attempted" in cpp and "udpfs_nic_claimed" in cpp
assert "SifExecModuleBuffer(udpfs_ioman_irx" in cpp
assert 'snprintf(iparg,sizeof(iparg),"ip=%s",ip);' in cpp
assert "strcmp(udpfs_initialized_ip, ip)" in cpp
assert '"UDPFS_IP_CHANGED_RESTART"' in cpp
assert 'snprintf(udpfs_initialized_ip,sizeof(udpfs_initialized_ip),"%s",ip);' in cpp
for key in ("usbd.irx.udpfs", "usbhdfsd.irx.udpfs"):
    assert f'ASSET_ENTRY("{key}"' in assets
    assert f'ASSET_ENTRY("POPSLDR/{key}"' in assets
    assert f"bin/POPSLDR/{key}" in make
for key in ("udpfs_net_smap.o", "udpfs_ministack.o", "udpfs_ioman.o"):
    assert key in make
assert (ROOT / "docs/third_party/okeanos_udpfs/THIRD_PARTY_NOTICES.md").is_file()
assert (ROOT / "docs/third_party/okeanos_udpfs/LICENSE").is_file()

print("POPS UDPFS: pinned IRX blobs and UDPFS wiring, preflight, and network lifecycle guards verified")

provenance = json.loads((ROOT / "docs/third_party/okeanos_udpfs/PROVENANCE.json").read_text())
assert set(provenance) == {"UDPFS_TEST"}  # no USB-first or 1.0.0 release remains
assert provenance["UDPFS_TEST"]["prerelease"] is True
for name, record in provenance["UDPFS_TEST"]["files"].items():
    body = (ROOT / "bin/POPSLDR" / name).read_bytes()
    assert len(body) == record["size"]
    assert sha256(body).hexdigest() == record["sha256"]
assert provenance["UDPFS_TEST"]["files"]["usbd.irx.udpfs"]["sha256"] == "24e272996a6ea4af5ef20cb5d89a29aa615d8b828087032e75bc2b05aaac583e"
if len(sys.argv) > 1:
    with zipfile.ZipFile(sys.argv[1]) as kit:
        assert "POPS/UDPFSCONFIG.DAT" not in kit.namelist(), "sample server IP must not be active"
        sample = kit.read("POPS/UDPFSCONFIG.DAT.example")
        assert sample.strip() == b"192.168.1.11"
        for name in provenance["UDPFS_TEST"]["files"]:
            assert kit.read("POPS/" + name) == (ROOT / "bin/POPSLDR" / name).read_bytes()
        for path in (ROOT / "docs/third_party/okeanos_udpfs").iterdir():
            if path.is_file():
                assert kit.read("POPS/UDPFS-NOTICES/" + path.name) == path.read_bytes()
        assert kit.read("POPS/UDPFS_BDMA.md") == (ROOT / "docs/UDPFS_BDMA.md").read_bytes()
    print("Release ZIP: current network-only UDPFS pair, setup and notices verified")

notice_root = ROOT / "docs/third_party/okeanos_udpfs"
assert (notice_root / "AFL-2.0.txt").read_bytes() == (notice_root / "LICENSE").read_bytes()
import re
for name in ("UPSTREAM-README.md", "THIRD_PARTY_NOTICES.md"):
    for link in re.findall(r"\]\(([^)]+)\)", (notice_root / name).read_text(encoding="utf-8")):
        if "://" not in link and not link.startswith("#"):
            assert (notice_root / link.split("#")[0]).is_file(), (name, link)
print("UDPFS mirrored documentation and license links verified")
