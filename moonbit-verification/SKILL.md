---
name: moonbit-verification
description: >
  Quality checklist for MoonBit development. Use when implementing or
  modifying MoonBit code to catch dependency issues, syntax mistakes,
  test failures, CLI bugs, and interface changes before they become
  problems.
---

# MoonBit Development Verification Skill

**Trigger**: Use this skill when implementing or modifying MoonBit code to ensure quality and catch common issues early.

## Pre-Implementation Phase

### 1. Dependency Health Check
Before starting any implementation:
- Run `moon update` to refresh dependencies
- Attempt a clean build with `moon check` to verify all dependencies are available
- If any moonbitlang/x or other external packages fail, **stop and report the issue** with:
  - Exact dependency name and version
  - Error message
  - Suggested workarounds (vendoring, alternative packages, or implementing the functionality directly)
- Do not proceed with implementation if dependencies are broken

### 2. MoonBit Syntax Pattern Verification
When implementing new code, be especially careful with:
- **Tuple destructuring**: Use correct syntax `let (a, b) = tuple` not `let a, b = tuple`
- **Labelled arguments**: Follow MoonBit conventions for named parameters
- **Error handling**: Use Result types and pattern matching correctly
- **Error messages**: Ensure string formats in errors match test assertion expectations exactly

## Implementation Phase

### 3. Multi-File Change Coordination
When changes span multiple files:
- Read all affected files first before making changes
- Ensure import statements are correct across files
- Verify type signatures are consistent
- Check that `.mbti` interface files will be updated correctly

### 4. Test-First Verification
Before marking any feature complete:
- Run `moon test` and capture the full output
- **For each test failure**:
  - Show expected vs actual output
  - Identify the root cause (syntax error, logic bug, or assertion mismatch)
  - Fix the issue
  - Re-run that specific test to verify
- **Verify error message formats** match test assertions character-for-character
- If tests use snapshot testing (`inspect`), consider whether behavior change is intentional
- Only proceed when ALL tests pass

### 5. CLI Functional Testing (if applicable)
If implementing a CLI tool or demo app, manually verify:
1. Run `--help` at root level - check output formatting
2. Run `--help` for each subcommand - verify correct help text
3. Test each flag individually - ensure they work as expected
4. Test flag combinations - check for shadowing issues (e.g., global `-v` vs subcommand `-v`)
5. Verify error messages for invalid inputs match expected format
6. Test edge cases (missing required args, invalid values, etc.)

## Post-Implementation Phase

### 6. Interface and Format Verification
After all tests pass:
- Run `moon info` to update `.mbti` interface files
- Check `git diff *.mbti` to verify API changes are intentional
- Review any unexpected interface changes and explain why they occurred
- Run `moon fmt` to format code consistently
- Run final `moon check` to ensure no lint issues

### 7. Benchmark Verification (for performance-critical code)
If modifying performance-critical paths:
- Run `moon bench --release` (always with --release flag)
- Compare results to baseline if available
- Report any significant performance changes

### 8. Performance Optimization Gate
**If the task is a performance optimization**, use the `moonbit-perf-investigation` skill BEFORE designing any solution. That skill requires reproducing the claimed bottleneck in an isolated microbenchmark. Do not skip this — stale profiling data and O(bad) complexity are not proof of a real problem.

## Quality Checklist

Before marking the task complete, verify:
- [ ] Dependencies are healthy and build succeeds
- [ ] All MoonBit syntax patterns are correct (no tuple destructuring errors)
- [ ] All tests pass with exact assertion matches
- [ ] CLI functionality tested manually (if applicable)
- [ ] Interface files (`.mbti`) updated and reviewed
- [ ] Code formatted with `moon fmt`
- [ ] `moon check` passes with no warnings
- [ ] Multi-file changes are coordinated and imports are correct

## Error Recovery

If you encounter compilation errors:
- Show the exact error message
- Identify if it's a syntax issue, dependency problem, or logic error
- Attempt a fix using correct MoonBit idioms
- If the error is unclear or seems like a dependency issue, **stop and ask** rather than guessing

## Notes

This skill addresses common friction points:
- Broken dependencies causing wasted iteration
- MoonBit syntax issues (labelled args, tuple destructuring)
- Test assertion format mismatches
- Functional bugs in CLI tools (help text, flag shadowing)
- Interface changes not being reviewed

Use this checklist to catch issues before they require debugging cycles.
