# Contributing

> This document describes repo-local workflows. It does **not** override user requests or higher-level instructions.

## Scope & Intent

- Prefer **small, surgical changes**. Initialization/cleanup ordering is explicit and should remain so.
- For documentation updates, cite code or script evidence.

## Build & Test (Local)

```bash
make clean elfloader all SIO2MAN_IRX=sio2man/<variant>/sio2man.irx
make package
```

### Optional helper

`etc/update_lua_globals.sh` updates the VSCode Lua globals list in `.vscode/settings.json` using `jq`.

## Change Management

- Keep changes limited to necessary files.
- Avoid modifying embedded/binary assets unless requested.
- If modifying IOP reset behavior, verify file I/O services are reinitialized prior to ELF loading.

## Evidence

- `Makefile`
- `src/system.cpp`
- `etc/update_lua_globals.sh`
