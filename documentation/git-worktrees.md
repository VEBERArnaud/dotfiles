# Git Worktrees

Git worktrees allow you to have multiple branches checked out simultaneously in separate directories. This is useful for:

- Reviewing PRs without losing your current work context
- Working on multiple features in parallel
- Making hotfixes while keeping your feature branch intact

## Directory Structure

```
~/Developer/src/github.com/org/repo/           # Main repo (main branch)
~/Developer/src/github.com/org/repo.wt/        # Worktree container
    feature-auth/                               # feature/auth branch
    hotfix-payment/                             # hotfix/payment branch
```

Branch names with slashes are converted to dashes: `feature/auth` -> `feature-auth`.

## Commands

| Command                      | Description                                               |
| ---------------------------- | --------------------------------------------------------- |
| `wt <branch>`                | Create/open worktree in sesh (creates branch if needed)   |
| `wt --no-create <branch>`    | Open worktree only if branch exists (error otherwise)     |
| `wt --no-switch <branch>`    | Create worktree without switching session                 |
| `wt --no-install <branch>`   | Create worktree without auto-installing deps              |
| `wt --no-editor <branch>`    | Create worktree without auto-opening editor               |
| `wt --no-envrc <branch>`     | Create worktree without auto-creating .envrc              |
| `wtd <branch>`               | Delete worktree, tmux session, and local branch           |
| `wtd -f <branch>`            | Force delete worktree and branch                          |
| `wtd --keep-branch <branch>` | Delete worktree but keep local branch                     |
| `git wl`                     | Native git worktree list                                  |
| `Ctrl-a W`                   | Tmux worktree picker (fzf)                                |

## Workflow Examples

### Example 1: Review a Pull Request

You're working on `feature/dashboard` and need to review a colleague's PR on `feature/auth`:

```bash
# You're in ~/Developer/src/github.com/org/myapp working on feature/dashboard

# Create worktree and open in new tmux session
wt feature/auth
# Now in a tmux session for ~/Developer/src/github.com/org/myapp.wt/feature-auth
# Cursor opens automatically with the worktree

# Review the code, run tests
npm test

# Switch between sessions with sesh
# Ctrl-a T -> sesh picker shows all sessions
# Ctrl-a L -> quick switch to last session

# After PR is merged, cleanup
wtd feature/auth
```

### Example 2: Urgent Hotfix

You're deep into `feature/new-checkout` when a critical bug is reported:

```bash
# Create hotfix branch in a worktree and open in sesh
wt hotfix/payment-bug
# Now in a tmux session for ~/Developer/src/github.com/org/myapp.wt/hotfix-payment-bug

# Fix the bug
vim src/payment.js
npm test
git add -p && git commit -m "fix: handle null payment method"
git push origin hotfix/payment-bug

# Switch back to your feature work
# Ctrl-a L -> last session (feature/new-checkout)

# After hotfix is merged
wtd hotfix/payment-bug
```

### Example 3: Parallel Feature Development

Working on two related features that you switch between:

```bash
# Setup both worktrees (each opens in its own sesh session)
wt feature/api-v2
wt feature/client-v2

# Switch between sessions
# Ctrl-a T -> sesh picker shows both sessions
# Ctrl-a L -> quick switch to last session
# Ctrl-a W -> worktree-specific picker

# When done with a feature
wtd feature/api-v2
```

### Example 4: Create Worktree Without Switching

Sometimes you want to prepare a worktree without leaving your current context:

```bash
# Create worktree in background
wt --no-switch feature/auth

# Continue working on current branch...
# Later, switch to it
wt feature/auth  # Opens existing worktree in sesh
```

### Example 5: Using Tmux Keybindings

Inside tmux, you have dedicated keybindings:

| Keybinding | Description                        |
| ---------- | ---------------------------------- |
| `Ctrl-a T` | sesh: all sessions (tmux + zoxide) |
| `Ctrl-a W` | Worktree picker for current repo   |
| `Ctrl-a L` | Quick switch to last session       |
| `Ctrl-a S` | Connect sesh to current directory  |

