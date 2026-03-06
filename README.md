# moonbit-skills

Claude Code skills for MoonBit development, managed via symlinks to `~/.claude/skills/`.

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

## Directory Structure

```
moonbit-skills/
├── README.md
├── install.sh
├── uninstall.sh
├── moonbit-traits/
│   └── SKILL.md
└── moonbit-expression-problem/
    └── SKILL.md
```

Each subdirectory containing a `SKILL.md` is treated as a skill and symlinked by `install.sh`.
