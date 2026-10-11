#!/usr/bin/env python3
"""Read-only reconciliation of two historical Bitbucket Downloads inventories.

2018 saved Wayback HTML was independently parsed into a six-column TSV;
the 2020 indexed listing was previously preserved separately. This program
compares the preserved *metadata*, NOT original binary downloads, and checks
that all 2018 entries survive in the canonical reference catalog.
"""
import argparse
import csv
from datetime import datetime
from pathlib import Path
from urllib.parse import unquote, urlparse


def read_tsv(path, required):
    with Path(path).open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(
            (line for line in f if not line.startswith("#") and line.strip()),
            delimiter="\t")
        if not reader.fieldnames or not set(required).issubset(reader.fieldnames):
            raise ValueError(f"{path}: missing TSV columns {set(required) - set(reader.fieldnames or [])}")
        rows = list(reader)
    if not rows:
        raise ValueError(f"{path}: empty source inventory")
    if any(not row.get(k, "").strip() for row in rows for k in required):
        raise ValueError(f"{path}: incomplete required source cells")
    return rows


def index(rows, field, source):
    result = {}
    for row in rows:
        key = row[field]
        if key in result:
            raise ValueError(f"{source}: duplicated filename: {key}")
        result[key] = row
    return result


def audit(first_path, later_path, catalog_path, strict=False):
    first = index(read_tsv(first_path, (
        "bitbucket_download_id", "filename", "size_displayed_2018",
        "original_uploaded_datetime_verbatim", "uploader_displayed",
        "archived_file_url_2018")), "filename", first_path)
    later = index(read_tsv(later_path, ("name", "original_size_displayed",
                                      "uploaded_by", "original_date")),
                  "name", later_path)
    catalog = index(read_tsv(catalog_path, ("filename", "evidence", "status",
                                          "source_reference")),
                    "filename", catalog_path)
    for name, row in first.items():
        if not row["bitbucket_download_id"].isdigit():
            raise ValueError("Invalid Bitbucket download ID for " + name)
        iso = row["original_uploaded_datetime_verbatim"]
        date = datetime.fromisoformat(iso)
        if date.tzinfo is not None or date > datetime(2018, 8, 18, 23, 59, 59):
            raise ValueError("Unexpected time attribute for " + name)
        source = row["archived_file_url_2018"]
        parsed = urlparse(source)
        if parsed.scheme != "https" or parsed.hostname != "web.archive.org":
            raise ValueError("Unexpected archived file host for " + name)
        if "/web/20180818023628/" not in parsed.path or unquote(parsed.path.rsplit("/", 1)[-1]) != name:
            raise ValueError("Archived URL does not match filename/capture for " + name)
        if "wiki_git" not in catalog.get(name, {}).get("evidence", "").split("+"):
            raise ValueError("Original 2018 upload absent from wiki Git-history catalog: " + name)
    only_first = sorted(set(first) - set(later))
    only_later = sorted(set(later) - set(first))
    overlap = sorted(set(first) & set(later))
    union = sorted(set(first) | set(later))
    print(f"2018 saved Bitbucket HTML upload rows: {len(first)}")
    print(f"2020 indexed Bitbucket upload rows: {len(later)}")
    print(f"Exact-name overlap: {len(overlap)}")
    print(f"2018-only upload names: {len(only_first)}")
    for name in only_first:
        item = first[name]
        print(f"  +2018 {item['bitbucket_download_id']} {name} "
              f"size={item['size_displayed_2018']} "
              f"upload={item['original_uploaded_datetime_verbatim']}")
    print(f"2020-only upload names: {len(only_later)}")
    for name in only_later:
        print(f"  +2020 {name}")
    print(f"Observed distinct upload filenames across both pages: {len(union)}")
    missing = sorted(set(union) - set(catalog))
    if missing:
        raise ValueError("Snapshot filename(s) absent from canonical catalog: " +
                         ", ".join(missing))
    wiki_rows = {x for x, row in catalog.items()
                 if "wiki_git" in row["evidence"].split("+")}
    print(f"Canonical wiki Git-history filename rows: {len(wiki_rows)}")
    if strict:
        if (len(first), len(later), len(overlap), len(only_first),
                len(only_later), len(union), len(wiki_rows)) != (
                29, 28, 23, 6, 5, 34, 80):
            raise ValueError("Historic snapshot denominator/count regression")
        for name in only_first:
            entry = catalog[name]
            original = first[name]
            if ("bitbucket_listing_2018" not in entry["evidence"].split("+")
                    or entry["original_size_displayed"] != original["size_displayed_2018"]
                    or entry["original_uploader"] != original["uploader_displayed"]
                    or entry["original_date"] !=
                        original["original_uploaded_datetime_verbatim"][:10]):
                raise ValueError("Catalog missing original 2018 upload metadata: " + name)
    print("PASS: exact set reconciliation; no recovered-binary claim")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("preserved_2018_tsv", type=Path)
    p.add_argument("indexed_2020_tsv", type=Path)
    p.add_argument("catalog_tsv", type=Path)
    p.add_argument("--strict-known-inventory", action="store_true",
                   help="Require researched 29/28/23/34 source counts and metadata")
    args = p.parse_args()
    try:
        audit(args.preserved_2018_tsv, args.indexed_2020_tsv, args.catalog_tsv,
              args.strict_known_inventory)
    except (OSError, ValueError, TypeError) as err:
        p.exit(1, f"FAIL: {err}\n")


if __name__ == "__main__":
    main()
