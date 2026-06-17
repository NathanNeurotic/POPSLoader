# Antigravity Next Task — ARCHIVED

This handoff note dates from the March/May 2026 BOOT.ELF debugging cycle and is **superseded by the BETA-10-5 release** (tag `9a0ebe2`, 2026-05-27, hardware-confirmed clean by Nuno 2026-05-28).

**For current state and active work, see:**
- [STATE.md](STATE.md) — current code and hardware status, post-release PR work
- [ROADMAP.md](ROADMAP.md) — prioritized backlog
- [QA_REGRESSION_MATRIX.md](QA_REGRESSION_MATRIX.md) — full hardware/CI ledger
- [docs/U10_INVESTIGATION.md](docs/U10_INVESTIGATION.md) — U-10 BOOT.ELF-from-HDD-boot hypothesis catalog (now an accepted known-broken item in BETA-10-5; investigation preserved)
- [docs/DOCUMENTATION_FOLLOWUP_AUDIT.md](docs/DOCUMENTATION_FOLLOWUP_AUDIT.md) — post-release doc cleanup plan
- [AGENTS_START_HERE.md](AGENTS_START_HERE.md) — current entry point for new agents

**BOOT.ELF status as of 2026-05-28:**
- BOOT.ELF from USB / OSDmenu / Browser / HOSDMenu / PSBBN: **PASS** (V2 working route at commit `d23520a`)
- BOOT.ELF from HDD-booted POPSLoader (`U-10`): **known-broken accepted** in BETA-10-5. Workaround: Exit → OSDSYS or reboot. Diagnostic data from PR #463 localized the hang to `SifIopReset` itself; F4 unconditional unmount in PR #464 didn't fix it on hardware. Investigation hypotheses preserved in [docs/U10_INVESTIGATION.md](docs/U10_INVESTIGATION.md) for future revisits.
