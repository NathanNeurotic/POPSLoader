#!/usr/bin/env python3
"""Verify legacy Pages-only Git objects; remove only source-authorized exceptions."""
import csv
import hashlib
import json
from pathlib import Path
import tempfile
import sys

LEDGER = Path(__file__).resolve().parents[1] / "research/legacy-gh-pages-inventory.tsv"
MANIFEST = ".docs-generated-source-manifest.json"


def oid(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def inventory():
    with LEDGER.open(encoding="utf-8") as file:
        rows = list(csv.DictReader((x for x in file if x.strip() and not x.startswith("#")), delimiter="\t"))
    if len(rows) != 20 or sum(r["policy"] == "retire" for r in rows) != 3:
        raise ValueError("Expected frozen 20-file inventory, exactly 3 retired")
    paths = set()
    for row in rows:
        name = row["path"]
        if (name in paths or name.startswith("/") or
                ".." in Path(name).parts or "\\" in name or
                row["policy"] not in ("preserve", "retire") or
                len(row["git_sha1"]) != 40):
            raise ValueError("Invalid legacy inventory row: " + name)
        paths.add(name)
    return rows


def audit(root, rows, strict=False):
    meta = root / MANIFEST
    if not meta.is_file():
        raise ValueError("Missing manifest of generator-owned Pages paths")
    generated = set(json.loads(meta.read_text(encoding="utf-8"))["files"])
    names = {r["path"] for r in rows}
    if generated & names:
        raise ValueError("Legacy and generator ownership overlap")
    published = {p.relative_to(root).as_posix() for p in root.rglob("*") if p.is_file()}
    unexpected = published - generated - names - {MANIFEST, ".git"}
    if unexpected:
        raise ValueError("Untracked Pages-only files: " + ", ".join(sorted(unexpected)))
    for row in rows:
        name = row["path"]
        file = root / name
        if not file.exists():
            if row["policy"] == "preserve":
                raise ValueError("Preserved historical file disappeared: " + name)
            continue
        if row["policy"] == "retire" and strict:
            raise ValueError("Policy-withheld/obsolete file remains public: " + name)
        if file.is_symlink() or not file.is_file():
            raise ValueError("Not a regular file: " + name)
        b = file.read_bytes()
        if len(b) != int(row["bytes"]) or oid(b) != row["git_sha1"]:
            raise ValueError("Legacy file changed without tracked provenance update: " + name)
    print(f"PASS: {sum(r['policy'] == 'preserve' for r in rows)} preserved legacy assets; "
          f"{sum(r['policy'] == 'retire' for r in rows)} retired paths")


def retire(root, rows):
    audit(root, rows)
    for row in rows:
        if row["policy"] == "retire":
            p = root / row["path"]
            if p.exists():
                p.unlink()
                print("RETIRE (policy): " + row["path"])
    audit(root, rows, strict=True)


def offline(site):
    import zipfile
    banned = ("discs_pooper", "disc_pooper", "disc_combining_kits",
              "popstarter_elfs-batcher")
    bundle = site / "popstarter-docs-archive.zip"
    if not bundle.is_file():
        raise ValueError("No generated offline ZIP")
    with zipfile.ZipFile(bundle) as z:
        bad = z.testzip()
        if bad:
            raise ValueError("Offline ZIP CRC failed: " + bad)
        if not {"index.html", "downloads.html"}.issubset(z.namelist()):
            raise ValueError("Offline ZIP lacks mandatory documents")
        for member in z.namelist():
            if any(b in member.casefold().replace("-", "_") for b in banned):
                raise ValueError("Withheld archive published in offline ZIP: " + member)
    for file in (site / "downloads").iterdir():
        if any(b in file.name.casefold().replace("-", "_") for b in banned):
            raise ValueError("Withheld archive in generated site downloads: " + file.name)
    print("PASS: generated offline ZIP CRC / withheld-file policy")


def self_test():
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        (root / MANIFEST).write_text(json.dumps({"files": {"index.html": "some-hash"}}))
        (root / "index.html").write_text("generated")
        (root / "kept.zip").write_bytes(b"original")
        (root / "forbidden.bin").write_bytes(b"withheld")
        rows = [
            {"path": "kept.zip", "bytes": "8", "git_sha1": oid(b"original"), "policy": "preserve"},
            {"path": "forbidden.bin", "bytes": "8", "git_sha1": oid(b"withheld"), "policy": "retire"},
        ]
        audit(root, rows)
        (root / "kept.zip").write_bytes(b"tampered")
        try:
            audit(root, rows)
        except ValueError:
            pass
        else:
            raise AssertionError("Tampered legacy file accepted")
        (root / "kept.zip").write_bytes(b"original")
        (root / "surprise.txt").write_text("untracked")
        try:
            audit(root, rows)
        except ValueError:
            pass
        else:
            raise AssertionError("Unlisted legacy file accepted")
        (root / "surprise.txt").unlink()
        retire(root, rows)
        assert not (root / "forbidden.bin").exists()
        (root / "kept.zip").unlink()
        try:
            audit(root, rows, strict=True)
        except ValueError:
            pass
        else:
            raise AssertionError("Missing preserved file accepted")
    print("PASS: legacy audit detects tampering, deletion, unknown files, and retirement")


if __name__ == "__main__":
    if len(sys.argv) not in (2, 3):
        raise SystemExit("usage: audit_legacy_pages.py self-test|offline|check|retire|verify [path]")
    cmd = sys.argv[1]
    if cmd == "self-test":
        self_test()
    elif len(sys.argv) == 3:
        folder = Path(sys.argv[2])
        if cmd == "offline":
            offline(folder)
        elif cmd == "check":
            audit(folder, inventory())
        elif cmd == "retire":
            retire(folder, inventory())
        elif cmd == "verify":
            audit(folder, inventory(), strict=True)
        else:
            raise SystemExit("invalid command: " + cmd)
    else:
        raise SystemExit("missing path")
