# Round 2 — Topic 3: CONFIG PARSING, function-level diff

**READ ONLY.** All clones verified at the Round-2 pins before and after the work, working trees clean:
RiptOPL `2e347d5ac885`, Launchstation `9fb0598a79f0`, Simple-Media-System (SMS) `e65ced39a27e`, POPSLoader `29272cddbf01`.
Every claim below is **READ** (line-cited from the pinned tree) unless marked **INFERRED** (derived by composing two READ facts; the composition is shown). No config *values* are reproduced anywhere — SMB credentials are discussed by key name and buffer size only (location-only rule).

**Headline:** there is no shared config parser in this family. There are **seven** distinct parsers across four repos (two of them inside Launchstation's `config.c` ecosystem alone, plus a third in the same repo), one repo whose "config parser" is not text at all, and one shared file — `title.cfg` — that one repo writes in a dialect another repo's reader silently cannot see (§4, Bug C-1, the worst finding).

---

## 1. Parser inventory (READ)

| # | Repo | Parser | Path:lines | File(s) it reads | Approach |
|---|------|--------|-----------|------------------|----------|
| P1 | RiptOPL | `splitAssignment` + `configReadFileBuffer` (+ libconfig twin `cfgReadLibconfigLine`) | `src/core/config.cpp:167-195`, `:1115-1182`, `:794-895` (file 1740 lines) | `settings_riptopl.cfg`, `conf_last/apps/network/game.cfg`, per-game `<ID>.cfg`, app `title.cfg` | `strchr('=')`, in-place via line reader |
| P2 | RiptOPL | `configReadLegacyIP` | `src/core/config.cpp:731-774` | legacy `SYS-CONF/IPCONFIG.DAT` | one `sscanf` of 12 dotted ints |
| P3 | Launchstation | `get_CNF_string` | `src/config.c:111-160` (file 1782 lines), callers `src/config.c:950` (`loadConfig`), `src/main_startup.c:180` (`readSystemCnf`) | `LAUNCHELF.CNF`, disc `SYSTEM.CNF` | hand-rolled char-class scan over a whole-file RAM buffer, destructive (NUL-punches the buffer) |
| P4 | Launchstation | `dashKvParse` (+ `dashTrim`) | `src/dash_store.c:65-103`, `:53-63` (file 870 lines); consumers `settingsKv:304-390`, `listsKv:392-406`; also reused by `dash_lib.c`, `dash_themes.c`, `cloud_google.c` | `DASHBOARD.CNF`, `DASHAPPS.CNF`, `DASHLIB.CNF`, `title.cfg`/`<ELF>.cfg` metadata, theme folders | `strchr('=')` per line over a whole-file buffer, callback dispatch |
| P5 | Launchstation | `smbConfigParse` (+ private `trim`, `copyValue`) | `src/smb_cnf.c:345-438`, `:60-70`, `:74-81` | SMB share blocks after `# SMB shares` inside the CNF (`smb_shares.h:26`) / `SMB2.CNF` | `strchr('=')` per line, state machine: a share is closed by its `URL` key |
| P6 | Launchstation | `getIpConfig` | `src/main_startup.c:53-141` | `SYS-CONF/IPCONFIG.DAT` | NUL-out every space/CR/LF, then walk three NUL-separated tokens |
| P7 | SMS | — none for the main config — `SMS_LoadConfig` | `src/SMS_Config.c:595-802` (file 1132 lines) | `SMS.cfg` | **binary struct dump**, not key=value (§2.3) |
| P8 | SMS | `SMS_LoadSMBInfo` over `File_GetString` | `src/SMS_Config.c:314-379`; helper `src/SMS_FileContext.c:2176-2211` | `SMS.smb` server list | **positional** line records (6 lines/record, 8 in the new format) — no keys at all |
| P9 | POPSLoader | per-key `string.match` extraction in `PLDR.LoadSettingsNonFatal` + `PLDR.SmbParse` | `bin/POPSLDR/system.lua:6222-~6760` (key matches `:6395-6460`), `:5877-5889`; writer `EncodeSettings:5891-5941` | `.pldrs` sidecar (per-device / `mc0:/POPSTARTER/.pldrs`) | not a loop: one anchored Lua pattern per known key over the whole file text |
| P10 | POPSLoader | `PLDR.ParseIpconfigDat` / `PLDR.ParseSmbconfigDat` (+ Ember `key:value` parser `PLDR.EmberReadSettings`) | `system.lua:8194-8202`, `:8204-8235`, `:8928-8942` | POPSTARTER's `IPCONFIG.DAT` / `SMBCONFIG.DAT`; Ember `settings.txt` | positional/space-split; Ember is `:`-separated, value class `[^%s;#]+` |

POPSLoader C-side: **READ** — no key=value config parser exists in `src/*.cpp`; the C side only *consumes* the Lua-parsed SMB values (`lua_smb_connect`, `src/luasystem.cpp:2359`). The `.DAT` files are POPSTARTER's format, parsed only in Lua (P10).

---

## 2. Per-parser record

### 2.1 P1 — RiptOPL legacy + libconfig (`src/core/config.cpp`)

- **Functions / lines:** `cfgClassifyLine:129-165`, `splitAssignment:167-195`, `parsePrefix:197-219`, `configReadFileBuffer:1115-1182`, `cfgReadLibconfigLine:794-895`, writers `configWrite:1498-1698` (legacy emit `:1595`), `cfgWriteLibconfigLine:1003-1043`, `cfgWriteLibconfig:1059-1113`. Storage `ConfigSet::setStr:363-387`, `find:257-264`, buffers in `include/configset.h:13-20` / `include/config.h:307-308`.
- **Line buffer:** none in the parser itself — lines come from `readFileBuffer` (`src/platform/util.cpp:550-646`) over a **4096-byte** file buffer (`config.cpp:1402`); a line longer than the buffer is returned in pieces (READ, util.cpp refill loop `:568-604`). Key buffer **48** (`CONFIG_KEY_NAME_LEN`), value buffer **256** (`CONFIG_KEY_VALUE_LEN`); composed prefix+key buffer 96 (`2 * CONFIG_KEY_NAME_LEN`).
- **Separator:** first `=` via `strchr` (both readers, `:182` and `:823`). A `prefix:` section line is handled by `parsePrefix` (`strchr(':')`, `:197-219`): following *indented* lines compose `prefix_key` (`:1157-1173`); an unindented assignment resets the prefix.
- **Line WITHOUT `=`:** three different fates in one function — (a) with a `:` it becomes a prefix (not an error); (b) otherwise it is **logged and skipped, parsing continues**: `LOG("CONFIG Malformed file …")` at `:1174-1178`; (c) in the libconfig reader a no-`=` line is treated as a group header if it has a `:` before any `=`, else silently dropped (`:823-843`).
- **Comment char:** `#` — but handled *twice*, and the first handler is not in this file: `readFileBuffer` itself discards any line whose first byte is `#` before the config parser ever sees it (`util.cpp:630-637`); `cfgClassifyLine:138-141` then also classifies `#` and `//` / `/*` as comments (the latter two only reachable via indented lines or the in-memory `configReadBuffer` path). Consequence (READ): the per-game `#Name`-style keys (`include/config.h:36-…`) can never be *read from disk* — they are runtime-only, which matches the writer skipping `#`-keys (`:1593`).
- **Escape / quote handling:** legacy: **absent** — no quote stripping, no escapes, either direction. Libconfig: **present both directions** — reader strips surrounding `"` and un-escapes `\\` / `\"` (`:855-884`), writer escapes `\` and `"` (`cfgWriteLibconfigLine:1020-1040`) and emits bare scalars unquoted (`cfgValueIsBareScalar:985-1001`).
- **Whitespace trimming:** `isWS` is space/tab only (`:75-78`). Legacy: leading WS skipped before the key (`:171-172`), but **the key is copied verbatim up to `=` — a trailing space stays in the key, and the value keeps its leading space** (`:180-193`). No trailing trim of value (CR is stripped earlier by `readFileBuffer`, `util.cpp:618-621`). Libconfig: key and value *are* trimmed (`:846-854`, `:848-853`).
- **Unknown keys:** kept. The set is a generic ordered list; any key is stored and **written back** (writer enumerates entries, `:1590-1598`). Only `#`-prefixed keys are dropped on write.
- **Duplicate keys:** collapsed, **last value wins, first position kept** — read path goes through `setStr`, which finds the existing entry and overwrites its value (`:363-387`).
- **Truncation divergence inside this one file (READ):** legacy `splitAssignment` **silently truncates** an over-long key to 47 chars and value to 255 (`min(keymax-1, …)`, `:184-193`) — two distinct long theme keys sharing a 47-char prefix collide and the second overwrites the first via `setStr`; the libconfig reader instead **rejects** a key `>= 48` outright (`:846-847`, comment: "never truncate into a hit") and truncates only the value (`:866-867`).
- **Empty value:** legacy stores `""` (`key=` parses fine); libconfig **drops it — empty == absent** (`:863-865`), deliberately, because wOPL writes every per-game key empty.
- **Format latch:** the file's format is decided by the *first* meaningful line and never revisited (`:1140-1148`); libconfig requires **all three** of space-before-`=`, trailing `;`, and a legal identifier (`:155-163`). This discriminator is the load-bearing detail for Bug C-1 (§4).
- **Approach summary:** `strchr` (no `sscanf`/`strtok` in the text path); `sscanf` appears only in P2.

### 2.2 P2 — RiptOPL legacy IPCONFIG (`configReadLegacyIP:731-774`)

Space-separated, keyless: one `sscanf("%d.%d.%d.%d %d.%d.%d.%d %d.%d.%d.%d", …)` (`:753-756`) into a 256-byte stack buffer with the read size clamped (`:740-748`). **All-or-nothing:** `n != 12` → returns 0, nothing is set (`:757-758`). No comment, no trim, no per-field salvage. DNS is not in the format; the gateway is duplicated into the DNS key (`:768-770`, location-only).

### 2.3 P7 — SMS main config is **not a parser** (`SMS_LoadConfig:595-802`)

Premise correction, READ: `SMS.cfg` is a raw C-struct image. The reader does `fioRead(…, &g_Config, 4)`, requires `m_Version == 14`, then `fioRead(…, &g_Config.m_DisplayMode, 892)` and requires exactly 892 (`:696-702`; duplicated for the legacy-path fallback at `:727-730`). The writer is the mirror `fioWrite(…, &g_Config, sizeof(g_Config))` (`:941`, `:1066`). `include/SMS_Config.h:59-61` states the constraint explicitly: the version-14/892-byte gate is why new settings must be *derived from existing bits* rather than added.

- Separator/comment/escape/trim/unknown/duplicate: **all N/A — there are no keys.** Every divergence row for SMS below follows from this.
- **Failure mode (the divergence that matters):** version ≠ 14, a short read, or a struct-layout change discards the **entire** config — the defaults assigned at `:597-695` simply remain. No per-key salvage is possible, where every text parser in this audit degrades per-key. Conversely it is the only config here immune to every text-parser bug class in §4 (no malformed lines, no truncation-into-a-hit, no spaced-key miss).
- File size is fixed by construction; there is no line buffer.

### 2.4 P8 — SMS SMB list (`SMS_LoadSMBInfo:314-379` + `File_GetString:2176-2211`)

- **Format:** positional, keyless. Each record is 6 consecutive lines (IP, server name, client name, user, password — field names only, no values reproduced — description), plus 2 more (port, share) in the new format; the 6-vs-8 decision is a single `!FILE_EOF` check after line 6 (`:331-348`). Writer `_smb_put_line`/`SMS_SaveSMBInfo:380-427` writes the same order, always 8 lines.
- **Field buffers (READ, `include/SMS_SMB.h:85-96`):** IP 16, server name 16, client name 16, user 32, password 64, description 64 (local, `:325`), port 8 (local), share 64.
- **Line reader:** `File_GetString` reads to `\n`, strips one trailing `\r` (`SMS_FileContext.c:2194-2197`), and on an over-long line **silently truncates to size−1 and drains the rest of the line** (`lfTruncated`, `:2180, 2201-2204`) — so an over-long field is cut, not rejected, and the cut value is what the writer later writes back.
- **No `=` / malformed:** the concept doesn't exist — **a blank or comment line is not skipped; it is consumed as a field**, shifting every subsequent field of that record and the record framing after it (READ: the six `File_GetString` calls are unconditional, `:333-338`). There is no comment char in this format.
- **Validation / unknown / duplicate:** a record is kept only if IP, server name and client name are non-empty and server name < 14 chars (`:357-361`); invalid records are dropped silently. Duplicates are **kept** — each valid record is pushed to the list (`:362-367`). No escaping anywhere; a field simply cannot contain `\n` by construction.

### 2.5 P3 — Launchstation `get_CNF_string` (`src/config.c:111-160`)

- **Buffers:** no line/key/value buffers at all — name/value are pointers into the whole-file RAM image from `preloadCNF`/`preloadCNFFd:435-531`, capped at **128 KiB** on the streamed fallback path (`CNF_MAX_SIZE`, `:441`). The limits that bite are the *destination* fields in `SETTING` (`include/launchelf.h:279-340`): `LK_Path[][1025]` (`MAX_PATH`, `launchelf.h:204`), `Misc* [64]`, USB-kbd/kbdmap/lang/font/popstarter/ember/neutrino paths `[1025]`, SMB user/password fields `[32]` (`:338-339`, sizes only).
- **Name grammar:** name chars are `*tp >= 'A'` or digits (`:131-132`). `>= 'A'` admits `_ [ ] ^ \`` and all lowercase, so `PathPad[02]` parses; it **excludes `.` and `-`** — a dotted/dashed name ends the name early (see malformed fate below). First char `< 'A'` ⇒ the whole line is treated as a comment and skipped to EOL (`:124-129`) — that is the comment mechanism: `#`, `;`, `/`, `-`, `!`, and also **any line starting with a digit** are all "comments".
- **Separator:** after the name, whitespace is NUL-punched and skipped, then `=` is **required** (`:136-140`).
- **Line WITHOUT `=` — the abort (READ):** `if (*tp != '=') return false;` (`:139-140`). The callers loop `for (…; get_CNF_string(…); …)` (`config.c:950`, `main_startup.c:180`), so **one malformed line terminates parsing of the entire file** — every setting after it is silently lost, with no log. A space *inside* a name (`Some Key = x`), a dotted key, or a stray word line all trigger this, not just a missing `=`.
- **Whitespace:** leading WS skipped; post-name WS skipped; pre-value WS skipped but not past EOL (`:118-119, 133-135, 142-145`). **Value trailing whitespace is NOT trimmed** — the value runs verbatim to `\r`/`\n` (`:149-153`).
- **Escape / quote:** absent, both directions. The writer (`configBuildSaveText:533-718`) emits values raw with `"KEY = %s\r\n"` spacing.
- **Unknown keys:** silently ignored after the dispatch chain falls through (the final `else` only tries `LK_*_Title` / `PathPad[` and drops everything else, `:1090-1155` approx. — READ as the tail of `loadConfig`).
- **Duplicates:** sequential assignment ⇒ **last wins**. This includes the writer's own duplicate: `configBuildSaveText` emits `PathPad_Lock` **twice** (`:621` inside the big settings block and again at `:686`) — harmless because both carry the same value, but it proves the writer is an append-only sprintf chain with no key registry.
- **Bounds asymmetry (READ):** exactly two consumers guard the copy — the SMB user/password keys require `value[0] && strlen(value) < sizeof(field)` (`:1050-1053`, sizes only). Most others do not: `strcpy(setting->LK_Path[i], value)` (`:962`), `strcpy(setting->usbkbd_file, value)` (`:1040`), `strcpy(setting->CNF_Path, value)` (`:1048`), `sprintf(setting->Misc, "%s/", value)` into `char[64]` (`:973`). INFERRED from P3's file cap: a hand-edited CNF can put up to ~128 KiB on one line, so these are unbounded copies from a bounded-but-much-larger source — the only thing standing between a long `Misc=` line and a 64-byte field overflow is that the program's own writer never produces one.

### 2.6 P4 — Launchstation `dashKvParse` (`src/dash_store.c:65-103`)

Written as the deliberate lenient counterpart — `include/dash_internal.h:657-660` says so in as many words: *"Unlike get_CNF_string it skips malformed lines instead of stopping."*

- **Buffers / caps:** whole-file, via `dashLoadTextFile:105-146`; call-site caps differ per file: `DASHBOARD.CNF` **64 KiB**, `DASHAPPS.CNF` **256 KiB** (`dashStoreInit:432, 460`), `title.cfg` **16 KiB** (`dash_lib.c:392, 420`). Key/value are pointers into the buffer (no fixed key/value size); consumers copy into `DASH_PATH_MAX` = **256** fields (`include/dash_internal.h:34`), `software_clock[24]` (`:579`), scan slots `[12][256]`.
- **Separator:** first `=` via `strchr` (`:88`); key and value both passed through `dashTrim` (`:86, 91-92`).
- **Line WITHOUT `=`:** **silently skipped, parsing continues** (`:88-97`) — the exact opposite of P3, in the same repo, for files sitting in the same directory.
- **Comment:** checked on the trimmed line start *before* the `=` search: `#`, `;`, `[` (section headers are skipped as comments), and `//` (`:86-87`). A UTF-8 BOM is skipped (`:73-75`).
- **Trim:** `dashTrim:53-63` — leading space/tab only; trailing space/tab/CR/LF. (Not `\v`/`\f`, not other WS.)
- **Escape / quote:** absent both directions; writers emit `"Dash_X = %d\r\n"` / `"%s\r\n"` raw (`dashStoreSettingsText:505-562`, `buildLists:569-589`), first line is a `#` comment header.
- **Unknown keys:** ignored by the callbacks (`settingsKv`/`listsKv` are `stricmp` chains with no default case). Matching is **case-insensitive** here (`stricmp`), where P3 is mostly `strcmp` with a few `stricmp` exceptions.
- **Duplicates:** scalars last-wins; the list keys are **append** semantics — `Dash_Scan` appends with a first-occurrence reset of the count (`settingsKv:376-385`), and `Favorite`/`Pinned`/`Recent`/`Hidden` append **without any dedup check** (`listsKv:392-406`), so a duplicated line in `DASHAPPS.CNF` produces a duplicated in-memory entry until a toggle/remove touches it (INFERRED: append code contains no `listFind` call, READ at `:392-406`).
- **Callback stop:** a non-zero callback return breaks the parse (`:93-95`); both built-in callbacks always return 0.
- **Also the `title.cfg` reader:** `metaKv` (`dash_lib.c:276-355`) deliberately uses **case-sensitive** `strcmp` for OPL-style `title`/`boot` (`:283-289, 296-298`) and case-insensitive matching for its own sidecar format — two case regimes inside one callback, switched by `opl_style`.

### 2.7 P5 — Launchstation `smbConfigParse` (`src/smb_cnf.c:345-438`)

The strictest parser in the audit, and the newest design. Keys (location-only; values never reproduced): `NAME`, `USERNAME`, `PASSWORD`, `VERSION`, `PLAINTEXT`, `URL` (`:394-430`).

- **Buffers:** fixed and enforced — name 32, user/password 32 each, URL 256, server 16, share 256 (`include/smb_shares.h:18-22, 48-60`); max 8 shares, excess counted in `cfg->dropped` (`:435-…` via `closeShare`).
- **Trim:** private `trim:60-70` — see §5 for its relationship to `dashTrim`.
- **Line WITHOUT `=`:** skipped, *"the rest still counts"* (`:386-388`). Comment: `#` and `;` (`:384`). BOM skipped (`:357-359`).
- **Overflow policy — reject, never truncate:** `copyValue:74-81` fails the copy if the value doesn't fit, and the share is recorded **invalid with a reason string** (e.g. name/credential/URL too long) instead of being silently cut (`:394-430`). This is the only parser here whose too-long behaviour is user-visible.
- **Duplicates:** duplicate keys inside one share: last wins (plain overwrite). Duplicate share *names*: rejected at close (`checkName`, `:…` in `closeShare` region; case-insensitive via `sameText`). Unknown keys: ignored, *"kept for later versions"* (`:431-433`).
- **Writer roundtrip:** `smbCnfBuildBlock` (`:~560-…`) pre-validates every field against the *parser's* limits and returns −1 rather than emit a block its own reader would reject — the only writer in the audit that is provably inside its reader's grammar.

### 2.8 P6 — Launchstation IPCONFIG (`getIpConfig`, `src/main_startup.c:53-141`)

Buffer `IPCONF_MAX_LEN` = **48** (`include/launchelf.h:353-354`). Method: read ≤47 bytes, NUL-out **every** space/CR/LF in the buffer, then take three consecutive NUL-separated tokens with `%.15s` caps (`:129-141`). No validation (no `sscanf`, no digit check at this layer), no comment support, extra tokens ignored, missing tokens yield whatever zero-filled tail remains. Same file as P2, opposite philosophy: P2 demands exactly 12 numbers or nothing; P6 accepts anything and validates nothing.

### 2.9 P9/P10 — POPSLoader Lua (`.pldrs`, `system.lua`, 11784 lines)

- **Not a line loop (READ).** `PLDR.LoadSettingsNonFatal:6222-…` extracts each key with two anchored patterns — `string.match(data, "\nKEY=([^\n]*)") or string.match(data, "^KEY=([^\n]*)")` — repeated ~25 times (`:6408-6460` region) plus the `SMB_` block via `PLDR.SmbParse:5877-5889`, which uses the same idiom per field. File size: no explicit cap in the loader (whole file via `ReadWholeFile`); contrast the Ember reader's explicit 8192-byte cap (`:8935-8937`).
- **Duplicate keys: FIRST wins** — `string.match` returns the first match in the string. Every C parser in this audit is last-wins. A `.pldrs` with a stale first copy of a key and a corrected second copy loads the **stale** one, and the next save (full rewrite from in-memory state) permanently deletes the correction (INFERRED from first-match + `EncodeSettings` full-rewrite, both READ).
- **Line WITHOUT `=` / malformed / comments:** unmatched keys are simply absent → defaults. There is **no comment syntax**: a `# KEY=` line doesn't match (pattern needs `\nKEY=` at line start), but neither does an *indented* or *spaced* key (` KEY=`, `KEY =`) — no key trimming at all (`:6408-…`). CRLF is pre-normalised for the whole file before matching (`gsub("\r\n?", "\n")`, `:6395-6399`) — the fix is documented in-code as load-bearing for booleans/enums.
- **Value capture:** `[^\n]+` for most keys (empty value ≡ absent) vs `[^\n]*` for paths / `HIDDEN_DEVICES` / SMB / Ember (empty is a real value) — an intentional, per-key distinction (READ across `:6408-6460`).
- **Whitespace:** no trim in the parser. Trimming lives in the *sanitizer*: `PLDR.SmbSanitize:5797-5845` trims string values **except the password field**, whose leading/trailing spaces are deliberately preserved (`:5795-5799, 5810-5825`, location-only), strips `\r\n` from values, caps strings at 255 chars, and shape-validates port/IP fields back to defaults. Non-SMB string settings (paths) get **no** sanitizer — they are stored exactly as captured.
- **Escape / quote:** absent. Writer `EncodeSettings:5891-5941` concatenates raw `tostring` values, LF-only line endings, keys always in the same fixed order, full-file rewrite via `PLDR.SaveSettingsAtomic:6145-6220`.
- **Unknown keys:** dropped — and because the writer only writes known keys, **one save permanently deletes any unknown/hand-added key** from the file. (RiptOPL P1 is the opposite: unknown keys survive a save. Launchstation P4/P5 also drop unknowns on rewrite, since their writers enumerate known keys too.)
- **P10 positional files:** `ParseIpconfigDat:8194-8202` — first line only, `^%s*(%S+)%s+(%S+)%s+(%S+)%s*$`, all-or-nothing like P2. `ParseSmbconfigDat:8204-8235` — line 1 splits on the **first** space (share may contain spaces, `:8228-8229` region and header comment `:8192-8193`); share is trailing-trimmed by the `(.-)%s*$` capture; lines 2/3 map to the credential fields verbatim, blank included. Its writer `RenderSmbConfig:8131-8173` always emits exactly three CRLF lines, credentials included even when blank (guest form) — reader and writer agree on "empty ≠ absent" here, in explicit contrast to RiptOPL's libconfig reader (P1, empty == absent).

---

## 3. Divergence table (READ unless marked)

| Axis | RiptOPL P1 legacy | RiptOPL P1 libconfig | Launchstation P3 `get_CNF_string` | Launchstation P4 `dashKvParse` | Launchstation P5 `smbConfigParse` | SMS P7/P8 | POPSLoader P9 |
|---|---|---|---|---|---|---|---|
| Format | `key=value` | `key = value;` + groups | `KEY = value` | `Key = value` | `KEY = value`, URL closes record | binary struct / positional lines | `KEY=value`, per-key regex |
| Line w/o `=` | prefix if `:`, else **log + skip** | group header or drop | **ABORTS whole file** (`config.c:139-140`) | skip | skip | N/A (blank line = a field, shifts record) | key simply absent |
| Comment | `#` (in line reader, `util.cpp:630`) + `#`,`//`,`/*` | same | **any first char < `'A'`** (incl. digit-led lines) | `# ; [ //` | `# ;` | none | none |
| Key trim | leading only; **trailing space kept** | both sides | name grammar excludes trailing space | both (`dashTrim`) | both (`trim`) | N/A | **none** |
| Value trim | leading space kept; trailing kept (CR stripped) | both sides | leading skipped, **trailing kept** | both | both | trailing `\r` only | none in parser; sanitizer trims except password field |
| Key/value caps | 48 / 256, **silent truncate** | key ≥48 **rejected**, value truncated | none in parser; dest fields 64–1025, mostly **unbounded `strcpy`** | none in parser; dest 256 (24 for clock) | 32/32/256, **reject + reason** | struct fields; text fields **silent truncate + drain** | none in parser; SMB strings capped 255 in sanitizer |
| Escape/quotes | absent | **present, both directions** | absent | absent | absent | absent | absent |
| Unknown key | **kept, written back** | kept (root, verbatim) | ignored; dropped on save | ignored; dropped on save | ignored ("for later versions") | N/A | ignored; **deleted on save** |
| Duplicate key | last wins, collapsed | last wins, collapsed | last wins | scalar last wins; lists **append, no dedup** | last wins; dup share-name rejected | records kept (list) | **FIRST wins** |
| Empty value | stored `""` | **dropped (absent)** | stored `""` | stored `""` | stored (blank cred = guest) | empty field = record likely invalid | per-key: `+` ≡ absent, `*` = real `""` |
| Case sensitivity | exact | exact | mostly exact, few `stricmp` | `stricmp` (but `title.cfg` mode: exact) | case-insensitive (`sameText`) | N/A | exact (uppercase keys) |
| Whole-file cap | 4096 B line buffer (streamed) | same | 128 KiB fallback cap | 64 KiB / 256 KiB / 16 KiB per file | none in parser | fixed 896 B read | none (Ember sub-parser: 8192 B) |
| Failure visibility | `LOG` per malformed line | silent per line | **silent, whole-tail loss** | silent per line | **reason string per bad share** | silent, whole-config loss | silent per key |

Same-key-different-size examples for the shared OPL-family concepts (READ): a *path* value is 255 usable chars in RiptOPL (P1 value cap), 1024 in a Launchstation `LK_Path`-style field (P3), 255 in a Launchstation dash field (P4, `DASH_PATH_MAX 256`), and uncapped-at-parse / 255-after-sanitize in POPSLoader SMB strings (P9). An SMB password field is 255 in RiptOPL's generic value, 31 usable in Launchstation's CNF SMB fields (`[32]`, guarded `:1050-1053`), 31 usable in Launchstation's share blocks (`SMB_CRED_LEN 32`, P5), 63 usable in SMS's list (P8, `[64]`), and 255 in POPSLoader's sidecar (P9) — five different ceilings for the same credential, set by five parsers that never agreed on one. (Sizes only; no values.)

IPCONFIG.DAT — one file, three parsers, three contracts (P2/P6/P10): RiptOPL-legacy demands exactly 12 integers via `sscanf` or sets nothing; Launchstation NUL-splits and validates nothing at parse; POPSLoader's Lua demands exactly 3 whitespace tokens on line 1 via an anchored pattern or sets nothing. A file with a trailing comment or a 4th token parses in Launchstation, and fails whole in the other two (INFERRED from the three READ grammars).

---

## 4. Bugs waiting (ranked)

### C-1 — WORST: Launchstation *writes* a `title.cfg` dialect RiptOPL's reader silently cannot see (cross-repo roundtrip break, fully READ)

Chain, every link line-cited:

1. Launchstation creates a starter `title.cfg` with **spaced** assignments and no semicolons: `"title = %s\r\n"`, `"boot = %s\r\n"`, `"description = \r\n"` … — `src/dash_apps.c:178-187`.
2. `title.cfg` is a genuinely shared file: RiptOPL scans app folders for it and requires **both** keys, looked up exactly: `configGetStr(appConfig, APP_CONFIG_TITLE /*"title"*/)` and `APP_CONFIG_BOOT /*"boot"*/` — `src/sources/appsupport.cpp:735`, `include/appsupport.h:15-16, 19`.
3. RiptOPL's format classifier only treats a spaced line as libconfig if it **also** ends in `;` (and has a legal identifier) — `src/core/config.cpp:155-163`. Launchstation's line has the space but no `;`, so the file latches **LEGACY** (`:1140-1148`).
4. The legacy splitter copies the key verbatim up to `=`: key = `"title "` (trailing space), value = `" …"` (leading space) — `splitAssignment:180-193`. RiptOPL's own header comment describes exactly this failure shape for the libconfig spelling at `config.cpp:86-90`.
5. `ConfigSet::find` is an exact compare (`:257-264`), so `"title "` ≠ `"title"`: the lookup at step 2 fails, and because *both* keys are required, **the app silently does not appear in RiptOPL at all** — no error anywhere (the legacy branch only logs lines with no `=` at all, `:1177`).

Corollaries (INFERRED from READ writer code): if RiptOPL later re-saves that folder's `title.cfg` (rename path, `appsupport.cpp:958-965`: read → `configSetStr("title", …)` → `configWrite`), it **appends** a correct unspaced `title=` line while keeping the spaced originals (legacy writer enumerates all non-`#` entries, `config.cpp:1590-1598`) — the file then contains both dialects, and which one a given reader sees depends on that reader's duplicate rule. Launchstation's own readers are unaffected (P4 trims both sides; P3's name scan stops before the space), and POPSLoader's shipped `bin/POPSLDR/title.cfg` uses the unspaced form, which parses everywhere. The break is one-directional: **Launchstation → RiptOPL**, triggered by a file Launchstation itself creates from its own UI.

