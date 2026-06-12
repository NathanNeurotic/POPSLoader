# POPSLoader launch arguments

POPSLoader accepts NHDDL-style launch arguments so a front-end (OSDMenu /
HOSDMenu, wLaunchELF, a forwarder, etc.) can boot it straight to a device
page or auto-launch a specific game. Arguments are parsed in
`src/main.cpp` `parseLaunchArgs()`, exposed to Lua via
`System.getLaunchArgs()`, and acted on in `bin/POPSLDR/system.lua`.

## The arguments

| Argument | Effect |
| --- | --- |
| `-page=<device>` | Open the main-menu carousel already centered on that device page. |
| `-mode=<device>` | NHDDL-compatible **alias** for `-page=` (identical behavior, same values). |
| `-game=<selector>` | Auto-launch a game. **Must be combined with `-page=`.** |
| `-debug` | Show an on-screen toast with the parsed args + resolved boot context. |

Each argument is a separate token, exactly like a command line:

```
mc0:/PS1_POPSLOADER/POPSLOADER.ELF -page=hdd
mc0:/PS1_POPSLOADER/POPSLOADER.ELF -mode=ata
mc0:/PS1_POPSLOADER/POPSLOADER.ELF -page=usb -game=Tekken 3
mc0:/PS1_POPSLOADER/POPSLOADER.ELF -page=hdd -debug
```

The first token is always POPSLoader's own ELF path; the launcher supplies
it as `argv[0]`. Pass each flag as its **own** argument entry — do not join
them into one quoted string (see *Front-end notes* below).

## Accepted `-page` / `-mode` values

Values are case-insensitive. Aliases in parentheses resolve to the same
page:

| Page | Accepted values |
| --- | --- |
| **HDD** (PFS) | `hdd`, `ata`, `pfs`, `apa` |
| **USB** | `usb`, `mass` |
| **MC** | `mc`, `memcard` |
| **MMCE** | `mmce` |
| **MX4SIO** | `mx4sio`, `mx4`, `sdc` |
| **SMB** | `smb` |
| **BDMA** (HDD exFAT) | `bdma` *(accepted but not navigable — see below)* |

`-mode=ata` is provided specifically for NHDDL parity (`-mode=ata` is how
NHDDL selects the HDD/ATA path).

## What each argument actually does

### `-page=` / `-mode=` (open a device's game list)
Boots **straight into the requested device's game list** (the same screen
you'd reach by scrolling to that page and pressing **X**) — it loads the
device and switches to its list automatically. Combine with `-game=` to go
one step further and auto-launch a specific title (see below); `-page=`
alone just opens the list so you can pick.

Enterable pages: **MMCE, MX4SIO, HDD (PFS), USB, SMB.** The HDD value
targets the implemented **PFS** page. `bdma` (HDD exFAT) and the i.Link
page are intentionally **not** wired, so `-page=bdma` is accepted but has
no effect. An unrecognized value is ignored and the carousel starts on its
default page (MMCE) with no auto-entry.

### `-game=` (auto-launch)
Boots straight into launching a game. Requires **both** `-page=` and
`-game=`. Auto-launch is wired for these pages:

| Page | `-game=` selector format |
| --- | --- |
| HDD | game title as listed in POPSLoader (e.g. `Bomberman - Party Edition`) |
| USB | `<FILE>` relative to `mass:/POPS` |
| MX4SIO | `<FILE>` relative to `mx4sio:/POPS` |
| MMCE | `<FILE>` relative to `mmce0:/POPS` |

