#!/bin/sh
set -eu
# Pin the reference install assets so POPS and EMBER cannot change
# unexpectedly when upstream updates. POPS is pinned separately from Ember.
# Ember Watch verifies Gageformer's release digest and updates the Ember pin.
RIPTOPL_SHA=ebb62e1d5db8099bb5b51b4b430a4d1914529bd2
RIPTOPL_EMBER_SHA=ebb62e1d5db8099bb5b51b4b430a4d1914529bd2
git clone --quiet --filter=blob:none --no-checkout \
  https://github.com/NathanNeurotic/Open-PS2-Loader.git /tmp/riptopl-kit
git -C /tmp/riptopl-kit checkout --quiet "$RIPTOPL_SHA" -- POPS Example/APP_RIPTOPL-OFFICIALROLLING-VERSION.ZIP/POPS .github/scripts/verify_psu_with_psumanager.cpp third_party/PSUManager/src/core
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
# Fail closed if any reference POPS or Ember component was lost or changed.
# Only the deliberately added ExampleGame placeholder may differ from source.
python3 - <<'PY'
from pathlib import Path
for part in ('POPS', 'EMBER'):
    original = Path('/tmp/riptopl-kit') / part
    package = Path('dist_root') / part
    files = [p for p in original.rglob('*') if p.is_file()]
    if not files:
        raise SystemExit(f"Empty pinned RiptOPL {part} source")
    for path in files:
        target = package / path.relative_to(original)
        if not target.is_file() or target.read_bytes() != path.read_bytes():
            raise SystemExit(f"Missing or modified reference payload: {path}")
    print(f"{part}: verified {len(files)} pinned RiptOPL files")
PY
# Replace the historical reference bundle's Alpha UDPFS payload and notices.
# The existing .udpfs suffix now always means the full-network 1.0.0 release.
cp bin/POPSLDR/usbd.irx.udpfs bin/POPSLDR/usbhdfsd.irx.udpfs dist_root/POPS/
rm -rf dist_root/POPS/UDPFS-NOTICES
mkdir -p dist_root/POPS/UDPFS-NOTICES
cp docs/third_party/okeanos_udpfs/* dist_root/POPS/UDPFS-NOTICES/
cp docs/UDPFS_BDMA.md dist_root/POPS/UDPFS_BDMA.md

test -s dist_root/EMBER/ember.elf
test -s dist_root/EMBER/LICENSE-BETA.txt
test ! -e dist_root/EMBER/bios.bin
# Never accidentally distribute user-owned BIOS dumps anywhere in the kit.
if find dist_root -type f -iname 'bios.bin' | grep -q .; then
  echo 'ERROR: BIOS file found in distribution' >&2
  exit 1
fi
# ExampleGame.bin is deliberately empty: a game-image placement
# illustration, not copyrighted content or a bootable PS1 game.
printf 'FILE "ExampleGame.bin" BINARY\n  TRACK 01 MODE2/2352\n    INDEX 01 00:00:00\n' > dist_root/EMBER/games/ExampleGame/ExampleGame.cue
: > dist_root/EMBER/games/ExampleGame/ExampleGame.bin
python3 tools/package_psu.py build dist_root/APPS/PS1_POPSLOADER dist_root/PS1_POPSLOADER.psu
# Independent cross-check with RiptOPL's original PSUManager C++ reader:
# reject malformed archives, nested files, extra entries and content drift.
g++ -std=c++17 -O2 /tmp/riptopl-kit/.github/scripts/verify_psu_with_psumanager.cpp \
  /tmp/riptopl-kit/third_party/PSUManager/src/core/PsuArchive.cpp \
  /tmp/riptopl-kit/third_party/PSUManager/src/core/PsuDate.cpp \
  -o /tmp/popsloader-verify-psu
/tmp/popsloader-verify-psu dist_root/PS1_POPSLOADER.psu dist_root/APPS/PS1_POPSLOADER
cp dist_root/PS1_POPSLOADER.psu PS1_POPSLOADER.psu
(cd dist_root && find APPS POPS EMBER -type f | LC_ALL=C sort | zip -X -9 ../POPSLOADER.zip -@ >/dev/null)
(cd dist_root && zip -X -9 ../POPSLOADER.zip PS1_POPSLOADER.psu >/dev/null)

python3 tools/test_udpfs_integration.py POPSLOADER.zip
