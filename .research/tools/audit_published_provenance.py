#!/usr/bin/env python3
"""Build-time gate for source-verified historical download warnings.

Ensures the generated site does not accidentally recommend a misidentified
historical archive as a working PAL fix. No external connections or writes.
"""
from pathlib import Path

site = Path(__file__).resolve().parents[1] / "site"
downloads = (site / "downloads.html").read_text(encoding="utf-8")
compatibility = (site / "compatibility.html").read_text(encoding="utf-8")
for term in ("Historical NOPAL patch name conflict", "188-byte", "226 bytes",
             "IGR ELF-loader", "archival copy", "not a verified",
             "93,934-byte"):
    if term not in downloads:
        raise SystemExit(f"Missing public provenance warning: {term}")
for disproven in ("PATCH_9.BIN, the file form of $NOPAL.",
                  "Turns POPStarter&#x27;s PAL patcher off.",
                  "Newer than the copy inside the SMB pack"):
    if disproven in downloads:
        raise SystemExit(f"False download claim remains: {disproven}")
if "Do not apply the hosted file as a verified PAL workaround" not in compatibility:
    raise SystemExit("The compatibility page lost its historical patch warning")
if 'href="downloads/NOPAL_PATCH.7z"' not in downloads:
    raise SystemExit("Archival item unexpectedly no longer linked")
for filename in ("POPStarter_USB_Quickstarter_Pack_20171027.7z",
                 "POPStarter_SMB_Quickstarter_Pack_20171027.7z",
                 "DISCS_POOPER.EXE", "uLE_kHn_20160723.7z"):
    if filename not in downloads:
        raise SystemExit(f"Missing historical reference from download catalog: {filename}")
print("PASS: public patch warning, intact historical listing and retained archival file")
