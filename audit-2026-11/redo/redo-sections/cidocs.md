# PS2-Servers — Blind Redo Audit: Build / CI / Packaging / Docs-Claims (CIDOCS)

- **Repo / pin:** `~/workspace/audit-clones-2026-11-13/PS2-Servers` @ `c5f021c4d38698860f56b03498adc261dbb8d8dd` (verified `git rev-parse HEAD`; clone never edited — `git status` clean at end of audit)
- **Method:** every workflow, build script, packaging file and Edge doc read in full; Edge binary built in a `/tmp` copy (`go build -trimpath -ldflags="-s -w" ./cmd/ps2servers-edge`, Go 1.27.4) and every subcommand's `-h` output plus one refusal path executed and compared claim-by-claim against the shipped text.
- **Edge binary measured (EXECUTED):** 7,667,975 bytes = **7.31 MiB** (linux/amd64, CGO off, `-s -w`) — under edge-build.yml's 9 MiB ceiling, ~1.1 MiB over the 6.19 MiB figure its comment quotes for the older workflow toolchain (the comment itself predicts this growth; no finding).

## Executed Edge defaults (ground truth for all claims below)

| Subcommand | Flag defaults actually printed by `-h` (EXECUTED) |
|---|---|
| `udpfs` | bind `0.0.0.0`, port `62966`, data-port `0` (auto), protocol-mode `auto`, peer-timeout `1h`, sector-size `512`, compression-cache-size `32`, metrics-period `1m`, log-format `text`, **read-only `false` (writable)** |
| `udpbd` | bind `0.0.0.0`, port `48573`, status-port `-1` (= UDP 62966), **read-only `false`** |
| `smb` | bind `0.0.0.0`, port `1111`, status-port `-1` (= UDP 62966), **read-only `false`** |
| `webui` | bind **`127.0.0.1`**, webui-port `8082`, auth-user `admin`, auth-pass `""`, config-file `/etc/ps2servers-edge/config.json`, log-lines `1000`, max-log-clients `8` |

Claims in `docs/EDGE.md`, `docs/EDITIONS.md`, `docs/INSTRUCTIONS.md` and `README.md` were spot-checked against this table (ports, writable-by-default, webui loopback default, status-port `-1` → 62966, Edge scope = UDPFS/SMBv1/UDPBD/WebUI, no HTTP-game/NFS/SMB2/3) and **match**. The contradictions are concentrated in generated/packaging text, below.

---

