---
name: codex
description: "Delegate coding to OpenAI Codex CLI (features, PRs)."
version: 1.0.1
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Coding-Agent, Codex, OpenAI, Code-Review, Refactoring]
    related_skills: [claude-code, hermes-agent]
---

# Codex CLI

Delegate coding tasks to [Codex](https://github.com/openai/codex) via the Hermes terminal. Codex is OpenAI's autonomous coding agent CLI.

## When to use

- Building features
- Refactoring
- PR reviews
- Batch issue fixing

Requires the codex CLI and a git repository.

## Prerequisites

- Codex installed: `npm install -g @openai/codex`
- OpenAI auth configured: either `OPENAI_API_KEY` or Codex OAuth credentials
  from the Codex CLI login flow
- **Must run inside a git repository** — Codex refuses to run outside one
- Use `pty=true` in terminal calls — Codex is an interactive terminal app

For Hermes itself, `model.provider: openai-codex` uses Hermes-managed Codex
OAuth from `~/.hermes/auth.json` after `hermes auth add openai-codex`. For the
standalone Codex CLI, a valid CLI OAuth session may live under
`~/.codex/auth.json`; do not treat a missing `OPENAI_API_KEY` alone as proof
that Codex auth is missing.

## One-Shot Tasks

```
terminal(command="codex exec 'Add dark mode toggle to settings'", workdir="~/project", pty=true)
```

For scratch work (Codex needs a git repo):
```
terminal(command="cd $(mktemp -d) && git init && codex exec 'Build a snake game in Python'", pty=true)
```

## Background Mode (Long Tasks)

```
# Start in background with PTY
terminal(command="codex exec --sandbox workspace-write 'Refactor the auth module'", workdir="~/project", background=true, pty=true)
# Returns session_id

# Monitor progress
process(action="poll", session_id="<id>")
process(action="log", session_id="<id>")

# Send input if Codex asks a question
process(action="submit", session_id="<id>", data="yes")

# Kill if needed
process(action="kill", session_id="<id>")
```

## Key Flags

| Flag | Effect |
|------|--------|
| `exec "prompt"` | One-shot execution, exits when done |
| `--sandbox workspace-write` (`-s`) | Sandboxed but auto-approves file changes in the workspace (the recommended auto-build mode) |
| `--dangerously-bypass-approvals-and-sandbox` | No sandbox, no approvals (fastest, most dangerous; `--yolo` still works as a hidden alias) |
| `--sandbox danger-full-access` | No Codex sandbox; useful when the host service context breaks bubblewrap |

> **Deprecated:** `--full-auto` still works but the live CLI warns to use `--sandbox workspace-write` instead.

## Hermes Gateway Caveat

When invoking the Codex CLI from a Hermes gateway/service context (for example,
Telegram-driven agent sessions), Codex `workspace-write` sandboxing may fail even
when the same command works in the user's interactive shell. A typical symptom is
bubblewrap/user-namespace errors such as `setting up uid map: Permission denied`
or `loopback: Failed RTM_NEWADDR: Operation not permitted`.

In that context, prefer:

```
codex exec --sandbox danger-full-access "<task>"
```

Use process boundaries as the safety layer instead: explicit `workdir`, clean git
status before launch, narrow task prompts, `git diff` review, targeted tests, and
human/agent confirmation before committing broad changes.

## PR Reviews

Clone to a temp directory for safe review:

```
terminal(command="REVIEW=$(mktemp -d) && git clone https://github.com/user/repo.git $REVIEW && cd $REVIEW && gh pr checkout 42 && codex review --base origin/main", pty=true)
```

## Parallel Issue Fixing with Worktrees

```
# Create worktrees
terminal(command="git worktree add -b fix/issue-78 ~/.hermes/cache/scratch/issue-78 main", workdir="~/project")
terminal(command="git worktree add -b fix/issue-99 ~/.hermes/cache/scratch/issue-99 main", workdir="~/project")

# Launch Codex in each
terminal(command="codex --sandbox workspace-write exec 'Fix issue #78: <description>. Commit when done.'", workdir="~/.hermes/cache/scratch/issue-78", background=true, pty=true)
terminal(command="codex --sandbox workspace-write exec 'Fix issue #99: <description>. Commit when done.'", workdir="~/.hermes/cache/scratch/issue-99", background=true, pty=true)

# Monitor
process(action="list")

# After completion, push and create PRs
terminal(command="cd ~/.hermes/cache/scratch/issue-78 && git push -u origin fix/issue-78")
terminal(command="gh pr create --repo user/repo --head fix/issue-78 --title 'fix: ...' --body '...'")

# Cleanup
terminal(command="git worktree remove ~/.hermes/cache/scratch/issue-78", workdir="~/project")
```

## Batch PR Reviews

```
# Fetch all PR refs
terminal(command="git fetch origin '+refs/pull/*/head:refs/remotes/origin/pr/*'", workdir="~/project")

# Review multiple PRs in parallel
terminal(command="codex exec 'Review PR #86. git diff origin/main...origin/pr/86'", workdir="~/project", background=true, pty=true)
terminal(command="codex exec 'Review PR #87. git diff origin/main...origin/pr/87'", workdir="~/project", background=true, pty=true)

# Post results
terminal(command="gh pr comment 86 --body '<review>'", workdir="~/project")
```

## Host Install Notes (arm64 Raspberry Pi / no sudo)

On an arm64 Debian host where the default npm prefix (`$(npm config get prefix)`) is
root-owned and there is no `sudo`, install into a user prefix and export it:

```
mkdir -p ~/.npm-global
npm install -g --prefix ~/.npm-global @openai/codex
```

- The platform binary is an **alias** on the main package, not a separate npm package:
  `@openai/codex@<ver>-linux-arm64`. Querying `@openai/codex-linux-arm64` directly
  returns E404 — that is expected, not a broken install. npm resolves the alias via
  `optionalDependencies`.
- Real binary path after install:
  `~/.npm-global/lib/node_modules/@openai/codex/node_modules/@openai/codex-linux-arm64/vendor/aarch64-unknown-linux-musl/bin/codex`
  (~245 MB, native ELF64 ARM64 — verify by reading `e_machine == 0xB7`).
- Known regression: issue #14474 segfaults (`SEGV_ACCERR`, exit 139) on Raspberry Pi
  aarch64 with the bundled musl binary, introduced in **0.114.0** (0.113.0 and earlier
  work). Confirm empirically with `codex doctor` before relying on a given version; if a
  version segfaults, pin the last known-good one.
- **Verify the real thing, not just `--version`**: `codex --version` and `--help` exit 0
  even when the provider is unreachable. Run `codex exec` in a throwaway git repo to
  confirm end-to-end reachability:
  `cd $(mktemp -d) && git init -q && codex exec --sandbox danger-full-access "say PONG"`
  A run that stalls on `ERROR: Reconnecting... n/5` means the provider endpoints are
  blocked from that network, not that the install is broken.

## Custom OpenAI-Compatible Provider (this host)

This host cannot reach `chatgpt.com` / `auth.openai.com` (000 / 403), but npm and GitHub
work. Codex is therefore pointed at an OpenAI-compatible relay instead of ChatGPT:

```toml
# ~/.codex/config.toml
model = "LongCat-2.5-Preview"
model_provider = "longcat"

[model_providers.longcat]
name = "LongCat Chat"
base_url = "https://api.longcat.chat/openai/v1"
env_key = "OPENAI_API_KEY"
supports_websockets = false
```

Field-name gotchas (learned by trial; `codex exec` reports ignored keys as warnings):
- The API-key env var field is **`env_key`**, NOT `api_key_env` (which is silently ignored
  and then yields `401 missing_api_key`).
- **`supports_websockets = false` is mandatory.** Codex's Responses client tries
  `wss://<base_url>/responses` first; relays that only allow POST answer `405`, and the
  fallback path also fails until websocket support is disabled.
- `api_key_env` / `wire_api` are dead ends; `wire_api = "chat"` is no longer supported.
- `OPENAI_API_KEY` is exported from `~/.profile` / `~/.bashrc` so fresh shells and cron
  jobs pick it up. **That file holds the key in plaintext** — treat it as a secret.

Quick verification (writes + runs code):
```
D=$(mktemp -d) && cd "$D" && git init -q
codex exec --sandbox danger-full-access "create hello.py with add(a,b); run it"
```

For proving the setup on **real multi-file work** instead of a toy prompt, see
`references/verification.md` — build a project with a known gap, delegate a bounded
feature, then re-check the diff and the test suite yourself.

## Rules

1. **Always use `pty=true`** — Codex is an interactive terminal app and hangs without a PTY
2. **Git repo required** — Codex won't run outside a git directory. Use `mktemp -d && git init` for scratch
3. **Use `exec` for one-shots** — `codex exec "prompt"` runs and exits cleanly
4. **`--sandbox workspace-write` for building** — auto-approves changes within the sandbox (`--full-auto` is deprecated for this)
5. **Background for long tasks** — use `background=true` and monitor with `process` tool
6. **Don't interfere** — monitor with `poll`/`log`, be patient with long-running tasks
7. **Parallel is fine** — run multiple Codex processes at once for batch work
8. **Verify independently — never report the agent's self-report as fact.** A completion summary ("18 tests pass") is a claim, not evidence. Re-run the test suite and exercise the CLI yourself before telling the user it works. See `references/verification.md`.
