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