### CIDOCS-01 — WHICH-DEVICE.txt shipped in every Edge archive falsely claims the binary is read-only by default
- **Category:** 6
- **Locations:** `.github/workflows/edge-build.yml:387-390` (generated `WHICH-DEVICE.txt` text: "Access: read-only by default. Pass --read-only=false to allow the console to write (saves)"), contradicted by `native/ps2servers-edge/cmd/ps2servers-edge/main.go:150` (`--read-only` defaults `envBool("RO", false)`) and by the same file's own Quick Start at `edge-build.yml:391-397` (`udpfs --root …` with no `--read-only`)
- **Problem:** The binary is **writable by default** (proven by execution: `udpfs -h` lists `-read-only` with no default-true, help text "omit to allow the console to write saves"; same for `udpbd`/`smb`). Every Edge download's first-read file tells the user the opposite, and its own Quick Start command produces an unauthenticated, LAN-writable share while the text above it says read-only. `docs/EDGE.md`, `docs/EDITIONS.md:39` and `docs/INSTRUCTIONS.md:16-17` all state the true default, so the archive contradicts the docs packaged alongside it. No test guards this text (grep of `tests/` for `WHICH-DEVICE` returns nothing).
- **Fix:** Change the generated block to state writes are allowed by default and `--read-only` restricts them (matching EDGE.md's wording); delete the `--read-only=false` instruction.
- **Benefit:** Removes a security-relevant false assurance from the single most-read file in every Edge release.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### CIDOCS-02 — Shipped systemd webui env file configures a start the binary refuses
- **Category:** 6
- **Locations:** `packaging/systemd/ps2servers-edge-webui.env:4` (`--webui-port 8082 --bind 0.0.0.0 --config-file /etc/ps2servers-edge/config.json` — no `--auth-pass`, no `--insecure`); binary rule at `native/ps2servers-edge/cmd/ps2servers-edge/main.go:476-484`
- **Problem:** Executed with exactly those arguments, the binary exits 1: `error: refusing to serve the web UI on a non-loopback address without a password`. So `systemctl enable --now ps2servers-edge@webui` with the shipped env file fails on first start. Every other shipped env file carries extensive warning comments; this 4-line file carries none. `packaging/systemd/README.md` does disclose the trap in prose, but the file a user actually edits does not.
- **Fix:** Either ship the env file with `--bind 127.0.0.1` (the binary's own default, which starts cleanly) or add the same warning comment block the sibling env files carry, in the env file itself.
- **Benefit:** First-run systemd webui deployment works, or fails with the explanation at the point of configuration instead of only in journal output.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED)

### CIDOCS-03 — ps2servers@.service header falsely states "Edge has no SMB at all"
- **Category:** 6
- **Locations:** `packaging/systemd/ps2servers@.service:5-7` ("Separate from ps2servers-edge.service, which runs the Go build and serves only UDPFS and UDPBD. Edge has no SMB at all, so a user who needs SMB … cannot use that unit")
- **Problem:** Both clauses are wrong against the shipped tree: the binary has `smb` and `webui` subcommands (executed `-h` for both), `packaging/systemd/ps2servers-edge@.service` exists precisely to run them, `packaging/systemd/README.md` documents "Edge now serves SMB too", and `ps2servers-edge.service` in fact serves UDPFS only (not "UDPFS and UDPBD"). A user trusting this comment concludes the Edge SMB unit they need does not exist. The same header (line 2) also presents the template's instance keys as only "smbv1, udpfs or udpbd", while `launcher/servers.py:738` REGISTRY has eight keys (smbv1, smbv2, smbv3, udpfs, http, nfs, udpbd, retroachievements) and the systemd README table claims the template serves SMB2/3 and HTTP too — the three texts disagree with each other.
- **Fix:** Rewrite the header to match the systemd README: Edge serves SMBv1 via `ps2servers-edge@smb`; this template is for the Python/Desktop build. State the template's real key scope in one place only.
- **Benefit:** Operators stop being routed away from a working deployment path by a stale comment in the unit they are installing.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ; binary subcommands EXECUTED)

### CIDOCS-04 — OpenWrt package metadata is a release behind and describes a UDPFS-only read-only server that no longer exists
- **Category:** 7
- **Locations:** `packaging/openwrt/Makefile:4` (`PKG_VERSION:=0.8.2`), `:21` (`TITLE:=PS2 Servers Edge UDPFS server`), `:26-28` (description: "A small read-only UDPFS server…"); source of truth `launcher/release_metadata.py:15` (`PRODUCT_VERSION = "0.9.4"`)
- **Problem:** The package version is hand-maintained and has drifted a full minor release behind the product version, and nothing catches it: `tools/version_source.py --check-sources` guards only `edge-build.yml`'s literals. The title/description also predate three of the binary's four subcommands (executed: udpfs, udpbd, smb, webui) and call the server itself read-only when read-only is only the package config's choice (`packaging/openwrt/files/ps2servers-edge.config` sets `read_only '1'`; the binary defaults writable). `opkg` users see a wrong version and a wrong capability summary.
- **Fix:** Derive or check `PKG_VERSION` against `tools/version_source.py` (extend its workflow list to the Makefile), and update TITLE/description to the four-subcommand scope with read-only attributed to the package defaults.
- **Benefit:** One version number across launcher, Edge archives and the OpenWrt package; package browsers describe the software actually installed.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### CIDOCS-05 — OpenWrt init script's fallback enables the shared status port that the shipped config deliberately disables
- **Category:** 6
- **Locations:** `packaging/openwrt/files/ps2servers-edge.init:123` and `:172` (`config_get status_port smb|udpbd status_port -1`) vs shipped `packaging/openwrt/files/ps2servers-edge.config:47,63` (`option status_port '0'`) and the config's own rationale comments (off by default because udpfs owns UDP 62966 and two owners race)
- **Problem:** The shipped config and the init fallback disagree about the default. With the option present the config wins (`0`, off); if a user deletes the option — a normal way to "reset to default" in UCI — the init script silently substitutes `-1`, enabling the status listener on the port udpfs already owns, recreating exactly the first-starter-wins race the config comments warn about. The binary default is also `-1` (executed), so the package's safety property currently lives only in one config line, contradicted by the layer beneath it.
- **Fix:** Change both init fallbacks to `0` so every layer below the binary agrees that smb/udpbd status is opt-in on this platform.
- **Benefit:** Deleting a UCI option can no longer silently change which service answers discovery on the router.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ; binary default EXECUTED)

