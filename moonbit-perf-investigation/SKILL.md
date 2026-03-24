---
name: moonbit-perf-investigation
description: Use BEFORE any performance optimization in MoonBit. Requires reproducing the claimed bottleneck in an isolated microbenchmark before designing a solution. Triggers on "optimize", "performance", "bottleneck", "slow", "speed up", or any TODO item citing millisecond costs. Do NOT skip this for "obvious" optimizations.
---

# Performance Investigation Gate

**HARD RULE:** Never design a performance optimization without first demonstrating the problem exists at measurable scale. This skill MUST run before brainstorming/designing any optimization.

## Why This Exists

We spent hours designing and implementing binary lifting jump pointers to replace an Euler Tour + Sparse Table LCA index based on a TODO claim of "3-5ms at 1000 items." Post-implementation benchmarks showed negligible improvement — the figure was stale (from before a prior optimization round) and existing mitigations already neutralized the hot paths.

## The Process

```
1. Identify the claim     → "X is slow" / "X costs Y ms" / "X is O(bad)"
2. Check staleness        → When was this measured? What changed since?
3. Check mitigations      → Is there already a batch mode, cache, or lazy eval?
4. Write microbenchmark   → Isolate the exact operation claimed to be slow
5. Run benchmark          → Does it demonstrate the problem?
   no  → STOP. Report finding. Find the real bottleneck.
   yes → Prototype fix (50 lines, no spec) → benchmark again
         improved? → THEN consider full design cycle if needed
         not improved? → STOP. Wrong approach.
```

## Step 1: Identify the Claim

What specific operation is claimed to be slow? Extract:
- The **operation** (e.g., "LCA index rebuild")
- The **claimed cost** (e.g., "3-5ms at 1000 items")
- The **source** (e.g., "TODO.md §5")
- The **context** (e.g., "per keystroke during live collaboration")

## Step 2: Check Staleness

```bash
# When was this measurement taken?
git log --all --oneline -- docs/TODO.md | head -5
git log --all --oneline -- docs/performance/ | head -5
# What optimizations landed since?
git log --oneline --since="<measurement_date>" -- <relevant_directory>
```

**Red flags:**
- Measurement predates a major refactoring (e.g., HashMap → Array migration)
- The profiling doc references types/functions that no longer exist
- The TODO item has been there for months without re-validation

If the measurement is stale, say so and suggest re-profiling before designing.

## Step 3: Check Existing Mitigations

Search for batch modes, caching, lazy evaluation, or other mitigations that may already neutralize the problem:

```bash
# Look for batch/cache/lazy patterns around the claimed bottleneck
grep -r "batch\|cache\|lazy\|invalidate\|skip\|fast.path" --include="*.mbt" <relevant_directory>
```

Ask: "Is this code path actually reached in the hot case, or is it already mitigated?"

## Step 4: Write Microbenchmark

Write a benchmark that isolates the **exact operation** claimed to be slow. Not a full pipeline benchmark — a microbenchmark.

```moonbit
///|
test "isolate: <operation name> at <N> items" (b : @bench.T) {
  // Setup: build realistic state
  // ...
  b.bench(fn() {
    // Measure ONLY the claimed slow operation
    // ...
    b.keep(result)
  })
}
```

**Rules:**
- Isolate the single operation, not the full pipeline
- Use realistic data (not trivial 10-item inputs)
- Use `--release` flag
- Fresh state per iteration if the operation mutates

## Step 5: Decision Gate

Run the benchmark. Three outcomes:

### Problem confirmed (operation IS slow)
Proceed to prototype a fix. Write 50 lines, benchmark again. If the prototype shows improvement, THEN consider whether a full spec/design cycle is needed.

### Problem not confirmed (operation is fast)
**STOP.** Report: "Benchmarked <operation> in isolation at <N> items: <X>µs. The claimed <Y>ms bottleneck is not reproducible. The TODO figure appears stale / already mitigated by <mechanism>."

Suggest: profile the full pipeline to find the actual bottleneck instead.

### Problem exists but smaller than claimed
Report the actual cost. Let the user decide if it's worth optimizing. Often it isn't.

## Anti-Patterns

| Anti-pattern | Why it's wrong |
|-------------|---------------|
| "O(n log n) is bad, let's fix it" | Asymptotic complexity is not a profile. O(n log n) at n=1000 with small constants can be microseconds. |
| "The TODO says it's the bottleneck" | TODOs record hypotheses, not measurements. Verify before acting. |
| "Let me design the ideal solution first" | You're optimizing for intellectual satisfaction, not user value. Measure first. |
| "The spec review will catch issues" | Spec reviews check solution correctness, not problem validity. |
| "It's architecturally cleaner anyway" | That's a refactoring argument, not a performance argument. If the goal is cleanliness, say so — don't dress it up as optimization. |

## Integration with Brainstorming

When the brainstorming skill is invoked for a performance optimization:

1. **This skill runs FIRST** — before exploring approaches or asking about scale
2. If the problem is not confirmed, brainstorming should pivot to finding the real bottleneck
3. If the problem IS confirmed, brainstorming proceeds normally with the benchmark data as input

The benchmark result is the first thing presented in the design: "Measured: <X>µs baseline → target: <Y>µs."
