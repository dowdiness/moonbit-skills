# MoonBit Base Conventions

## Quick Reference

| When...                    | Use...                              | Not...                        |
|----------------------------|-------------------------------------|-------------------------------|
| Top-level fixed value      | `const`                             | `let`                         |
| Local immutable binding    | `let`                               | `const` (illegal in functions)|
| Mutable variable           | `let mut`                           |                               |
| Bail out early             | `guard`                             | `if ... { return }`           |
| Branch on variants         | `match`                             | chained `if/else`             |
| Simple boolean             | `if/else`                           |                               |
| Public struct              | custom `fn new()` constructor       | bare `{ field: value }`       |
| Empty callback body        | `() => ()`                          | `() => {}` (map literal!)     |
| Tuple field access         | `.0`                                | `._` (deprecated)             |
| Fallible return type       | `T!Error` with `!` propagation      | `try?` (won't catch abort)    |
| Iteration                  | `for .. in`                         | `loop` (deprecated)           |
| Visibility default         | `pub`                               | `pub(all)` unless needed      |
| Foreign trait + foreign type | newtype wrapper                   | direct impl (orphan rule)     |
| Unimplemented placeholder  | `...`                               | leaving in committed code     |

## MoonBit Code Search

Prefer `moon ide` over grep/glob for MoonBit-specific code search. These commands use the compiler's semantic understanding, not text matching.

```bash
moon ide peek-def SyncEditor              # Go-to-definition with context
moon ide peek-def -loc editor/foo.mbt:5   # Definition at cursor position
moon ide find-references SyncEditor       # All usages across codebase
moon ide outline editor/                  # Package structure overview
moon ide doc "String::*rev*"              # API discovery with wildcards
```

Symbol syntax: `Symbol`, `@pkg.Symbol`, `Type::method`, `@pkg.Type::method`

When to use: finding definitions, tracing usages, understanding package APIs, discovering methods. Falls back to grep only for non-MoonBit files or cross-language patterns.

### Convention Audit Commands

`moon ide` audits **semantic** properties (symbols, types, visibility). Grep audits **stylistic** choices (which keyword was used). Both are needed.

```bash
# Semantic audits (moon ide)
moon ide analyze <pkg> | grep "can be removed"       # Over-exposed pub(all)
moon ide analyze <pkg> | grep "usage: 0"             # Unused public APIs
moon ide outline <pkg> | grep ' | let '              # Top-level let → review if should be const
moon ide outline <pkg> | grep 'const'                # Verify const usage exists
moon ide find-references abort --loc <file:line>      # abort sites → potential guard candidates
moon ide doc --dump /tmp/symbols.jsonl                # Full symbol dump (NEVER pass a source file path — it overwrites!)

# Stylistic audits (grep — moon ide can't see keywords like return/if/guard)
grep -rn 'if .* { return' <pkg>/*.mbt                # guard candidates (early return)
grep -rn '() => {}' <pkg>/*.mbt                      # Empty callback anti-pattern
```

## Bindings & Visibility

- **`const`** for top-level compile-time constants — **top-level only, cannot appear inside functions** (unlike JavaScript/TypeScript). When defining a fixed value at module scope (magic numbers, sizes, thresholds, string keys), always use `const`, not `let`.
  ```moonbit
  const MAX_SIZE = 1024      // correct — top-level fixed value → const
  const PREFIX = "incr"      // correct — top-level fixed string → const
  //! let MAX_SIZE = 1024    // wrong — use const for top-level fixed values

  fn main {
    let x = 10               // correct — immutable local binding
    let mut i = 10            // correct — mutable local binding
    //! const LOCAL = 10      // ILLEGAL — const cannot appear inside functions
  }
  ```
- **Visibility:** `pub` exposes a symbol to direct dependents only. `pub(all)` exposes it transitively to all downstream packages. `pub(open)` on enums allows downstream packages to add variants. Use `pub` by default; only use `pub(all)` for types/functions that downstream-of-downstream consumers need, and `pub(open)` only for intentionally extensible enums.
- **Naming:** `snake_case` for functions, methods, variables, and modules. `PascalCase` for types, enums, and constructors. `SCREAMING_SNAKE_CASE` for `const` constants.

## Control Flow

- **Decision tree:**
  ```
  Need to bail out early (precondition, unwrap, validation)?
    ├── yes → guard (bool or pattern — keeps happy path unindented)
    └── no → Destructuring enum/Option/Result variants?
          ├── yes → match (exhaustive, compiler-checked)
          └── no → if/else (simple boolean)
  ```
  **`guard`** filters out the bad case so the rest of the function stays flat. Prefer `guard` over `if ... { return }` or nested `match` when only one branch exits early.
  ```moonbit
  guard let Some(x) = opt else { return Err("missing") }
  guard n > 0 else { abort("n must be positive") }
  // happy path continues here — no nesting
  ```
- **Iteration:** `for .. in` with accumulator state. `loop` keyword is deprecated.
  ```moonbit
  // Preferred: for-in with accumulator
  for x in xs; sum = 0 {
    continue sum + x
  } nobreak { sum }

  // Also fine: for-in with mut for simple cases
  let mut acc = 0
  for i in 0..<n { acc += xs[i] }
  ```
- **StringView/ArrayView patterns:** Use `.view()` for prefix/suffix matching with `match`:
  ```moonbit
  match s.view() {
    [.."let", ..rest] => ...  // prefix match
    [a, ..rest, b] => ...     // first and last
    [] => ...                 // empty
  }
  ```

## Functions & Types

- **Arrow functions:** `() => expr` (zero params, single expression), `() => { stmts }` (multi-statement), `x => expr` (one param), `(x, y) => expr` (multiple params). Empty body: `() => ()` — not `() => {}` which MoonBit parses as a map literal. Named functions (`pub fn`, `fn name(...)`) are unaffected.
- **Custom constructors for structs:** When defining public structs, declare a custom constructor via `fn new(...)` inside the struct body. This enables `StructName(args)` construction syntax with labelled/optional parameters, validation, and defaults. Prefer this over bare struct literals `{ field: value }`.
  ```moonbit
  struct MyStruct {
    x : Int
    y : Int

    fn new(x~ : Int, y? : Int) -> MyStruct  // declaration inside struct
  } derive(Show)

  fn MyStruct::new(x~ : Int, y? : Int = x) -> MyStruct {  // implementation
    { x, y }
  }

  let s = MyStruct(x=1)  // usage — like enum constructors
  ```
- **Trait impl:** `pub impl Trait for Type with method(self) { ... }` — one method per impl block
- **Orphan rule** (error 4061): can't impl foreign trait for foreign type — use a private newtype wrapper
- **Error handling:** use `Unit!Error` or `T!Error` for fallible return types. Error propagation uses `!` suffix on calls, not `raise` keyword. `try?` does not catch `abort`. `?` operator is not always supported — use explicit match/error handling when it fails.
- **TODO syntax:** `...` is a placeholder for unimplemented code. It type-checks as any type but aborts at runtime. Do not leave `...` in committed code.

## Testing

- **Files:** `*_test.mbt` (blackbox), `*_wbtest.mbt` (whitebox), `*_benchmark.mbt`
- **Assertions:** Use `inspect` for snapshots, `@qc` for properties
- **Panic tests:** name starts with `"panic "` — test runner expects `abort()`
- **Blackbox tests** cannot construct internal structs — use whitebox tests or expose constructors
- **Block-style:** Code organized in `///|` separated blocks
- **Format:** Always `moon info && moon fmt` before committing

## Pitfalls

- `._` syntax is deprecated — use `.0` for tuple access
- `ref` is a reserved keyword — do not use as variable/field names
- `() => {}` is a map literal, not an empty function body — use `() => ()`
- `loop` keyword is deprecated — use `for .. in`
- `try?` does not catch `abort`
- For cross-target builds, use per-file conditional compilation rather than `supported-targets` in moon.pkg.json

## Code Changes & Review

- Before suggesting code removal, check if symbols are re-exported as public API for downstream consumers. Do not delete structs/types that appear unused internally but may be part of the library's public interface.
- Never dismiss a review request — always do a thorough line-by-line review even if changes seem minor
- Check for: integer overflow, zero/negative inputs, boundary validation, generation wrap-around
- Do not suggest deleting public API types (Id structs, etc.) as 'unused' — they may be needed by downstream consumers
- Verify method names match actual API before writing tests (e.g., check if it's `insert` vs `add_local_op`)

## Development Workflow

### Performance Optimization Rule

Before designing any performance optimization, write a microbenchmark that **reproduces the claimed bottleneck** in isolation. If the benchmark can't demonstrate the problem, stop and re-evaluate. Stale profiling data and O(bad) complexity are not proof of a real problem.

### Incremental Edit Rule

**CRITICAL:** After every file edit, run `moon check` before proceeding to the next file. If there are errors, fix them immediately before continuing with the plan.

### Standard Workflow

1. Make edits
2. `moon check` — Lint
3. `moon test` — Run tests
4. `moon test --update` — Update snapshots (if behavior changed)
5. `moon info` — Update `.mbti` interfaces
6. Check `git diff *.mbti` — Verify API changes
7. `moon fmt` — Format

## Git & PR Workflow

- Always check if git is initialized before running git commands
- After rebase operations, verify files are in the correct directories
- When asked to 'commit remaining files', interpret generously even if phrasing is unclear
- When merging PRs, always verify CI status is actually passing (not skipped) before proceeding. Never represent CI as green if any checks were skipped or failed.
- After rebasing or refactoring, verify file paths haven't shifted unexpectedly. Run `git diff --stat` to confirm only intended files changed.
