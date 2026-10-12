"""Regression gate for bundled UDPFS blobs and POPSLoader's network-mode wiring.

Runs without the PS2 SDK and protects against publishing an incomplete binary
pair or accidentally routing a network VCD through POPSTARTER's SMB selector.
Hardware operation is verified separately.
"""
from hashlib import sha1
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
BLOBS = {
    "bin/POPSLDR/usbd.irx.udpfs": ("5cf9772fed86eaf015a67fa77240e4bd7e65e358", 76365),
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
assert 'UI.RunSharePicker({ "SMBv1", "USB + UDPFS" }' in ui
assert "UI.NET_TRANSPORT == \"UDPFS\"" in ui
assert "UI.RunSmbConnectFlow()" in ui
assert "UI.RunUdpfsConnectFlow()" in ui
assert 'UI.NET_TRANSPORT ~= "UDPFS"' in ui  # SMB-only launch and disconnect gates
assert 'PLDR.InitUDPFSPopsRoot(report)' in ui
assert 'UI.NET_TRANSPORT = "UDPFS"' in ui
assert '.gamecache' not in ui[ui.index("function UI.RunUdpfsConnectFlow()"):
                                  ui.index("function UI.RunNetworkModePicker()")]

assert 'if device_page == "UDPFS" then' in system
assert 'return "mass:/POPS/XX."..game_name..".ELF"' in system
assert 'PLDR.PrepareUdpfsUsbConfig()' in system
assert 'PLDR.IsBdmaModeEquipped("UDPFS")' in system
assert 'PLDR.ApplyBdmaModeOnce("UDPFS"' in system
assert 'local adaptive_ok, adaptive_res = pcall(PLDR.MaybeApplyAdaptiveBdma' in system
assert 'return "udpfs:/POPS/"' in system
assert "UDPFS needs a static PS2 address" in system
assert "doesFolderExist(dir)" in system
assert "WriteBytesAtomicBounded(desired.." in system

assert '"initUDPFS",              lua_udpfs_init' in cpp
assert '"udpfsState",              lua_udpfs_state' in cpp
assert "net_stack_attempted" in cpp and "udpfs_nic_claimed" in cpp
assert "SifExecModuleBuffer(udpfs_ioman_irx" in cpp
assert 'snprintf(iparg,sizeof(iparg),"ip=%s",ip);' in cpp
for key in ("usbd.irx.udpfs", "usbhdfsd.irx.udpfs"):
    assert f'ASSET_ENTRY("{key}"' in assets
    assert f'ASSET_ENTRY("POPSLDR/{key}"' in assets
    assert f"bin/POPSLDR/{key}" in make
for key in ("udpfs_net_smap.o", "udpfs_ministack.o", "udpfs_ioman.o"):
    assert key in make
assert (ROOT / "docs/third_party/okeanos_udpfs/THIRD_PARTY_NOTICES.md").is_file()
assert (ROOT / "docs/third_party/okeanos_udpfs/LICENSE").is_file()

print("POPS UDPFS: pinned IRX blobs and 26 wiring/guard conditions verified")
