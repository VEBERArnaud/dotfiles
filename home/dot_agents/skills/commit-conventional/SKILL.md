---
name: commit-conventional
description: Create a conventional commit with proper format
disable-model-invocation: true
allowed-tools: Bash, Read
---

# Conventional Commit Helper

Create a properly formatted conventional commit from staged changes.

## Process

1. Check for staged changes: `git diff --staged --stat`
2. If no staged changes, prompt to stage files first
3. Analyze changes: `git diff --staged`
4. Determine commit type based on changes:
   - `feat`: new functionality
   - `fix`: bug fixes
   - `docs`: documentation changes only
   - `style`: formatting, whitespace
   - `refactor`: code restructuring without feat/fix
   - `perf`: performance improvements
   - `test`: adding/fixing tests
   - `chore`: maintenance, dependencies, config
5. Identify scope from changed files/directories
6. Write subject line:
   - Imperative mood ("add" not "added")
   - Lowercase
   - No trailing period
   - Max 72 characters
7. Present commit message for approval
8. Execute commit with GPG signing

## Commit format

```
type(scope): subject

[optional body]

[optional footer]
```

## Example flow

```
$ /commit-conventional

Staged changes:
 src/auth/login.ts | 25 +++++++++
 src/auth/types.ts |  8 +++

Proposed commit:
  feat(auth): add OAuth2 login support

Proceed with commit? (y/n)
```

## Notes

- GPG signing is enabled by default (from gitconfig)
- Do not commit if no changes are staged
- Ask for confirmation before executing commit
