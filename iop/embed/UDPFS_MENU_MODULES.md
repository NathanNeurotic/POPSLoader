# UDPFS menu modules

`udpfs_net_smap.irx`, `udpfs_ministack.irx` and `udpfs_ioman.irx` list games over
UDPFS in the menu. They are not Okeanos's UDPFS Assault pair, which POPStarter loads
at launch (see `docs/UDPFS_BDMA.md`).

Source: NathanNeurotic/Open-PS2-Loader, branch `rebuild/main`, commit
`2b7f8eaa` (the RiptOPL source tree):

| File here | Built from |
|---|---|
| `udpfs_net_smap.irx` | `modules/network/udpfs_smap` |
| `udpfs_ministack.irx` | `modules/network/udpfs_ministack` |
| `udpfs_ioman.irx` | `modules/network/udpfs_ioman` (+ `udpfs_shared`) |

Built with `ps2dev/ps2dev:v2.0.0` (the image POPSLoader CI uses) by running
`make` in each module folder. One local change, in `udpfs_smap.irx` only:
[`udpfs_smap-link-wait.patch`](udpfs_smap-link-wait.patch).

| File | Bytes | SHA-256 |
|---|---|---|
| `udpfs_net_smap.irx` | 7441 | `70832345b19f275fda0528c8ef87b411be43e26be16a9228a55effd56e2b9e13` |
| `udpfs_ministack.irx` | 7537 | `1a144e0fdb1e19017384f13c40d00d3801b92b33878768998325325d53f6c7ee` |
| `udpfs_ioman.irx` | 12849 | `15272c1f08f55727f4742a1838f96e1f8f80b4b3300abee47ac19eebd768f586` |

`tools/test_udpfs_integration.py` pins these files.

Why they replaced the stock Neutrino copies (ioman `85faad56...`, smap `4b81d9bf...`):

- The server search started before the network link could be up. When SMAP
  loads, `InitPHY()` waits a fixed 3.0 s, then up to 4.0 s for the link, then
  0.5 s on a DP83846A, before it can send. The stock search sends 4 packets
  1.25 s apart and stops after 5 s, and the stock `udpfs_ioman` searches only
  that once. So at best its last packet got out, and when it missed, `udpfs:`
  stayed dead until POPSLoader restarted.
- The patch makes `smap_transmit()` wait up to 8 s (one full autonegotiation
  round) instead of 2 s, so the search starts once the link is up and gets its
  whole 5 s.
- This `udpfs_ioman` also registers `udpfs:` when the server is not running
  yet, and keeps looking in the background, so R1 lists games once the server
  answers.
- The stock SMAP driver dropped the last byte of odd-sized reads. This copy
  reads it.

Hardware status: NOT tested on a PS2.
