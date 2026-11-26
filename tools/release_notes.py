#!/usr/bin/env python3
"""Write the GitHub release page text for a POPSLoader rolling or official release.

Same layout as RiptOPL's release pages: the full kit first, the other files in a
collapsed table, then a short list of changes. Nothing here is copied from a
notes file in full, so the page stays short.

  release_notes.py rolling  --version v1.4.7-1050 --sha <commit> --built "2026-11-26 03:10 UTC"
  release_notes.py official --version 1.4.7 --sha <commit> --built ... --notes RELEASE_1.4.7.md
"""
import argparse
import re
import subprocess
import sys

REPO = "NathanNeurotic/POPSLoader"
SITE = "https://nathanneurotic.github.io/POPSLoader/popsloader.html"
WIKI = f"https://github.com/{REPO}/wiki"
CHANGES_SHOWN = 10


def download(tag, name):
    return f"https://github.com/{REPO}/releases/download/{tag}/{name}"


def commit_link(sha):
    return f"[{sha[:8]}](https://github.com/{REPO}/commit/{sha})"


def other_files(rows, tag):
    out = [
        "<details>",
        f"<summary><strong>Other files</strong> ({len(rows)})</summary>",
        "",
        "| File | What it is |",
        "|---|---|",
    ]
    for name, what in rows:
        out.append(f"| [{name}]({download(tag, name)}) | {what} |")
    out += ["", "</details>"]
    return out


def recommended(tag, kit):
    return [
        "## Recommended downloads",
        "",
        f"- **[{kit}]({download(tag, kit)})** - Not sure what to pick? Take this one. "
        "It has `APPS/PS1_POPSLOADER/`, `POPS/` and `EMBER/` ready to copy to the root of a game "
        "device, and the rest of this page is optional. No BIOS, POPS emulator files or games are included.",
        f"- **[POPSLOADER.ELF]({download(tag, 'POPSLOADER.ELF')})** - already installed: replace your "
        "POPSLOADER.ELF, or use **Settings, About, Check for Updates** in POPSLoader.",
    ]


def recent_changes(sha, count=CHANGES_SHOWN):
    log = subprocess.run(
        ["git", "log", "--first-parent", f"-n{count}", "--format=%H%x09%s", sha],
        check=True, capture_output=True, text=True).stdout
    out = []
    for line in log.splitlines():
        full, _, subject = line.partition("\t")
        if full:
            out.append(f"- {subject.strip()} ({commit_link(full)})")
    return out


def release_sections(path):
    """The release file without its title and its Installation section.

    The downloads list above replaces the Installation section; the rest (changes,
    validation and limits) is short by convention and is kept as written.
    """
    with open(path, encoding="utf-8") as f:
        text = f.read()
    kept, skip = [], False
    for line in text.splitlines():
        if line.startswith("# "):
            continue
        if line.startswith("## "):
            skip = line[3:].strip().lower() == "installation"
        if not skip:
            kept.append(line)
    return "\n".join(kept).strip().splitlines()


def footer(sha):
    return [
        "",
        f"[Full history](https://github.com/{REPO}/commits/{sha}) - "
        f"[Installation and guides]({SITE}) - [Wiki]({WIKI})",
        "",
        "Not tested on a real PS2 unless a change says so. Ember is "
        "[Gageformer's Ember](https://github.com/Gageformer/Ember), unmodified; supply your own BIOS and games.",
    ]


def rolling(args):
    tag = "rolling-release"
    kit = f"PS1_POPSLOADER-{args.version}.zip"
    bundle = f"POPSLOADER-rolling-release-{args.version}.zip"
    lines = [
        f"**POPSLoader** `{args.version}` - Development build {commit_link(args.sha)}, "
        f"built {args.built}.",
        "",
        *recommended(tag, kit),
        "",
        *other_files([
            ("PS1_POPSLOADER.psu", "The app folder only, for a memory card: install it with a PSU manager."),
            (bundle, "Everything in one ZIP: the kit, the ELF, POPStarter and its other versions, "
                     "the SMB pack and this build's source."),
            ("SHA256SUMS.txt", "SHA-256 of the kit, the PSU and the ELF. Check for Updates reads it."),
        ], tag),
        "",
        "## Changes",
        "",
        *recent_changes(args.sha),
        *footer(args.sha),
    ]
    return lines


def official(args):
    tag = args.version
    kit = f"PS1_POPSLOADER-{args.version}.zip"
    lines = [
        f"**POPSLoader {args.version}** - Release build {commit_link(args.sha)}, built {args.built}.",
        "",
        *recommended(tag, kit),
        "",
        *other_files([
            ("PS1_POPSLOADER.psu", "The app folder only, for a memory card: install it with a PSU manager."),
            ("BUILD-MANIFEST.txt", "How it was built: commit, CI run, build image and the Ember hash."),
            ("SHA256SUMS.txt", "SHA-256 of every file here. Check for Updates reads it."),
        ], tag),
        "",
        *release_sections(args.notes),
        *footer(args.sha),
    ]
    return lines


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("channel", choices=("rolling", "official"))
    p.add_argument("--version", required=True)
    p.add_argument("--sha", required=True)
    p.add_argument("--built", required=True, help='build time, e.g. "2026-11-26 03:10 UTC"')
    p.add_argument("--notes", help="RELEASE_<version>.md (official only)")
    p.add_argument("--out", required=True)
    args = p.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.sha):
        sys.exit("--sha must be a full commit hash")
    if args.channel == "official" and not args.notes:
        sys.exit("official needs --notes RELEASE_<version>.md")
    lines = rolling(args) if args.channel == "rolling" else official(args)
    text = "\n".join(lines).rstrip() + "\n"
    # GitHub refuses a release body over 125000 characters; this page is a few KB.
    if len(text) > 20000:
        sys.exit(f"release notes are {len(text)} characters; keep the page short")
    with open(args.out, "w", encoding="utf-8") as f:
        f.write(text)
    print(text)


if __name__ == "__main__":
    main()
