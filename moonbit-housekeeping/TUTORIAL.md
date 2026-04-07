# Housekeeping Tutorial

## When to Use Which Subcommand

```
Opening a session?           → /moonbit-housekeeping
Finished a session?          → /moonbit-housekeeping fix
Lost track of priorities?    → /moonbit-housekeeping triage
About to cut a release?      → /moonbit-housekeeping release
```

---

## Subcommands

### `/moonbit-housekeeping` — code health check

Quick sanity check. Answers: **"is my repo in a clean state right now?"**

Checks git state, submodules, and lint. Takes ~60s, costs ~$0.04 (Haiku).

Use at the **start of every session** and **before pushing a commit**.

Example output:

```
## Housekeeping Report

git:   PASS  (main, up to date with origin)
lint:  WARN  (2 files needed formatting — run fix)
sync:  PASS  (all submodules clean)
```

---

### `/moonbit-housekeeping fix` — full check + auto-fix

Same check as default, but also runs build + test and applies safe fixes automatically:

- `moon fmt` — reformat .mbt files
- `moon info` — regenerate .mbti interface files
- `moon test --update` — update test snapshots

Use at the **end of a long session** before committing.

---

### `/moonbit-housekeeping triage` — project direction

Answers: **"what should I work on next?"**

Reads `docs/TODO.md`, active plans, GitHub issues, and stale branches. Produces:

- Classified TODO items (done / active / blocked / stale / needs-human-review)
- Orphaned plans not referenced from TODO.md
- Stale branch and worktree candidates (with confirmation before pruning)
- Top 3 recommended next actions

Updates `docs/decisions-needed.md` with items needing a decision.

Use **weekly** or when returning after a break and feeling unsure what to tackle. Costs ~$1-2 (Sonnet).

---

### `/moonbit-housekeeping release` — pre-release prep

Answers: **"is this ready to ship?"**

Runs three checks:

- **changelog** — drafts user-facing changelog from git log, suggests semantic version bump
- **api-review** — classifies `.mbti` changes as intentional / accidental / needs-review, flags breaking changes
- **doc-drift** — checks dev docs, READMEs, and active plans for stale file paths and symbol references

Use **before tagging a release or opening a major PR**. Costs ~$3-5 (Sonnet).

---

## Understanding the Output

### Status levels

- **PASS** — no issues found
- **WARN** — non-blocking (formatting needed, stale branch, dirty submodule)
- **FAIL** — blocking (test failure, build error, lint error)

### Fixable items

Items marked `(fixable)` can be auto-fixed by running `/moonbit-housekeeping fix`. Only formatting, interface regeneration, and snapshot updates are auto-fixed. The skill never commits, pushes, or deletes files without confirmation.

### Confidence levels (triage + release)

- **high** — strong evidence, safe to act on
- **medium** — reasonable evidence, verify before acting
- **low** — mixed signals, human review needed

Items with `confidence: low` or `needs-human-review` are flagged explicitly.

---

## Cost Reference

| Subcommand | Model | Per run |
|---|---|---|
| `/moonbit-housekeeping` | Haiku | ~$0.04 |
| `/moonbit-housekeeping fix` | Haiku | ~$0.06 |
| `/moonbit-housekeeping triage` | Sonnet | ~$1-2 |
| `/moonbit-housekeeping release` | Sonnet | ~$3-5 |
