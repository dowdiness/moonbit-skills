# moonbit-skills

Claude Code skills for MoonBit development, managed via symlinks to `~/.claude/skills/`.

## Skills

| Skill | Description |
|-------|-------------|
| `moonbit-agent-guide` | Guide for writing, refactoring, and testing MoonBit projects. Moon tooling, layout, and conventions. |
| `moonbit-c-binding` | Writing MoonBit bindings to C libraries using native FFI. Stubs, ownership, callbacks, ASan. |
| `moonbit-expression-problem` | Solving the Expression Problem in MoonBit using Finally Tagless encoding and two-layer architecture. |
| `moonbit-opaque-types` | Opaque/newtype pattern for user-friendly public APIs. Type-safe wrappers and facade layers. |
| `moonbit-perf-investigation` | **Prerequisite for any optimization.** Reproducing bottlenecks in microbenchmarks before designing solutions. |
| `moonbit-refactoring` | Idiomatic MoonBit refactoring: shrink public APIs, pattern matching, methods, loop invariants. |
| `moonbit-settings` | Bootstrap `.claude/settings.json` and `CLAUDE.md` for MoonBit projects. Auto-detects structure. |
| `moonbit-traits` | Effective trait usage in MoonBit's Self-based trait system. Endomorphisms, capabilities, visitors. |
| `moonbit-verification` | Quality checklist: dependencies, syntax, tests, interfaces, formatting. |

## Installation

```bash
git clone https://github.com/dowdiness/moonbit-skills.git
cd moonbit-skills
./install.sh
```

This creates symlinks in `~/.claude/skills/` for each skill directory.

## Uninstallation

```bash
./uninstall.sh
```

Only removes symlinks pointing to this repository. Other skills are not affected.

## Adding a New Skill

1. Create a new directory at the repository root (e.g., `moonbit-my-skill/`)
2. Add a `SKILL.md` file inside it with YAML frontmatter (`name`, `description`) followed by the skill content
3. Run `./install.sh` to link the new skill

Each subdirectory containing a `SKILL.md` is treated as a skill and symlinked by `install.sh`.
