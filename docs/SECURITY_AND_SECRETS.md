# Security & Secrets

## Repository Audit Summary

- No secret files (keys, tokens, credentials) were found in the repository during this audit.
- CI uses the standard `GITHUB_TOKEN` secret for releases.

## Contributor Checklist (Do NOT paste into issues/PRs)

- Console serials, memory card dumps, or proprietary game content.
- Private keys, access tokens, or credentials.
- Full memory card or HDD images.
- Any copyrighted or licensed binary you do not have rights to redistribute.

## Where Secrets Should Live

- GitHub Actions secrets (repository or organization settings) for CI tokens.
- Local `.env` or developer-specific storage **outside** the repository.

## Unknown / Requires Confirmation

- If additional secrets are used in downstream forks or local scripts, they are not evident in the audited files.

## Evidence

- `.github/workflows/compilation.yml`
