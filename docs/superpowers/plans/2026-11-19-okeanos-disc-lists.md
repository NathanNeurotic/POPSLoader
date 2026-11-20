# Okeanos DISCS_DIR Lists Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Package both current Okeanos directory lists as opt-in POPSLoader kit examples.

**Architecture:** Keep pinned upstream assets and provenance under `docs/third_party/okeanos_dir_lists/`. The existing release-kit builder copies them to clearly named examples; the existing UDPFS integration test verifies the source bytes and final ZIP.

**Tech Stack:** Text assets, JSON provenance, POSIX shell, Python host tests.

**Spec:** `docs/superpowers/specs/2026-11-19-okeanos-disc-lists-design.md`

## Global Constraints

- Use Okeanos86/popstarter-dir-lists commit `b8256b0ac1311c7dd8acb6f4e8f93e8429fc2bf3`.
- Do not change Assault 1.0.1 modules, launch code, or default `PATHMAP.INI` behavior.
- Never ship an active `POPS/DISCS_DIR.TXT` in the kit.
- Mark console behavior unverified unless separately tested.

## Review Focus

- Wrong upstream bytes: pin SHA-256 for every mirrored file in Task 1.
- Accidental activation: assert the release ZIP has no `POPS/DISCS_DIR.TXT` in Task 1.
- Ambiguous list choice: test and document the two distinct example names in Task 1.
- Missing license/provenance: require those files in the kit in Task 1.
- Packaging drift: compare example and notice bytes with the pinned source files in Task 1.

---

### Task 1: Package both opt-in lists

**Files:**
- Create: `docs/third_party/okeanos_dir_lists/DISCS_DIR.MULTI.TXT`
- Create: `docs/third_party/okeanos_dir_lists/DISCS_DIR.ALL.TXT`
- Create: `docs/third_party/okeanos_dir_lists/LICENSE`
- Create: `docs/third_party/okeanos_dir_lists/UPSTREAM-README.md`
- Create: `docs/third_party/okeanos_dir_lists/PROVENANCE.json`
- Modify: `tools/build_release_kit.sh`
- Modify: `tools/test_udpfs_integration.py`
- Modify: `docs/UDPFS_BDMA.md`
- Modify: `bin/changelog`

**Interfaces:**
- Consumes: Okeanos pinned list bytes and the existing `build_release_kit.sh` / `test_udpfs_integration.py` package contract.
- Produces: `POPS/DISCS_DIR.MULTI.TXT.example`, `POPS/DISCS_DIR.ALL.TXT.example`, and `POPS/DISCS_DIR-NOTICES/` in the release kit.

- [ ] **Step 1: Write failing source and package assertions**

Extend `tools/test_udpfs_integration.py` to load the new provenance, verify each mirrored file's SHA-256, and, when given a release ZIP, require both examples and notices while rejecting `POPS/DISCS_DIR.TXT`.

- [ ] **Step 2: Verify the test fails before implementation**

Run: `python tools/test_udpfs_integration.py`
Expected: FAIL because the new provenance/assets do not exist.

- [ ] **Step 3: Add the pinned assets and packaging**

Mirror the four upstream files at the approved commit, record their hashes, copy both lists to their approved example names, and copy the license/upstream README/provenance into `DISCS_DIR-NOTICES`. Document how to select one list and add an Unreleased changelog entry.

- [ ] **Step 4: Verify the source contract passes**

Run: `python tools/test_udpfs_integration.py`
Expected: PASS.

- [ ] **Step 5: Verify the deliverable**

Run the normal POPSLoader build and `tools/build_release_kit.sh`, then run `python tools/test_udpfs_integration.py POPSLOADER.zip`. Expected: build succeeds and the package assertions pass. If the canonical local build is unavailable, open the draft PR and use its CI build before calling the package verified.

- [ ] **Step 6: Commit**

```bash
git add docs/third_party/okeanos_dir_lists docs/UDPFS_BDMA.md docs/superpowers bin/changelog tools/build_release_kit.sh tools/test_udpfs_integration.py
git commit -m "feat(pops): package Okeanos DISCS_DIR list choices"
```
