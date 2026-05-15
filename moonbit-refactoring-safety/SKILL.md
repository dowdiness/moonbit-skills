---
name: moonbit-refactoring-safety
description: >
  Execution discipline for boundary-crossing MoonBit refactors:
  splitting packages, extracting modules into a facade-and-internals
  layout, splitting files safely, and pinning invariants with property
  tests before structural change. Use when the task is "split this
  package", "extract these files", "verify the public API didn't
  change", or "set up tests before refactoring". Pairs with
  `moonbit-refactoring`, which covers *what* to refactor toward.
---

# MoonBit Refactoring Safety

Three execution disciplines for refactors where the *direction* is decided but the *transition* is where bugs hide: pre-refactor invariant tests, file splits, and the facade-and-internals package split. Each replaces eyeball verification ("did I move everything? does it still work?") with something the compiler or test runner enforces.

Pairs with `moonbit-refactoring` — that skill covers *what* to refactor toward (idiomatic patterns, API minimization, view types). This one covers *how* to make a mechanical change without regressions.

## Relationship to `moonbit-refactoring`'s package-split section

Upstream `moonbit-refactoring` documents a different package-split flow: put `using @A { ... }` in the new package `B` and migrate consumers' references from A's names to B's names. That flow fits the scenario where `B` is a shared-utilities package and consumers should depend directly on it.

This skill documents the **facade-and-internals** scenario: `A` is the existing package, internals get extracted into a new `B`, `A` becomes a thin facade that re-exports `B`'s public surface via `pub using`. Consumers of `A` see no change at the call site. This fits the much more common case where `A`'s name and import path must stay stable.

If you're doing a facade extraction, this skill supersedes the upstream procedure. If you're consolidating into a fresh utilities package, the upstream procedure is lighter and sufficient.

## When to invoke

- "Split this package into A and B" (facade + internals shape).
- "Extract these files into a new module."
- "Move this code into an `internal/` package without breaking consumers."
- "Set up a safety net before I refactor this."
- "I refactored X; how do I verify the public API didn't change?"

If the task is "refactor this code to be more idiomatic" (rename, pattern matching, method conversion, loop style), use `moonbit-refactoring` instead — those changes are local and the compiler catches the breakage. This skill kicks in when the change touches *boundaries* (files, packages, public API).

## 1. Safety Net: Property Tests Before Structural Changes

Before a refactor that crosses a file or package boundary, write property tests that pin the behavioral invariants the refactor must preserve. Once the structure moves, you want the test suite — not your memory — telling you what broke. Strongly recommended for any refactor that touches non-trivial behavior; can be skipped for purely-mechanical extractions of pure code where the invariant ("this function still returns the same value") is obvious from the type.

Verified pattern using `moonbitlang/core/quickcheck`:

```mbt
test "encode/decode round-trip" {
  let cases : Array[Array[Int]] = @quickcheck.samples(100)
  for xs in cases {
    let encoded = encode(xs)
    let decoded = decode(encoded).unwrap()
    assert_eq(decoded, xs)
  }
}
```

Add to the package's `moon.pkg` to enable `@quickcheck`:

```
import {
  "moonbitlang/core/quickcheck" @quickcheck,
}
```

**Generator discipline:**
- `@quickcheck.samples(N) : Array[T]` produces `N` random values of any `T : Arbitrary`. Built-in `Arbitrary` impls exist for `Unit`, `Bool`, `Byte`, `Char`, `Int`, `Int64`, `UInt`, `UInt64`, etc. and for collections of those.
- If a sample needs validation (e.g., a `Pos` that rejects negatives), call the validating constructor and `unwrap()` — **never** write `Err(_) => return` or `None => continue` to silently skip. A silently-skipped sample turns the property test into a no-op that passes for the wrong reason; refactors then break under load and the tests don't notice.
- If valid inputs are hard to generate, that itself is a refactor smell — the constructor is doing too much or the invariants aren't where they should be.

**Why this step matters for boundary refactors:** unit tests pin local behavior, but boundary refactors change *which side* of a boundary owns a piece of logic. The unit test that exercised the old owner may pass against the new owner for the wrong reason (different code path, same answer). Properties cross the boundary; unit tests don't.

> **Verified:** `@qc.quick_check_fn` does **not** exist in `moonbitlang/core/quickcheck`. Earlier MoonBit refactoring guidance referenced it; if you see that name in older docs, it was either a project-specific helper or aspirational. The actual API is `gen` (single value) and `samples` (Array). Build a property test by iterating over `samples`.

## 2. File Splits: Delete-First Technique

When splitting a large `.mbt` file into smaller focused files within the same package, **delete the original after extracting the sections**, then run `moon check`. The compiler will enumerate every missing definition. This is faster and more reliable than verifying line-range extractions by counting.

```bash
# 1. Extract sections into new files (parser_lex.mbt, parser_parse.mbt, etc.)
# 2. Delete the original
rm parser.mbt
# 3. Let the compiler report everything still referenced
moon check
# Each "value identifier X is unbound" / "type Y not found" tells you exactly
# what didn't make it into a new file.
```

**Never** verify a file split by comparing line counts (`wc -l` before/after, "the totals match"). A line count match proves nothing — you can have duplicated content in two files, or have moved comments while losing code, and the counts will agree.

