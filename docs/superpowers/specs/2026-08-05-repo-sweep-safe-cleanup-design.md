# repo-sweep: safe local cleanup of unmerged branches and worktrees

**Date:** 2026-08-05
**Target:** `home/dot_local/bin/executable_repo-sweep`

## Problem

repo-sweep only surfaces `GONE` and `MERGED` items in its default fzf filter.
Local branches and worktrees tied to open PRs (pushed, unmerged) never show up,
even though deleting the local copy is lossless — the remote branch and the PR
remain on GitHub. Conversely, the current manual escape hatch (clearing the fzf
query) is dangerous: `wt-remove` silently falls back to `git worktree remove
--force` on dirty worktrees, and `git branch -D` destroys unpushed commits
without warning.

## Goals

1. Propose lossless local cleanup by default, including branches with open PRs.
2. Make lossy deletions (uncommitted files, unpushed commits) explicit and
   gated behind a confirmation.

## Statuses

Status detection is extracted into a `branch_status()` helper shared by the
worktree block and the branch block (the GONE/MERGED logic is currently
duplicated between them). The `DIRTY` check stays in the worktree block.

| Status     | Condition                                                        | Loss on deletion                    |
|------------|------------------------------------------------------------------|-------------------------------------|
| `DIRTY`    | (worktrees only) modified or untracked files — checked first     | local files + any unpushed commits  |
| `GONE`     | upstream deleted on remote (`[gone]`)                            | none (PR merged/closed)             |
| `MERGED`   | branch tip is ancestor of `origin/<default>`                     | none                                |
| `PUSHED`   | upstream exists, zero local commits ahead (up to date or behind) | none — remote branch and PR remain  |
| `UNPUSHED` | everything else: no upstream, or ahead of upstream               | local commits permanently lost      |

`ACTIVE` disappears — every candidate now falls into one of the five statuses.
Check order: `DIRTY` → `GONE` → `MERGED` → `PUSHED` → `UNPUSHED`.

Detached-HEAD worktrees (no branch) are treated as `UNPUSHED` when clean:
reachability of the checked-out commit cannot be cheaply guaranteed, so they
stay out of the default filter and go through confirmation.

### branch_status() contract

```
branch_status <repo> <branch> <cmp_ref>   # echoes GONE|MERGED|PUSHED|UNPUSHED
```

- `%(upstream:track)` == `[gone]` → `GONE`
- `git merge-base --is-ancestor <branch> <cmp_ref>` → `MERGED` (skipped when
  `cmp_ref` is empty)
- upstream configured and `%(upstream:track)` does not contain `ahead` →
  `PUSHED`
- otherwise → `UNPUSHED`

## Candidate line format

The status becomes a real field so the deletion phase can partition the
selection. New format (6 fields, was 5):

```
<display>\t<type>\t<branch>\t<repo>\t<wt_path>\t<status>
```

## fzf selection (phase 4)

- Prefilled query becomes `'GONE' | 'MERGED' | 'PUSHED'`.
- `DIRTY` and `UNPUSHED` items remain in the list, visible by clearing the
  query.
- Header updated to mention that clearing the query reveals risky items.

## Confirmation (phase 6)

The selection is partitioned into safe (`GONE`, `MERGED`, `PUSHED`) and risky
(`DIRTY`, `UNPUSHED`) items.

- Selection contains no risky items → behavior unchanged, no prompt.
- Selection contains risky items → print a recap before deleting anything, one
  line per risky item showing what would be lost:
  - unpushed commit count: `git rev-list --count <upstream>..<branch>` when an
    upstream exists, else `git rev-list --count <cmp_ref>..<branch>` when
    `cmp_ref` exists, else `?`
  - dirty file count: `git status --porcelain | wc -l` on the worktree
- Prompt `Delete these too? [y/N]`, read from the script's stdin; EOF is treated as decline.
  - `y` → delete everything; confirmed dirty worktrees use an explicit
    `wt-remove --force`
  - anything else → delete only the safe items; risky items are reported under
    `Skipped (declined)`

## Report (phase 7)

New `Skipped (declined)` section listing risky items the user declined.

## Out of scope

- `wt-remove` itself is not modified. Its silent `--force` fallback is
  debatable but it is used outside repo-sweep; repo-sweep now always makes the
  force decision explicitly upstream of it.
- No GitHub API calls (PR state lookup) — status detection stays git-only and
  fast.
- No squash-merge detection heuristics (`git cherry`/patch-id): `PUSHED` +
  GitHub's `delete_branch_on_merge` already cover the real-world cases.

## Testing

- ShellCheck must pass (already enforced by CI).
- Manual test against fixture repos: a scratchpad base directory with a bare
  "origin" and clones covering each status (gone, merged, pushed, ahead,
  no-upstream, dirty worktree, clean worktree, detached worktree), driven via
  `REPO_SWEEP_BASE`. Verify: candidate statuses, default filter contents,
  confirmation recap and both `y`/`N` outcomes, final report sections.
- Real-world sanity check on `vbr-tech/laminutebaseball.fr`: 16 `evergreen/*`
  branches → `PUSHED`, `feature/231-evergreen` worktree → `UNPUSHED`,
  `evergreen-combien-de-manches-baseball` worktree → `PUSHED`.
