---
name: moonbit-deprecated-syntax
description: Tracks deprecated MoonBit syntax to avoid generating invalid code. Reference this before writing MoonBit code. Auto-maintained when deprecated patterns are discovered.
---

# MoonBit Deprecated Syntax

Reference this skill before writing MoonBit code. Using deprecated syntax causes warnings, and CI configurations with `-w @a` (warnings as errors) will fail.

## Deprecated Patterns

| Deprecated | Replacement | Notes |
|-----------|-------------|-------|
| `tuple._` | `tuple.0`, `tuple.1` | Positional index, not underscore |
| `opt.is_some()` | `opt is Some(_)` | Use `is` pattern matching |
| `opt.is_none()` | `opt is None` | Use `is` pattern matching |
| `opt.is_empty()` on Option | `opt is None` | Use `is` pattern matching |
| `supported-targets` in moon.pkg.json | Per-file conditional compilation | Use `*_js.mbt`, `*_wasm.mbt` suffixes |
| `inspect!(expr)` | `inspect(expr)` | Bang syntax deprecated |
| `map.size()` | `map.length()` | Use `.length()` for all collections |
| `opt.or(default)` | `opt.unwrap_or(default)` | `.or()` deprecated |
| `text.substring(start=i, end=j)` | `text[i:j].to_string()` | Slice syntax preferred |
| `pub typealias X = Y` | `pub type X = Y` | `typealias` keyword removed |
| `let UPPER_CASE` at module level | `let lower_case` | Uppercase requires `const`, not `let` |
| `not(expr)` | `!expr` | Use prefix `!` operator |
| `else { ... }` in for-loop nobreak | `nobreak { ... }` | `else` deprecated for nobreak blocks |
| `loop (xs, 0) { ... => continue ... }` | `for` + `match` with state variables | `loop` keyword being removed |
| `derive(Show)` | `derive(Debug)` + manual `impl Show` if needed | `derive(Show)` warns [0027]; `Show` trait itself is NOT deprecated — `inspect()` still requires it. Use `derive(Debug)` for debugging; add manual `impl Show` for `inspect`/`to_string` (v0.9) |
| `lexmatch`/`lexmatch?` | `s =~ re"..."` regex expressions | Planned removal; use stable regex syntax (v0.9) |
| `@immut/array` | `@immut/vector` | `immut/vector` replaces `immut/array` with better performance (v0.9) |

## API Patterns

| Don't use | Use instead | Notes |
|-----------|-------------|-------|
| `map[key]` for lookup | `map.get(key)` | `map[key]` calls `at()` which panics on missing key |
| `map[key]` is fine for SET | `map[key] = value` | Setting values with `[]` is correct |
| `@math.ln(x)` | `@math.ln(x)` | Method `.ln()` doesn't exist on Double |
| `Array::init(n, fn)` | `Array::makei(n, fn)` | Check which is available |

## Loop Syntax Guide

```moonbit
// DEPRECATED — being removed
loop (xs, 0) {
  (Empty, acc) => acc
  (More(x, rest), acc) => continue (rest, x + acc)
}

// REPLACEMENT — for + match (direct translation of loop's multi-value pattern matching)
// Each loop state variable becomes a `for` binding; pattern arms use break/continue
for xs = xs, acc = 0 {
  match xs {
    Empty => break acc
    More(x, rest) => continue rest, x + acc
  }
}

// PREFERRED — for-in with additional loop variables (when iterating a collection)
for x in xs; sum = 0 {
  continue sum + x
} nobreak {
  sum
}

// VALID — C-style for with multiple bindings
for i = 0, acc = 0; i < n; i = i + 1 {
  continue i + 1, acc + xs[i]
} nobreak { acc }

// VALID — simple for-in with mut (imperative style)
let mut acc = 0
for x in xs {
  acc += x
}
```

### When to use which replacement

| `loop` pattern | Replace with |
|---|---|
| Pattern matching on a recursive structure (linked list, tree) | `for` + `match` with state variables |
| Iterating over a collection with accumulator | `for x in xs; acc = 0 { ... }` |
| Index-based iteration with state | C-style `for i = 0, acc = 0; ...` |
| Simple aggregation, no pattern matching needed | `for x in xs` with `let mut` |

## How This Skill Is Maintained

When a new deprecated pattern is discovered (e.g., CI fails with `deprecated` warning, or user corrects syntax), add it to the table above with the replacement.
