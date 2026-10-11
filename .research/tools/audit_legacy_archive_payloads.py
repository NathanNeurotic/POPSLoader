#!/usr/bin/env python3
"""Read-only byte integrity and container checks for legacy gh-pages archives.

Use after checking out the *actual* gh-pages branch. The source-controlled
legacy inventory pins Git blob identities and sizes. The separately retained
historical SHA256SUMS.txt pins byte digests for old 7z files; it is NOT a
current download availability list or a malware-safety certificate.

No member is extracted to disk or executed. 7-Zip test mode decodes/CRC-tests
the compressed streams. Directory metadata is bounded to avoid obvious bombs.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
LEDGER = ROOT / "research" / "legacy-gh-pages-inventory.tsv"
CHECKSUM_RE = re.compile(r"^([a-f0-9]{64})  ([^\r\n]+)$")
EXPECTED_RETAINED_ARCHIVES = 14
EXPECTED_MANIFEST_ENTRIES = 17
EXPECTED_WITHHELD_REFERENCE = "DISCS_POOPER.BAT.7z"
OTHER_CURRENT_DOWNLOADS = {"pfsshell-0.2a.7z", "RadHostClient_1.8a.7z"}
MAX_ARCHIVE_SIZE = 8_000_000
MAX_UNCOMPRESSED = 256_000_000
MAX_MEMBER = 128_000_000
MAX_ENTRIES = 5000


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for part in iter(lambda: f.read(1024 * 1024), b""):
            h.update(part)
    return h.hexdigest()


def git_blob(path: Path) -> str:
    body = path.read_bytes()
    return hashlib.sha1(
        b"blob " + str(len(body)).encode() + b"\0" + body
    ).hexdigest()


def original_inventory() -> list[dict[str, str]]:
    with LEDGER.open(encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(
            (line for line in f if line.strip() and not line.startswith("#")),
            delimiter="\t"
        ))
    if len(rows) != 20:
        raise ValueError(f"Expected 20 known legacy paths, got {len(rows)}")
    if len({row["path"] for row in rows}) != len(rows):
        raise ValueError("Duplicate path in legacy inventory")
    return rows


def historical_checksums(path: Path) -> dict[str, str]:
    checksums: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        match = CHECKSUM_RE.fullmatch(line)
        if not match:
            raise ValueError(f"Malformed SHA256SUMS line: {line!r}")
        digest, name = match.groups()
        if "/" in name or "\\" in name or name in checksums:
            raise ValueError(f"Unsafe or duplicated checksum entry: {name!r}")
        checksums[name] = digest
    if len(checksums) != EXPECTED_MANIFEST_ENTRIES:
        raise ValueError("Historical checksum manifest member count changed")
    return checksums


def archive_members(archive: Path, executable: str) -> tuple[int, int, int]:
    cmd = [executable, "l", "-slt", str(archive)]
    p = subprocess.run(cmd, check=False, text=True, capture_output=True, timeout=60)
    if p.returncode or "----------" not in p.stdout:
        raise ValueError(f"Unable to parse 7z directory for {archive.name}")
    count, total, nested = 0, 0, 0
    for section in p.stdout.split("----------", 1)[1].split("\n\n"):
        attributes: dict[str, str] = {}
        for row in section.splitlines():
            if " = " in row:
                key, value = row.split(" = ", 1)
                attributes[key] = value
        if not attributes.get("Path") or attributes.get("Folder") == "+":
            continue
        count += 1
        if count > MAX_ENTRIES:
            raise ValueError(f"Archive has excessive members: {archive.name}")
        name = attributes["Path"]
        if name.startswith(("/", "\\")) or ".." in name.replace("\\", "/").split("/"):
            raise ValueError(f"Unsafe archive member path: {archive.name} {name!r}")
        size = int(attributes.get("Size", "-1"))
        if size < 0 or size > MAX_MEMBER:
            raise ValueError(f"Unexpected decoded member length: {archive.name} {name!r}")
        total += size
        if total > MAX_UNCOMPRESSED:
            raise ValueError(f"Excessive total uncompressed length: {archive.name}")
        if name.lower().endswith((".exe", ".elf", ".kelf", ".irx", ".dll", ".bat",
                                 ".com", ".cmd", ".vbs", ".ps1", ".rar", ".zip", ".7z")):
            nested += 1  # metadata only; NOT a malware detection
    if count == 0:
        raise ValueError(f"No regular 7z members found: {archive.name}")
    return count, total, nested


def audit(root: Path):
    rows = original_inventory()
    preserve = [r for r in rows if r["policy"] == "preserve"]
    archives = [r for r in preserve if r["path"].lower().endswith(".7z")]
    if len(preserve) != 17 or len(archives) != EXPECTED_RETAINED_ARCHIVES:
        raise ValueError("Unexpected retained legacy file count")
    sums = historical_checksums(root / "downloads/SHA256SUMS.txt")
    known = {Path(r["path"]).name for r in archives}
    expected = known | OTHER_CURRENT_DOWNLOADS | {EXPECTED_WITHHELD_REFERENCE}
    if set(sums) != expected:
        raise ValueError("Unexpected checksum entries: missing="
                         + str(sorted(expected - set(sums))) + " extra="
                         + str(sorted(set(sums) - expected)))
    if (root / "downloads" / EXPECTED_WITHHELD_REFERENCE).exists():
        raise ValueError("Withheld historical checksum entry is publicly available")
    print("Historical checksum list: 14 retained legacy 7z, "
          "2 separately generated archives, 1 intentionally WITHHELD record. "
          "It is NOT a live-download inventory.")
    exe = next((shutil.which(name) for name in ("7zz", "7z", "7za")
                if shutil.which(name)), None)
    if not exe:
        raise ValueError("7-Zip command required to validate archive member CRCs")
    inspected = []
    for record in archives:
        path = root / record["path"]
        if not path.is_file() or path.is_symlink():
            raise ValueError(f"Legacy archive vanished: {record['path']}")
        if path.stat().st_size != int(record["bytes"]):
            raise ValueError(f"Changed legacy byte count: {record['path']}")
        if path.stat().st_size > MAX_ARCHIVE_SIZE:
            raise ValueError(f"Oversized legacy archive: {record['path']}")
        if git_blob(path) != record["git_sha1"]:
            raise ValueError(f"Legacy Git object mismatch: {record['path']}")
        digest = sha256(path)
        if sums[path.name] != digest:
            raise ValueError(f"SHA256SUMS disagreement: {record['path']}")
        count, decoded, risky_names = archive_members(path, exe)
        p = subprocess.run([exe, "t", "-bd", "-y", str(path)],
                           check=False, text=True, capture_output=True, timeout=120)
        if p.returncode or "Everything is Ok" not in p.stdout:
            raise ValueError(f"Archive decompression/CRC test failed: {path.name} "
                             + (p.stderr or p.stdout)[-350:])
        inspected.append(path.name)
        print(f"PASS {path.name}: archiveSHA256={digest} "
              f"members={count} unpacked_bytes={decoded} "
              f"executable_or_nested_extension_members={risky_names}")
    for record in preserve:
        if record["path"].lower().endswith(".7z"):
            continue
        path = root / record["path"]
        if not path.is_file() or path.stat().st_size != int(record["bytes"]):
            raise ValueError(f"Retained ancillary file absent/changed: {record['path']}")
        if git_blob(path) != record["git_sha1"]:
            raise ValueError(f"Legacy ancillary Git object mismatch: {record['path']}")
        print(f"PASS retained ancillary: {record['path']}")
    for name in sorted(OTHER_CURRENT_DOWNLOADS):
        p = root / "downloads" / name
        if not p.is_file():
            raise ValueError(f"Checksum-listed generated archive missing: {name}")
        current = sha256(p)
        if current != sums[name]:
            raise ValueError(f"Historical checksum disagrees with served {name}")
        print(f"PASS generated-file checksum crosscheck: {name} {current}")
    print(f"PASS: {len(inspected)}/{EXPECTED_RETAINED_ARCHIVES} legacy archives "
          "are byte-verified and pass full container integrity tests.")
    print("NOTE: none of these tests establish software safety, version "
          "authenticity, legal redistribution rights or console compatibility.")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("published", type=Path)
    args = ap.parse_args()
    try:
        audit(args.published)
    except (ValueError, OSError, subprocess.TimeoutExpired) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
