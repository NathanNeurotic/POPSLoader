# Third-party notices

UDP FS Assault includes or derives from the works listed below. Each keeps its own license.
The license of this project itself is in the `LICENSE` file.

| Component | Author / copyright | License | Where it is used |
|---|---|---|---|
| BDM Assault | israpps and contributors | Academic Free License 2.0 | origin of the project structure and of the `bdm` library interface (empty stubs) |
| PS2SDK / PS2DEV headers and libraries | PS2DEV / PS2SDK contributors | Academic Free License 2.0 | build system, IOP headers, imports |
| Neutrino, UDPFS, UDPBD, UDPRDMA, `udpfs_server.py` (all in the Neutrino repository) | ps2max32 | Academic Free License 3.0 | protocol implemented by the client; `src/net/` derives from UDPBD |
| udpfsd | Copyright 2026 Ivan V (pcm720) | BSD-3-Clause (below) | reference for the protocol (no code copied); the server the module is tested with |

Full license texts (AFL 2.0, AFL 3.0) are in the `licenses/` folder of `__udp_fs_assault`:

- `licenses/AFL-2.0.txt`
- `licenses/AFL-3.0.txt`

---

## udpfsd (pcm720)

```
Copyright 2026 Ivan V (pcm720)

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```
