## First-party display & PAL notes (maintainer-tested)

> First-party, tested by the POPSLoader maintainer.

### `PATCH_8.BIN` — "Black &amp; White? NTSC on PAL" fix
- Place `PATCH_8.BIN` into the game's **VMC folder** (the actual file is 64 bytes). It forces the PAL path,
  which fixes the black-and-white picture you get when a PAL title runs in POPS' native NTSC — equivalent to
  the `$FORCEPAL` cheat.
- You may also need a `CHEATS.TXT` containing `$SAFEMODE` then `$YPOS_40` (raise/lower the number to move the
  screen down/up).
- VMC-folder paths for `<vcd name>.VCD`: `hdd:/__common/POPS/<name>/`, `mass:/POPS/<name>/`, `smb:/POPS/<name>/`.

### `$HDTVFIX` and vertical positioning — the reality
- `$HDTVFIX` only fixes HDTV / component **compatibility**; it does **not** resize the image.
- For vertical positioning use `$YPOS_##` in `CHEATS.TXT` (higher value = image moves **down**). Starting
  recipe: `$HDTVFIX` + `$YPOS_10`, then test `$YPOS_5 / 10 / 15 / 20` until centred. Works only in normal
  PAL/NTSC modes, **not** with `$480p`; there is no universal default (it's game-dependent).
- POPStarter has horizontal controls (`$XPOS_####`, `$DWSTRETCH_####`, `$DWCROP_####`) but **no** real
  vertical height-shrink/crop. If the image is cut off at **both** top and bottom, that's TV overscan — use
  the TV's "Just Scan / Screen Fit / Full Pixel / 1:1" setting.