### CIDOCS-06 — The portable/AppImage half of the release pipeline cannot fail, so missing downloads stay green
- **Category:** 7
- **Locations:** `.github/workflows/release.yml` — 13 `continue-on-error: true` steps (lines 146, 228, 235, 252, 269, 343, 361, 379, 388, 403, 420 and the portable/AppImage build-stage steps), including `:403-420` where the portable **upload** step pairs `if-no-files-found: error` with `continue-on-error: true`, negating the error; same pattern, 5 occurrences, in `.github/workflows/release-on-main.yml`
- **Problem:** The intent (optional variants must not block the primary release) is documented and the release-notes generator has fallback rows, but the composition means a broken portable or AppImage build produces no red signal anywhere: build, checksum, attestation and upload all swallow failure, and the upload's own `if-no-files-found: error` is explicitly overridden. A regression in `build/build.py`'s standalone mode would silently remove the antivirus-friendly portable download — the variant that exists for users who cannot run the primary one — from every release until a user reports it.
- **Fix:** Keep `continue-on-error` on build/stage steps if desired, but drop it from one final verification step per optional artifact (assert the file exists when its build step reported success), or surface absence as a job summary warning that a human sees. Remove the self-negating `if-no-files-found: error` + `continue-on-error` pairing.
- **Benefit:** Optional downloads can still fail soft for users, but no longer fail invisible for maintainers.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### CIDOCS-07 — Desktop release build duplicated across release.yml and release-on-main.yml; the copies have already drifted
- **Category:** 2
- **Locations:** `.github/workflows/release.yml` (606 lines) and `.github/workflows/release-on-main.yml` (489 lines): same 5-target desktop matrix, libchdr build, portable build/stage, source-archive and checksum logic — 90 identical non-trivial lines by script comparison. Drift proof: `release-on-main.yml:333-334` emits an AppImage row in its download table, but that workflow contains no AppImage build step at all (release.yml has the full AppImage chain); conversely release.yml's `verify-version` job and Windows desktop-startup check have no counterpart in release-on-main.yml
- **Problem:** The repo already solved this exact problem for Edge — `edge-build.yml`'s header says the reusable workflow exists so callers "cannot drift apart" — but the larger desktop build was left as two hand-copies, and the predicted drift is observable now (a download-table row for an artifact one workflow can never produce; version verification present on tagged releases, absent on the rolling releases users actually download day-to-day).
- **Fix:** Extract the desktop build matrix into a reusable workflow the way `edge-build.yml` was, with the two callers keeping only their publish/prune differences.
- **Benefit:** One place to fix build bugs; rolling and tagged releases get identical gating (including the version check).
- **Effort:** L · **Risk:** Med · **Confidence:** High (READ)

### CIDOCS-08 — Go toolchain pinned three different ways across Edge's own build paths
- **Category:** 7
- **Locations:** `native/ps2servers-edge/go.mod:3` (`go 1.22`, consumed via `go-version-file` by `.github/workflows/edge.yml:44` test job and `edge-build.yml`), `.github/workflows/edge.yml:198` (parity job hardcodes `go-version: "1.25"`), `packaging/docker/Dockerfile.edge:2` (`golang:1.23-alpine`)
- **Problem:** The differential parity evidence, the unit-test evidence and the shipped binary are produced by three different compilers, none of which is stated to be intentional. Binary size and codegen demonstrably move with toolchain version (edge-build.yml's own size comment documents ~1 MiB of drift between Go versions), so "parity passed" and "the released binary" are weaker claims than they appear. The Docker image additionally runs `go test ./...` with its third toolchain at image-build time.
- **Fix:** Point the parity job at `go-version-file` like the test job, and either pin the Dockerfile to the go.mod version or document why the container intentionally differs.
- **Benefit:** Test, parity and shipped artifacts describe the same compiler; size-ceiling reasoning in edge-build.yml stays valid.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ)

