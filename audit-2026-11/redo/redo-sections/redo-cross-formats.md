# REDO Audit — Cross-Repo Format & SMB Pass

Independent blind redo. Everything below was derived from the clones only; nothing under
`~/workspace/Sable-audit/` was read, listed, or opened. All work in the clones was read-only.

## Pins verified (HEAD at time of audit)

| Repo | HEAD |
|---|---|
| RiptOPL | `2e347d5ac885cd0ff73e9ad4143781946396f492` |
| Launchstation | `9fb0598a79f09b4ff06fdc3078ab26c38d7f4790` |
| POPSLoader | `29272cddbf0122f14e76bc3bdd75e3b46aa870be` |
| Simple-Media-System | `e65ced39a27eee8d996e9257e21594d1cac1c93d` |
| PS2-Servers | `c5f021c4d38698860f56b03498adc261dbb8d8dd` |

Method: for each shared format, the actual writer code and the actual parser code were both
read and traced; a disagreement is only claimed where both sides are traced to specific lines.
Lens: LESS-NOT-MORE — where a fix is suggested, it is the smallest change that removes the
divergence, on the side that is out of step with every other implementation of the same format.

---

## (a) Inventory of cross-repo format pairs examined

| # | Pair (writer → reader) | Verdict |
|---|---|---|
| 1 | `title.cfg` — Launchstation dashboard starter (`src/dash_apps.c`) → RiptOPL app scanner | **DISAGREE** → FMT-01 |
| 2 | `title.cfg` launch-argument key — Launchstation `arg=` ↔ RiptOPL `argv1=` | **DISAGREE** → FMT-02 |
| 3 | `title.cfg` — Launchstation `make_title_cfg` (`src/filer_actions.c:1917-1938`) → RiptOPL | Agree |
| 4 | `title.cfg` — Launchstation Python packager (`scripts/package_apps.py:116-119`, enforced by `scripts/package_kit.py:373`) → RiptOPL | Agree |
| 5 | `title.cfg` — POPSLoader shipped file (`bin/POPSLDR/title.cfg`) → RiptOPL / Launchstation scanners | Agree |
| 6 | `title.cfg` — RiptOPL's own template + release packager → RiptOPL parser | Agree |
| 7 | `IPCONFIG.DAT` — Launchstation, RiptOPL (POPSTARTER handoff), POPSLoader, SMS writers/readers | Agree |
| 8 | `SMBCONFIG.DAT` (POPSTARTER) — RiptOPL and POPSLoader writers → RiptOPL parser | Agree |
| 9 | SMB2 dialect/signing — Launchstation `smb2man` ↔ RiptOPL `smb2man` + in-game `cdvdman/smb2` ↔ PS2-Servers `smb2_server` | Agree |
| 10 | SMB2 max I/O sizes — both clients, Launchstation `smbd`, PS2-Servers | Agree |
| 11 | SMB1 (NT LM 0.12) — Launchstation `smbman` ↔ RiptOPL `smbman-ra` ↔ PS2-Servers `smbv1_server` | Agree |
| 12 | Launchstation `smbd` server vs the PS2 SMB2 clients | No traced break (caveat noted) |
| 13 | Neutrino `config/bsd-smb.toml` handoff — Launchstation and RiptOPL both write it for Neutrino | Agree |
| 14 | Cover-art naming — Launchstation reader vs RiptOPL packager/reader | Agree |
| 15 | PSU container layout — Launchstation & RiptOPL Python packers, Launchstation C save-PSU writer/restore, Launchstation self-update reader | Agree (two mode vocabularies, each reader matched to its own flavour — see note) |
| 16 | `LAUNCHELF.CNF` / `LAUNCHSTATION.CNF` vs RiptOPL settings files | No shared pair (see note); shipped template largely matches its parser |
| 17 | `SMB2.CNF` share blocks (Launchstation) | No pair — RiptOPL does not read it |
| 18 | POPSTARTER launcher prefixes (`XX.`/`SB.`/`EL.`/`SM.`) — RiptOPL recognition vs Launchstation/POPSLoader launch paths | Coverage difference, not a format disagreement |
| 19 | Neutrino `-gc` compat digits — Launchstation vs RiptOPL encoders | Not countable (reader not in any clone) |
| 20 | SMS `SMS.cfg` / `SMS.smb` | No pair — SMS-private formats |

