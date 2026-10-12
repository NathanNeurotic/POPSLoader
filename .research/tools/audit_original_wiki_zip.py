#!/usr/bin/env python3
"""Check published light-gun revision and authentic, conditional original Git ZIP.

This does not retrieve missing binaries or publish them. When the exact
2,102,657-byte source is present in .research/downloads, the generator
publishes it after SHA-256 validation. When absent, the site must say it
is NOT hosted and must never expose a dead download link.
"""
import hashlib
from pathlib import Path
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SITE = ROOT / "site"
ARCHIVE = "popstarter-documentation-stuff-wiki-git-20240731.zip"
SHA256 = "d0c243d91e417988825ed92b440224ed46cbbf448d0b67528e0957c15c0d029a"
EXPECTED_BYTES = 2_102_657
EXPECTED_SOURCE_HEAD = "960d675d278296a3a62143410b38aa8882d21a79"
EXPECTED_MODULE_LINE = (
    "For light gun, first .IRX might be USBD.IRX and second .IRX USBGUN.IRX;"
)


def audit():
    source = (ROOT / "wiki/ps1-special-devices.md").read_text(encoding="utf-8")
    rendered = (SITE / "wiki/ps1-special-devices.html").read_text(encoding="utf-8")
    if EXPECTED_MODULE_LINE not in source or EXPECTED_MODULE_LINE not in rendered:
        raise ValueError("Original wiki's corrected USBGUN.IRX example absent")
    if "second .IRX USBD.IRX;" in rendered:
        raise ValueError("Outdated duplicate USBD.IRX error reappeared")
    if "AKuHAK" not in source or "AKuHAK" not in rendered:
        raise ValueError("Original special-device tutorial attribution lost")

    downloads = (SITE / "downloads.html").read_text(encoding="utf-8")
    staged = ROOT / "downloads" / ARCHIVE
    hosted = SITE / "downloads" / ARCHIVE
    if not staged.exists():
        if hosted.exists():
            raise ValueError("Generated site has untracked original ZIP")
        if ("Original wiki Git history ZIP — not yet hosted" not in downloads or
                "Status: not hosted; no download link." not in downloads):
            raise ValueError("Unhosted original wiki ZIP lacks transparent status")
        if f'href="downloads/{ARCHIVE}"' in downloads:
            raise ValueError("Generated a dead link for absent wiki ZIP")
        print("PASS: corrected USBGUN.IRX documentation and honest missing-ZIP notice")
        return

    if not staged.is_file() or staged.stat().st_size != EXPECTED_BYTES:
        raise ValueError("Wrong original wiki ZIP byte length")
    with staged.open("rb") as stream:
        actual = hashlib.file_digest(stream, "sha256").hexdigest()
    if actual != SHA256:
        raise ValueError("Supplied original wiki ZIP changed: SHA256 mismatch")
    if not hosted.is_file():
        raise ValueError("Verified original ZIP not copied into site")
    with hosted.open("rb") as stream:
        generated_hash = hashlib.file_digest(stream, "sha256").hexdigest()
    if generated_hash != SHA256:
        raise ValueError("Published ZIP differs from supplied original")
    with zipfile.ZipFile(staged) as z:
        if z.testzip() is not None:
            raise ValueError("Historical wiki ZIP CRC failure")
        names = set(z.namelist())
        for expected in (
            "wiki/.git/HEAD",
            "wiki/.git/config",
            "wiki/ps1-special-devices.textile",
        ):
            if expected not in names:
                raise ValueError("Original archive missing expected Git/source member " + expected)
        head = z.read("wiki/.git/HEAD").decode("ascii").strip()
        if not (head.startswith("ref:") or head == EXPECTED_SOURCE_HEAD):
            raise ValueError("Unexpected original Git HEAD")
    if f'href="downloads/{ARCHIVE}"' not in downloads:
        raise ValueError("Verified archive is staged but not linked from Downloads")
    if "Original wiki Git history ZIP — not yet hosted" in downloads:
        raise ValueError("Published archive incorrectly marked unavailable")
    if "AstroSnail" not in downloads:
        raise ValueError("Archive contributor attribution disappeared")
    print("PASS: original wiki ZIP identical, CRC-valid, attributed and linked")


if __name__ == "__main__":
    try:
        audit()
    except (OSError, ValueError, zipfile.BadZipFile) as exc:
        print("FAIL:", exc, file=sys.stderr)
        raise SystemExit(1)
