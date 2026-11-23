# Trust anchors for POPSLoader's Check for Updates

The only certificates the updater's HTTPS client trusts. github.com chains to the Sectigo roots, and the release download host
(its redirect target) chains to the ISRG roots. Every one is in the current Mozilla root store.

| File | Subject | SHA-256 (DER) | Expires |
| --- | --- | --- | --- |
| `isrgrootx1.der` | ISRG Root X1 | `96bcec06264976f37460779acf28c5a7cfe8a3c0aae11a8ffcee05c0bddf08c6` | 2035-06-04 |
| `isrg-root-x2.der` | ISRG Root X2 | `69729b8e15a86efc177a57afb7171dfc64add28c2fca8cf1507e34453ccb1470` | 2040-09-17 |
| `sectigo-e46.der` | Sectigo Public Server Authentication Root E46 | `c90f26f0fb1b4018b22227519b5ca2b53e2ca5b3be5cf18efe1bef47380c5383` | 2046-03-21 |
| `sectigo-r46.der` | Sectigo Public Server Authentication Root R46 | `7bb647a62aeeac88bf257aa522d01ffea395e0ab45c73f93f65654ec38f25a06` | 2046-03-21 |

The files are the same four roots RiptOPL's updater trusts. `Makefile` turns each into an object with `bin2c`.
