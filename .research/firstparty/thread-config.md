## From the official thread — config-table & direct hex edits

> Sourced from the [official psx-place POPStarter thread](https://www.psx-place.com/threads/popstarter.19139/).
> **krHACKen** items are authoritative.

- **`$HDTVFIX` can be applied by direct hex edit:** config-table offset **`$412`**, change the value from
  `00` to `01` inside `POPSTARTER.ELF`. Use this when the `CHEATS.TXT` route green-screens on internal HDD.
  *(krHACKen)*
- **Offset `$413` is the USB device access / detection-retry delay** (default `0x02`). If one USB HDD/stick
  works but another isn't detected, hex-edit `$413` up to `0x04`–`0x05` (higher for slow externals). This is
  the byte that actually fixes USB detection — **not** the `$USBDELAY_#` cheat (which patches POPS for
  streaming). *(jolek / Okeanos)*
- **POPStarter ships a built-in per-game default-config table.** Example: **Final Fantasy IX** has
  `$COMPATIBILITY 0x04` enabled by default (since WIP02), so it "just works" with no CHEATS.TXT. *(Peppe90)*
- **The SMB-mode startup debug overlay cannot be disabled** in the 2019-06-05 build — there is no CHEATS.TXT
  or config switch for it; it is cosmetic. *(VanhuX)*

> See the full per-offset table in the [Config Table](config.html) section above; these thread notes pin down
> `$412`/`$413` with concrete edit values.