### C-2 — One malformed line amputates a Launchstation CNF (P3 abort)

`get_CNF_string` returns `false` on any non-comment line without a reachable `=` (`src/config.c:139-140`), and both callers treat `false` as EOF (`config.c:950`, `main_startup.c:180`). A hand-edited `LAUNCHELF.CNF` with a dotted key, a space inside a key, or one stray word loses **every setting below that line**, silently, on every boot — and the next save rewrites the file from the truncated in-memory state, making the loss permanent (INFERRED: writer enumerates in-memory `setting`, `configBuildSaveText:533-718`). The same file format in the same repo has the lenient parser (P4) that skips such lines; the main config just doesn't use it. P4's header comment (`dash_internal.h:657-660`) proves the abort behaviour is *known* in-repo.

### C-3 — POPSLoader first-wins duplicates + save-deletes-unknowns (P9)

First-match extraction (`system.lua:5877-5889, 6408-6460`) inverts the family-wide last-wins rule: in a hand-merged `.pldrs` the *earlier* (stale) duplicate governs, and because `EncodeSettings:5891-5941` rewrites the file from sanitized in-memory state only, the first save after such a load deletes the corrected duplicate and every unknown key, permanently. No other parser here combines both properties (RiptOPL is last-wins *and* preserves unknowns).

