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

| Command          | Description                            |
| ---------------- | -------------------------------------- |
| `wt <branch>`    | Create worktree for existing branch    |
| `wt -b <branch>` | Create worktree with new branch        |
| `wtc <branch>`   | Create worktree and cd into it         |
| `wts`            | Interactive worktree switcher (fzf)    |
| `wtd <branch>`   | Delete worktree (and tmux session)     |
| `wtgo <branch>`  | Open worktree in tmux session via sesh |
| `wtls`           | List all worktrees with colors         |
| `git wl`         | Native git worktree list               |
| `Ctrl-a W`       | Tmux worktree picker                   |

## Workflow Examples

### Example 1: Review a Pull Request

You're working on `feature/dashboard` and need to review a colleague's PR on `feature/auth`:

```bash
# You're in ~/Developer/src/github.com/org/myapp working on feature/dashboard

# Create worktree for the PR branch (fetches from origin automatically)
wtc feature/auth
# Now in ~/Developer/src/github.com/org/myapp.wt/feature-auth

# Review the code, run tests
npm test

# Switch back to your feature (interactive picker)
wts
# Select main repo -> back to feature/dashboard

# Or open the PR review in a dedicated tmux session
wtgo feature/auth
# Now in a tmux session named "myapp:feature-auth"

# After PR is merged, cleanup
wtd feature/auth
```

### Example 2: Urgent Hotfix

You're deep into `feature/new-checkout` when a critical bug is reported:

```bash
# Create hotfix branch in a worktree
wtc -b hotfix/payment-bug
# Now in ~/Developer/src/github.com/org/myapp.wt/hotfix-payment-bug

# Fix the bug
vim src/payment.js
npm test
git add -p && git commit -m "fix: handle null payment method"
git push origin hotfix/payment-bug

# Switch back to your feature work
wts  # or just: cd back to main repo

# After hotfix is merged
wtd hotfix/payment-bug
```

### Example 3: Parallel Feature Development

Working on two related features that you switch between:

```bash
# Setup both worktrees
wt -b feature/api-v2
wt -b feature/client-v2

# Open each in dedicated tmux sessions
wtgo feature/api-v2    # Session: myapp:feature-api-v2
wtgo feature/client-v2 # Session: myapp:feature-client-v2

# Switch between sessions
# Ctrl-a T -> sesh picker shows both sessions
# Ctrl-a L -> quick switch to last session
# Ctrl-a W -> worktree-specific picker

# When done with a feature
wtd feature/api-v2
```

### Example 4: Using with Tmux

Inside tmux, you have dedicated keybindings:

| Keybinding | Description                        |
| ---------- | ---------------------------------- |
| `Ctrl-a T` | sesh: all sessions (tmux + zoxide) |
| `Ctrl-a W` | Worktree picker for current repo   |
| `Ctrl-a L` | Quick switch to last session       |
| `Ctrl-a S` | Connect sesh to current directory  |

The worktree picker (`Ctrl-a W`) shows a preview of recent commits for each worktree.

## Tips

- **Tab completion**: All `wt*` commands support zsh tab completion for branch names
- **Zoxide integration**: Worktree paths are added to zoxide for quick access with `z`
- **Session cleanup**: `wtd` automatically kills the associated tmux session
- **Branch naming**: Use `feature/`, `hotfix/`, `bugfix/` prefixes for clarity
- **Main repo**: Keep `main` branch in the original repo, worktrees for feature branches

## Troubleshooting

### "Not in a git repo"

Make sure you're inside a git repository when running worktree commands.

### "Branch not found"

The branch doesn't exist locally or on origin. Use `wt -b <branch>` to create a new branch.

### "Can't remove while inside"

You need to `cd` out of the worktree before deleting it with `wtd`.

### Worktree picker empty in tmux

Make sure you're in a git repository when pressing `Ctrl-a W`.