**Why this works:** MoonBit treats files within a package as organizational units, not separate modules. A symbol moved between files in the same package needs no import update — the compiler simply finds it (or doesn't). The "doesn't" case is the entire signal you need.

**When to skip:** if the file is small enough to read top-to-bottom in one screen, just move it and verify visually. The delete-first technique pays off when the file is large enough that you can't trust a visual scan.

## 3. Facade + Internals Package Split: Six Steps

Splitting package `A` (the existing public package) by extracting its internals into a new package `B`. `A` becomes a thin facade re-exporting `B`'s public surface, so existing consumers continue compiling unchanged. Each step exposes one specific failure mode.

### Step 1 — Create `B`, move source files

Create a new directory `B/` with an empty `moon.pkg`, move the relevant source files there. Do not yet touch `A`'s `moon.pkg`.

### Step 2 — Re-export via `pub using` in the facade

In `A`'s `moon.pkg`, add `B` as a dependency. Then in an `.mbt` file inside `A`, re-export `B`'s public surface:

```mbt
// In package A — backward-compatible re-export
pub using @B {
  type MyType,       // structs, enums (methods/associated fns/constructors come along)
  trait MyTrait,     // traits
  my_function,       // functions and constants
}
```

`pub using` does two things at once: re-exports to consumers of `A`, **and** makes the names available locally inside `A` without the `@B.` prefix. Code remaining in `A` keeps compiling unchanged. Run `moon check` after this step.

**What re-exports automatically** (verified with `moon check` and `moon info`). Listing `type Foo` re-exports the type *and* all of its methods, associated functions, and custom constructor. From a consumer's perspective:

```mbt
let s : @A.MyType = @A.MyType()   // custom constructor through facade
s.method()                         // method through facade
```

both work without listing `MyType::method` or `MyType::MyType` separately. Methods don't need to be listed individually — listing the type pulls them along. Functions, constants, and traits must be listed by name.

**`pub using` forwards names, not permissions.** A `pub struct S` is read-only to external code (fields readable, but external code cannot construct `S::{...}` or write `mut` fields). Re-exporting does not change that — consumers of `@A` see the same visibility they would see importing directly from `@B`. If external construction or field mutation is required, declare the origin as `pub(all) struct S`, or expose a constructor / mutator method.

### Step 3 — Expect private-symbol errors

After steps 1 and 2, `moon check` will report errors at every private function inside `B` that used to live next to its caller (which is now in `A`). The error reads as **"Value X not found in package B"** — the compiler treats private symbols as if they don't exist from outside, rather than emitting a separate "private" diagnostic. **This is the point** — the split reveals hidden coupling that was invisible while everything was in one package.

Fix by making necessary functions `pub` in `B`. If consumers of `A` need them too, add them to the `pub using` list. If only `A` itself needs them (after the split), `pub` is enough.

**Note on direction:** errors flow `A → B` (caller now in `A`, callee private in `B`). The reverse direction (`B` calling something private in `A`) cannot occur — that would require `B` to import `A`, but `A` already imports `B`, and the compiler hard-rejects the cycle with **"Import loop detected"**. Internals never depend on facade.

**Don't preempt step 3.** Resist the urge to `pub` everything in step 1. The errors are the inventory of what actually needs to cross the boundary — usually a smaller set than you'd guess.

### Step 4 — Verify `.mbti` stability

Run `moon info` and inspect `git diff A/pkg.generated.mbti`. The interface file is the source of truth for what consumers of `A` see.

Verified `.mbti` shape after re-exporting `type Store, put` from `@internals`:

```
// A/pkg.generated.mbti (excerpt)
import { "internals" }

// Values
pub fn put(@internals.Store, String, Int) -> Unit      // function: inlined with origin types

// Type aliases
pub using @internals {type Store}                       // type: under "Type aliases" section
```

Functions get inlined as ordinary forwarded signatures whose parameter and return types reference the canonical origin (`@internals.Store`). Types land in the `Type aliases` section of the `.mbti` as `pub using @origin {type Name}` lines. Consumer code written against `@A.Store` / `@A.put` still compiles unchanged.

If the `.mbti` diff shows any change you didn't intend (a removed symbol, a changed signature, an unexpected origin path), the split has leaked. Stop and fix before continuing.

### Step 5 — Migrate consumers incrementally

Once `.mbti` is stable, the split is invisible to consumers. They can switch from `@A.MyType` to `@B.MyType` at their own pace; the facade keeps working until they do.

`moon ide find-references <symbol>` enumerates call sites for the migration. Once all consumers of a symbol have migrated, remove the corresponding entry from `A`'s `pub using` block.

### Step 6 — Audit and remove newly-unused `pub` APIs

After consumer migration completes, walk both packages with `moon ide analyze` and remove any `pub` that was added defensively but ended up unused. The post-split surface area should be smaller than pre-split, not larger.

## Commands quick reference

```bash
moon check                                  # surface private-symbol errors and missing defs
moon info                                   # regenerate .mbti
git diff <pkg>/pkg.generated.mbti           # verify only intended interface changes
moon ide find-references <symbol>           # enumerate call sites for migration
moon ide analyze <pkg> | grep "can be removed"   # find over-exposed pub after migration
```

## See also

- `moonbit-refactoring` — the upstream skill: *what* to refactor toward (API minimization, pattern matching with views, method conversion, loop forms), plus the shared-utilities package-split variant.
- `moonbit-verification` — the post-change quality checklist: typecheck, tests, `.mbti` audit, formatting. Run after each safety-step above.
