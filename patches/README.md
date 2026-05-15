# Local Patches Against Upstream Skills

This directory stores diffs that represent local extensions to skills vendored from
`moonbit-agent-guide/` (the upstream submodule). When the top-level duplicate copies
of `moonbit-c-binding/` and `moonbit-refactoring/` were removed in favor of linking
the submodule's versions directly, the local-only content was preserved here.

## Files

| Patch | Base | Status |
|-------|------|--------|
| `moonbit-refactoring-extensions.diff` | `moonbit-agent-guide/moonbit-refactoring/SKILL.md` (commit 25ec084) | Local-only content; candidate for upstream PR |

## Patch Contents — `moonbit-refactoring-extensions.diff`

Adds the following sections to upstream's `moonbit-refactoring/SKILL.md`. Most have been **promoted to the standalone `moonbit-refactoring-safety` skill** and no longer need to live as a patch — see the status column.

| Section | Status |
|---------|--------|
| Workflow step 3 — Safety net (property tests with `@qc.quick_check_fn`) | Promoted to `moonbit-refactoring-safety` |
| Splitting Files — Delete-first technique | Promoted to `moonbit-refactoring-safety` |
| Splitting Packages — expanded walkthrough (`pub using` mechanics, `.mbti` audit, visibility forwarding semantics) | Promoted to `moonbit-refactoring-safety` |
| Prefer List Comprehensions for Build-and-Return Loops (v0.9.2) | Lives in `moonbit-base.md`; candidate for upstream PR |
| Deprecated Syntax Quick Reference rows (v0.9.2 entries, etc.) | Canonical in `moonbit-deprecated-syntax`; not for upstream |
| Misc. stylistic polish (visibility-transfer note for `#as_free_fn`, `..` vs `..rest` semantics, pattern-matching micro-tips) | Candidates for upstream PR; minor enough to drop if the patch becomes inconvenient |

## Usage

To re-apply locally over a fresh upstream pull:

```bash
git -C moonbit-agent-guide apply ../patches/moonbit-refactoring-extensions.diff
```

To turn into an upstream PR: cherry-pick the additions into a branch of
`moonbitlang/moonbit-agent-guide` and open the PR there.
