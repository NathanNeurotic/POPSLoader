#!/usr/bin/env python3
import argparse
import json
import re
import sys
from pathlib import Path

AI_TERMS = r"(?:claude|chatgpt|codex|openai|anthropic|kimi|copilot|gemini|deepseek|qwen|coderabbit|cursor|windsurf|antigravity|devin|aider|opencode)"
PATTERNS = (
    (
        "AI co-author trailer",
        re.compile(r"(?im)^\s*co[-_ ]?authored[-_ ]?by\s*:.*\b" + AI_TERMS + r"\b"),
    ),
    (
        "AI generation notice",
        re.compile(r"(?im)^\s*(?:🤖\s*)?generated with\b.*\b" + AI_TERMS + r"\b"),
    ),
    ("Claude session trailer", re.compile(r"(?im)^\s*claude-session\s*:")),
    (
        "Claude session URL",
        re.compile(r"(?i)https?://(?:www\.)?claude\.ai/code/session_[^\s)\]]+"),
    ),
    (
        "AI authorship line",
        re.compile(r"(?im)^\s*(?:written|created|authored|committed|reviewed)\s+(?:by|with)\b.*\b" + AI_TERMS + r"\b"),
    ),
    (
        "AI model signature",
        re.compile(r"(?im)^\s*(?:claude|chatgpt|codex|kimi)(?:\s+[a-z0-9._-]+)*\s+<[^>]+>\s*$"),
    ),
)


def find_violations(text, label):
    matches = []
    for rule, pattern in PATTERNS:
        match = pattern.search(text)
        if match:
            excerpt = match.group(0).strip().splitlines()[0]
            matches.append((label, rule, excerpt[:240]))
    return matches


def read_text(path):
    return Path(path).read_text(encoding="utf-8", errors="replace")


def check_sources(text_files, json_files, log_files):
    violations = []
    artifact_count = 0
    for filename in text_files:
        artifact_count += 1
        violations.extend(find_violations(read_text(filename), f"text file {filename}"))
    for filename in json_files:
        data = json.loads(read_text(filename))
        if not isinstance(data, list):
            raise ValueError(f"Expected a commit array in {filename}")
        for index, item in enumerate(data, start=1):
            message = item.get("commit", {}).get("message", "")
            sha = item.get("sha", f"commit {index}")
            artifact_count += 1
            violations.extend(find_violations(message, f"commit {sha}"))
    for filename in log_files:
        fields = read_text(filename).split("\x00")
        if len(fields) < 2:
            raise ValueError(f"Expected NUL-delimited commit records in {filename}")
        for index in range(0, len(fields) - 1, 2):
            sha = fields[index].strip()
            message = fields[index + 1]
            if not sha:
                continue
            artifact_count += 1
            violations.extend(find_violations(message, f"commit {sha}"))
    return violations, artifact_count


def self_test():
    clean = (
        "fix: correct README typo",
        "Co-authored-by: Jane Doe <jane@example.com>",
        "Preserve the OpenAI license and upstream project credits.",
    )
    rejected = (
        "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>",
        "co-authored-by: ChatGPT <chatgpt@openai.com>",
        "Co-authored-by: Codex <codex@openai.com>",
        "Generated with [Claude Code](https://claude.com/claude-code)",
        "🤖 Generated with ChatGPT",
        "Claude-Session: https://claude.ai/code/session_123",
        "See https://claude.ai/code/session_123 for context.",
        "Written by Kimi",
        "Claude Opus 5.5 <noreply@anthropic.com>",
        "Reviewed by ChatGPT",
        "Co-authored-by: OpenAI <noreply@openai.com>",
    )
    for text in clean:
        if find_violations(text, "clean self-test"):
            raise AssertionError(f"Clean text was rejected: {text}")
    for text in rejected:
        if not find_violations(text, "rejection self-test"):
            raise AssertionError(f"Attribution was accepted: {text}")
    print(f"Attribution validator self-test passed ({len(clean) + len(rejected)} cases).")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--text-file", action="append", default=[])
    parser.add_argument("--commits-json", action="append", default=[])
    parser.add_argument("--commits-log", action="append", default=[])
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return 0
    if not (args.text_file or args.commits_json or args.commits_log):
        parser.error("provide at least one input file or --self-test")
    try:
        violations, artifact_count = check_sources(args.text_file, args.commits_json, args.commits_log)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"Attribution validation error: {error}", file=sys.stderr)
        return 2
    if violations:
        for label, rule, excerpt in violations:
            print(f"{label}: {rule}: {excerpt}", file=sys.stderr)
        print(f"Found prohibited AI attribution in {len(violations)} artifact field(s).", file=sys.stderr)
        return 1
    print(f"No prohibited AI attribution found in {artifact_count} artifact(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