### CIDOCS-09 — conformance/integration/http_probe.py is orphaned: no CI step, test or runner references it
- **Category:** 8
- **Locations:** `conformance/integration/http_probe.py` (219 lines, complete socket-level OPL HTTP probe)
- **Problem:** Grep-verified across workflows, tests and docs: nothing invokes or imports this file — its only usage text is its own docstring. Every sibling is wired: `opl_http`, `riptopl_http`, `neutrino_smb`, `neutrino_nfs`, `libsmb2` run in `ci.yml`; `udpfs_probe`, `udpbd_probe`, `udpfs_parity` run in `edge.yml`; `ra_dependency/*` runs via `tests/test_ra_dependency.py` under `unittest discover`. HTTP is the one protocol whose conformance probe silently rots, in a repo whose README calls HTTP "experimental" — exactly where a live probe matters most.
- **Fix:** Either wire it into `ci.yml` alongside the other HTTP conformance runners (it takes `--host/--port` against a running server, like the Edge probes in edge.yml), or delete it. Keeping an unrunnable-by-CI probe is the worst of the three states.
- **Benefit:** HTTP wire behaviour is either actually gated or no longer appears to be.
- **Effort:** S · **Risk:** Low · **Confidence:** High (READ, grep-verified)

### CIDOCS-10 — Byte-identical 571,581-byte banner PNG tracked twice
- **Category:** 7
- **Locations:** `ps2serversgithubbanner.png` and `docs/assets/ps2servers-banner.png` (identical size 571,581 B and identical md5 `7d13770364c4192c47463f2ba0ee1ff0`, census by script over `git ls-files`)
- **Problem:** The same image is stored twice in the tree; the docs copy is the one referenced by the site's `og:image` tags. Any future banner update must be made in two places or the GitHub-facing and site-facing banners diverge.
- **Fix:** Keep one canonical copy and reference it from the other location (or accept the docs copy as canonical and delete the root duplicate if nothing references it).
- **Benefit:** 571 KB out of every clone and no two-place update hazard.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED census)

### CIDOCS-11 — Two parallel documentation systems (34 Markdown + 22 HTML) cover the same topics with no generator between them
- **Category:** 2
- **Locations:** `docs/*.md` (34 tracked) vs `docs/*.html` (22 tracked), overlapping pairs including EDITIONS/editions, EDGE/edge, SMB/smb, NFS/nfs, HTTP/http, OPENWRT/openwrt, PROTOCOL-COMPATIBILITY/protocol-compatibility, antivirus-transparency/antivirus; `tools/build_docs_index.py` only indexes the HTML into the (correctly drift-gated) `docs/data/search-index.json` — nothing generates HTML from MD or checks the pair's agreement
- **Problem:** Git history shows both copies edited in the same documentation commits (e.g. the NFS/SMB2 docs pass touched both), i.e. every behaviour change is written twice by hand, in two formats, with no consistency gate comparable to `tests/test_edge_manual.py` (which pins the one manual that ships in Edge archives). The Edge defaults audit above is the cost made concrete: claims had to be checked in four places, and the false ones survived in the places without a pinning test.
- **Fix:** Designate one source per topic (Markdown for repo/operator docs is the natural survivor) and generate or link the site pages from it; where a pair must both exist, extend the existing manual-pinning test pattern to the pair's load-bearing claims (ports, defaults, edition scope).
- **Benefit:** Behaviour changes update one text; the class of stale-claim findings above stops recurring.
- **Effort:** L · **Risk:** Med · **Confidence:** High (READ, census by script)

### CIDOCS-12 — ~3.16 MB of generated compression test fixtures are tracked as binaries
- **Category:** 7
- **Locations:** `native/ps2servers-edge/internal/compression/testdata/test.iso` (1,110,016 B), `test_cd.chd` (1,055,592 B), `test_dvd.chd` (1,049,766 B) — census by script over `git ls-files`
- **Problem:** Three of the four largest non-vendor files in the tree are test fixtures for formats (ISO/CHD) whose test content is synthetic; they are paid for in every clone and every `git archive` source download (which release.yml ships as the "inspection" artifact). This is the smallest finding here and may be a deliberate choice (CHD fixtures are awkward to regenerate without libchdr tooling), but no in-tree note says so.
- **Fix:** Either generate the ISO fixture in-test and keep only the CHDs with a one-line justification in the testdata directory, or record the deliberate choice so it is not re-litigated.
- **Benefit:** ~1–3 MB out of every clone/source archive, or a documented reason it stays.
- **Effort:** S · **Risk:** Low · **Confidence:** High (EXECUTED census)

