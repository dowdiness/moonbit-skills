# Housekeeping Tutorial

## Quick Start

Run this at the start of any session:

```
/moonbit-housekeeping
```

You'll get a report like:

```
## Housekeeping Report

git:   PASS  (main, up to date with origin)
lint:  WARN  (2 files needed formatting)
sync:  PASS  (all submodules clean)
build: PASS  (js: ok, web: ok)
test:  PASS  (1906 tests passed across 6 modules)
```

If there are fixable items (formatting, stale interfaces), run:

```
/moonbit-housekeeping fix
```

That's it for daily use.

---

## Daily Workflow

### Start of session

```
/moonbit-housekeeping
```

Checks everything: git state, submodules, lint, build, tests. Takes ~60 seconds, costs ~$0.04 (Haiku).

### Before committing

```
/moonbit-housekeeping lint
```

Runs only `moon fmt`, `moon check`, `moon info`. Fastest check (~20s). If it reports drift, run `fix`:

```
/moonbit-housekeeping fix
```

Then stage and commit.

Note: there's also a pre-commit hook in `settings.json` that blocks commits with formatting drift or test failures. The hook runs automatically — `/moonbit-housekeeping lint` is for checking before you're ready to commit.

### Before creating a PR

```
/moonbit-housekeeping
```

Full Haiku check. Make sure everything is green before pushing.

### After pulling submodule changes

```
/moonbit-housekeeping test
```

Runs tests across main module and all submodules. Catches breakage from upstream changes.

---

## Weekly Cleanup

### Step 1: Triage the backlog

```
/moonbit-housekeeping triage
```

This Sonnet agent reads `docs/TODO.md`, checks plan files, greps for evidence of completion, and classifies each item:

- **done** — work is implemented, plan is complete
- **active** — plan exists, work not finished
- **blocked** — explicitly waiting on something
- **stale** — no plan, no code evidence, no recent activity
- **needs-human-review** — mixed signals, you need to decide

It also finds **orphaned plans** — files in `docs/plans/` not referenced from `docs/TODO.md`.

### Step 2: Update the decision queue

```
/moonbit-housekeeping organize
```

This reads the triage output and updates `docs/decisions-needed.md`:

- Adds new `needs-human-review` items
- Flags items that have been resolved since last run
- Preserves any notes you've added
- Suggests creating plans for active items without one

### Step 3: Review decisions

Open `docs/decisions-needed.md`. Each pending item has:

```markdown
### <title>
**Source:** where it came from
**Context:** what the decision is about
**Blocks:** what this blocks
**Evidence:** what triage found
**Added:** when it was added
```

When you've decided:

1. Create `docs/decisions/YYYY-MM-DD-<topic>.md` with your decision
2. Remove the item from `docs/decisions-needed.md`
3. Next time organize runs, it will detect the resolution

---

## Release Prep

### Full check

```
/moonbit-housekeeping full
```

Runs all Haiku categories + all Sonnet categories. Takes a few minutes, costs ~$5-8. Shows everything:

```
### Tier 1 (Haiku)
git:   PASS  (...)
lint:  PASS  (...)
sync:  PASS  (...)
build: PASS  (...)
test:  PASS  (...)

### Tier 2 (Sonnet)
triage:     WARN  (2 done, 7 active, 3 stale, 12 orphaned plans)
changelog:  PASS  (50 commits → suggested bump: minor)
api-review: PASS  (3 changes: 3 intentional, 0 needs review)
doc-drift:  WARN  (2 stale references in dev docs)
```

### Draft a changelog

```
/moonbit-housekeeping changelog
```

Reads git log, groups by conventional commit type, drafts user-facing changelog entries, suggests semantic version bump. Output follows Keep a Changelog format.

### Review API changes

```
/moonbit-housekeeping api-review
```

Reads `.mbti` interface diffs and classifies each change as intentional, accidental, or needs-review. Flags potential breaking changes.

### Check doc freshness

```
/moonbit-housekeeping doc-drift
```

Checks development docs, READMEs, and active plans for stale file paths, function names, and command examples. Skips architecture docs (those describe principles, not symbols).

---

## Single-Category Reference

| Command | Tier | What it checks | When to use |
|---------|------|---------------|-------------|
| `/moonbit-housekeeping` | Haiku | All mechanical checks | Session start, before PR |
| `/moonbit-housekeeping fix` | Haiku | All + auto-fix safe items | After long sessions |
| `/moonbit-housekeeping git` | Haiku | git status, branches, PRs, submodules | Quick state check |
| `/moonbit-housekeeping lint` | Haiku | moon fmt, check, info | Before committing |
| `/moonbit-housekeeping sync` | Haiku | Submodule state, mbti drift | After submodule updates |
| `/moonbit-housekeeping build` | Haiku | JS build, web build | After FFI changes |
| `/moonbit-housekeeping test` | Haiku | All test suites | After any code change |
| `/moonbit-housekeeping triage` | Sonnet | TODO.md freshness | Weekly cleanup |
| `/moonbit-housekeeping organize` | Sonnet | Update decisions-needed.md | After triage |
| `/moonbit-housekeeping changelog` | Sonnet | Draft changelog | Release prep |
| `/moonbit-housekeeping api-review` | Sonnet | .mbti change classification | After refactoring |
| `/moonbit-housekeeping doc-drift` | Sonnet | Stale doc references | After refactoring |
| `/moonbit-housekeeping full` | Both | Everything | Release prep |

---

## Understanding the Output

### Status levels

- **PASS** — no issues found
- **WARN** — non-blocking issues (formatting needed, stale branch, dirty submodule)
- **FAIL** — blocking issues (test failure, build error, lint error)

### Fixable items

Items marked `(fixable)` in the report can be auto-fixed by running `/moonbit-housekeeping fix`. Only these operations are auto-fixed:

- `moon fmt` — reformat .mbt files
- `moon info` — regenerate .mbti interface files
- `moon test --update` — update test snapshots

Everything else is report-only. The skill never commits, pushes, or deletes files.

### Sonnet confidence levels

Sonnet categories include confidence ratings:

- **high** — strong evidence, safe to act on
- **medium** — reasonable evidence, verify before acting
- **low** — mixed signals, human review needed

Items with `confidence: low` or `classification: needs-human-review` are flagged explicitly.

---

## Cost Reference

| Tier | Per run | When |
|------|---------|------|
| Haiku (default) | ~$0.04 | Every session |
| Single Sonnet category | ~$1-2 | On demand |
| Full (all categories) | ~$5-8 | Release prep |

Default `/moonbit-housekeeping` is always Haiku-only. Sonnet categories are never run unless you explicitly ask for them.
