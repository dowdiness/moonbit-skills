---
name: moonbit-settings
description: Use when setting up Claude Code configuration for a MoonBit project, bootstrapping .claude/settings.json hooks, or generating CLAUDE.md with MoonBit conventions. Triggers on requests like "set up settings", "configure hooks", "create CLAUDE.md for MoonBit".
---

# MoonBit Project Settings Bootstrap

Set up `.claude/settings.json` and `CLAUDE.md` for a MoonBit project. Auto-detects project structure. Idempotent — safe to re-run.

## Process

```dot
digraph moonbit_settings {
  "Detect modules" [shape=box];
  "Generate settings.json" [shape=box];
  "Generate CLAUDE.md" [shape=box];
  "Merge or create?" [shape=diamond];
  "Merge into existing" [shape=box];
  "Create new file" [shape=box];
  "Verify" [shape=doublecircle];

  "Detect modules" -> "Generate settings.json";
  "Generate settings.json" -> "Merge or create?";
  "Merge or create?" -> "Merge into existing" [label="file exists"];
  "Merge or create?" -> "Create new file" [label="no file"];
  "Merge into existing" -> "Generate CLAUDE.md";
  "Create new file" -> "Generate CLAUDE.md";
  "Generate CLAUDE.md" -> "Merge or create?";
  "Merge or create?" -> "Verify";
}
```

## Step 1: Auto-Detect Project Structure

Scan from working directory:

```bash
# Find all MoonBit modules
find . -name "moon.mod.json" -not -path "./.worktrees/*"

# Find all packages per module
find . -name "moon.pkg.json" -not -path "./.worktrees/*"

# Detect test files
find . -name "*_test.mbt" -o -name "*_wbtest.mbt" -o -name "*_benchmark.mbt" | head -20

# Check for git submodules
cat .gitmodules 2>/dev/null
```

Record: module names, package paths, test file locations, submodule presence.

## Step 2: Generate `.claude/settings.json`

### Correct Hook Schema

Claude Code hooks use this EXACT format — do NOT use `"PreCommit"` or other made-up keys:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash(git commit*)",
        "hooks": [
          {
            "type": "command",
            "command": "moon check && moon test",
            "timeout": 120
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "moon update",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

### Key rules

- **`PreToolUse` with `matcher`** — NOT `"PreCommit"`. The matcher `"Bash(git commit*)"` scopes the hook to commit commands only.
- **Keep pre-commit fast** — only `moon check && moon test` for the current module. Do NOT run `moon info && moon fmt` in the hook (those change files, which is confusing mid-commit). Do NOT run all modules — just the current one.
- **Relative commands** — do NOT hardcode absolute paths. The hook runs from the working directory.
- **`SessionStart`** — run `moon update` to ensure dependencies are fresh.

### Idempotent Merge

If `.claude/settings.json` already exists:

1. Read the existing file
2. Parse as JSON
3. For each hook key (`PreToolUse`, `SessionStart`):
   - If the key doesn't exist → add it
   - If the key exists → check if a matching entry already exists (same matcher/command). Skip if duplicate; append if new.
4. Preserve all other existing keys (e.g., `permissions`, `enabledPlugins`)
5. Write the merged result

**NEVER overwrite the entire file.**

### Multi-Module Projects

For monorepos with multiple `moon.mod.json` files, the pre-commit hook should run checks for each module:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash(git commit*)",
        "hooks": [
          {
            "type": "command",
            "command": "cd loom && moon check && moon test && cd ../seam && moon check && moon test && cd ../incr && moon check && moon test && cd ../examples/lambda && moon check && moon test",
            "timeout": 300
          }
        ]
      }
    ]
  }
}
```

Adjust module paths based on auto-detected structure. Use relative paths from the project root.

## Step 3: Generate `CLAUDE.md`

### Section Order (MANDATORY)

Generate sections in this EXACT order. Language Notes MUST be near the top — not buried at the bottom.

1. `# CLAUDE.md` — title
2. `## Project Overview` — auto-detected from `moon.mod.json` name/description
3. `## MoonBit Language Notes` — FIXED content, near top so always visible
4. `## Commands` — auto-detected per-module commands
5. `## Package Map` — auto-detected from `moon.pkg.json` hierarchy
6. `## Documentation` — auto-detected from docs/ structure, with archive rule
7. `## MoonBit Conventions` — FIXED template for test patterns, file naming
8. `## Code Review Standards` — FIXED content
9. `## Development Workflow` — FIXED quality-first checklist
10. `## Git Workflow` — FIXED content

### Fixed Section: MoonBit Language Notes

```markdown
## MoonBit Language Notes

- `pub` vs `pub(all)` visibility modifiers have different semantics — check current docs before using
- `._` syntax is deprecated, use `.0` for tuple access
- `try?` does not catch `abort` — use explicit error handling
- `?` operator is not always supported — use explicit match/error handling when it fails
- `ref` is a reserved keyword — do not use as variable/field names
- Blackbox tests cannot construct internal structs — use whitebox tests or expose constructors
- For cross-target builds, use per-file conditional compilation rather than `supported-targets` in moon.pkg.json
```

