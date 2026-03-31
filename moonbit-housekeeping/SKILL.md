---
name: moonbit-housekeeping
description: >
  Repo maintenance for MoonBit projects. Two tiers: Haiku for mechanical checks
  (git, lint, sync, build, test), Sonnet for analysis (triage, changelog,
  api-review, doc-drift). Default runs Haiku only; Sonnet categories are opt-in.
  Use at session start, before commits, before PRs, or for periodic cleanup.
---

# MoonBit Housekeeping

Two-tier repo maintenance. **Tier 1 (Haiku):** mechanical checks in 4 sequential phases — fast, cheap, runs by default. **Tier 2 (Sonnet):** bounded analysis tasks — opt-in, for release prep or periodic cleanup.

## Usage

### Tier 1 — Haiku (mechanical, ~$0.04, ~60s)
- `/moonbit-housekeeping` — all Haiku categories, report only (default)
- `/moonbit-housekeeping fix` — all Haiku categories + auto-fix safe items
- `/moonbit-housekeeping git` — git state only
- `/moonbit-housekeeping lint` — formatting + lint only
- `/moonbit-housekeeping sync` — submodule state + mbti drift
- `/moonbit-housekeeping build` — build smoke test only
- `/moonbit-housekeeping test` — test suite only

### Tier 2 — Sonnet (analysis, ~$1-2 each, opt-in)
- `/moonbit-housekeeping triage` — TODO.md freshness, plan archival, orphan detection
- `/moonbit-housekeeping changelog` — draft changelog from git log
- `/moonbit-housekeeping api-review` — classify .mbti changes by risk/intent
- `/moonbit-housekeeping doc-drift` — check dev docs for stale references
- `/moonbit-housekeeping organize` — update decisions-needed.md from triage results

### Combined
- `/moonbit-housekeeping full` — all Haiku + all Sonnet categories (~$5-8)

## When to Use

**Tier 1 (routine):**
- **Start of session** — see repo state before working
- **Before committing** — catch formatting/lint issues
- **After pulling submodule changes** — verify nothing broke
- **Before creating a PR** — full Haiku check
- **After a long session** — `/moonbit-housekeeping fix` to clean up drift

**Tier 2 (periodic):**
- **Release prep** — `/moonbit-housekeeping full` or `/moonbit-housekeeping changelog`
- **Weekly cleanup** — `/moonbit-housekeeping triage` to prune stale TODOs
- **After major refactoring** — `/moonbit-housekeeping api-review` + `/moonbit-housekeeping doc-drift`

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

### Step 2: Determine mode, tier, and categories

Parse the user's argument:

| Input | Mode | Tier | Categories |
|-------|------|------|------------|
| (none) | report | haiku | git, lint, sync, build, test |
| `fix` | fix | haiku | git, lint, sync, build, test |
| `git` | report | haiku | git |
| `lint` | report | haiku | lint |
| `sync` | report | haiku | sync |
| `build` | report | haiku | build |
| `test` | report | haiku | test |
| `fix lint` | fix | haiku | lint |
| `triage` | report | sonnet | triage |
| `changelog` | report | sonnet | changelog |
| `api-review` | report | sonnet | api-review |
| `doc-drift` | report | sonnet | doc-drift |
| `organize` | report | sonnet | organize (runs triage first if needed) |
| `full` | report | both | all haiku + all sonnet |
| `help` | — | none | Read and display TUTORIAL.md |
| `tutorial` | — | none | Same as help |

### Step 2b: Handle help/tutorial

If the input is `help` or `tutorial`: read the file `TUTORIAL.md` from the same directory as this skill file and display its contents to the user. Do not dispatch any subagents. Stop here.

### Step 3: Dispatch subagents

**If Haiku categories requested:** Dispatch Haiku subagent using the Agent tool with `model: haiku`. Use the Haiku Prompt Template below.

**If Sonnet categories requested:** Dispatch Sonnet subagent(s) using the Agent tool with `model: sonnet`. Use the appropriate Sonnet Prompt Template below. Each Sonnet category is a separate agent.

**If `full` mode:** Run Haiku first, then pass Haiku output as context to Sonnet agents. Dispatch all 4 Sonnet agents in parallel (they are independent).

### Step 4: Render report (Opus)

Parse the JSON output from all subagents. Render the unified report. Haiku categories first, then Sonnet categories. If `truncated` is true, note the scan was incomplete. If fixable items exist in report mode, suggest `/moonbit-housekeeping fix`.

---

## Haiku Subagent Prompt Template

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

## Sonnet Subagent Prompt Templates

