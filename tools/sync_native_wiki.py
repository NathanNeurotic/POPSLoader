#!/usr/bin/env python3
"""Publish current POPSLoader docs to GitHub's native Gollum Wiki.

The historical POPStarter archive remains untouched. Only namespaced,
generated POPSLoader pages are replaced. Existing Home/Sidebar material
is retained, with a bounded managed navigation block appended.
"""
from __future__ import annotations
import argparse
import pathlib
import re
import tempfile

SOURCE_TO_WIKI = {
    "Project-Wiki.md": "POPSLoader-Project.md",
    "Installation-Guide.md": "POPSLoader-Installation.md",
    "Release-Formats.md": "POPSLoader-Release-Formats.md",
    "Ember-Core.md": "POPSLoader-Ember.md",
    "Device-Support.md": "POPSLoader-Device-Support.md",
}
OWNER = "<!-- POPSLoader native wiki mirror; generated from dev/docs/wiki; do not hand-edit this page -->"
START = "<!-- POPSLOADER-WIKI-NAV-START -->"
END = "<!-- POPSLOADER-WIKI-NAV-END -->"
REPO_BASE = "https://github.com/NathanNeurotic/POPSLoader/blob/"
LINKS = {
    "Project-Wiki.md": "POPSLoader-Project",
    "Installation-Guide.md": "POPSLoader-Installation",
    "Release-Formats.md": "POPSLoader-Release-Formats",
    "Ember-Core.md": "POPSLoader-Ember",
    "Device-Support.md": "POPSLoader-Device-Support",
}
NAV = """### Current POPSLoader project

- [Current POPSLoader Wiki](POPSLoader-Project)
- [Installation and PSU](POPSLoader-Installation)
- [Release ZIP / PSU Format](POPSLoader-Release-Formats)
- [Ember PS1 Core](POPSLoader-Ember)
- [Device Support and Testing](POPSLoader-Device-Support)

The [historical POPStarter wiki](https://nathanneurotic.github.io/POPSLoader/wiki/index.html)
is maintained separately. POPSLoader 1.4.8 is the latest stable release;
Ember is included and remains hardware-unverified.
""" + "\n" + '[RiptOPL](https://github.com/NathanNeurotic/RiptOPL) · [Launchstation](https://github.com/NathanNeurotic/Launchstation) · [PS2-Servers](https://github.com/NathanNeurotic/PS2-Servers) · [launcHER](https://github.com/NathanNeurotic/launcHER) · [Simple-Media-System](https://github.com/NathanNeurotic/Simple-Media-System) · **POPSLoader**\n\nTranslate this wiki (automatic, by Google): [Español](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=es&_x_tr_hl=es) · [Português (Brasil)](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=pt&_x_tr_hl=pt) · [Português](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=pt-PT&_x_tr_hl=pt-PT) · [Français](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=fr&_x_tr_hl=fr) · [Deutsch](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=de&_x_tr_hl=de) · [Italiano](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=it&_x_tr_hl=it) · [Nederlands](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=nl&_x_tr_hl=nl) · [Dansk](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=da&_x_tr_hl=da) · [Svenska](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=sv&_x_tr_hl=sv) · [Polski](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=pl&_x_tr_hl=pl) · [Čeština](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=cs&_x_tr_hl=cs) · [Hrvatski](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=hr&_x_tr_hl=hr) · [Српски](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=sr&_x_tr_hl=sr) · [Български](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=bg&_x_tr_hl=bg) · [Русский](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=ru&_x_tr_hl=ru) · [Ελληνικά](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=el&_x_tr_hl=el) · [Magyar](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=hu&_x_tr_hl=hu) · [Română](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=ro&_x_tr_hl=ro) · [Galego](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=gl&_x_tr_hl=gl) · [Shqip](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=sq&_x_tr_hl=sq) · [Türkçe](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=tr&_x_tr_hl=tr) · [العربية](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=ar&_x_tr_hl=ar) · [فارسی](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=fa&_x_tr_hl=fa) · [日本語](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=ja&_x_tr_hl=ja) · [한국어](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=ko&_x_tr_hl=ko) · [简体中文](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=zh-CN&_x_tr_hl=zh-CN) · [繁體中文](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=zh-TW&_x_tr_hl=zh-TW) · [Tiếng Việt](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=vi&_x_tr_hl=vi) · [ລາວ](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=lo&_x_tr_hl=lo) · [Bahasa Indonesia](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=id&_x_tr_hl=id) · [Filipino](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=tl&_x_tr_hl=tl) · [Cebuano](https://github-com.translate.goog/NathanNeurotic/POPSLoader/wiki?_x_tr_sl=en&_x_tr_tl=ceb&_x_tr_hl=ceb)\n'
# Rewrite all source-tree relative links into either native Wiki page links
# or absolute dev/master repository links. Never leave ../ paths in Gollum.
def rewrite(target: str) -> str:
    if target.startswith(("https://", "http://", "mailto:", "#")):
        return target
    link, sep, fragment = target.partition("#")
    fragment = ("#" + fragment) if sep else ""
    if link in LINKS:
        return LINKS[link] + fragment
    path = pathlib.PurePosixPath("/docs/wiki") / link
    parts: list[str] = []
    for segment in path.parts:
        if segment in ("", "/"):
            continue
        if segment == "..":
            if parts:
                parts.pop()
            else:
                raise ValueError(f"Unsafe relative path in wiki Markdown: {target}")
        elif segment != ".":
            parts.append(segment)
    resolved = "/".join(parts)
    if resolved.startswith("docs/") or resolved in ("README.md", "STATE.md", "QA_REGRESSION_MATRIX.md"):
        return REPO_BASE + "dev/" + resolved + fragment
    if resolved.startswith(".github/workflows/"):
        return REPO_BASE + "master/" + resolved + fragment
    raise ValueError(f"Unrecognized relative wiki link: {target} -> {resolved}")