### Notes on the agreeing / non-pair inventory items

**7 — IPCONFIG.DAT.** One format, four implementations, all interoperable.
Launchstation writes `"%s %s %s\n\r"` (note the reversed `\n\r`) at
`Launchstation/src/config_network.c:62` and reads by NUL-splitting on space/`\r`/`\n` in
`getIpConfig` (`Launchstation/src/main_startup.c:55`). RiptOPL's POPSTARTER writer emits
`"%d.%d.%d.%d %d.%d.%d.%d %d.%d.%d.%d\n"` (`RiptOPL/src/sources/vcdsupport.cpp:2796`,
`vcdBuildIpConfig`; empty file = DHCP) and parses with `sscanf` (`vcdsupport.cpp:2471`,
`vcdParseIpConfig`); RiptOPL's legacy network import does the same `sscanf`
(`RiptOPL/src/core/config.cpp:731-776`, `configReadLegacyIP`). POPSLoader renders the identical
single line (`POPSLoader/bin/POPSLDR/system.lua:8128-8132`, `PLDR.RenderSmbIpconfig`). SMS is
the shape outlier — its editor writes three lines, one field per line
(`Simple-Media-System/src/SMS_GUIMenuSMS.c:1937`, `_saveipc_handler`) — but its own reader
NUL-splits on space/`\r`/`\n` (`Simple-Media-System/src/SMS_IOP.c:1368-1427`, `_read_ipconfig`),
and `sscanf`'s whitespace matching means the one-line readers also accept SMS's three-line
file. No break traced in any direction.

**8 — SMBCONFIG.DAT.** RiptOPL writes `"<IP>[:port] <share>\n<user>\n<pass>\n"`, omitting the
port when it is 0/445 (`RiptOPL/src/sources/vcdsupport.cpp:2809`, `vcdBuildSmbConfig`), and
parses the same shape (`vcdsupport.cpp:2483`, `vcdParseSmbConfig`). POPSLoader writes the same
three-line body but always writes the port explicitly, including `:445`
(`POPSLoader/bin/POPSLDR/system.lua:8134-8171`, `PLDR.RenderSmbConfig`); RiptOPL's parser
accepts an explicit port, so the round trip is safe. Agree.

**9 — SMB2 dialect/signing.** The two clients are behaviourally identical. Both offer
`0x0202, 0x0210` first and reconnect offering `0x0300, 0x0302` only on `STATUS_NOT_SUPPORTED`:
Launchstation `Launchstation/iop/smb2man/smb2man.c:591-595`, RiptOPL
`RiptOPL/modules/network/smb2man/smb2man.c:617-621` (mirrored in-game at
`RiptOPL/modules/iopcore/cdvdman/smb2.c:537`). Both refuse a 3.x dialect when the server
requires signing, because neither implements AES-CMAC: Launchstation `smb2man.c:602-603`,
RiptOPL `smb2man.c:624`. Both fall back to user `"Guest"` on a blank username: Launchstation
`smb2man.c:587-588`, RiptOPL `smb2man.c:613-614`. PS2-Servers' server defines dialects
0x0202/0x0210/0x0300/0x0302 (`PS2-Servers/smb2_server/smb2_wire.py:64-68`; 0x0311 defined at
`:68` but deliberately never picked, `pick_dialect` at `smb2_wire.py:211`, called from
`smb2_server.py:757`) and answers NEGOTIATE with `SECURITY_MODE_SIGNING_ENABLED` — "enabled,
never required" (`PS2-Servers/smb2_server/smb2_server.py:782`) — so the clients' 3.x signing
refusal is never triggered against it. Agree on all three sides.

