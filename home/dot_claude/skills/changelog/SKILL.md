---
name: changelog
description: Generate a changelog from recent commits
disable-model-invocation: true
allowed-tools: Bash, Read
argument-hint: [since-tag-or-count]
---

# Changelog Generator

Generate a structured changelog from git commits.

## Arguments

- Tag name (e.g., `v1.0.0`): generate changelog since that tag
- Number (e.g., `20`): generate from last N commits
- No argument: generate from last 10 commits

## Process

1. Get commits using `git log --oneline --no-merges`
2. Parse conventional commit format: `type(scope): subject`
3. Group by type:
   - **Features** (feat)
   - **Bug Fixes** (fix)
   - **Documentation** (docs)
   - **Performance** (perf)
   - **Refactoring** (refactor)
   - **Other** (style, test, chore)
4. Format as markdown with bullet points

## Output format

```markdown
## Changelog

### Features

- (scope): description

### Bug Fixes

- (scope): description

### Documentation

- description
```

## Example usage

```
/changelog v1.2.0
/changelog 15
/changelog
```
