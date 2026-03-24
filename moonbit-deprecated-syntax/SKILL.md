---
name: moonbit-deprecated-syntax
description: Tracks deprecated MoonBit syntax to avoid generating invalid code. Reference this before writing MoonBit code. Auto-maintained when deprecated patterns are discovered.
---

# MoonBit Deprecated Syntax

Reference this skill before writing MoonBit code. Using deprecated syntax causes warnings, and CI configurations with `-w @a` (warnings as errors) will fail.

## Deprecated Patterns

| Deprecated | Replacement | Since | Notes |
|-----------|-------------|-------|-------|
| `tuple._` (underscore field access) | `tuple.0`, `tuple.1`, etc. | 2025 | Positional index, not underscore |
| `.is_some()` | `x is Some(_)` | 2026 | Use `is` pattern matching |
| `.is_none()` | `x is None` | 2026 | Use `is` pattern matching |
| `.is_empty()` on Option | `x is None` | 2026 | Use `is` pattern matching |
| `supported-targets` in moon.pkg.json | Per-file conditional compilation | 2025 | Use `*_js.mbt`, `*_wasm.mbt` suffixes |

## Examples

```moonbit
// WRONG — deprecated
let has_value = opt.is_some()
let no_value = opt.is_none()
let (a, b) = (tuple._, tuple._)

// CORRECT — current syntax
let has_value = opt is Some(_)
let no_value = opt is None
let (a, b) = (tuple.0, tuple.1)
```

## How This Skill Is Maintained

When a new deprecated pattern is discovered (e.g., CI fails with `deprecated` warning), add it to the table above with the replacement and approximate date.