The worktree picker (`Ctrl-a W`) shows a preview of recent commits for each worktree and displays status indicators:
- `☠ orphan` — remote branch deleted (requires cleanup)
- `✓ merged` — branch has been merged into main (cleanup candidate)
- `⬡ PR #N (CI ✓)` — open PR with passing CI
- `⬡ PR #N (CI ✗)` — open PR with failing CI
- `⬡ PR #N (CI ⏳)` — open PR with CI in progress
- `◇ draft #N` — draft PR (CI not shown for drafts)
- `(CI ✓)` / `(CI ✗)` / `(CI ⏳)` — CI status when no PR exists
- `⚠ N behind` — branch is N commits behind main (may need rebase)

Status hierarchy: orphan > merged > PR/CI > CI > behind (only highest priority shown).

PR and CI status load asynchronously via `gh` CLI — the picker opens instantly and indicators appear after ~500ms.

## Auto-installation of Dependencies

When creating a new worktree, dependencies are automatically installed in the new sesh session:

1. `wt` creates the worktree and a `.wt-new` marker file
2. `sesh connect` opens a new tmux session
3. The shell starts and `nvm use` runs automatically (if `.nvmrc` exists)
4. Dependencies are installed based on the lockfile detected:
   - `package-lock.json` → `npm install`
   - `yarn.lock` → `yarn install`
   - `pnpm-lock.yaml` → `pnpm install`
   - `bun.lockb` → `bun install`

To skip auto-installation, use `wt --no-install <branch>`.

**Note**: Dependencies are only installed on worktree creation, not when reopening an existing worktree.

## Auto-opening Editor

When creating a new worktree, your editor (Cursor) is automatically opened in the new sesh session:

1. `wt` creates the worktree and a `.wt-open-editor` marker file
2. `sesh connect` opens a new tmux session
3. The shell starts and detects the marker file
4. `cursor .` is executed to open the editor in the worktree directory

To skip auto-opening the editor, use `wt --no-editor <branch>`.

**Note**: The editor only opens on worktree creation, not when reopening an existing worktree.

## Auto-loading Environment

When creating a new worktree, if the main repository has a `.envrc` file, a new `.envrc` is automatically created in the worktree that sources the main repo's environment:

1. `wt` detects if `.envrc` exists in the main worktree
2. Creates a `.envrc` in the new worktree with `source_env_if_exists`
3. Runs `direnv allow` automatically

This ensures environment variables (API keys, paths, etc.) are shared across all worktrees without manual setup.

To skip auto-creating the `.envrc`, use `wt --no-envrc <branch>`.

**Note**: The `.envrc` only sources from the main worktree, not copies. Changes to the main `.envrc` are automatically reflected in all worktrees.

### Overriding Variables

To customize environment variables for a specific worktree, create a `.envrc.override` file:

```bash
# .envrc.override - worktree-specific overrides
export API_URL="http://localhost:3001"
export DEBUG=true
```

Variables in `.envrc.override` take precedence over those from the main `.envrc`.

## Tips

- **Tab completion**: `wt` and `wtd` support zsh tab completion for branch names
- **Zoxide integration**: Worktree paths are added to zoxide for quick access with `z`
- **Full cleanup**: `wtd` deletes the worktree, tmux session, and local branch (use `--keep-branch` to preserve the branch)
- **Branch naming**: Use `feature/`, `hotfix/`, `bugfix/` prefixes for clarity
- **Main repo**: Keep `main` branch in the original repo, worktrees for feature branches
- **Idempotent**: Running `wt <branch>` on an existing worktree simply opens it in sesh
- **Node version**: If `.nvmrc` exists, the correct Node version is activated before installing deps

## Troubleshooting

### "Not in a git repo"

Make sure you're inside a git repository when running worktree commands.

### "Branch not found"

The branch doesn't exist locally or on origin and you used `--no-create`. Remove the flag to create the branch automatically.

### "Can't remove while inside"

You need to switch to another session before deleting the worktree with `wtd`.

### Worktree picker empty in tmux

Make sure you're in a git repository when pressing `Ctrl-a W`.
