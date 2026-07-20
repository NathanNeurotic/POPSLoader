#!/usr/bin/env python3
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent


def run(*args: str) -> None:
    subprocess.run(args, cwd=ROOT, check=True)


# Apply the exact patch already validated by the 28-test host battery and full
# PS2 build. The fixers only repair the temporary applicator/test definitions;
# apply_storage_fix_v4.py writes the intended runtime and permanent tests.
run("python3", "tools/fix_storage_v4_applicator_quotes.py")
run("python3", "tools/fix_storage_v4_t25_input.py")
run("python3", "tools/apply_storage_fix_v4.py")

# Remove every diagnostic-only workflow/applicator before the branch commit.
temporary_paths = [
    ".github/workflows/apply-storage-fix-v4.yml",
    ".github/workflows/apply-storage-fix-v5.yml",
    ".github/workflows/apply-storage-fix-v7.yml",
    ".github/workflows/debug-storage-handoff.yml",
    ".github/workflows/debug-storage-handoff-v2.yml",
    ".github/workflows/debug-storage-handoff-v3.yml",
    "tools/apply_storage_fix_v4.py",
    "tools/fix_storage_v4_applicator_quotes.py",
    "tools/fix_storage_v4_t25_diag.py",
    "tools/fix_storage_v4_t25_input.py",
    "tools/apply_storage_fix.py",
]
for rel in temporary_paths:
    path = ROOT / rel
    if path.exists():
        path.unlink()

run("git", "diff", "--check")
run("git", "config", "user.name", "github-actions[bot]")
run("git", "config", "user.email", "41898282+github-actions[bot]@users.noreply.github.com")
run("git", "add", "-A")
run("git", "commit", "-m", "fix(storage): restore lazy BDM startup and launch environment")
run("git", "push", "origin", "HEAD:agent/fix-mmce-mx4-first-entry")
print("Committed validated storage hardware follow-up and removed diagnostics")
