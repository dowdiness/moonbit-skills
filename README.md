# moonbit-skills

Agent skills for MoonBit development, managed via symlinks to Claude Code and Codex skill directories.

Some skills originate from the [official MoonBit skills repository](https://github.com/moonbitlang/skills) and are included here as git submodules or copies. The rest are community-created.

## Skills

| Skill | Origin | Description |
|-------|--------|-------------|
| `moonbit-agent-guide` | [official](https://github.com/moonbitlang/moonbit-agent-guide) (submodule) | Guide for writing, refactoring, and testing MoonBit projects. Moon tooling, layout, and conventions. |
| `moonbit-c-binding` | [official](https://github.com/moonbitlang/skills/tree/main/moonbit-c-binding) (copy) | Writing MoonBit bindings to C libraries using native FFI. Stubs, ownership, callbacks, ASan. |
| `moonbit-deprecated-syntax` | community | Tracks deprecated MoonBit syntax to avoid generating invalid code. Auto-maintained. |
| `moonbit-expression-problem` | community | Solving the Expression Problem in MoonBit using Finally Tagless encoding and two-layer architecture. |
| `moonbit-housekeeping` | community | Repo maintenance with generic worker profiles for phased checks (git, lint, sync, build, test). |
| `moonbit-opaque-types` | community | Opaque/newtype pattern for user-friendly public APIs. Type-safe wrappers and facade layers. |
| `moonbit-perf-investigation` | community | **Prerequisite for any optimization.** Reproducing bottlenecks in microbenchmarks before designing solutions. |
| `moonbit-refactoring` | community | Idiomatic MoonBit refactoring: shrink public APIs, pattern matching, methods, loop invariants. |
| `moonbit-agent-setup` | community | Bootstrap MoonBit project instructions and agent-specific adapters for Codex, Claude Code, or generic coding agents. |
| `moonbit-traits` | community | Effective trait usage in MoonBit's Self-based trait system. Endomorphisms, capabilities, visitors. |
| `moonbit-verification` | community | Quality checklist: dependencies, syntax, tests, interfaces, formatting. |

## Installation

```bash
git clone --recursive https://github.com/dowdiness/moonbit-skills.git
cd moonbit-skills
./install.sh
```

This creates symlinks for each skill directory in:

- `~/.claude/skills/`
- `~/.agents/skills/`

Codex documents `~/.agents/skills/` as the user-level skills directory.

It also links `moonbit-base.md` into `~/.claude/` and `~/.agents/`.
Restart Claude Code or Codex after installing so the tools discover newly linked skills.

## Uninstallation

```bash
./uninstall.sh
```

Only removes symlinks pointing to this repository from the Claude Code and Codex locations, including old compatibility symlinks in `~/.codex/skills/`. Other skills are not affected.

## Adding a New Skill

1. Create a new directory at the repository root (e.g., `moonbit-my-skill/`)
2. Add a `SKILL.md` file inside it with YAML frontmatter (`name`, `description`) followed by the skill content
3. Run `./install.sh` to link the new skill

Each subdirectory containing a `SKILL.md` is treated as a skill and symlinked by `install.sh`.
