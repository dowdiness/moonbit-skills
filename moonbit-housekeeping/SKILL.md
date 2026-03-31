---
name: moonbit-housekeeping
description: >
  Repo maintenance for MoonBit projects. Dispatches a Haiku subagent to run
  phased mechanical checks (git state, moon fmt/check/info, build, test).
  Default is read-only report; fix mode auto-applies safe changes.
  Use at session start, before commits, before PRs, or for periodic cleanup.
---

# MoonBit Housekeeping

Dispatches a single Haiku subagent to run mechanical repo maintenance in 4 sequential phases. Replaces manual `/health-check` workflows.

## Usage

- `/moonbit-housekeeping` — full scan, report only (default)
- `/moonbit-housekeeping fix` — full scan + auto-fix safe items
- `/moonbit-housekeeping git` — git state only
- `/moonbit-housekeeping lint` — formatting + lint only
- `/moonbit-housekeeping sync` — submodule state + mbti drift
- `/moonbit-housekeeping build` — build smoke test only
- `/moonbit-housekeeping test` — test suite only

## When to Use

- **Start of session** — see repo state before working
- **Before committing** — catch formatting/lint issues
- **After pulling submodule changes** — verify nothing broke
- **Before creating a PR** — full check
- **After a long session** — `/moonbit-housekeeping fix` to clean up drift

## When NOT to Use

- Mid-implementation (use incremental `moon check` after each edit)
- For debugging (use `/systematic-debugging`)
- For code review (use `/parallel-review`)

## Execution

### Step 1: Preflight (Opus)

Before dispatching the subagent, verify:

```bash
which moon
```

If `moon` is not on PATH, report the error and stop.

### Step 2: Determine mode and categories

Parse the user's argument:

| Input | Mode | Categories |
|-------|------|------------|
| (none) | report | all |
| `fix` | fix | all |
| `git` | report | git |
| `lint` | report | lint |
| `sync` | report | sync |
| `build` | report | build |
| `test` | report | test |
| `fix lint` | fix | lint |

### Step 3: Dispatch Haiku subagent

Use the Agent tool with `model: haiku`. Compose the prompt by substituting `{MODE}`, `{CATEGORIES}`, and `{CWD}` into the template below.

### Step 4: Render report (Opus)

Parse the JSON output from the subagent. Render the unified report format shown below. If `truncated` is true, note the scan was incomplete. If fixable items exist in report mode, suggest `/moonbit-housekeeping fix`.

---

## Subagent Prompt Template

~~~
You are a housekeeping agent for a MoonBit project. Run mechanical repo checks and output structured JSON.

MODE: {MODE}  (report = read-only, fix = keep safe changes)
CATEGORIES: {CATEGORIES}  (all, git, lint, sync, build, test)
WORKING DIRECTORY: {CWD}

RULES:
- MINIMIZE tool calls. Batch multiple commands into single Bash calls using && or ;
- Maximum 18 tool calls. If approaching the limit, report what you have and stop.
- Output ONLY a single JSON object matching the schema below. No prose before or after.
- Discover submodules dynamically: parse .gitmodules for paths.
- Discover test targets dynamically: check for moon.mod.json in each submodule directory.
- Skip categories not in {CATEGORIES}.

---

PHASE 1 — git snapshot (categories: git, sync, all)

Run ALL of these in ONE Bash call, separated by ; (so all run even if one fails):
  echo "=== STATUS ===" ; git status --short ;
  echo "=== AHEAD ===" ; git log --oneline origin/main..HEAD ;
  echo "=== BEHIND ===" ; git log --oneline HEAD..origin/main ;
  echo "=== MERGED ===" ; git branch --merged main | grep -v main ;
  echo "=== WORKTREES ===" ; git worktree list ;
  echo "=== PRS ===" ; gh pr list --state open --json number,title,headRefName,statusCheckRollup 2>/dev/null || echo "gh not available" ;
  echo "=== SUBMODULES ===" ; git submodule status ;
  echo "=== UNTRACKED ===" ; git ls-files --others --exclude-standard

For submodules, note if any are dirty (+prefix) or on detached HEAD.

---

PHASE 2 — moon tools (categories: lint, sync, all)

Run ALL in ONE Bash call:
  moon update && moon fmt ; moon check 2>&1 ; moon info

If any command fails, the remaining commands still run due to ; separators.