MARKDOWN_LINK = re.compile(r"(?<!!)\[([^\]\n]+)\]\(([^)\n]+)\)")
def render(path: pathlib.Path) -> str:
    text = path.read_text(encoding="utf-8")
    def replace(m: re.Match[str]) -> str:
        return f"[{m.group(1)}]({rewrite(m.group(2))})"
    content = MARKDOWN_LINK.sub(replace, text)
    return OWNER + "\n\n" + content.rstrip() + "\n"

def merge_navigation(previous: str, block: str) -> str:
    section = START + "\n" + block.rstrip() + "\n" + END
    has_start, has_end = START in previous, END in previous
    if has_start != has_end:
        raise ValueError("Wiki navigation marker pair is incomplete; refusing overwrite")
    if has_start:
        if previous.count(START) != 1 or previous.count(END) != 1:
            raise ValueError("Duplicate Wiki navigation markers; refusing overwrite")
        first, last = previous.index(START), previous.index(END) + len(END)
        return previous[:first] + section + previous[last:]
    return previous.rstrip() + ("\n\n" if previous.strip() else "") + section + "\n"

def sync(source: pathlib.Path, dest: pathlib.Path) -> list[str]:
    if not source.is_dir() or not dest.is_dir():
        raise ValueError("Source wiki and cloned GitHub Wiki repository must exist")
    changes = []
    for source_name, wiki_name in SOURCE_TO_WIKI.items():
        path = source / source_name
        if not path.is_file():
            raise ValueError(f"Source page absent: {path}")
        content = render(path)
        outfile = dest / wiki_name
        if outfile.exists():
            old = outfile.read_text(encoding="utf-8")
            if not old.startswith(OWNER):
                raise ValueError(f"{wiki_name} is manually managed: refusing overwrite")
            if old == content:
                continue
        outfile.write_text(content, encoding="utf-8")
        changes.append(wiki_name)
    for name in ("Home.md", "_Sidebar.md"):
        outfile = dest / name
        previous = outfile.read_text(encoding="utf-8") if outfile.exists() else ""
        desired = merge_navigation(previous, NAV)
        if previous != desired:
            outfile.write_text(desired, encoding="utf-8")
            changes.append(name)
    # The canonical guide links MUST be resolvable in the materialized Wiki.
    for fname in SOURCE_TO_WIKI.values():
        published = (dest / fname).read_text(encoding="utf-8")
        if "/../" in published or "](../" in published:
            raise ValueError(f"Bad unresolved Wiki-relative link in {fname}")
    return changes

def selftest(source: pathlib.Path) -> None:
    with tempfile.TemporaryDirectory() as td:
        wiki = pathlib.Path(td)
        (wiki / "Home.md").write_text("# Existing community home\n\nDo not delete me.\n")
        (wiki / "Unrelated.md").write_text("# Existing historical work\n")
        changes = sync(source, wiki)
        assert len(changes) == len(SOURCE_TO_WIKI) + 2, changes
        assert "Do not delete me." in (wiki / "Home.md").read_text()
        assert (wiki / "Unrelated.md").read_text() == "# Existing historical work\n"
        assert not sync(source, wiki), "Non-idempotent regeneration"
        g = (wiki / "POPSLoader-Ember.md").read_text()
        assert "[technical integration](https://github.com/NathanNeurotic/POPSLoader/blob/dev/docs/EMBER_INTEGRATION.md)" in g
        assert "[Ember Watch workflow](https://github.com/NathanNeurotic/POPSLoader/blob/master/.github/workflows/ember-watch.yml)" in g
        (wiki / "POPSLoader-Ember.md").write_text("manually edited")
        try:
            sync(source, wiki)
        except ValueError:
            pass
        else:
            raise AssertionError("Non-generated wiki collision was not rejected")
        print("PASS: native Wiki link rewrites, idempotence, external page preservation and overwrite guard")

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--source", default="docs/wiki", type=pathlib.Path)
    p.add_argument("--destination", type=pathlib.Path)
    p.add_argument("--self-test", action="store_true")
    args = p.parse_args()
    if args.self_test:
        selftest(args.source)
    else:
        if args.destination is None:
            p.error("--destination is required when not using --self-test")
        changed = sync(args.source, args.destination)
        print(f"Native wiki pages prepared: {', '.join(changed) or '(already current)'}")
