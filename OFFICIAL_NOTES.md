# POPSLoader 1.2.3 — Disc Icons, USB Recovery and Experimental UDPFS

This release advances the official source from 1.2.2. It incorporates the reviewed
October 2026 storage/network integration and maintenance changes.

## Highlights

- RiptOPL-compatible PS1 disc icons: exact VCD basename + `_ICO.png` from
  the same `ART/` folder as `_COV.png`, displayed beside the selected cover.
  Both use the asynchronous image-loading path. HDD/PFS uses
  `hdd0:__common/POPS/ART/`; UDPFS also checks artwork beside the VCD.
- Fixed a USB initialization-success flag that incorrectly latched failed
  module initialization, preventing its bounded retry.
- Includes the new Ethernet **SMBv1 / USB + UDPFS** selection and embedded
  Okeanos86 USB + UDPFS BDMA support. Existing SMBv1 remains selectable.
- Updated documentation, hardware QA matrix, and executable Lua host tests.

## Compatibility disclosures

- **USB + UDPFS is experimental.** Native PS2 build and host-Lua tests have
  passed, but end-to-end PS2 VCD launch, multi-USB behavior, and controller
  recovery have NOT been certified on physical hardware. Treat the network
  option as opt-in; see `docs/UDPFS_BDMA.md` for setup and limitations.
- **Issue #577 remains open:** a reported Samsung external exFAT HDD was
  enumerated by BDM but not mounted. This release corrects the USB readiness
  latch; it does not establish that the reporter's disk now works, and it
  does not require or advise reformatting on speculation.
- Normal POPStarter, local storage and SMB launch paths require regression
  checks on hardware before claiming broader parity.
- Third-party drivers retain their upstream attribution and licenses.

**This official release has passed automated build and source-level test gates;
physical-console UDPFS support remains experimental and unverified.**