**10 — SMB2 max I/O.** Both clients clamp to 64 KiB (`SMB2MAN_IO_MAX 65536`:
Launchstation `smb2man.c:83`, applied `:532-535`; RiptOPL `smb2man.c:87`, applied `:550-553`).
Launchstation's server offers the same 64 KiB (`SMBD_MAX_IO 65536`,
`Launchstation/iop/smbd/smbd.h:28`, applied `smbd_fs.c:997`). PS2-Servers advertises 1 MiB
(`smb2_wire.py:207-208`), which both clients safely clamp down. Agree.

**11 — SMB1.** Launchstation `Launchstation/iop/smbman/smb.c` and RiptOPL
`RiptOPL/modules/network/smbman-ra/smb.c` are the same lineage: single dialect `"NT LM 0.12"`
(LS `smb.c:367`, OPL `smb.c:357`), 64 KiB-class buffers, and the identical WRITE_ANDX
byte-count correction. PS2-Servers' SMB1 server (`PS2-Servers/smbv1_server/smbserver_opl.py:64-73`)
answers guest logons with caps `CAP_NT_SMBS|CAP_STATUS32|CAP_LARGE_FILES|CAP_LARGE_READX` and
UNICODE deliberately off; both clients handle the non-UNICODE branch. Plaintext handling is an
opt-in on both client sides (Launchstation refuses a plaintext server unless the share sets
`PLAINTEXT = 1`: `smb.c:484-489`, `Launchstation/src/smb_shares.c:290`; RiptOPL has a plaintext
fallback at `RiptOPL/src/sources/ethsupport.cpp:118`). No interop break traced.

**12 — Launchstation `smbd` vs the PS2 clients.** `smbd_serve` sets `signing_enabled = 1`,
`allow_anonymous = 0`, 64 KiB caps (`Launchstation/iop/smbd/smbd_fs.c:995-997`), serves only
`mc0`/`mc1` shares with default credentials `ps2`/`ps2` (`Launchstation/iop/smbd/smbd.c:28`),
and accepts versions 2.0.2–3.1.1 (`smbd_fs.c:981`, `SMB2_VERSION_ANY`; the server engine is
libsmb2, fetched pinned by `Launchstation/scripts/fetch_libsmb2.sh`, not vendored — so whether
its `signing_enabled` also sets the NEGOTIATE *required* bit could not be traced in-repo).
The clients negotiate 2.1 first against it, where they do implement HMAC-SHA256 signing, and a
guest logon is refused by design (`authorize_user`, `smbd_fs.c:252`). No break traced; also,
RiptOPL pointing at Launchstation's memory-card shares is not an intended pairing (RiptOPL
expects a game share). Recorded for completeness, not as a finding.

**13 — Neutrino SMB TOML.** Both apps rewrite Neutrino's `config/bsd-smb.toml` with the same
module split — `ministack.irx` gets only `ip=`; `smb_ioman.irx`/`smb_fhi.irx` get all seven keys
`ip= mask= gw= srv= user= pass= share=` — and the same limits (user/pass ≤ 31, share ≤ 63,
path ≤ 127, port 445 only). Launchstation: `Launchstation/src/neutrino_smb.c` (module list at
`:144`). RiptOPL: `RiptOPL/src/platform/sysneutrino.cpp:472` ff. (`sysNeutrinoSmbPreflight`),
constants at `RiptOPL/include/system.h:61-65`. Agree.

**14 — Cover art.** Launchstation's resolution order includes the OPL forms `<NAME>.ELF_COV.png`
and `ART/<NAME>_COV.png` (`Launchstation/src/dash_art.c:16-22`, `:227-230`). RiptOPL's packager
emits `ART/<ELF>_<SUFFIX>.png` for suffixes `BG, COV, COV2, ICO, LAB, LGO, SCR, SCR2`
(`RiptOPL/.github/scripts/package_release_app.py:36`, `:256-260`, `:320`), and POPSLoader's
README documents the same `<basename>_COV.png` in device-root `ART/`. Agree.

