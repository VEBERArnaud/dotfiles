---
name: claude-md
description: Trim a repository's CLAUDE.md (or AGENTS.md) to a brief under 150 lines, moving reference material to docs/ and subtree conventions to path-scoped .claude/rules, without losing a line. Use when the user asks to slim, shorten, refactor or review a CLAUDE.md, an AGENTS.md or a repository's agent instructions.
allowed-tools: Bash, Read, Glob, Grep, Write, Edit, AskUserQuestion
---

# CLAUDE.md diet

A CLAUDE.md is loaded whole into every session, so every line costs context on every turn and long files lower adherence (the documentation targets under 200 lines). The brief keeps what every session needs; the rest moves where it is reached on demand. Nothing is deleted: content moves, restatements of the environment are dropped because the environment already holds them, and stale lines are fixed against the code.

Three facts decide where things go:

- `@path` imports do not save anything: imported files load at launch with the file that names them.
- `.claude/rules/<topic>.md` with a `paths:` frontmatter loads only when Claude works on a matching file. This is the only mechanism that removes context from sessions that do not need it.
- `docs/` (or the repository's own documentation tree) loads only when Claude opens the file, so a one-line pointer in the brief is what makes it reachable.

## Steps

### 1. Measure

- Instruction files: `CLAUDE.md`, `.claude/CLAUDE.md`, `CLAUDE.local.md`, `AGENTS.md`, `.claude/rules/*.md`; documentation tree (`docs/`, `CONTRIBUTING.md`, `README.md`).
- Size of each: lines, characters, tokens estimated as characters / 4. Long paragraphs count: a 121-line file with 20 000 characters is not short.
- Baseline commands: every command the brief mentions, checked against `package.json` scripts, `Cargo.toml`, `Makefile` or the CLI itself. A command that no longer exists is sediment.

Done when a table lists each file with lines, characters and estimated tokens, and each mentioned command with exists or stale.

### 2. Sort every section

One of four destinations, the section named in full:

| Destination | What goes there |
| --- | --- |
| Brief (stays) | what the repository is (3 lines), the commands used daily, the architecture map in at most 10 lines with pointers, conventions that apply everywhere, the PR checklist, the "where to look" index |
| Rule (`.claude/rules/<topic>.md`, `paths:`) | conventions that apply to a subtree: a frontend, an API, a `tf/` directory, the tests |
| Doc (`docs/<topic>.md`) | reference read on demand: full endpoint or query lists, migration journals, detailed architecture, deployment considerations |
| Drop | a cache of the environment (scripts already listed in `package.json`, options readable from `--help`), a no-op the model does by default, a duplicate of README or CONTRIBUTING (link instead) |

A repository used with Codex, or one following the agent convention, keeps the brief in `AGENTS.md` and a one-line `CLAUDE.md` holding `@AGENTS.md` (Claude Code reads an `AGENTS.md` on its own when no `CLAUDE.md` sits in the working directory or above it, and only `CLAUDE.md` when both exist, so the import keeps the two tools on the same file). Codex does not load `.claude/rules`: the brief names each rule and when to read it (`When editing apps/api/src, read .claude/rules/api.md first`), so Codex reaches them on demand while Claude loads them by path.

Done when every section of the current file has a destination and a reason.

### 3. Move

- Docs: the moved text lands byte for byte in its destination file, under a heading; an existing page on the same topic is extended, never duplicated. A new page is linked from the brief and from the documentation index if the repository has one.
- Rules: one file per topic, frontmatter first:

```markdown
---
paths:
  - "apps/web/**/*.{ts,tsx}"
---

# Frontend conventions
```

- Brief: rewritten in this order: purpose, commands, architecture map, conventions, checklist, where to look. Every moved section leaves one line: `See docs/graphql-api.md when touching the GraphQL layer`. Specific over adjectives, positive instructions over prohibitions, no sentence the model already follows by default.
- Stale lines are fixed, not moved.

Done when the brief is under 150 lines and under 10 000 characters, and every destination file exists.

### 4. Verify

- Lines and characters of the new brief against the baseline.
- Every relative link in the brief and the rules resolves to a file; the repository's own link check runs if it has one (lychee, `docs:validate`).
- Nothing lost: every non-empty line of the old file longer than 40 characters is found in the brief, a rule or a doc, or listed as dropped with its reason. A line that is in none of the three is a bug in the move. A trimmed line counts as dropped only when its facts already stand in the page it duplicates: a paraphrase is not a move, and a name or a number the reference page lacks is appended there first. The check, with the old file taken from git so a worktree guard never blocks it:

```bash
git show HEAD:CLAUDE.md > /tmp/claude-md-old.md
python3 - <<'EOF'
import pathlib
old=[l for l in pathlib.Path('/tmp/claude-md-old.md').read_text().split('\n') if len(l.strip())>40]
dest=[pathlib.Path(p).read_text() for p in ['CLAUDE.md', *pathlib.Path('.claude/rules').glob('*.md'), *pathlib.Path('docs').rglob('*.md')]]
for l in old:
    if not any(l in t for t in dest): print('-', l[:140])
EOF
```

- The repository's own validators (`docs:validate`, a link check) need its dependencies: a fresh worktree gets the package manager's install first.
- `/doctor prompt-audit` (Claude Code 2.1.283 or later), run by the user in a session, reads the brief, the rules and the skills and reports stale references and contradictions: the report names it as the follow-up check.
- Rules load: `paths` globs match real files (`git ls-files | grep`), a frontmatter typo silently turns a rule into an always-loaded file.

Done when the lost-lines check prints nothing and every link resolves.

### 5. Report

- Before and after: lines, characters, estimated tokens.
- The destination table from step 2.
- Dropped lines with their reason, stale lines fixed.
- For a team repository: the rules benefit every contributor; personal additions belong in `CLAUDE.local.md`, which stays out of git.

The commit is the user's call.
