## Skills
A skill is a set of local instructions to follow that is stored in a `SKILL.md` file. Below is the list of skills that can be used. Each entry includes a name, description, and file path so you can open the source for full instructions when using a specific skill.
### Available skills
- develop-web-game: Use when Codex is building or iterating on a web game (HTML/JS) and needs a reliable development + testing loop: implement small changes, run a Playwright-based test script with short input bursts and intentional pauses, inspect screenshots/text, and review console errors with render_game_to_text. (file: /mnt/c/Users/natha/.codex/skills/develop-web-game/SKILL.md)
- doc: Use when the task involves reading, creating, or editing `.docx` documents, especially when formatting or layout fidelity matters; prefer `python-docx` plus the bundled `scripts/render_docx.py` for visual checks. (file: /mnt/c/Users/natha/.codex/skills/doc/SKILL.md)
- gh-address-comments: Help address review/issue comments on the open GitHub PR for the current branch using gh CLI; verify gh auth first and prompt the user to authenticate if not logged in. (file: /mnt/c/Users/natha/.codex/skills/gh-address-comments/SKILL.md)
- gh-fix-ci: Use when a user asks to debug or fix failing GitHub PR checks that run in GitHub Actions; use `gh` to inspect checks and logs, summarize failure context, draft a fix plan, and implement only after explicit approval. Treat external providers (for example Buildkite) as out of scope and report only the details URL. (file: /mnt/c/Users/natha/.codex/skills/gh-fix-ci/SKILL.md)
- imagegen: Use when the user asks to generate or edit images via the OpenAI Image API (for example: generate image, edit/inpaint/mask, background removal or replacement, transparent background, product shots, concept art, covers, or batch variants); run the bundled CLI (`scripts/image_gen.py`) and require `OPENAI_API_KEY` for live calls. (file: /mnt/c/Users/natha/.codex/skills/imagegen/SKILL.md)
- playwright: Use when the task requires automating a real browser from the terminal (navigation, form filling, snapshots, screenshots, data extraction, UI-flow debugging) via `playwright-cli` or the bundled wrapper script. (file: /mnt/c/Users/natha/.codex/skills/playwright/SKILL.md)
- screenshot: Use when the user explicitly asks for a desktop or system screenshot (full screen, specific app or window, or a pixel region), or when tool-specific capture capabilities are unavailable and an OS-level capture is needed. (file: /mnt/c/Users/natha/.codex/skills/screenshot/SKILL.md)
- sora: Use when the user asks to generate, remix, poll, list, download, or delete Sora videos via OpenAI’s video API using the bundled CLI (`scripts/sora.py`), including requests like “generate AI video,” “Sora,” “video remix,” “download video/thumbnail/spritesheet,” and batch video generation; requires `OPENAI_API_KEY` and Sora API access. (file: /mnt/c/Users/natha/.codex/skills/sora/SKILL.md)
- speech: Use when the user asks for text-to-speech narration or voiceover, accessibility reads, audio prompts, or batch speech generation via the OpenAI Audio API; run the bundled CLI (`scripts/text_to_speech.py`) with built-in voices and require `OPENAI_API_KEY` for live calls. Custom voice creation is out of scope. (file: /mnt/c/Users/natha/.codex/skills/speech/SKILL.md)
- transcribe: Transcribe audio files to text with optional diarization and known-speaker hints. Use when a user asks to transcribe speech from audio/video, extract text from recordings, or label speakers in interviews or meetings. (file: /mnt/c/Users/natha/.codex/skills/transcribe/SKILL.md)
- vercel-deploy: Deploy applications and websites to Vercel. Use when the user requests deployment actions like "deploy my app", "deploy and give me the link", "push this live", or "create a preview deployment". (file: /mnt/c/Users/natha/.codex/skills/vercel-deploy/SKILL.md)
- yeet: Use only when the user explicitly asks to stage, commit, push, and open a GitHub pull request in one flow using the GitHub CLI (`gh`). (file: /mnt/c/Users/natha/.codex/skills/yeet/SKILL.md)
- skill-creator: Guide for creating effective skills. This skill should be used when users want to create a new skill (or update an existing skill) that extends Codex's capabilities with specialized knowledge, workflows, or tool integrations. (file: /mnt/c/Users/natha/.codex/skills/.system/skill-creator/SKILL.md)
- skill-installer: Install Codex skills into $CODEX_HOME/skills from a curated list or a GitHub repo path. Use when a user asks to list installable skills, install a curated skill, or install a skill from another repo (including private repos). (file: /mnt/c/Users/natha/.codex/skills/.system/skill-installer/SKILL.md)
### How to use skills
- Discovery: The list above is the skills available in this session (name + description + file path). Skill bodies live on disk at the listed paths.
- Trigger rules: If the user names a skill (with `$SkillName` or plain text) OR the task clearly matches a skill's description shown above, you must use that skill for that turn. Multiple mentions mean use them all. Do not carry skills across turns unless re-mentioned.
- Missing/blocked: If a named skill isn't in the list or the path can't be read, say so briefly and continue with the best fallback.
- How to use a skill (progressive disclosure):
  1) After deciding to use a skill, open its `SKILL.md`. Read only enough to follow the workflow.
  2) When `SKILL.md` references relative paths (e.g., `scripts/foo.py`), resolve them relative to the skill directory listed above first, and only consider other paths if needed.
  3) If `SKILL.md` points to extra folders such as `references/`, load only the specific files needed for the request; don't bulk-load everything.
  4) If `scripts/` exist, prefer running or patching them instead of retyping large code blocks.
  5) If `assets/` or templates exist, reuse them instead of recreating from scratch.