### Auto-Detected Section: Commands

Generate per-module commands based on discovered `moon.mod.json` files:

```markdown
## Commands

```bash
cd <module1> && moon check && moon test    # N tests
cd <module2> && moon check && moon test    # N tests
```

Before every commit:
```bash
moon info && moon fmt   # regenerate .mbti interfaces + format
```

Benchmarks (always `--release`):
```bash
cd <module_with_benchmarks> && moon bench --release
```
```

### Auto-Detected Section: Package Map

Build a table per module from discovered `moon.pkg.json` files. Include package path and purpose (inferred from directory name and imports).

### Auto-Detected Section: Documentation

If a `docs/` directory exists, generate a Documentation section listing the subdirectories. Include the documentation doctrine rules and the archive rule:

```markdown
## Documentation

**Main docs:** [docs/](docs/)

- **Architecture:** [docs/architecture/](docs/architecture/) — principles and invariants only
- **Development:** [docs/development/](docs/development/)
- **Performance:** [docs/performance/](docs/performance/) — dated snapshots, not updated in place
- **Archive:** `docs/archive/` — completed plans and stale documents. Do not search here unless you need historical context.

**Documentation rules:**
- Architecture docs = principles only, never reference specific types/fields/lines. Link to files instead.
- Plans = implementation details (struct defs, code examples, file paths). Archived on completion.
- Performance docs = dated snapshots. New measurements go in new files, old ones are not updated.
- Code is the source of truth — if a doc and the code disagree, the doc is wrong.
```

The **documentation doctrine is mandatory** for all generated CLAUDE.md files. It prevents the staleness problem where architecture docs reference specific types/fields that change every PR. The **archive rule is mandatory** when `docs/archive/` exists.

### Fixed Section: MoonBit Conventions

```markdown
## MoonBit Conventions

- **Block-style:** Code organized in `///|` separated blocks
- **Testing:** Use `inspect` for snapshots, `@qc` for properties
- **Files:** `*_test.mbt` (blackbox), `*_wbtest.mbt` (whitebox), `*_benchmark.mbt`
- **Format:** Always `moon info && moon fmt` before committing
- **Trait impl:** `pub impl Trait for Type with method(self) { ... }` — one method per impl block
- **Arrow functions:** `() => expr`, `() => { stmts }`. Empty body: `() => ()` not `() => {}`
```

### Fixed Section: Code Review Standards

```markdown
## Code Review Standards

- Never dismiss a review request — always do a thorough line-by-line review even if changes seem minor
- Check for: integer overflow, zero/negative inputs, boundary validation, generation wrap-around
- Do not suggest deleting public API types (Id structs, etc.) as 'unused' — they may be needed by downstream consumers
- Verify method names match actual API before writing tests (e.g., check if it's `insert` vs `add_local_op`)
```

### Fixed Section: Development Workflow

```markdown
## Development Workflow

### Performance Optimization Rule

Before designing any performance optimization, write a microbenchmark that **reproduces the claimed bottleneck** in isolation. If the benchmark can't demonstrate the problem, stop and re-evaluate. Stale profiling data (from before prior optimizations) and O(bad) asymptotic complexity are not proof of a real problem. Check if existing mitigations (batch modes, caching, lazy eval) already neutralize the issue.

### Standard Workflow

1. Make edits
2. `moon check` — Lint
3. `moon test` — Run tests
4. `moon test --update` — Update snapshots (if behavior changed)
5. `moon info` — Update `.mbti` interfaces
6. Check `git diff *.mbti` — Verify API changes
7. `moon fmt` — Format
```

### Fixed Section: Git Workflow

```markdown
## Git Workflow

- Always check if git is initialized before running git commands
- After rebase operations, verify files are in the correct directories
- When asked to 'commit remaining files', interpret generously even if phrasing is unclear
```

### Idempotent Merge for CLAUDE.md

If `CLAUDE.md` already exists:

1. Read existing content
2. Parse section headings (`## ...`)
3. For each required section:
   - If heading already exists → **skip** (do not overwrite user customizations)
   - If heading is missing → **append** at the correct position in the ordering
4. Never remove existing sections

## Step 4: Verify

After generating both files, run:

```bash
cat .claude/settings.json | python3 -m json.tool  # Verify valid JSON
head -50 CLAUDE.md  # Verify section order
moon check  # Verify project still works
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Using `"PreCommit"` hook key | Use `"PreToolUse"` with `"matcher": "Bash(git commit*)"` |
| Hardcoding absolute paths in hooks | Use relative paths from project root |
| Running `moon fmt` in pre-commit hook | `moon fmt` modifies files — don't run during commit check |
| Overwriting existing settings.json | Read first, merge, then write |
| Burying Language Notes at bottom | Section #3 — right after Project Overview |
| Missing Code Review Standards | Always include — prevents lazy review behavior |
| Running all modules in single-module project | Detect module count and scope accordingly |
