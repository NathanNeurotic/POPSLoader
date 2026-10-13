#!/bin/sh
set -eu
# Pin the reference install assets so POPS and EMBER cannot change
# unexpectedly when upstream updates. POPS is pinned separately from Ember.
# Ember Watch verifies Gageformer's release digest and updates the Ember pin.
RIPTOPL_SHA=ebb62e1d5db8099bb5b51b4b430a4d1914529bd2
RIPTOPL_EMBER_SHA=ebb62e1d5db8099bb5b51b4b430a4d1914529bd2
git clone --quiet --filter=blob:none --no-checkout \
  https://github.com/NathanNeurotic/Open-PS2-Loader.git /tmp/riptopl-kit
git -C /tmp/riptopl-kit checkout --quiet "$RIPTOPL_SHA" -- POPS Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS
git -C /tmp/riptopl-kit checkout --quiet "$RIPTOPL_EMBER_SHA" -- EMBER
rm -rf dist_root POPSLOADER.zip PS1_POPSLOADER.psu
mkdir -p dist_root/APPS/PS1_POPSLOADER dist_root/POPS dist_root/EMBER/games/ExampleGame
test -s bin/POPSLOADER.ELF
test -s bin/POPSLDR/POPSTARTER.ELF
cp bin/POPSLOADER.ELF dist_root/APPS/PS1_POPSLOADER/POPSLOADER.ELF
for f in POPSTARTER.ELF icon.sys list.icn copy.icn del.icn title.cfg APPINFO.PBT; do
  test -s "bin/POPSLDR/$f"
  cp "bin/POPSLDR/$f" "dist_root/APPS/PS1_POPSLOADER/$f"
done
cp -a /tmp/riptopl-kit/POPS/. dist_root/POPS/
cp -a /tmp/riptopl-kit/EMBER/. dist_root/EMBER/
for f in CHEATS.TXT IGR_BG.TM2 IGR_NO.TM2 IGR_YES.TM2 POPSTARTER.KELF TROJAN_7.BIN; do
  test -s "/tmp/riptopl-kit/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/$f"
  cp "/tmp/riptopl-kit/Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS/$f" "dist_root/POPS/$f"
done
test -s dist_root/EMBER/ember.elf
test -s dist_root/EMBER/LICENSE-BETA.txt
test ! -e dist_root/EMBER/bios.bin
# ExampleGame.bin is deliberately empty: a game-image placement
# illustration, not copyrighted content or a bootable PS1 game.
printf 'FILE "ExampleGame.bin" BINARY\n  TRACK 01 MODE2/2352\n    INDEX 01 00:00:00\n' > dist_root/EMBER/games/ExampleGame/ExampleGame.cue
: > dist_root/EMBER/games/ExampleGame/ExampleGame.bin
python3 tools/package_psu.py build dist_root/APPS/PS1_POPSLOADER dist_root/PS1_POPSLOADER.psu
cp dist_root/PS1_POPSLOADER.psu PS1_POPSLOADER.psu
(cd dist_root && find APPS POPS EMBER -type f | LC_ALL=C sort | zip -X -9 ../POPSLOADER.zip -@ >/dev/null)
(cd dist_root && zip -X -9 ../POPSLOADER.zip PS1_POPSLOADER.psu >/dev/null)