---

PHASE 3 — git diff (runs if phase 2 ran)

Run in ONE Bash call:
  echo "=== STAT ===" ; git diff --stat ; echo "=== MBTI ===" ; git diff -- '*.mbti'

This captures what phase 2 changed (formatting fixes, interface regeneration).

If MODE is "report": run `git checkout -- .` to revert all changes.
If MODE is "fix": keep the changes. They will be reported as fixed items.

---

PHASE 4 — build + test (categories: build, test, all)

For build (category: build, all) — run in ONE Bash call:
  echo "=== JS BUILD ===" ; moon build --target js 2>&1 ; echo "=== WEB BUILD ===" ; if [ -d examples/web/node_modules ]; then cd examples/web && npm run build 2>&1; else echo "skipped: node_modules not installed"; fi

For test (category: test, all) — run in ONE Bash call:
  First discover submodules with moon.mod.json, then run all tests chained:
  echo "=== MAIN ===" ; moon test 2>&1 ; for dir in $(grep 'path = ' .gitmodules | sed 's/.*= //'); do if [ -f "$dir/moon.mod.json" ]; then echo "=== $dir ===" ; (cd "$dir" && moon test 2>&1) ; fi ; done

---

OUTPUT SCHEMA:

{
  "phases": {
    "git": {
      "status": "pass|warn|fail",
      "items": [
        {"severity": "error|warning|info", "file": null, "message": "description", "fixable": false}
      ]
    },
    "lint": {"status": "pass|warn|fail", "items": [...]},
    "sync": {"status": "pass|warn|fail", "items": [...]},
    "build": {"status": "pass|warn|fail", "items": [...]},
    "test": {"status": "pass|warn|fail", "items": [...]}
  },
  "truncated": false,
  "tool_calls_used": 20
}

Only include categories that were requested. Omit skipped categories from the JSON.

STATUS RULES:
- "pass" = no issues found
- "warn" = non-blocking issues (dirty submodule, formatting needed, stale branch, commits ahead/behind)
- "fail" = blocking issues (test failure, build error, moon check error)

SEVERITY RULES:
- "error" = must fix (test failure, build error, lint error)
- "warning" = should fix (dirty submodule, formatting drift, stale branch, detached HEAD)
- "info" = informational (commits ahead/behind, open PRs, untracked files, skipped checks)

FIXABLE RULES:
- Set "fixable": true ONLY for: formatting changes (moon fmt), interface regeneration (moon info), snapshot updates (moon test --update)
- Everything else is "fixable": false
~~~

---

## Report Format (Opus renders this from JSON)

```
## Housekeeping Report

git:   {STATUS}  ({one-line summary})
lint:  {STATUS}  ({one-line summary})
sync:  {STATUS}  ({one-line summary})
build: {STATUS}  ({one-line summary})
test:  {STATUS}  ({one-line summary})
```

If any category has warnings or errors, add a Details section:

```
### Details

**lint (WARN)**
- warning: `editor/foo.mbt` needs formatting (fixable)
- warning: unused import `immut/hashset` in `event-graph-walker/internal/causal_graph/moon.pkg`

**sync (WARN)**
- warning: `loom` submodule is 3 commits behind origin/main
- info: `event-graph-walker` submodule is clean
```

If MODE was "fix", list what was auto-fixed.
If MODE was "report" and fixable items exist:
> Run `/moonbit-housekeeping fix` to auto-fix {N} items.

## Fix Mode Whitelist

ONLY these operations are allowed in fix mode:
- `moon fmt` — reformat .mbt files (deterministic, reversible)
- `moon info` — regenerate .mbti interface files (deterministic)
- `moon test --update` — update test snapshots (reviewable via git diff)

Everything else is report-only:
- Never `git pull`, `git push`, `git stash`, or checkout branches
- Never modify source code logic
- Never delete files or branches
- Never commit (the user decides when to commit)

## Guardrails

- Default mode is **read-only**. Phase 2 changes are reverted after phase 3 in report mode.
- 25 tool-call hard limit prevents runaway subagents.
- Dynamic discovery (`.gitmodules`, `moon.mod.json`) prevents hardcoded staleness.
- Build failures in `examples/web/` due to missing `node_modules` are reported as skipped, not failed.
- If `gh` CLI is not available, PR checks are skipped gracefully.
