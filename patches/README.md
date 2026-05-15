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

Adds the following sections to upstream's `moonbit-refactoring/SKILL.md`:

- **Workflow step 3 — Safety net**: write property tests with `@qc.quick_check_fn` before structural changes.
- **Splitting Files — Delete-first technique**: delete the original after extracting, let `moon check` report missing definitions.
- **Splitting Packages — expanded walkthrough**: `pub using` re-export mechanics, `.mbti` stability checks, what re-exports automatically, visibility forwarding semantics.
- **Prefer List Comprehensions for Build-and-Return Loops (v0.9.2)**: replacing `Array::new` + `push` patterns with `[ for x in xs => f(x) ]`, including the filter form and the "when to keep the explicit loop" caveat.
- **Deprecated Syntax Quick Reference table**: extra rows beyond upstream's coverage, including v0.9.2 entries.

## Usage

To re-apply locally over a fresh upstream pull:

```bash
git -C moonbit-agent-guide apply ../patches/moonbit-refactoring-extensions.diff
```

To turn into an upstream PR: cherry-pick the additions into a branch of
`moonbitlang/moonbit-agent-guide` and open the PR there.
