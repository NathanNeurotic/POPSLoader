#!/usr/bin/env python3
"""Refuse to overwrite GitHub Pages files changed outside the source generator.

gh-pages deploys are generated from .research; manual edits to a previously
generated path are rejected on the next push. Bootstrap creates a manifest for
the current audited deployment, then all subsequent deployments are guarded.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import tempfile

MANIFEST = ".docs-generated-source-manifest.json"
SCHEMA = 1


def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for block in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def eligible(name):
    parts = PurePosixPath(name).parts
    return bool(parts) and name != MANIFEST and not name.startswith("/") and ".." not in parts


def collect(root):
    return {
        path.relative_to(root).as_posix(): digest(path)
        for path in sorted(root.rglob("*"))
        if path.is_file() and path.name != MANIFEST
    }


def check(published):
    path = published / MANIFEST
    if not path.exists():
        print("BOOTSTRAP: no generated-file manifest on gh-pages yet; "
              "first audited deployment will establish overwrite protection.")
        return
    manifest = json.loads(path.read_text(encoding="utf-8"))
    if manifest.get("schema") != SCHEMA or not isinstance(manifest.get("files"), dict):
        raise ValueError("Unrecognized gh-pages generated-file manifest; refusing publish")
    files = manifest["files"]
    if not files:
        raise ValueError("Empty generated-file manifest; refusing publish")
    for name, old_hash in sorted(files.items()):
        if not eligible(name) or not isinstance(old_hash, str) or len(old_hash) != 64:
            raise ValueError("Bad generated-file manifest entry: " + str(name))
        target = published / name
        if not target.is_file() or digest(target) != old_hash:
            raise ValueError("OUT-OF-BAND gh-pages edit/removal detected: " + name
                             + ". Port changes to .research source and regenerate "
                             "before deploying. Do not silently overwrite.")
    print(f"PASS: {len(files)} previously generated gh-pages files are unchanged "
          "since the last audited deployment.")


def record(published, source):
    expected = collect(source)
    if not expected:
        raise ValueError("Source build has no generated site files")
    for name, sha in expected.items():
        target = published / name
        if not target.is_file() or digest(target) != sha:
            raise ValueError("Deployment overlay did not match generator source: " + name)
    payload = {"schema": SCHEMA, "files": expected}
    (published / MANIFEST).write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(f"PASS: recorded {len(expected)} generated files for future drift detection.")


def self_test():
    with tempfile.TemporaryDirectory() as d:
        site, pages = Path(d) / "site", Path(d) / "pages"
        site.mkdir()
        pages.mkdir()
        (site / "index.html").write_text("original source", encoding="utf-8")
        (pages / "index.html").write_text("original source", encoding="utf-8")
        check(pages)
        record(pages, site)
        check(pages)
        (pages / "index.html").write_text("manual edit", encoding="utf-8")
        try:
            check(pages)
        except ValueError as error:
            if "OUT-OF-BAND" not in str(error):
                raise
        else:
            raise AssertionError("Direct gh-pages edits must fail deployment")
        (pages / "index.html").write_text("original source", encoding="utf-8")
        check(pages)
        (site / "index.html").write_text("legitimate generated change", encoding="utf-8")
        (pages / "index.html").write_text("legitimate generated change", encoding="utf-8")
        record(pages, site)
        check(pages)
    print("PASS: deployment guard catches manual drift and permits source-driven changes")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("mode", choices=["check", "record", "self-test"])
    p.add_argument("published", nargs="?", type=Path)
    p.add_argument("source", nargs="?", type=Path)
    args = p.parse_args()
    if args.mode == "self-test":
        self_test()
    elif args.mode == "check" and args.published:
        check(args.published)
    elif args.mode == "record" and args.published and args.source:
        record(args.published, args.source)
    else:
        p.error("check requires published path; record requires published and source paths")


if __name__ == "__main__":
    main()