**15 — PSU.** The 512-byte record layout is byte-identical across every implementation:
`struct "<HHI8sII8sI28s448s"` in both Python packagers (Launchstation
`scripts/package_apps.py:13`; RiptOPL `.github/scripts/package_release_app.py:38`) and the C
`psu_header` in `Launchstation/include/psu_types.h:30`. Two mode vocabularies exist by design:
app PSUs use 0x8027 (dir) / 0x8017 (file), which the strict readers check exactly
(Launchstation `src/update_psu.c:61`, `:78-81`, `:97`; both Python `inspect_psu` functions),
while Launchstation's game-save PSU writer uses memory-card attr values 0x8427/0x8497
(`Launchstation/src/psu_functions.c`, root/`.`/`..` records) — and its restore path checks only
the `sceMcFileAttrSubdir` bit (`psu_functions.c:328`, `:356-358`), so it accepts both
vocabularies. Each reader is matched to the flavour it must read. Agree.

**16 — App config filenames.** There is no shared master-config pair. Launchstation boots from
`LAUNCHSTATION.CNF`, importing a legacy `LAUNCHELF.CNF` read-only and redirecting saves to its
own name in the same folder (`Launchstation/src/main_boot.c:62-66`). RiptOPL never reads either
file: its master file is `settings_riptopl.cfg`, with `conf_riptopl.cfg` auto-migrated
(`RiptOPL/include/config.h:23-29`; `RiptOPL/src/app/settingsio.cpp:135`), and official OPL's
`conf_opl.cfg` is never adopted as its own settings (`settingsio.cpp:840`; consulted only as a
read-only seed in one path-redirect context, `settingsio.cpp:1205`). Launchstation's shipped
annotated template `Launchstation/docs/LAUNCHELF.CNF` was spot-verified against its parser
(e.g. `CNF_version`, `LK_*` keys) and carries a source-verified note listing dead keys as
comments — largely agrees. One intra-repo doc drift worth noting, not a cross-repo finding:
`Launchstation/docs/dashboard.md:314` correctly calls `title.cfg` "OPL application format
(`title=`, `boot=`)", yet its example block at `:318` shows the spaced `title = Open PS2 Loader`
form — the same spaced shape as FMT-01, in the docs.

**18 — POPSTARTER prefixes.** RiptOPL recognises `POPSTARTER.ELF` plus `XX.`/`SB.`/`EL.`/`SM.`
prefixed launcher ELFs (`RiptOPL/src/sources/appsupport.cpp:156-195`). Launchstation's own
POPSTARTER launch builds only the `XX.` (FAT) and partition forms and returns unsupported for
SMB paths (`Launchstation/src/popstarter_path.c:348-405`). Launchstation writes no file here
that RiptOPL then misreads, so this is a coverage difference, not a format disagreement.