If auto-launch fails (game not found, etc.) POPSLoader does **not** hang —
it falls back to the normal welcome screen + main menu and shows an error
toast describing what happened. `-page=smb -game=...` will navigate to SMB
but will **not** auto-launch (SMB auto-launch isn't wired); it shows an
"Auto-launch page not supported" toast.

### `-debug`
Queues an on-screen info toast on the first main-menu frame listing:

```
[debug] boot context
kind: <HDD|USB|MC|MMCE|MX4SIO|SMB|HOST>
boot_path: <argv[0]>
sidecar: <settings sidecar path>
settings: <resolved settings path>
args.page: <normalized page or <nil>>
args.game: <selector or <nil>>
```

Use this to confirm the args actually reached POPSLoader. If the toast
shows `args.page: HDD` you know parsing works and any remaining problem is
downstream; if the toast never appears, the args didn't reach
`parseLaunchArgs()` at all (front-end delivery or an outdated build).

## Front-end notes (important)

- **One flag per argument entry.** Front-ends that pass each argument as a
  distinct `argv` token (OSDMenu's `arg_OSDSYS_ITEM_<n>` lines, NHDDL,
  OPL) work directly. Writing two flags on one line — e.g.
  `-page=hdd -debug` as a single value — historically arrived as one token
  `"-page=hdd -debug"`. POPSLoader now defends against this (it keeps only
  the first word of a page value and still detects a trailing `-debug`),
  but the clean, portable form is two separate argument entries.
- **Whitespace / quotes are tolerated.** Leading/trailing spaces and one
  pair of surrounding quotes are stripped from each token (some CNF parsers
  leave a trailing space on the line). Internal spaces in `-game=` values
  are preserved, so titles like `Bomberman - Party Edition` are fine.
- **OSDMenu Browser-icon (PATINFO) launches** don't read
  `arg_OSDSYS_ITEM_*`; for those, arguments come from the OSDMenu
  `SYSTEM.CNF` `arg` extensions in the partition attribute area.
- **Build requirement.** These arguments only exist in builds from
  `BETA-12-PLAY` (feature added 2026-05-25). All Lua runs from assets
  embedded in the ELF at build time, so updating on-card `.lua` files has
  **no effect** — you must run a current `POPSLOADER.ELF`. Verify with
  `-debug`.

## Example OSDMenu `OSDMENU.CNF` entry

```
name_OSDSYS_ITEM_1 = POPSLoader (HDD)
path1_OSDSYS_ITEM_1 = mc0:/PS1_POPSLOADER/POPSLOADER.ELF
arg_OSDSYS_ITEM_1 = -page=hdd
```

Add games or debug as additional, separate `arg_OSDSYS_ITEM_1` lines:

```
arg_OSDSYS_ITEM_1 = -page=hdd
arg_OSDSYS_ITEM_1 = -game=Bomberman - Party Edition
arg_OSDSYS_ITEM_1 = -debug
```

## Source map (for maintainers)

| Concern | Location |
| --- | --- |
| Token parse + trim | `src/main.cpp` `parseLaunchArgs()`, `trimLaunchArgToken()` |
| Lua binding | `src/luasystem.cpp` `lua_getLaunchArgs()` → `System.getLaunchArgs()` |
| Normalize + populate | `bin/POPSLDR/system.lua` `NormalizeLaunchPage()` + `PLDR.LAUNCH_ARGS` |
| Carousel navigation | `bin/POPSLDR/system.lua` page-jump block (raises `Carousel.allowOptWrite`) |
| Auto-launch | `bin/POPSLDR/system.lua` `PLDR.AutoLaunchFromLaunchArgs()` |
| Debug toast | `bin/POPSLDR/system.lua` `PLDR.SurfaceLaunchArgsDebug()` |

### Why navigation needs `allowOptWrite`
`UI.MainMenu` installs a `__newindex` write-guard that silently drops any
`OPT` assignment unless `Carousel.allowOptWrite` is raised, and
`MainMenu.Play()` re-syncs the carousel **from** `OPT` every non-animating
frame. The page-jump block therefore raises that gate around its `OPT`
write (and sets the carousel indices to match). Without it the navigation
is a silent no-op — that was the 2026-06 "launch args do nothing on
hardware" bug.