### C-4 — Unbounded copies in Launchstation's main CNF dispatch (P3)

`strcpy`/`sprintf` into 64-byte and 1025-byte `SETTING` fields from a file buffer that can hold a ~128 KiB line (`config.c:962, 973, 1040, 1048`), with the SMB credential keys (`:1050-1053`) as the conspicuous guarded exception — i.e. the guard pattern exists in the same function and wasn't applied to its neighbours. Trigger requires a hand-edited/hostile CNF (the program's own writer can't produce an over-long value), so this is a robustness bug, not a self-roundtrip bug.

### C-5 — Legacy RiptOPL truncates keys *into* collisions (P1)

47-char silent key truncation (`config.cpp:184-185`) + overwrite-on-set (`:363-387`) means two long theme keys sharing a 47-char prefix merge into one entry; the file's own libconfig reader rejects the same key instead (`:846-847`). Internal inconsistency, reachable with the multi-view theme keys the 48-byte size was chosen for (`include/config.h:303-306`).

### C-6 — SMS positional framing has no resync (P8)

`SMS.smb`: one blank/comment/extra line desynchronises every following record (`SMS_Config.c:333-348`), and over-long fields are silently cut and later written back cut (`SMS_FileContext.c:2201-2204`). No key names exist to recover by. Mitigated only by the fact that SMS is normally the file's sole writer.