- Coordination and sequencing:
  - If multiple skills apply, choose the minimal set that covers the request and state the order you'll use them.
  - Announce which skill(s) you're using and why (one short line). If you skip an obvious skill, say why.
- Context hygiene:
  - Keep context small: summarize long sections instead of pasting them; only load extra files when needed.
  - Avoid deep reference-chasing: prefer opening only files directly linked from `SKILL.md` unless you're blocked.
  - When variants exist (frameworks, providers, domains), pick only the relevant reference file(s) and note that choice.
- Safety and fallback: If a skill can't be applied cleanly (missing files, unclear instructions), state the issue, pick the next-best approach, and continue.

## AI Docs
Last updated: 2026-03-05

### Purpose
Operational rules for AI agents working in this repository.

### Scope
- Allowed: task-focused edits to requested files only.
- Allowed: documentation, tests, and narrowly scoped fixes tied to the active task.
- Avoid touching unrelated Lua/C/C++ files unless explicitly required.
- Preserve boot/launch pipelines and device detection logic unless the task is explicitly about them.
- If project-specific ownership boundaries are unknown, add `TODO(owner/component)` before expanding scope.

### Change Discipline
- Keep diffs minimal and localized.
- One task per commit.
- No drive-by refactors or formatting churn.
- Do not rename/move files unless required by the task.
- Prefer additive, reversible changes.

### Safety Rules
- Never run destructive commands (for example `rm -rf`, `git reset --hard`, force-push) without explicit instruction.
- Do not overwrite user-authored changes outside task scope.
- Pause and report if unexpected repo changes appear during work.
- Avoid adding logging unless explicitly requested.

### Testing Expectations
- Pick the smallest test plan that proves the change.
- For docs-only changes: lint/spell-check if available; otherwise note "not run".
- For code changes: run targeted tests first, then broader tests only if risk requires.
- Include manual verification steps when automated coverage is missing.
- Add `TODO(test-command)` placeholders where project test commands are unknown.

### Communication Format
Use this exact report structure in task responses:
- Summary: what changed and why.
- Diffstat: file-level change summary.
- Diff: key hunks or full patch when requested.
- Test plan: what was run, what passed/failed, and what was not run.
