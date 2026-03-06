# Solving the Expression Problem in MoonBit

## The Expression Problem

The Expression Problem, coined by Philip Wadler in 1998, asks: can you add both new data variants *and* new operations to a datatype, without modifying existing code, while maintaining type safety and separate compilation?

It defines two axes of extension:

- **Data axis**: Add a new variant (e.g., add `Mul` to an expression language that has `Lit` and `Add`)
- **Operation axis**: Add a new operation (e.g., add `pretty_print` to a language that already supports `eval`)

Most languages make one axis easy and the other hard:

| Approach | Data axis | Operation axis |
|----------|-----------|----------------|
| Algebraic data types + pattern matching | Hard (must edit enum) | Easy (add a new function) |
| OOP classes + virtual methods | Easy (add a new subclass) | Hard (must edit base class) |

MoonBit, with its Self-based traits (no type parameters, no associated types), has a specific set of tools available. This document surveys the solution space, from the most effective approach to partial workarounds.

## Solution 1: Finally Tagless (Primary Recommendation)

Finally Tagless encoding is the most effective solution to the Expression Problem under MoonBit's constraints. It works by representing syntax as **trait method calls** rather than data constructors.

### Basic Setup

```moonbit
// The "syntax" is a trait — each constructor is a method
trait ExprSym {
  lit(Int) -> Self
  add(Self, Self) -> Self
  neg(Self) -> Self
}
```

An "expression" is not a data structure; it is a polymorphic function that works for any type implementing `ExprSym`. Concrete types serve as *interpretations* (operations):

```moonbit
// Interpretation 1: Evaluation
struct Eval { value: Int }

impl ExprSym for Eval with lit(n) { { value: n } }
impl ExprSym for Eval with add(a, b) { { value: a.value + b.value } }
impl ExprSym for Eval with neg(a) { { value: -a.value } }

// Interpretation 2: Pretty-printing
struct Show { repr: String }

impl ExprSym for Show with lit(n) { { repr: n.to_string() } }
impl ExprSym for Show with add(a, b) {
  { repr: "(\{a.repr} + \{b.repr})" }
}
impl ExprSym for Show with neg(a) {
  { repr: "(-\{a.repr})" }
}
```

Expressions are written as generic functions:

```moonbit
fn example1[T : ExprSym]() -> T {
  T::add(T::lit(1), T::neg(T::lit(2)))
}

// Use:
// example1[Eval]()  => Eval { value: -1 }
// example1[Show]()  => Show { repr: "(1 + (-2))" }
```

### Extending the Data Axis

To add a new syntactic form (e.g., multiplication), define a **new trait** — no existing code changes:

```moonbit
trait MulSym {
  mul(Self, Self) -> Self
}

// Extend all existing interpretations:
impl MulSym for Eval with mul(a, b) { { value: a.value * b.value } }
impl MulSym for Show with mul(a, b) {
  { repr: "(\{a.repr} * \{b.repr})" }
}
```

New expressions can use both traits:

```moonbit
fn example2[T : ExprSym + MulSym]() -> T {
  T::mul(T::add(T::lit(2), T::lit(3)), T::lit(4))
}
```

### Extending the Operation Axis

To add a new operation (e.g., computing expression depth), define a **new struct** and implement all relevant traits — no existing code changes:

```moonbit
struct Depth { depth: Int }

impl ExprSym for Depth with lit(_n) { { depth: 0 } }
impl ExprSym for Depth with add(a, b) {
  { depth: 1 + @math.maximum(a.depth, b.depth) }
}
impl ExprSym for Depth with neg(a) {
  { depth: 1 + a.depth }
}

impl MulSym for Depth with mul(a, b) {
  { depth: 1 + @math.maximum(a.depth, b.depth) }
}
```

### Scorecard

| Property | Status | Notes |
|----------|--------|-------|
| New variants without modifying existing code | ✓ | Add a new trait |
| New operations without modifying existing code | ✓ | Add a new struct + impls |
| Type safety | ✓ | Fully static |
| Separate compilation | ✓ | Each extension is independent |
| Pattern matching on structure | ✗ | Structure is lost after construction |
| Simultaneous multiple interpretations | Partial | Requires boilerplate (see below) |
| Dynamic expression construction | ✗ | Expressions are parametric functions |

### Combining Multiple Interpretations

To evaluate *and* pretty-print simultaneously, you need a product type:

