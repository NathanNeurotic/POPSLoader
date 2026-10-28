# POPSLoader Device Support and Testing

This is an overview of **code coverage**, not a blanket compatibility certification. For current regressions and dated hardware evidence, always use [STATE.md](../../STATE.md) and [QA_REGRESSION_MATRIX.md](../../QA_REGRESSION_MATRIX.md).

| Storage | POPStarter/VCD | Ember integration, PR #600 |
| --- | --- | --- |
| USB and two USB drives | Existing VCD backend | Library enumeration host-tested; console handoff and VMC unverified |
| MX4SIO | Existing backend | Library enumeration host-tested; console handoff and VMC unverified |
| MMCE | Existing backend | Library enumeration host-tested; console handoff and VMC unverified |
| Internal exFAT / ATA | Existing BDM-backed support | Host-tested; actual device startup and VMC unverified |
| APA/PFS HDD | Existing backend | `__.EMBER` mount/scan host-tested; write-through unverified |
| SMBv1 | Existing network VCD route | Library host-tested; Ember handoff/mount lifetime unverified |
| UDPFS | Experimental UDPFS network read/write | Library host-tested; end-to-end console path unverified |
| i.Link | Existing device-menu placeholder | **Deferred** until RiptOPL has proven hardware support |

The Ethernet menu supports choosing SMBv1 or experimental **UDPFS** for POPStarter, with appropriate server, driver and setup requirements. Neither POPStarter's UDPFS path nor Ember's network handoff should be advertised as certified solely because host tests pass. Consult [UDPFS details](../UDPFS_BDMA.md).

POPSLoader's [Ember development guide](Ember-Core.md) documents separate Ember settings and its keep-IOP launch path. **i.Link is intentionally excluded from the PR #600 completion gate.** Retain existing unsupported UI, revisit when RiptOPL demonstrates the device on real hardware, and do not call the resulting Ember release full-device parity.
