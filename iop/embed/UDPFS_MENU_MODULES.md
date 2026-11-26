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
`make` in each module folder, with no local changes.

| File | Bytes | SHA-256 |
|---|---|---|
| `udpfs_net_smap.irx` | 7441 | `b4f4097e04316bb37b5762218a6667701402dbacfa33d66d5361997226823d91` |
| `udpfs_ministack.irx` | 7537 | `1a144e0fdb1e19017384f13c40d00d3801b92b33878768998325325d53f6c7ee` |
| `udpfs_ioman.irx` | 12849 | `15272c1f08f55727f4742a1838f96e1f8f80b4b3300abee47ac19eebd768f586` |

`tools/test_udpfs_integration.py` pins these files.

Why they replaced the stock Neutrino copies (ioman `85faad56...`, smap `4b81d9bf...`):

- The stock `udpfs_ioman` looked for the server once, for about 5 seconds, while
  the module loaded. The network chip needs about 3 seconds before it can send,
  so that one search could miss the server; `udpfs:` then stayed dead until
  POPSLoader restarted, and R1 could not help. This copy registers `udpfs:`
  anyway and keeps looking for the server in the background.
- The stock SMAP driver dropped the last byte of odd-sized reads. This copy
  reads it.

Hardware status: NOT tested on a PS2.