```moonbit
struct EvalAndShow {
  eval: Eval
  show: Show
}

impl ExprSym for EvalAndShow with lit(n) {
  { eval: ExprSym::lit(n), show: ExprSym::lit(n) }
}
impl ExprSym for EvalAndShow with add(a, b) {
  {
    eval: ExprSym::add(a.eval, b.eval),
    show: ExprSym::add(a.show, b.show),
  }
}
impl ExprSym for EvalAndShow with neg(a) {
  {
    eval: ExprSym::neg(a.eval),
    show: ExprSym::neg(a.show),
  }
}
```

This is repetitive but mechanical. With macro support or code generation, it can be automated.

### Limitations in Detail

**No structural observation.** The following cannot be written:

```moonbit
// IMPOSSIBLE: there is no AST node to match on
fn optimize[T : ExprSym](e: T) -> T {
  match e {
    Add(Lit(0), x) => x    // No match — Self is opaque
    _ => e
  }
}
```

Optimization passes, tree transformations, and structural queries are out of scope for Finally Tagless.

**No first-class expression values.** An expression like `example1` is a function `[T : ExprSym]() -> T`, not a storable value. You cannot place it in a data structure or pass it to a function that is not generic. Workaround: materialize to a concrete AST (see Solution 3).

## Solution 2: Enum + Trait (Baseline, One-Axis Only)

For reference, the conventional approach:

```moonbit
enum Expr {
  Lit(Int)
  Add(Expr, Expr)
}

fn eval(e: Expr) -> Int {
  match e {
    Lit(n) => n
    Add(a, b) => eval(a) + eval(b)
  }
}
```

**Operation axis**: Easy. Define a new function with a match.
**Data axis**: Impossible without editing `Expr`.

This is not a solution to the Expression Problem, but it is the right choice when:

- The set of variants is closed (known at design time, unlikely to change)
- Pattern matching / structural observation is essential
- Performance of tree traversal matters

## Solution 3: Two-Layer Architecture (Recommended Hybrid)

The most practical architecture combines Finally Tagless for extensibility with a concrete AST for structural operations.

### Layer 1: Abstract (Finally Tagless)

```moonbit
trait ExprSym {
  lit(Int) -> Self
  add(Self, Self) -> Self
}

trait MulSym {
  mul(Self, Self) -> Self
}
```

### Layer 2: Concrete (Enum, used as one interpretation)

```moonbit
enum ConcreteExpr {
  Lit(Int)
  Add(ConcreteExpr, ConcreteExpr)
  Mul(ConcreteExpr, ConcreteExpr)
}

impl ExprSym for ConcreteExpr with lit(n) { Lit(n) }
impl ExprSym for ConcreteExpr with add(a, b) { Add(a, b) }
impl MulSym for ConcreteExpr with mul(a, b) { Mul(a, b) }
```

### Workflow

1. **Construct** expressions using the Finally Tagless API (generic functions)
2. **Interpret** directly for operations that don't need structure (eval, show, depth)
3. **Materialize** to `ConcreteExpr` when structure is needed (optimization, serialization, debugging)
4. **Replay** a `ConcreteExpr` back through the tagless API if needed

```moonbit
// Replay: convert concrete AST back to any interpretation
fn replay[T : ExprSym + MulSym](e: ConcreteExpr) -> T {
  match e {
    Lit(n) => T::lit(n)
    Add(a, b) => T::add(replay(a), replay(b))
    Mul(a, b) => T::mul(replay(a), replay(b))
  }
}
```

### Where the Compromise Lives

When a **new variant** is added (e.g., `DivSym`):

- The Finally Tagless traits: **no change** (new trait `DivSym` added independently)
- Existing interpretations (Eval, Show, Depth): **no change** to existing impls (new impls added)
- `ConcreteExpr` enum: **must be modified** to add `Div(ConcreteExpr, ConcreteExpr)`
- `replay` function: **must be modified** to handle the new case

The key insight: *the cost of change is localized.* Only `ConcreteExpr` and `replay` need updating; all generic code (expression construction functions, interpretations) remains untouched.

### Scorecard

| Property | Status |
|----------|--------|
| New variants | ✓ (tagless layer unchanged; enum changes localized) |
| New operations | ✓ (new struct + impls) |
| Pattern matching | ✓ (via ConcreteExpr) |
| Type safety | ✓ |
| Optimization passes | ✓ (on ConcreteExpr, then replay) |

## Solution 4: Open Recursion with Function Records

An alternative to traits — represent the "algebra" as a record of functions:

```moonbit
struct ExprAlgebra {
  on_lit: (Int) -> Int
  on_add: (Int, Int) -> Int
}

fn eval_algebra() -> ExprAlgebra {
  {
    on_lit: fn(n) { n },
    on_add: fn(a, b) { a + b },
  }
}
```

Extension is done by defining a new record type:

```moonbit
struct ExtExprAlgebra {
  base: ExprAlgebra
  on_mul: (Int, Int) -> Int
}

fn eval_ext_algebra() -> ExtExprAlgebra {
  {
    base: eval_algebra(),
    on_mul: fn(a, b) { a * b },
  }
}
```

### Trade-offs

- **Pro**: Does not require the trait system at all; purely value-level
- **Pro**: Algebras are first-class values (can be stored, passed, composed)
- **Con**: No type-level enforcement that all cases are handled
- **Con**: Extending with a new variant requires a new record type
- **Con**: No method dispatch — callers must manually select the right function

This is essentially the **Object Algebra** pattern without type parameters. It is useful when you need runtime flexibility (e.g., swappable interpreters) but is less type-safe than the Finally Tagless approach.

## Solution 5: Defunctionalized Tagless (Partial Structure Recovery)

A middle ground: retain *tags* indicating which constructor was used, alongside the computed result.

```moonbit
enum ExprTag {
  TagLit
  TagAdd
  TagMul
}

struct TaggedEval {
  tag: ExprTag
  value: Int
  children_tags: Array[ExprTag]
}

impl ExprSym for TaggedEval with lit(n) {
  { tag: TagLit, value: n, children_tags: [] }
}
impl ExprSym for TaggedEval with add(a, b) {
  {
    tag: TagAdd,
    value: a.value + b.value,
    children_tags: [a.tag, b.tag],
  }
}
```