**19 — Neutrino `-gc` digits (examined, deliberately not a finding).** Launchstation emits
compat digits {0,2,3,5,7} (`Launchstation/src/gui_neutrino.c:10-91`); RiptOPL re-encodes its
compat bitmask to {1,2,3,5,7}, mapping its "Accurate Reads" mode to digit 1
(`RiptOPL/src/platform/sysneutrino.cpp:113-142`). The reader — Neutrino itself — is not in any
clone, so both sides cannot be traced and this cannot be counted as a disagreement under the
audit method. The two apps also keep separate per-game stores (Launchstation's private
checksummed `NEUT-<GameID>-A/B.CNF` profiles vs RiptOPL's `CFG/<id>.cfg`), so neither overwrites
the other's encoding. Recorded as INFERRED/unverifiable-in-scope.

**20 — SMS.** `SMS.cfg` and the `SMS.smb` server list (`Simple-Media-System/src/SMS_Config.c:54`)
are SMS-private; no other repo reads or writes them. No pair.

---

## (b) Candidate findings

### FMT-01

- **TEMP-ID:** FMT-01
- **Title:** Launchstation's dashboard starter `title.cfg` is written with spaced `title = / boot =` lines that RiptOPL's parser silently drops — the app vanishes from RiptOPL's Apps list
- **Category:** 6 (bugs/security)
- **Locations:**
  - Writer: `Launchstation/src/dash_apps.c:175-187` (`editMetadata()` starter template: `"title = %s\r\n"`, `"boot = %s\r\n"`)
  - Writer locked in by test: `Launchstation/tests/test_opl_title_cfg.py:101` (asserts the spaced strings are present; never feeds the file to RiptOPL's parser)
  - Reader: `RiptOPL/src/sources/appscan.cpp` (`scanApps` opens each APPS subfolder's `title.cfg` via `configRead`)
  - Reader: `RiptOPL/include/appsupport.h:15-19` (`APP_CONFIG_TITLE "title"`, `APP_CONFIG_BOOT "boot"`, `APP_TITLE_CONFIG_FILE "title.cfg"`)
  - Reader: `RiptOPL/src/core/config.cpp:167-191` (`splitAssignment` — no trim on either side of `=`)
  - Reader: `RiptOPL/src/core/config.cpp:1115-1182` (`configReadFileBuffer` format latch; classifier `cfgClassifyLine` at `:129`)
  - Reader: `RiptOPL/src/core/config.cpp:257-265` (`ConfigSet::find` — exact key match)
  - Reader: `RiptOPL/src/sources/appsupport.cpp:729-773` (`appScanCallback`; requires title+boot at `:735`, drops the app at `:770`)
- **Problem:** The starter emits `title = X` / `boot = Y`. RiptOPL's format latch only treats a
  line as libconfig if it has whitespace before `=` **and** ends with `;`; the starter has the
  whitespace but no `;`, so the file latches to the legacy parser. The legacy `splitAssignment`
  copies the key as everything before `=` with no trailing-space trim and the value as everything
  after `=` with no leading-space trim, producing key `"title "` and value `" X"`.
  `ConfigSet::find` matches keys exactly, so lookups for `"title"`/`"boot"` miss, `appScanCallback`
  logs "APPSUPPORT item has no boot/title." and the app is never listed. RiptOPL's own comment at
  `RiptOPL/src/core/config.cpp:85-103` documents exactly this failure mode and states its own
  writer emits `"%s=%s\n"` (writer at `config.cpp:1595`) — never a space before `=`. CRLF is not
  the problem: RiptOPL strips a trailing `\r` per line before parsing. Launchstation never notices
  because its own reader trims both sides of `=` (`Launchstation/src/dash_store.c:53-102`,
  `dashTrim`/`dashKvParse`), and its metadata parser even records that OPL keys are case-sensitive
  lowercase (`Launchstation/src/dash_lib.c:283-296`) — the case is right; the whitespace is the
  defect. Every other `title.cfg` writer in either repo agrees on the unspaced form:
  Launchstation's `make_title_cfg` (`Launchstation/src/filer_actions.c:1924`,
  `"title=%s\nboot=%s"`), Launchstation's packager (`scripts/package_apps.py:116`), POPSLoader's
  shipped `bin/POPSLDR/title.cfg`, and RiptOPL's shipped example and packager.
- **Fix in words:** Change the one wrong writer: make the `dash_apps.c` starter emit
  `title=%s\r\nboot=%s\r\n` (unspaced, matching every other writer of this format), and update the
  host test at `tests/test_opl_title_cfg.py:101` to assert the unspaced strings. (The alternative —
  teaching RiptOPL's legacy `splitAssignment` to trim key and value — also works and would harden
  the reader against hand-edited files, but it touches the parser every config file in the app
  flows through; LESS-NOT-MORE favours fixing the single writer that is out of step.)
- **Benefit:** Apps whose metadata was created from Launchstation's dashboard appear in RiptOPL
  again; the two launchers stop disagreeing about a file both claim is "OPL format".
- **Effort:** Small — one format string in one function, plus the test assertion that locks it in.
- **Risk:** Low. Launchstation's own reader trims whitespace, so unspaced lines still parse
  identically inside Launchstation; no other consumer of the starter is known.
- **Confidence:** READ

### FMT-02

- **TEMP-ID:** FMT-02
- **Title:** Same shared `title.cfg`, same concept, different key: Launchstation writes launch arguments as `arg=`, RiptOPL reads `argv1=` — each silently ignores the other's
- **Category:** 6 (bugs/security)
- **Locations:**
  - Launchstation starter comment: `Launchstation/src/dash_apps.c:187` (`"# arg = first argument (one per line)"`)
  - Launchstation parser/consumer: `Launchstation/src/dash_lib.c:325-328` (`metaKv` accepts `arg`/`args`, case-insensitive, including in its OPL-style pass), `Launchstation/src/dash_lib.c:431-438` (`dashLibLoadArgs`), called from `Launchstation/src/dash_main.c:629`
  - RiptOPL: `RiptOPL/include/appsupport.h:17` (`APP_CONFIG_ARGV1 "argv1"` — the only argument key), read at `RiptOPL/src/sources/appsupport.cpp:761-765`
- **Problem:** Launch arguments are the one `title.cfg` concept both launchers implement, under
  two different key names. A user who adds `arg=` lines in Launchstation (its own starter template
  tells them to) gets a launch with no arguments in RiptOPL, and an `argv1=` written for RiptOPL
  is invisible to Launchstation. There are zero occurrences of `argv1` in Launchstation's
  src/include, and RiptOPL has no `arg=` handling. Unlike FMT-01 this is not a parse failure —
  both files parse cleanly — it is a silent semantic divergence in a shared format. (Launchstation's
  other extra keys in `title.cfg` — `description`, `author`, `version`, `category`, `cover`,
  `pinned` — are plain extensibility that RiptOPL is free to ignore, and are not part of this
  finding. Relatedly, RiptOPL-only keys `REBOOTIOP`/`HANDOFFPATH` at
  `RiptOPL/src/sources/appsupport.cpp:215`, `:243` are matched against the raw parsed key/value,
  so they inherit the same spaced-line fragility as FMT-01 if ever written spaced; Launchstation
  never emits them.)
- **Fix in words:** Pick one key for the shared file and have both sides honour it: the smallest
  change is for Launchstation's `metaKv` OPL-style pass to also accept `argv1` (RiptOPL's existing
  key, and the name its shipped examples use), and for its starter comment to name `argv1` instead
  of `arg`. Accepting both spellings on read costs one comparison; writing only the shared one
  stops the divergence growing.
- **Benefit:** Launch arguments set in one launcher take effect in the other; one less silent
  no-op in a file users hand-edit expecting both apps to honour it.
- **Effort:** Small — one extra key comparison in one parser function, plus a comment/string change
  in the starter template.
- **Risk:** Low. `arg`/`args` support stays for Launchstation-private sidecar files; only the
  OPL-style `title.cfg` pass gains the shared spelling.
- **Confidence:** READ

---

## Summary

- **Pairs examined:** 20 (13 traced to a verdict of agree, 2 disagreements, 5 no-pair /
  not-countable items documented with reasons).
- **Disagreements found:** 2, both in the shared `title.cfg` format, both traced on both sides.
- **Candidates:** 2 — FMT-01 (spaced starter `title.cfg` silently dropped by RiptOPL) and
  FMT-02 (`arg=` vs `argv1=` launch-argument key divergence).
- Nothing in the SMB space disagreed: the two SMB2 clients are behaviourally identical, both
  interop cleanly with PS2-Servers' SMB1 and SMB2 servers on every traced axis (dialect ladder,
  signing refusal, guest fallback, I/O ceilings, WRITE_ANDX byte counts).
- No PS2-build or hardware verification was performed; all claims are source-traced (READ)
  except the Neutrino `-gc` item, which is labelled INFERRED/unverifiable-in-scope and is
  explicitly not counted as a finding.
