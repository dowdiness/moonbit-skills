# Effective Trait Usage Patterns in MoonBit

## Introduction

MoonBit's trait system uses a **Self-type based** design: unlike Haskell's type classes (`class Eq a where ...`), MoonBit traits do not take explicit type parameters. The implementing type is implicitly available as `Self`. This design is shared with Rust and Swift, but MoonBit's traits are further constrained by the absence of associated types.

This document explores how to write effective, idiomatic traits under these constraints, organized from the most natural patterns to increasingly creative workarounds.

## Understanding the Constraints

A MoonBit trait can reference:

- **`Self`** — the implementing type (implicit)
- **Concrete types** — `Int`, `String`, `Bool`, user-defined structs/enums, etc.

A MoonBit trait *cannot* reference:

- Type parameters on the trait itself (no `trait Convert[T]`)
- Associated types (no `type Item` inside a trait)

This means every type that appears in a trait method signature, other than `Self`, must be a specific, known type.

## Pattern 1: Self-Closed Algebras (Endomorphisms)

The most natural pattern. All inputs and outputs are `Self`.

```moonbit
trait Monoid {
  empty() -> Self
  combine(Self, Self) -> Self
}

trait Ord {
  compare(Self, Self) -> Ordering
}

trait Semigroup {
  append(Self, Self) -> Self
}
```

This is ideal for **algebraic structures** where operations close over a single type. Mathematical traits (groups, rings, lattices) and comparison traits fit perfectly.

### Builder Pattern Variant

Fluent builders are a natural application of `Self -> Self` chains:

```moonbit
trait Builder {
  with_name(Self, String) -> Self
  with_size(Self, Int) -> Self
  build(Self) -> Result
}
```

Each method returns `Self`, enabling chained calls while remaining fully type-safe.

### When to Use

- Equality, ordering, hashing
- Algebraic operations (combine, merge, union)
- Fluent/builder APIs
- Any operation that is "closed" over one type

## Pattern 2: Fixed-Type Projections

When a trait needs to produce or consume a value of a type other than `Self`, fix that type to a concrete, domain-appropriate type.

```moonbit
trait Show {
  to_string(Self) -> String
}

trait Hash {
  hash(Self) -> Int
}

trait ToJson {
  to_json(Self) -> JsonValue
}

trait ToBytes {
  to_bytes(Self) -> Bytes
}

trait Measure {
  size(Self) -> Int
}
```

The key insight: if you would write `trait Show[T] { show(Self) -> T }` and then *always* instantiate `T = String`, the type parameter adds no value. A fixed projection is simpler.

### Choosing the Right Target Type

The choice of target type matters. Prefer types that are:

- **Rich enough** to encode all cases: `JsonValue` (a sum type) is far more useful as a serialization target than `String`
- **Standardized** within your codebase: pick one canonical representation for bytes, one for JSON, etc.
- **Composable**: `Bytes` can be concatenated; `Int` (for hashing) can be combined

### When to Use

- Serialization / deserialization
- Display / debug output
- Measurement / metrics
- Any "extract a summary" operation

## Pattern 3: Capability Traits (Fine-Grained Interfaces)

Keep traits small — ideally one or two methods — representing a single capability.

```moonbit
// Good: fine-grained capabilities
trait Readable  { read(Self, Bytes) -> Int }
trait Writable  { write(Self, Bytes) -> Int }
trait Closable  { close(Self) -> Unit }
trait Flushable { flush(Self) -> Unit }

// Bad: monolithic interface
trait Stream {
  read(Self, Bytes) -> Int
  write(Self, Bytes) -> Int
  close(Self) -> Unit
  flush(Self) -> Unit
  seek(Self, Int) -> Int
}
```

Fine-grained traits are essential under this constraint set because:

1. **No type parameters** means you cannot parameterize behavior — so each trait must represent one coherent capability
2. **Composition via multiple trait bounds** (`T : Readable + Closable`) replaces what would otherwise require generic traits
3. **Implementors** only pay for what they provide

### The Go Lesson

Go's `io.Reader` interface (a single `Read([]byte) (int, error)` method) demonstrates that fixing the buffer type to `[]byte` and keeping interfaces minimal produces a highly composable ecosystem. The same principle applies here.

### When to Use

- I/O abstractions
- Resource management (open, close, flush)
- Permission / access control modeling
- Any cross-cutting concern

## Pattern 4: Callback-Based Iteration (CPS Style)

Without associated types, you cannot write a generic `Iterator` trait. The workaround is to push values into callbacks instead of pulling them out.

### Problem

```moonbit
// Cannot write this — `Item` would need to be an associated type
trait Iterator {
  next(Self) -> Item?  // What is `Item`?
}
```

### Solution A: Domain-Specific Iterables

Fix the element type to something domain-appropriate:

```moonbit
trait CharSource {
  for_each_char(Self, (Char) -> Unit) -> Unit
}

trait EventSource {
  on_event(Self, (Event) -> Unit) -> Unit
}

trait LineReader {
  for_each_line(Self, (String) -> Unit) -> Unit
}
```

You cannot write a single generic `Iterable[T]`, but you can write `CharSource`, `EventSource`, `LineReader` — each serving a specific domain. In practice, this is often sufficient.

### Solution B: Universal Value Type

If you need a single, cross-domain iterable, route through a sum type:

```moonbit
enum Value {
  VInt(Int)
  VStr(String)
  VBool(Bool)
  VList(Array[Value])
  VRecord(Map[String, Value])
}

trait Iterable {
  for_each(Self, (Value) -> Unit) -> Unit
}
```

