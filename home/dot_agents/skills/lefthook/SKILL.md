---
name: lefthook
description: Create or update a repository's lefthook config (lefthook.yml, or lefthook-local.yml with the `local` argument) from its CI workflow and toolchain. Use when the user asks for lefthook, git hooks or quality gates on a repository.
allowed-tools: Bash, Read, Glob, Grep, Write, Edit, AskUserQuestion
argument-hint: [local]
---

# Lefthook config generator

Write the lefthook config that the Claude Code hook (`~/.claude/scripts/hook.sh`) runs with `lefthook run pre-commit` before a `git commit` and `lefthook run pre-push --force` before Claude stops, and that git runs once a developer opts in with `lefthook install`. The repository's own CI and scripts are the source of truth: mirror them, never invent a check.

`$ARGUMENTS` = `local`: write `lefthook-local.yml` (personal, listed in `~/.gitignore_global`) instead of the committed `lefthook.yml`. It is the file for a team repository whose git history must stay untouched.

## Steps

### 1. Locate

- Repository root: `git rev-parse --show-toplevel`.
- Existing config: any of `{,.}lefthook{,-local}.{yml,yaml,toml,json}` at the root. Found: update mode, read it whole and keep every existing job under its name. Not found: create mode.
- Target: `lefthook-local.yml` when `$ARGUMENTS` is `local` or when the only existing config is a `-local` file, else `lefthook.yml`.
- Create mode without `local`, and `git shortlog -sn --no-merges HEAD` lists other human authors (bots excluded): ask which file to write before going further.

Done when the mode and the target path are stated.

### 2. Inventory

Read, in this order, and note every check with its exact command:

1. CI: `.github/workflows/*.yml` and any other pipeline file. Each format, lint, typecheck, validate or test step is a candidate job.
2. Units: every directory holding a marker (`package.json`, `Cargo.toml`, `go.mod`, `composer.json`, `Package.swift`, a directory of `*.tf`), the root included. Per unit, the scripts and config files that [recipes.md](recipes.md) names: package manager, formatter, linter, typecheck, tests.
3. Local tools: `command -v` on every binary a job would call. A JavaScript unit without `node_modules` (fresh clone or worktree) gets its package manager's install first, otherwise every exec-form tool reads as missing.
4. Duration: run each candidate once and note the time.

Done when a table unit x stage gives the command and duration of each cell, and every CI check is either mapped to a job or marked "left out" with its reason: tool not installed locally, needs credentials or network, pip-only, too slow for a hook (build, e2e).

### 3. Write

Compose the file from the recipes:

- `pre-commit`: fast checks on `{staged_files}`. Formatters first, with `stage_fixed: true`, then lint and typecheck. `glob` scoped to the unit, `exclude` for generated or vendored paths, `root:` with a trailing slash for a unit in a subdirectory. A check over 30 seconds belongs to pre-push only.
- `pre-push`: whole-suite checks written as plain commands: tests, full validation. No file template in this stage: the Claude hook runs it with `--force` and no push files, so `{push_files}` would expand to nothing.
- `parallel: true` on both stages, one job per tool, the job named after the tool.
- `glob_matcher: doublestar` at the top of the file: globs then read like Bash, `*.ts` is the root only and `packages/*/src/**/*.ts` any depth under src, so a CI scope such as `./*.{ts,js}` can be mirrored exactly. With the default matcher a bare `*.ts` matches every directory.
- The repo script when one exists (`pnpm run lint`), the tool through the package manager's exec form when none does. A missing script is a gap for the report, never a reason to run a tool on a guessed config.
- Header comment, this text with the CI path filled in:

```yaml
# Quality gates for this repository, mirroring .github/workflows/<file>.
#
# pre-commit runs on staged files only, pre-push validates the whole source.
# Git runs them once `lefthook install` has been run in a clone. The Claude
# Code hook (~/.claude/scripts/hook.sh) invokes the same two stages with
# `lefthook run <stage>`, which needs no install.
```

Update mode: add the missing jobs and leave the rest byte for byte; an existing job you would have written differently goes in the report, not in the file.

Existing husky + lint-staged: each lint-staged entry becomes a pre-commit job with the same glob and `stage_fixed: true`; `.husky/` and the two devDependencies go, `lefthook` comes in as devDependency, and `"prepare": "husky"` becomes `"prepare": "lefthook install --reset-hooks-path"`. The repository already forced its hooks on every clone, so the forcing level stays what it was. Two traps: husky's own `prepare` (run by the first `pnpm install`) leaves `core.hooksPath=.husky/_` in the shared git config, which makes a plain `lefthook install` refuse, hence the flag; and `pnpm add`/`pnpm remove` run from inside the repository with `--ignore-scripts`, otherwise the `prepare` failure makes pnpm drop the package.json change and the lockfile ends up out of date.

Done when `lefthook dump` parses the file and every mapped command appears exactly once.

### 4. Verify

Run both stages with `--no-auto-install`: without it, `lefthook run` writes git hooks into the clone.

```bash
lefthook run pre-commit --all-files --no-tty --no-auto-install
lefthook run pre-push --force --no-tty --no-auto-install
```

A failure is one of two kinds. A config error (wrong path, wrong flag, tool not found): fix it and rerun. A pre-existing defect in the repository (a lint warning that was already there): report it with file and rule, and leave the code alone unless asked.

`--all-files` feeds every file to the formatters, and `stage_fixed` stages what they rewrite: read `git status` right after the run. A rewritten file outside the CI scope means the glob is too wide; restore the file (`git reset`, `git checkout -- <path>`) and narrow the glob before rerunning. Tests that import sibling packages from their build output need the build job first: a `group` with `piped: true` in pre-push, bundle then tests.

`lefthook install` is never run here: installing git hooks is the developer's decision.

Done when both stages run to completion and every remaining failure is attributed to a named file.

### 5. Report

- The coverage table: unit, stage, command, CI step mirrored.
- CI checks left out, with the reason.
- Pre-existing failures.
- Opt-in follow-ups: `lefthook install` for git-level hooks on this clone; for a `-local` file, the `lefthook-local.yml` line in `~/.gitignore_global` and its copy into each worktree.

The commit is the user's call.
