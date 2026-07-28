## Partition-installed POPS games (PP.* / __.* — HDDOSD & PSBBN)

> **This is an *additional* launch path, not a replacement.** The standard internal-HDD method documented
> above — the `__.POPS` / `__.POPS0`…`__.POPS9` partition holding named `.VCD` files — is unchanged and
> remains the primary way to run HDD games. Partition-installed games (below) **coexist with it**; the
> launcher supports both.

On top of the file-based layouts above, POPStarter can *also* run a PS1 game that is installed as **its own
PFS-APA partition** on the internal HDD — the form you get from **HDDOSD** and **PSBBN** installs. In that
case the disc image inside the partition is **always named `IMAGE0.VCD`**, and the game's identity comes
from the **partition name**, not from the VCD filename.

Two partition types exist:

- **`PP.<name>`** — *visible* in the PS2 HDDOSD browser; its launcher is a KELF; contains `IMAGE0.VCD`.
- **`__.<name>`** — *hidden* (not shown by HDDOSD); contains `IMAGE0.VCD`.

To launch one, the renamed POPSTARTER ELF uses the **`PP.` prefix plus the partition name** —
`PP.<name>.ELF` — because every such partition's image is `IMAGE0.VCD`, the launcher pulls the game name
from the **partition**, not the disc image.

### uLE_kHn launch map

| Install location | Disc-image path | Launch ELF |
| --- | --- | --- |
| USB `mass:` | `mass:POPS/GAME.VCD` | `uLE:XX.GAME.elf` |
| HDD `__.POPS` partition | `hdd0:/__.POPS/GAME.VCD` | `uLE:/GAME.elf` |
| HDD `PP.*` / `__.*` partition | `hdd0:/PP.GAME/IMAGE0.VCD` | `uLE:PP.GAME.elf` |

### How it resolves

A partition-installed game is accepted when **either** the partition is an `hdd0:__.POPS*` partition **or**
the full path is `pfs0:/IMAGE0.VCD`:

```
if (partition is not hdd0:__.POPS*  &&  fullpath is not pfs0:/IMAGE0.VCD)
    reject;
```

Note this is a **union, not a swap**: the first branch (`__.POPS*`) is the standard file-based HDD method
that already works; the second branch (`pfs0:/IMAGE0.VCD`) simply *adds* support for partition-installed
games. Normal HDD `.VCD` games keep launching exactly as before.

The partition's `SYSTEM.CNF` (in its patinfo) points POPS at the image with `BOOT2 = pfs:/IMAGE0.VCD`.
PS2 `SYSTEM.CNF` carries three ordered parameters — **BOOT2** (full path to the executable to launch),
**VER** (title version), and **VMODE** (`PAL` or `NTSC`). See the
[PS2 Developer wiki — SYSTEM.CNF](https://www.psdevwiki.com/ps2/System.cnf).

> **Source:** R3Z3N (launch map + partition-acceptance logic) and Ripto, via the POPSLoader community,
> 2026-06-21. This is the partition layout commonly produced by HDDOSD and PSBBN.
