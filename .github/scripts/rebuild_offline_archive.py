#!/usr/bin/env python3
"""Rebuild the offline POPStarter archive after all recovered 7z files arrive.

Runs in GitHub Actions; checks the SHA-256 manifest, preserves old archive files,
and refuses partial or mismatched uploads. Never executes archived binaries.
"""
from __future__ import annotations

import hashlib
import os
from pathlib import Path
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]
DOWNLOADS = ROOT / "downloads"
OFFLINE = ROOT / "popstarter-docs-archive.zip"
WITHHELD = "Disc_Combining_Kits.7z"
NEW = (
    "BATCHER_0.3.1.EXE.7z", "Compatibility_Modes.7z", "CUE2POPS_2.3.7z",
    "DEBUG_AND_HALT.7z", "DISCS_POOPER.BAT.7z",
    "hddosd_sample_files.7z", "IGR_Behaviour_Modifiers.7z", "IGR_sample_kit.7z",
    "IGR_textures_-_English_pack.7z", "IGR_textures_-_French_pack.7z",
    "IGR_textures_-_German_Pack.7z", "IGR_textures_-_Polish_pack.7z",
    "IGR_textures_-_Portuguese_pack.7z", "IGR_textures_-_Spanish_pack.7z",
    "uLE_kHn_20191110_2.7z",
)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> None:
    if (DOWNLOADS / WITHHELD).exists():
        raise RuntimeError(f"Withheld file is present in public downloads: {WITHHELD}")
    missing = [name for name in NEW if not (DOWNLOADS / name).is_file()]
    if missing:
        print(f"WAITING: {len(missing)} original files not yet uploaded: {', '.join(missing)}")
        return

    sums_file = DOWNLOADS / "SHA256SUMS.txt"
    records = dict(line.split("  ", 1) for line in sums_file.read_text(encoding="utf-8").splitlines() if "  " in line)
    expected = {name: sha for sha, name in records.items()}
    if WITHHELD in expected:
        raise RuntimeError("Withheld file remains in public SHA256SUMS.txt")
    for name in NEW:
        if not expected.get(name) or digest((DOWNLOADS / name).read_bytes()) != expected[name]:
            raise RuntimeError(f"SHA-256 mismatch for {name}; not rebuilding the offline archive")

    wanted = {f"downloads/{name}": (DOWNLOADS / name).read_bytes() for name in NEW}
    wanted["downloads/SHA256SUMS.txt"] = sums_file.read_bytes()
    wanted["downloads/Disc_Combining_Kits_SECURITY_NOTICE.txt"] = (DOWNLOADS / "Disc_Combining_Kits_SECURITY_NOTICE.txt").read_bytes()
    wanted["downloads.html"] = (ROOT / "downloads.html").read_bytes()
    wanted["multidisc.html"] = (ROOT / "multidisc.html").read_bytes()
    wanted["data/search-index.json"] = (ROOT / "data/search-index.json").read_bytes()

    with zipfile.ZipFile(OFFLINE, "r") as original:
        paths = original.namelist()
        prefixes = [path[:-len("downloads.html")] for path in paths if path.endswith("downloads.html")]
        if len(prefixes) != 1:
            raise RuntimeError(f"Unexpected downloads page in offline ZIP: {prefixes}")
        prefix = prefixes[0]
        pending = {prefix + name: data for name, data in wanted.items()}
        withheld_path = prefix + "downloads/" + WITHHELD
        if all(path in paths and digest(original.read(path)) == digest(data) for path, data in pending.items()) and withheld_path not in paths:
            print("ALREADY CURRENT: offline ZIP contains all recovered archives")
            return
        fd, temp_name = tempfile.mkstemp(prefix="popsdocs-", suffix=".zip", dir=ROOT)
        os.close(fd)
        try:
            with zipfile.ZipFile(temp_name, "w") as output:
                for member in original.infolist():
                    if member.filename == withheld_path:
                        continue  # Deliberately remove this risk from the published ZIP.
                    data = pending.pop(member.filename, None)
                    output.writestr(member, original.read(member.filename) if data is None else data)
                for path, data in pending.items():
                    output.writestr(path, data, compress_type=zipfile.ZIP_STORED)
            with zipfile.ZipFile(temp_name) as checked:
                if withheld_path in checked.namelist():
                    raise RuntimeError("Withheld archive survived offline ZIP rewrite")
                if not all(prefix + path in checked.namelist() for path in wanted):
                    raise RuntimeError("Offline ZIP is missing required recovery files")
                bad = checked.testzip()
                if bad:
                    raise RuntimeError(f"ZIP CRC validation failed for {bad}")
            os.replace(temp_name, OFFLINE)
        finally:
            if os.path.exists(temp_name):
                os.remove(temp_name)

    print(f"UPDATED: complete offline documentation ZIP ({OFFLINE.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