### C-7 — Writer/reader escape asymmetry check (all repos, READ)

Checked every writer against its reader for the keys the reader parses: RiptOPL legacy (none/none — consistent), RiptOPL libconfig (escape on write `:1020-1040`, un-escape on read `:868-884` — consistent, including the "unescape before the 255 cap so re-saves don't compound" detail), Launchstation P3/P4/P5 (none/none), SMS (none/none), POPSLoader (none/none, values are newline-stripped at sanitize `:5813`). **No escape-in-writer-only or quote-in-reader-only mismatch exists.** The one quoting asymmetry is C-1's cousin: RiptOPL's libconfig reader *strips* quotes, so a legacy file whose value legitimately begins/ends with `"` is only safe because the format latch keeps it on the legacy path — a legacy file whose first meaningful line happens to satisfy all three libconfig tests would be re-read *and re-written* in the other dialect (format inheritance, `:1140-1148, 1588-1589`).

---

## 5. Named duplicated functions (near-copies, with diff evidence)

Extracted and diffed during this audit (scratch in `/tmp/cfgx/`, not retained):

1. **`dashTrim` vs `trim` — same repo, verbatim copy.** `Launchstation/src/dash_store.c:53-63` vs `Launchstation/src/smb_cnf.c:60-70`: `diff` of the two 11-line extractions differs in **exactly one line** — the signature (`char *dashTrim(char *s)` vs `static char *trim(char *s)`); the other 10 lines are byte-identical. `smb_cnf.c` is explicitly host-testable standalone ("Text only, no device IO", `smb_cnf.c:1-13`), which explains — but does not require — the copy: `dashTrim` is a non-static export in the same link.
2. **`get_CNF_string` vs `dashKvParse` — same repo, divergent re-implementation.** `config.c:111-160` (50 lines) vs `dash_store.c:65-103` (39 lines plus the 11-line trim): a full `diff` runs to 102 lines of churn — same job (skip WS/comments → split at first `=` → trim → dispatch), opposite malformed-line policy, different comment sets, different name grammar. The divergence is *documented intent* (`dash_internal.h:657-660`), i.e. the second parser was written because the first's abort behaviour was unacceptable for dashboard files — and the first was left in place for the main CNF and `SYSTEM.CNF`.
3. **`preloadCNF` is shared, its parser is not:** `config.c:515-531`/`435-513` feeds both `loadConfig` (P3) and `readSystemCnf` (`main_startup.c:178-182`), so P3's abort also governs disc `SYSTEM.CNF` parsing.
4. **Cross-repo, same *file* three times:** IPCONFIG.DAT parsers P2 (`RiptOPL config.cpp:731-774`, `sscanf`), P6 (`Launchstation main_startup.c:53-141`, NUL-split), P10 (`POPSLoader system.lua:8194-8202`, Lua pattern) share no code and no contract (§3). Likewise `title.cfg`: parsed by RiptOPL P1 and Launchstation P4/`metaKv`, written by Launchstation (`dash_apps.c:178-187`) and shipped by POPSLoader (`bin/POPSLDR/title.cfg`, unspaced form) — the family's only true shared config *format*, and the site of C-1.
5. **Cross-repo, same *pattern* independently:** "skip malformed, keep going" was independently implemented four times (RiptOPL legacy log+skip, P4, P5, P9-absent-key); "reject don't truncate" exactly once (P5 `copyValue`); "first wins" exactly once (P9). No function body is a cross-repo near-copy — duplication across repos is at the *format* level (IPCONFIG, title.cfg, OPL per-game keys), not the code level (READ: the four codebases' parsers share no identifier/structure beyond the ubiquitous `strchr('=')` idiom).

---

## 6. LESS-NOT-MORE verdicts (per repo-pair)

- **Launchstation internal (P3 vs P4 vs P5) — CONSOLIDATE, proof C-2 + §5.1/§5.2.** Three parsers, two trim copies (one literally byte-identical bar the signature), and a documented policy split where the *main* config uses the parser its own codebase calls out as the stopping one. Keep: `dashKvParse` as the single line parser (it already serves settings, lists, library, themes, cloud, and `title.cfg`), `smbConfigParse` as a *validator/record layer on top of it* (its reject-with-reason and URL-closes-record semantics are real added value, not duplication), and retire `get_CNF_string` — or, minimally, change its missing-`=` path to skip-and-continue, which is a one-branch change with P4 as the existence proof. Keep `getIpConfig` separate (different format: positional, keyless).
- **RiptOPL ↔ Launchstation — KEEP SEPARATE parsers, FIX THE SHARED FORMAT (title.cfg), proof C-1.** Their main configs are not shared files and their stores are structurally different (generic ordered list vs fixed `SETTING` struct); a shared parser would serve neither. What *is* shared — `title.cfg` (and per-game/app conventions) — needs a format rule, not shared code: writers must emit the unspaced `key=value` form (the only dialect all three readers accept; POPSLoader's shipped file already does), or RiptOPL's legacy splitter must trim the key. One side changing is sufficient; Launchstation's starter template (`dash_apps.c:180-181`) is the smaller, newer surface.
- **RiptOPL ↔ POPSLoader — KEEP SEPARATE, with one contract note.** No shared files except via POPSTARTER's `.DAT`s, which POPSLoader owns in Lua (P10) and RiptOPL doesn't parse. The Ember `settings.txt` colon format (P10) and RiptOPL's `$Ember*` per-game keys (`include/config.h:56-59`) are two encodings of the same five concepts in two files — flag as a format-level duplication to watch, not a code consolidation target (READ both key sets; no shared file today).
- **SMS ↔ everyone — KEEP SEPARATE, proof §2.3.** SMS's binary config cannot converge with text parsers without breaking every existing `SMS.cfg` (the version-14 gate is precisely the migration wall, `SMS_Config.h:59-61`). Its one text format, the positional SMB list (P8), has no counterpart elsewhere (the other three all use keyed or POPSTARTER-positional formats with different field orders/limits — §3 password-size row). Nothing to consolidate that wouldn't be a breaking format change; the honest LESS-NOT-MORE move in SMS is internal: none identified in scope (its parser count is already minimal — one binary load, one positional list).
- **POPSLoader internal — CONSOLIDATE the extraction idiom, keep the parsers.** ~25 hand-unrolled two-pattern `string.match` extractions (`system.lua:6408-6460`) plus the same idiom again in `SmbParse` and the Ember block are one missing helper (`matchKey(data, key)`); the `.DAT` parsers (P10) are genuinely different grammars and stay. Also the one-line policy fix with the highest value in this repo: document or change first-wins (C-3) — every other parser in the family is last-wins, so the Lua side is where a hand-edited file behaves unlike anywhere else.

**Net count if the verdicts were taken:** 10 parsers → 7 (Launchstation 4→2 line parsers + 1 positional; POPSLoader's idiom helper doesn't reduce parser count but reduces extraction sites ~27→1), zero format changes except Launchstation's `title.cfg` template spacing — the single change that fixes the audit's worst bug.

*End of Topic 3. Method note: all functions above were read in full at the pinned HEADs; diffs in §5.1–5.2 were run on extracted line ranges during this audit. Hardware behaviour (e.g. whether RiptOPL's app scan is the only consumer of a Launchstation-created title.cfg on a real card) is not claimed — C-1 is a code-level certainty about the parse, stated as such.*