Each Sonnet category is dispatched as a separate agent with `model: sonnet`.
In `full` mode, include the Haiku JSON output as `{HAIKU_OUTPUT}` context.

### Triage Prompt

~~~
You are a triage agent for a MoonBit project. Assess backlog freshness and output structured JSON.

WORKING DIRECTORY: {CWD}
HAIKU CONTEXT: {HAIKU_OUTPUT_OR_NONE}

RULES:
- Maximum 25 tool calls. Batch aggressively.
- Output ONLY a single JSON object. No prose.
- Separate observations from judgment.
- If uncertain, classify as "needs-human-review", not "done".

WORKFLOW:
1. Read docs/TODO.md in one call.
2. Fetch GitHub issues in ONE Bash call:
   gh issue list --state open --json number,title,labels,body --limit 50 2>/dev/null || echo "gh not available"
   Also fetch recently closed issues for cross-referencing:
   gh issue list --state closed --json number,title,labels --limit 20 2>/dev/null || echo "gh not available"
3. Extract all plan file references (docs/plans/*.md paths). Check which exist in ONE batched Bash call:
   for f in <list of paths>; do echo "=== $f ===" ; test -f "$f" && echo "EXISTS" || echo "MISSING" ; done
4. Extract key terms/symbols from each TODO item. Use `moon ide` for semantic search (preferred) or batch-grep as fallback:
   moon ide find-references Term1 ; moon ide find-references Term2
   Fallback (for non-symbol text): echo "=== term1 ===" ; rg -l "term1" --type mbt ; ...
5. List all files in docs/plans/ and identify orphans (not referenced in TODO.md).
6. Cross-reference TODO items with GitHub issues:
   - TODO items matching closed issues → likely "done"
   - Open issues not in TODO.md → report as "untracked_issues"
   - TODO items with no matching issue → note as "no-issue"
7. Classify each TODO item based on all evidence gathered (local + GitHub).

OUTPUT SCHEMA:
{
  "category": "triage",
  "status": "pass|warn|fail",
  "findings": [
    {
      "id": "todo-1",
      "subject": "TODO item text (truncated)",
      "classification": "done|active|blocked|stale|needs-human-review",
      "confidence": "high|medium|low",
      "severity": "info|warning|error",
      "evidence": ["plan file exists: docs/plans/...", "moon ide find-references: found in editor/foo.mbt", "matches closed issue #12"],
      "recommendation": "archive|keep|investigate"
    }
  ],
  "orphaned_plans": ["docs/plans/file-not-in-todo.md"],
  "untracked_issues": [
    {
      "number": 5,
      "title": "Issue title not tracked in TODO.md",
      "labels": ["enhancement"],
      "recommendation": "add-to-todo|ignore"
    }
  ],
  "truncated": false,
  "tool_calls_used": 12
}

CLASSIFICATION RULES:
- "done": evidence that the work is implemented AND plan status says complete (confidence: high)
- "active": plan exists, no completion evidence, not marked blocked (confidence: high)
- "blocked": plan explicitly says blocked or waiting on dependency (confidence: high)
- "stale": no plan file, no recent git activity, no code evidence (confidence: medium)
- "needs-human-review": mixed signals or insufficient evidence (confidence: low)
~~~

### Changelog Prompt

~~~
You are a changelog agent for a MoonBit project. Draft a changelog from git history and output structured JSON.

WORKING DIRECTORY: {CWD}
HAIKU CONTEXT: {HAIKU_OUTPUT_OR_NONE}

RULES:
- Maximum 25 tool calls. Batch aggressively.
- Output ONLY a single JSON object. No prose.

WORKFLOW:
1. Find the base reference in ONE call:
   echo "=== LATEST TAG ===" ; git describe --tags --abbrev=0 2>/dev/null || echo "NO_TAGS" ; echo "=== COMMIT COUNT ===" ; git rev-list --count HEAD
2. Get commits since base in ONE call:
   If tag exists: git log <tag>..HEAD --oneline --no-merges
   If no tag: git log -50 --oneline --no-merges (last 50 commits)
3. Group commits by conventional commit type (feat, fix, chore, docs, perf, refactor, test).
   For commits without conventional prefix, infer from the message content.
4. Draft user-facing changelog entries. Transform commit messages into readable descriptions.
   Drop chore/internal commits unless they affect users.
5. Suggest semantic version bump based on:
   - feat → minor
   - fix → patch
   - BREAKING in any message → major
   - Only chore/docs → no bump needed

OUTPUT SCHEMA:
{
  "category": "changelog",
  "status": "pass",
  "base": {
    "type": "tag|commit_count",
    "value": "v0.1.0 or 50"
  },
  "total_commits": 23,
  "suggested_bump": "major|minor|patch|none",
  "bump_confidence": "high|medium|low",
  "sections": [
    {
      "type": "added|changed|fixed|removed|deprecated|performance",
      "entries": [
        {
          "description": "User-facing description",
          "commits": ["abc1234"],
          "breaking": false
        }
      ]
    }
  ],
  "skipped_commits": ["def5678 chore: update submodules"],
  "truncated": false,
  "tool_calls_used": 5
}
~~~

### API Review Prompt

~~~
You are an API review agent for a MoonBit project. Classify .mbti interface changes by risk and intent.

WORKING DIRECTORY: {CWD}
HAIKU CONTEXT: {HAIKU_OUTPUT_OR_NONE}

RULES:
- Maximum 25 tool calls. Batch aggressively.
- Output ONLY a single JSON object. No prose.
- Separate observations (what changed) from judgment (is it intentional).
- If HAIKU_CONTEXT includes mbti diff, use it. Do NOT re-run moon info.

WORKFLOW:
1. If no HAIKU_CONTEXT with mbti diff: run `moon info` then `git diff -- '*.mbti'` in ONE call.
   If HAIKU_CONTEXT has mbti diff: skip to step 2.
2. Parse the diff to identify which packages changed. For each changed package, run:
   moon ide analyze <package_dir>/
   This gives the full public API with usage counts (total and test-only).
   Symbols with "usage: 0" are potential dead code.
3. Cross-reference the analyze output with the diff:
   - Added symbols: new in diff + present in analyze output
   - Removed symbols: gone from diff + absent from analyze output
   - Usage counts reveal impact: removing a symbol with "usage: 15" is high-risk
4. For each change, assess intent:
   - Check recent git log for the file to understand what work is in progress.
   - Symbols with 0 non-test usage may be safe to remove (but check if they are public API for library consumers).
5. Classify each change.

OUTPUT SCHEMA:
{
  "category": "api-review",
  "status": "pass|warn|fail",
  "findings": [
    {
      "file": "editor/pkg.generated.mbti",
      "change_type": "added|removed|modified",
      "symbol": "pub fn SyncEditor::new_method(self) -> Unit",
      "classification": "intentional|accidental|needs-review",
      "confidence": "high|medium|low",
      "severity": "info|warning|error",
      "evidence": ["recent commit abc1234 added this method", "no related changes in source"],
      "breaking": false
    }
  ],
  "summary": {
    "added": 3,
    "removed": 0,
    "modified": 1,
    "breaking_changes": 0
  },
  "truncated": false,
  "tool_calls_used": 10
}

CLASSIFICATION RULES:
- "intentional": change matches recent work, source file has corresponding implementation
- "accidental": no corresponding source change, likely drift from moon info regeneration
- "needs-review": unclear intent, mixed signals
- Removed public symbols are always severity "warning" or "error" (potential breaking change)
~~~

### Doc Drift Prompt

~~~
You are a doc-drift agent for a MoonBit project. Check development docs for stale references.

WORKING DIRECTORY: {CWD}
HAIKU CONTEXT: {HAIKU_OUTPUT_OR_NONE}

RULES:
- Maximum 25 tool calls. Batch aggressively.
- Output ONLY a single JSON object. No prose.
- ONLY check development docs, READMEs, and plan references.
- Do NOT check docs/architecture/ — those describe principles, not symbols.
- Do NOT check submodule docs — different ownership.

SCOPE:
- docs/development/*.md
- docs/decisions/*.md
- docs/TODO.md (file/path references only)
- README.md, AGENTS.md
- docs/plans/*.md (active plans only, not archived)

WORKFLOW:
1. List all in-scope doc files in ONE Bash call:
   echo "=== DEV ===" ; ls docs/development/*.md 2>/dev/null ;
   echo "=== DECISIONS ===" ; ls docs/decisions/*.md 2>/dev/null ;
   echo "=== PLANS ===" ; ls docs/plans/*.md 2>/dev/null ;
   echo "=== ROOT ===" ; ls README.md AGENTS.md 2>/dev/null
2. Read each doc file (batch where possible — multiple Read calls are OK).
3. Extract concrete references: file paths, package names, function names, command examples.
   Ignore principle-level statements ("the framework uses X pattern").
4. Verify references exist in ONE batched Bash call:
   for ref in <paths>; do echo "=== $ref ===" ; test -e "$ref" && echo "EXISTS" || echo "MISSING" ; done
5. For function/type references, use `moon ide` (semantic) or grep (fallback):
   moon ide find-references Symbol1 ; moon ide find-references Symbol2
   Fallback (for non-symbol text): for sym in <terms>; do echo "=== $sym ===" ; rg -l "$sym" --type mbt | head -3 ; done
6. Report drift.

OUTPUT SCHEMA:
{
  "category": "doc-drift",
  "status": "pass|warn|fail",
  "findings": [
    {
      "doc_file": "docs/development/workflow.md",
      "reference": "framework/core/types.mbt",
      "reference_type": "file_path|symbol|command|package",
      "classification": "valid|stale|renamed|removed",
      "confidence": "high|medium|low",
      "severity": "info|warning|error",
      "evidence": ["file does not exist", "similar file at framework/core/node.mbt"],
      "recommendation": "update reference|remove reference|investigate"
    }
  ],
  "docs_checked": 12,
  "references_checked": 45,
  "truncated": false,
  "tool_calls_used": 15
}

CLASSIFICATION RULES:
- "valid": reference target exists and matches description (confidence: high)
- "stale": reference target does not exist, no obvious rename (confidence: high)
- "renamed": reference target missing but similar name found nearby (confidence: medium)
- "removed": reference target and related code completely gone (confidence: high)
~~~

### Organize Prompt

~~~
You are an organize agent for a MoonBit project. Update the decision queue from triage results.

WORKING DIRECTORY: {CWD}
TRIAGE OUTPUT: {TRIAGE_JSON_OR_NONE}

RULES:
- Maximum 15 tool calls. Batch aggressively.
- This agent WRITES files (docs/decisions-needed.md). It is NOT read-only.
- Always show the proposed changes before writing. Output a JSON diff first.
- Preserve any human-added notes or annotations in existing items.

WORKFLOW:
1. If TRIAGE_JSON is not provided, tell Opus to run triage first. Do not proceed.
2. Read docs/decisions-needed.md (if it exists).
3. From triage findings, extract items with classification "needs-human-review".
4. Compare with existing decisions-needed.md:
   - NEW: items in triage but not in decisions-needed.md → add to "Pending" section
   - RESOLVED: items in decisions-needed.md but classified as "done" in triage → move to "Recently Resolved"
   - UNCHANGED: items in both with same classification → preserve, keep any human notes
   - DECIDED: items that now exist in docs/decisions/ → remove from decisions-needed.md
5. Also check: items classified as "active" or "blocked" that have no plan file → suggest creating one
6. Write the updated docs/decisions-needed.md using the Edit tool.

For NEW items, format as:

### <short title>
**Source:** <where it came from>
**Context:** <what the decision is about, 2-3 sentences>
**Blocks:** <what this decision blocks, or "Nothing directly">
**Evidence:** <evidence from triage>
**Added:** <today's date>

OUTPUT SCHEMA:
{
  "category": "organize",
  "status": "pass|warn",
  "actions": [
    {
      "type": "added|resolved|removed|unchanged",
      "item": "short title",
      "reason": "explanation"
    }
  ],
  "pending_count": 3,
  "resolved_count": 0,
  "suggestions": [
    "Consider creating a plan for 'position-cache-non-sequential' (active, no plan)"
  ],
  "truncated": false,
  "tool_calls_used": 8
}
~~~

---

## Report Format (Opus renders this from JSON)

```
## Housekeeping Report

### Tier 1 (Haiku)
git:   {STATUS}  ({one-line summary})
lint:  {STATUS}  ({one-line summary})
sync:  {STATUS}  ({one-line summary})
build: {STATUS}  ({one-line summary})
test:  {STATUS}  ({one-line summary})

### Tier 2 (Sonnet)  ← only shown if Sonnet categories were requested
triage:     {STATUS}  ({N} done, {N} active, {N} stale, {N} orphaned plans, {N} untracked issues)
changelog:  {STATUS}  ({N} commits → suggested bump: {minor/patch/none})
api-review: {STATUS}  ({N} changes: {N} intentional, {N} needs review)
doc-drift:  {STATUS}  ({N} docs checked, {N} stale references)
```

If any category has warnings or errors, add a Details section:

```
### Details

**lint (WARN)**
- warning: `editor/foo.mbt` needs formatting (fixable)
- warning: unused import `immut/hashset` in `event-graph-walker/internal/causal_graph/moon.pkg`

**triage (WARN)**
- warning: TODO item "add X feature" appears done (high confidence) — recommend archive
- info: 3 orphaned plans in docs/plans/ not referenced in TODO.md
```

If MODE was "fix", list what was auto-fixed.
If MODE was "report" and fixable items exist:
> Run `/moonbit-housekeeping fix` to auto-fix {N} items.

For Sonnet findings with `confidence: low` or `classification: needs-human-review`, flag them explicitly so the user knows to verify.

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