This is effectively a fallback to dynamic typing within a statically-typed shell. It trades compile-time element-type safety for universality. Use it when you need a common interface across many different data sources.

### Solution C: Fold-Style Aggregation

Instead of yielding individual elements, fold them into a fixed accumulator type:

```moonbit
trait Summable {
  sum(Self) -> Int
}

trait Countable {
  count(Self) -> Int
}

trait Reducible {
  reduce(Self, (Int, Int) -> Int, Int) -> Int
}
```

This pre-applies the operation, sidestepping the need to abstract over element types entirely. Useful when you know *what* you want to compute but want to abstract over *what* you're computing it from.

### When to Use

- Streams / event sources / async producers
- Any "collection-like" abstraction
- Logging, metrics, observer patterns

## Pattern 5: Trait Multiplication (Enumerating Concrete Pairs)

When you need a multi-parameter relationship like `Convert[T]`, decompose it into one trait per target type.

```moonbit
// Cannot write: trait Convert[T] { convert(Self) -> T }

// Instead, enumerate the targets:
trait ToInt    { to_int(Self) -> Int }
trait ToFloat  { to_float(Self) -> Double }
trait ToString { to_string(Self) -> String }
trait ToJson   { to_json(Self) -> JsonValue }
```

### Managing Combinatorial Growth

The concern with this pattern is explosion of trait count. Mitigations:

1. **Only define what you need.** In practice, the set of useful conversions is small.
2. **Group by domain.** A serialization module defines `ToJson`, `ToBytes`, `ToXml`. A numeric module defines `ToInt`, `ToFloat`.
3. **Prefer a universal representation.** If many types need to interconvert, route them all through a common intermediate (like `Value` or `JsonValue`) rather than defining N² direct conversions.

### When to Use

- Type conversions
- Encoding / decoding to specific formats
- Any relationship that would be `trait R[A, B]` in a more expressive system

## Pattern 6: Newtype Wrappers for Type-Level Distinctions

Without type parameters, you can use newtypes to recover some type-level precision:

```moonbit
struct Meters { value: Double }
struct Seconds { value: Double }
struct MetersPerSecond { value: Double }

trait HasMagnitude {
  magnitude(Self) -> Double
}

impl HasMagnitude for Meters with magnitude(self) { self.value }
impl HasMagnitude for Seconds with magnitude(self) { self.value }
impl HasMagnitude for MetersPerSecond with magnitude(self) { self.value }
```

Each newtype can implement the same trait differently, and the type system prevents you from mixing `Meters` and `Seconds` accidentally. This is the technique that compensates most directly for the lack of type parameters: instead of `Quantity[Unit]`, you define `Meters`, `Seconds`, etc., each as its own type.

### When to Use

- Units of measure
- Tagged identifiers (UserId vs. PostId)
- Domain-specific wrappers that share behavior but must not be confused

## Pattern 7: Visitor / Double Dispatch

For operations that need to branch on multiple types without type parameters:

```moonbit
trait Visitor {
  visit_int(Self, Int) -> Unit
  visit_str(Self, String) -> Unit
  visit_list(Self, Array[Value]) -> Unit
}

trait Visitable {
  accept(Self, &Visitor) -> Unit
}
```

Each `visit_*` method takes a concrete type, so no type parameters are needed. This is the classic GoF Visitor pattern, and it remains relevant precisely because it solves the dispatch problem without generics.

### When to Use

- AST traversal
- Serialization of heterogeneous data
- Any situation where you need double dispatch

## Anti-Patterns

### Over-Sized Traits

```moonbit
// Avoid: too many responsibilities, hard to implement partially
trait DatabaseConnection {
  query(Self, String) -> Result
  insert(Self, String, Bytes) -> Bool
  delete(Self, String, Int) -> Bool
  begin_transaction(Self) -> Self
  commit(Self) -> Bool
  rollback(Self) -> Bool
  set_timeout(Self, Int) -> Self
  get_stats(Self) -> String
}
```

Split into `Queryable`, `Transactional`, `Configurable`, etc.

### Phantom Generality

Don't create a trait that *looks* general but can only have one meaningful implementation:

```moonbit
// If only one type will ever implement this, it's not a useful trait
trait AppConfig {
  get_port(Self) -> Int
  get_host(Self) -> String
  get_db_url(Self) -> String
}
```

Use a struct directly instead.

### Forcing Trait Where a Function Suffices

If the operation does not vary by type, it does not need to be a trait:

```moonbit
// This is just a function, not a meaningful trait
trait Addable {
  add_ints(Self, Int, Int) -> Int  // Self is never used meaningfully
}

// Just write a function
fn add_ints(a: Int, b: Int) -> Int { a + b }
```

## Summary of Design Heuristics

| Situation | Pattern | Key Idea |
|-----------|---------|----------|
| Operations closed over one type | Self-Closed Algebra | `Self -> Self` |
| Extract a summary/representation | Fixed-Type Projection | `Self -> ConcreteType` |
| Minimal behavioral contracts | Capability Traits | 1-2 methods per trait |
| "Iterate over contents" | Callbacks / CPS | Push values to `(T) -> Unit` |
| Multi-type relationships | Trait Multiplication | One trait per concrete pair |
| Type-safe wrappers | Newtypes | Distinct structs, shared traits |
| Branching on multiple types | Visitor | Concrete `visit_*` methods |

The overarching principle: **embrace the concreteness.** Without type parameters, your traits describe relationships between `Self` and specific, known types. This is not a weakness to work around but a design constraint that pushes toward clear, discoverable, domain-grounded interfaces.