---

## Files read

Workflows (all 7, in full): `.github/workflows/attribution-policy.yml`, `ci.yml`, `edge-build.yml`, `edge.yml`, `release-on-main.yml`, `release.yml`, `udpfs-transport-replay.yml`; plus `.github/scripts/release-downloads.sh` (referenced, skimmed via release steps) and `.github/release-notes-common.md` (via compliance tool references).
Build/tools (in full): `build/build.py`, `build/build_achievements.py`, `build/build_libchdr.py`, `build/build_ra_evaluator.py`, `tools/build_docs_index.py`, `tools/check_achievements_package.py`, `tools/check_desktop_startup.py`, `tools/check_release_compliance.py`, `tools/replay_neutrino_udpfs.py` (header/scope), `tools/verify_docs.py`, `tools/version_source.py`, `ps2servers.py`, `Start-Launcher.bat`, `start-launcher.sh`.
Packaging (in full): all of `packaging/systemd/` (3 units, 8 env files, README), `packaging/openwrt/Makefile` + `files/ps2servers-edge.config` + `files/ps2servers-edge.init` + README, `packaging/docker/Dockerfile.edge` + README, `packaging/openrc/` (init, confd, README).
Conformance: `conformance/README.md`, `conformance/ra_dependency/README.md`, runner inventory + wiring for `integration/*.py` and `ra_dependency/*.py` (full read of `http_probe.py` header; wiring grep-verified for all).
Docs/claims: `README.md` (claims grep + relevant sections), `docs/EDGE.md`, `docs/EDGE-WHICH-BUILD.md`, `docs/EDITIONS.md`, `docs/INSTRUCTIONS.md`, `docs/OPENWRT.md` (claims grep), `native/ps2servers-edge/README.md` (via packaging step), `launcher/release_metadata.py`, `launcher/servers.py` (REGISTRY keys).
Code ground truth: `native/ps2servers-edge/cmd/ps2servers-edge/main.go` (in full), `internal/smb/server.go`/`wire.go` (port/status semantics), `internal/protocol/packet.go` (DefaultPort), `internal/webui/webui.go` (DefaultPort).
Executed: Edge build + all four subcommand `-h` outputs, webui refusal run, `tools/verify_docs.py` (0 errors — correctly exit-coded, no finding), `tools/build_docs_index.py` + `git diff` (index in sync, drift gate real, no finding), git censuses (tracked files, sizes, duplicates).

## Files not read (in scope)

- `tools/remove-windows-firewall-rules.ps1` — PowerShell helper, listed in tools/ but not opened; no docs/CI claim about it was in scope of the claims checked.
- `conformance/integration/` runner bodies (`opl_http/run.py`, `riptopl_http/run.py`, `neutrino_smb/run.py`, `neutrino_nfs/run.py`, `libsmb2/run.py`, `udpfs_probe.py`, `udpbd_probe.py`, `udpfs_parity.py`) — read for wiring/line counts and CI invocation only, not line-by-line; their internal correctness belongs to the protocol scopes.
- `docs/*.html` bodies (22 files) — inventoried, categorised via `tools/build_docs_index.py`'s page map and spot-read (`editions.html` head); not read in full.
- Remaining `docs/*.md` beyond the Edge/editions/instructions set (RA-*, UDPFS-* handoffs, plans) — inventoried for the duplication census; their protocol claims belong to other scopes.
- `build/native/`, `build/__pycache__/`, `tools/__pycache__/` in the working tree — untracked local artefacts; `git ls-files` confirms no `__pycache__`/`.pyc`/binary build output is tracked (census clean, no finding).
- `.github/scripts/check_ai_attribution.py` — exercised only via its workflow; attribution logic is outside this scope.
