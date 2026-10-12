# Historical HDDOSD PAL centering note (2016): removed from later wiki revisions

**Dated source finding, not a present-day bug report.** Original source `popstarter-hddosd.textile`, in the user-supplied verified Bitbucket Git clone.

On **2016-10-16 09:31:06 UTC**, commit `3dd6c24ebca144edea1855b257eb5b5d24b340c0` changed the `system.cnf` description to say that the file controlled both the boot target (`BOOT2=pfs:/EXECUTE.KELF`) **and the PAL/NTSC video mode**. It added the following historic note:

> PAL games are off-centered, even if you choose PAL for VMODE. To be fixed soon.

On **2016-11-02 13:39:19 UTC**, commit `495db290c8dcbdd4dd3d5895ba4680b527248cfc` **deleted that note**, while retaining the `VMODE (PAL/NTSC)` explanatory phrase. The earlier October 16 revision had also superseded an anecdotal claim that a sample `system.cnf` with `VMODE=NTSC` worked fine on the author's PAL setup. Treat these as **different observations from different versions**, not as mutually current configuration advice.

Direct inspection of merged `master`:
- `.research/wiki/popstarter-hddosd.md` retains the `system.cnf` setup and boot-target instructions but contains **no warning about off-centering in PAL with `VMODE=PAL``.
- `.research/wiki/popstarter-changelog.md` and `.research/firstparty/original-wiki-git-historical-additions.md` have no equivalent note.

The source proves that a **historical warning existed and was removed**. It **does not** prove the defect persisted after November 2016, was fixed by a particular release, or applies to today's POPSLoader, modern TV setups, different video cables or emulator modes. No executable fix is inferred from it.

**Proposed future editorial treatment:** one dated, version-scoped archival footnote if full historical fidelity is desired; retain the 2016 wording and deletion date, and explicitly mark present-day status unknown. This draft PR only preserves the evidence, without modifying the public manual or any `system.cnf`.
