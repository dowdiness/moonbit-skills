# MoonBit Development Verification Skill

A comprehensive quality checklist for MoonBit development that catches common issues before they become bugs.

## Usage

Invoke this skill when working on MoonBit code:

```bash
/moonbit-check
```

Or reference it in your prompts:

```
"Implement this feature following the moonbit-check skill workflow"
"Use /moonbit-check to verify this implementation"
```

## What It Does

This skill guides Claude through a systematic verification process:

1. **Pre-flight checks**: Verifies dependencies before implementation starts
2. **Syntax awareness**: Ensures correct MoonBit idioms (tuple destructuring, labelled args, error handling)
3. **Test verification**: Runs tests and verifies assertion formats match exactly
4. **CLI testing**: Checks help text, flag shadowing, and error messages for CLI tools
5. **Interface review**: Updates and reviews `.mbti` files for API changes
6. **Quality gates**: Won't mark tasks complete until all checks pass

## Why This Helps

Based on Claude Code usage insights, this skill addresses:

- **49 instances of buggy code** - Catches functional bugs before delivery
- **19 dependency issues** - Checks dependency health upfront
- **Syntax struggles** - Prevents MoonBit-specific compilation errors
- **Test failures** - Ensures error message formats match assertions exactly
- **CLI bugs** - Catches help text and flag shadowing issues early

## Designed For

- Feature implementation in MoonBit projects
- CLI tool development (argparser, command-line apps)
- Library development with public APIs
- Multi-file refactoring
- Code that needs to pass comprehensive test suites

## Tips

- Use this skill before starting large features to establish a quality baseline
- Reference it in your project's CLAUDE.md to make it automatic
- Combine with hooks to auto-run checks after edits
