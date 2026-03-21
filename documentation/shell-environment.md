# Shell Environment

The shell environment is split into two drop-in directories sourced automatically by zsh. This avoids a monolithic `.zprofile` or `.zshenv` and makes it easy to add, remove, or conditionally include configuration.

## Architecture

### `~/.zprofile.d/` — Login Shell

Sourced by `~/.zprofile` via a `*.sh(N)` glob. These files run once per login session (terminal window, SSH session). Use this for environment variables, PATH modifications, and tool initialization.

### `~/.zshenv.d/` — Every Shell

Sourced by `~/.zshenv` via a `*.sh(N)` glob. These files run for every shell invocation (including non-interactive scripts). Use this for variables that must be available everywhere, such as API tokens injected from 1Password at `chezmoi apply` time.

### Sourcing Mechanism

Both directories use the same pattern:

```zsh
if [[ -d "${ZDOTDIR:-$HOME}/.zprofile.d" ]]; then
  for file in "${ZDOTDIR:-$HOME}/.zprofile.d"/*.sh(N); do
    source "$file"
  done
fi
```

The `(N)` glob qualifier ensures no error if the directory is empty. Files are sourced in alphabetical order, so numeric prefixes control load order.

## Numbering Convention

| Range   | Category           | Description                                    |
| ------- | ------------------ | ---------------------------------------------- |
| `00-09` | Base environment   | Locale, editor, PATH, history, pager, terminal |
| `10-19` | Package managers   | Homebrew                                       |
| `20-29` | Languages/runtimes | Go, Node.js/nvm, Rust, Whisper                 |
| `30-39` | Databases/services | MySQL                                          |
| `40-49` | Shell tools        | direnv, fzf, zoxide                            |
| `50-79` | (reserved)         | Available for future use                       |
| `80-89` | Cleanup/system     | Temp directory setup                           |
| `90-99` | Local overrides    | Source `~/.zshenv.local`                       |

## Files in `~/.zprofile.d/`

| File                    | Template | Guard                                  | Description                                                |
| ----------------------- | -------- | -------------------------------------- | ---------------------------------------------------------- |
| `00-locale.sh`          | No       | —                                      | Sets `LANG` and `LC_ALL` to `en_US.UTF-8`                  |
| `01-editor.sh`          | No       | —                                      | Sets `EDITOR` and `VISUAL` to `vim`                        |
| `02-path.sh`            | No       | —                                      | Adds `~/.local/bin` to PATH                                |
| `03-history.sh`         | No       | —                                      | Configures zsh history (32768 entries, ignore patterns)    |
| `04-pager.sh`           | No       | —                                      | Configures `less` as pager with sensible defaults          |
| `05-terminal.sh`        | No       | —                                      | Sets `TERM=xterm-256color`, key timeout, cheat colors      |
| `10-homebrew.sh.tmpl`   | Yes      | brew path exists                       | Initializes Homebrew shellenv, disables analytics          |
| `20-golang.sh.tmpl`     | Yes      | `.with_golang`                         | Sets `GOPATH=~/Developer`, adds `$GOPATH/bin` to PATH      |
| `21-javascript.sh.tmpl` | Yes      | `.with_javascript`                     | Loads nvm, auto-switches Node via `chpwd` hook on `.nvmrc` |
| `22-rust.sh.tmpl`       | Yes      | `.with_rust`                           | Adds `~/.cargo/bin` to PATH                                |
| `23-whisper.sh.tmpl`    | Yes      | `.is_apple_silicon` AND `.user_emmett` | Sets Metal acceleration path for whisper-cpp               |
| `30-mysql.sh`           | No       | —                                      | Configures MySQL prompt format                             |
| `40-direnv.sh`          | No       | —                                      | Hooks direnv into zsh                                      |
| `41-fzf.sh`             | No       | —                                      | Sets fzf default command to `rg --files --hidden`          |
| `42-zoxide.sh`          | No       | —                                      | Initializes zoxide for smart directory jumping             |
| `80-tmpdir.sh`          | No       | —                                      | Ensures `$TMPDIR` exists with 700 permissions              |
| `99-local.sh`           | No       | —                                      | Sources `~/.zshenv.local` if it exists                     |

## Files in `~/.zshenv.d/`

These files set environment variables that must be available in all shells, including non-interactive ones. They typically contain secrets injected from 1Password at `chezmoi apply` time. They follow the same numbering convention as `zprofile.d/`.

| File                        | Template | Guard             | Description                             |
| --------------------------- | -------- | ----------------- | --------------------------------------- |
| `40-eurosport-jira.sh.tmpl` | Yes      | (always rendered) | Sets `JIRA_API_TOKEN` from 1Password    |
| `41-things3.sh.tmpl`        | Yes      | (always rendered) | Sets `THINGS_AUTH_TOKEN` from 1Password |

## Template Guards

Template files (`.tmpl`) use chezmoi's Go template conditionals to produce an empty file when the guard is false. This means the file still exists but is empty and has no effect when sourced.

Example pattern:

```go
{{- if .with_golang }}
# Go
export GOPATH=$HOME/Developer
export PATH=$PATH:$GOPATH/bin
{{- end }}
```

If `.with_golang` is `false`, the rendered file is empty.

## Adding a New Drop-in File

1. Choose the appropriate directory (`zprofile.d` for login shell, `zshenv.d` for all shells)
2. Pick a numeric prefix in the correct range for the category
3. Create the file in `home/dot_zprofile.d/` or `home/dot_zshenv.d/`
4. Add `.tmpl` suffix if the file needs template variables
5. Wrap content in a guard if it should be conditional: `{{- if .with_feature }}...{{- end }}`
6. Run `chezmoi apply` to deploy
