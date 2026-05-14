# Project Instructions

@/home/antisatori/.codex/RTK.md
@~/.agents/moonbit-base.md

## Project Context

This repository packages MoonBit development skills for coding agents. It is not itself a MoonBit module: there is no root `moon.mod.json`, `moon.pkg`, or MoonBit test target.

## Commands

Use these from the repository root:

```bash
rtk ./install.sh
rtk ./uninstall.sh
rtk git submodule update --init --recursive
rtk bash -n install.sh
rtk bash -n uninstall.sh
rtk rg --files -g SKILL.md
```

Do not run `moon check` from the repo root. If a future skill or submodule contains its own `moon.mod.json`, run MoonBit commands from that module root.

## Documentation

Use `README.md` for repository layout and installation behavior.

Each skill's `SKILL.md` is the source of truth for trigger rules and workflow. Read only the directly relevant `references/`, `scripts/`, tutorial, or asset files for the skill being edited.

`moonbit-base.md` contains shared MoonBit conventions and is linked into `~/.agents/` by `install.sh`.

## Project-Specific Notes

- `install.sh` links top-level directories containing `SKILL.md` into `~/.agents/skills` and `~/.claude/skills`.
- `install.sh` also links `moonbit-agent-guide/moonbit-agent-guide` as `moonbit-agent-guide`.
- `moonbit-agent-guide/` is a git submodule; treat upstream content separately from local community skills.
- `uninstall.sh` removes symlinks that point back to this repository, including old compatibility links under `~/.codex/skills`.
- For Codex-only setup, do not create `.claude/` hooks or edit `.codex/config.toml` unless explicitly requested.
- Keep skill files concise. Put durable language-level MoonBit conventions in `moonbit-base.md`, not repeated in every skill.