This recovers *shallow* structural information (what operation produced this value, and what were its immediate children's tags) without storing the full tree. Useful for:

- Debugging / tracing
- Lightweight profiling ("how many additions vs. multiplications?")
- Conditional behavior based on the last operation

It does **not** enable tree transformations or deep pattern matching.

## Solution 6: Visitor Pattern (Classic OOP Approach)

If you need runtime polymorphism and are willing to fix the set of *operations* but leave the set of *types* open:

```moonbit
trait ExprVisitor {
  visit_lit(Self, Int) -> Unit
  visit_add(Self, Int, Int) -> Unit
  visit_mul(Self, Int, Int) -> Unit
}

trait Visitable {
  accept(Self, &ExprVisitor) -> Unit
}
```

This is the dual of the enum approach: operations are fixed in the `ExprVisitor` trait, but any type can become `Visitable`. Adding a new variant requires modifying `ExprVisitor` (adding a new `visit_*` method), so this does **not** solve the Expression Problem in general, but it can be useful when the set of operations is truly stable.

## Theoretical Boundaries

A complete solution to the Expression Problem requires the ability to **abstract over types** — specifically:

1. **Existential types**: "some type that implements `ExprSym`" as a first-class value
2. **Type constructor polymorphism**: abstracting over `F[_]` (needed for Object Algebras, Free Monads)
3. **Extensible variants / row polymorphism**: open sum types that can be extended post-definition

MoonBit's Self-based traits without type parameters provide none of these directly. Finally Tagless succeeds because it cleverly avoids needing them: instead of storing "an expression" as a value (which requires existential types), it represents expressions as **parametrically polymorphic construction processes**.

The price paid is the inability to observe structure. This is a fundamental trade-off, not an implementation limitation:

- **Structure = closed** (enum): you can see inside, but cannot extend
- **Abstraction = open** (tagless): you can extend, but cannot see inside

The Two-Layer Architecture (Solution 3) explicitly manages this trade-off by maintaining both representations and providing a bridge (`replay`) between them.

## Decision Guide

```
Is the set of variants fixed?
├─ Yes → Use an enum with pattern matching (Solution 2)
└─ No
   ├─ Do you need structural observation (optimization, transformation)?
   │  ├─ Yes → Two-Layer Architecture (Solution 3)
   │  └─ No  → Pure Finally Tagless (Solution 1)
   └─ Do you need runtime-swappable interpretations?
      ├─ Yes → Function Records / Object Algebras (Solution 4)
      └─ No  → Finally Tagless (Solution 1)
```

## Complete Example: A Mini Language

Bringing it all together with a realistic example:

```moonbit
// ── Syntax traits (extensible) ──

trait ArithSym {
  lit(Int) -> Self
  add(Self, Self) -> Self
  neg(Self) -> Self
}

trait MulSym {
  mul(Self, Self) -> Self
}

trait LetSym {
  // `let x = e1 in e2` as a higher-order method
  let_(String, Self, (Self) -> Self) -> Self
}

// ── Interpretation: Evaluate ──

struct Eval { value: Int }

impl ArithSym for Eval with lit(n)      { { value: n } }
impl ArithSym for Eval with add(a, b)   { { value: a.value + b.value } }
impl ArithSym for Eval with neg(a)      { { value: -a.value } }
impl MulSym   for Eval with mul(a, b)   { { value: a.value * b.value } }
impl LetSym   for Eval with let_(_name, e1, body) { body(e1) }

// ── Interpretation: Count operations ──

struct OpCount { count: Int }

impl ArithSym for OpCount with lit(_n)    { { count: 0 } }
impl ArithSym for OpCount with add(a, b)  { { count: 1 + a.count + b.count } }
impl ArithSym for OpCount with neg(a)     { { count: 1 + a.count } }
impl MulSym   for OpCount with mul(a, b)  { { count: 1 + a.count + b.count } }
impl LetSym   for OpCount with let_(_name, e1, body) {
  let e2 = body(e1)
  { count: e1.count + e2.count }
}

// ── Interpretation: Pretty-print ──

struct Pretty { repr: String }

impl ArithSym for Pretty with lit(n)     { { repr: n.to_string() } }
impl ArithSym for Pretty with add(a, b)  { { repr: "(\{a.repr} + \{b.repr})" } }
impl ArithSym for Pretty with neg(a)     { { repr: "(-\{a.repr})" } }
impl MulSym   for Pretty with mul(a, b)  { { repr: "(\{a.repr} * \{b.repr})" } }
impl LetSym   for Pretty with let_(name, e1, body) {
  let placeholder = Pretty::{ repr: name }
  let e2 = body(placeholder)
  { repr: "let \{name} = \{e1.repr} in \{e2.repr}" }
}

// ── Concrete AST (for structural operations) ──

enum Ast {
  ALit(Int)
  AAdd(Ast, Ast)
  ANeg(Ast)
  AMul(Ast, Ast)
}

impl ArithSym for Ast with lit(n)    { ALit(n) }
impl ArithSym for Ast with add(a, b) { AAdd(a, b) }
impl ArithSym for Ast with neg(a)    { ANeg(a) }
impl MulSym   for Ast with mul(a, b) { AMul(a, b) }

// ── Optimization (on concrete AST) ──

fn optimize(e: Ast) -> Ast {
  match e {
    AAdd(ALit(0), x) => optimize(x)       // 0 + x => x
    AAdd(x, ALit(0)) => optimize(x)       // x + 0 => x
    AMul(ALit(1), x) => optimize(x)       // 1 * x => x
    AMul(x, ALit(1)) => optimize(x)       // x * 1 => x
    AMul(ALit(0), _) => ALit(0)           // 0 * x => 0
    AAdd(a, b) => AAdd(optimize(a), optimize(b))
    AMul(a, b) => AMul(optimize(a), optimize(b))
    ANeg(a) => ANeg(optimize(a))
    other => other
  }
}

// ── Replay optimized AST through any interpretation ──

fn replay[T : ArithSym + MulSym](e: Ast) -> T {
  match e {
    ALit(n) => T::lit(n)
    AAdd(a, b) => T::add(replay(a), replay(b))
    ANeg(a) => T::neg(replay(a))
    AMul(a, b) => T::mul(replay(a), replay(b))
  }
}

// ── Usage ──

fn program[T : ArithSym + MulSym]() -> T {
  // (1 + 0) * (2 + 3)
  T::mul(T::add(T::lit(1), T::lit(0)), T::add(T::lit(2), T::lit(3)))
}

// Direct interpretation:
//   program[Eval]()    => Eval { value: 5 }
//   program[Pretty]()  => Pretty { repr: "((1 + 0) * (2 + 3))" }

// Optimized interpretation:
//   let ast = program[Ast]()          // materialize
//   let opt = optimize(ast)           // transform:  AMul(ALit(1), AAdd(ALit(2), ALit(3)))
//   replay[Pretty](opt)              // replay:     Pretty { repr: "(1 * (2 + 3))" }
//   replay[Eval](opt)                // replay:     Eval { value: 5 }
```

## References

- Wadler, P. (1998). *The Expression Problem.* Java-genericity mailing list.
- Carette, J., Kiselyov, O., & Shan, C. (2009). *Finally Tagless, Partially Evaluated.* Journal of Functional Programming.
- Oliveira, B. C. d. S., & Cook, W. R. (2012). *Extensibility for the Masses: Practical Extensibility with Object Algebras.* ECOOP.
- Wadler, P., & Blott, S. (1989). *How to Make Ad-Hoc Polymorphism Less Ad Hoc.* POPL.
- Canning, P., Cook, W., Hill, W., Olthoff, W., & Mitchell, J. C. (1989). *F-Bounded Polymorphism for Object-Oriented Programming.* FPCA.
- Swierstra, W. (2008). *Data Types à la Carte.* Journal of Functional Programming.
