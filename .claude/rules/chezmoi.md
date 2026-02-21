# Chezmoi conventions

## Repository structure

- Source directory: `home/` (defined in `.chezmoiroot`)
- Chezmoi version required: see `.chezmoiversion`

## File naming conventions

- `dot_` prefix → `.filename` (e.g., `dot_zshrc` → `~/.zshrc`)
- `private_` prefix → restricted permissions (600)
- `executable_` prefix → executable permission
- `empty_` prefix → creates empty file
- `.tmpl` suffix → Go template processed by chezmoi

## Shell drop-in directories (zprofile.d, zshenv.d)

Files are sourced in alphabetical order via `*.sh(N)` glob. Use numeric prefixes to control load order:

| Range   | Category           | Examples                          |
|---------|--------------------|-----------------------------------|
| `00-09` | Base environment   | locale, editor, path, history, pager, terminal |
| `10-19` | Package managers   | homebrew                          |
| `20-29` | Languages/runtimes | golang, javascript, rust, whisper |
| `30-39` | Databases/services | mysql                             |
| `40-49` | Shell tools        | direnv, fzf, zoxide              |
| `50-79` | (reserved)         |                                   |
| `80-89` | Cleanup/system     | tmpdir                            |
| `90-99` | Local overrides    | source ~/.zshenv.local            |

- Static files: `NN-name.sh`
- Templated files: `NN-name.sh.tmpl` (chezmoi renders, guards produce empty file if condition is false)

## Template variables

Available in `.tmpl` files via `{{ .variable }}`:

### OS & Architecture

- `.is_mac`, `.is_linux`, `.is_windows`, `.is_unix`
- `.is_apple_silicon` (ARM64 Macs)

### Device type (hostname-based)

- `.type_laptop`, `.type_desktop`, `.type_server`

### Users (hostname-based)

- `.user_veberarnaud` (human user, GUI apps)
- `.user_emmett` (AI agent, headless)

### Projects (hostname-based)

- `.project_personal`, `.project_eurosport`, `.project_mega_lap`, `.project_vbr_tech`

### Peripherals (hostname-based)

- `.has_elgato`, `.has_insta360`, `.has_scanner`

### Feature flags

- `.with_aws`, `.with_docker`, `.with_golang`, `.with_javascript`
- `.with_nomad`, `.with_php`, `.with_rust`, `.with_terraform`

## Scripts

Located in `home/.chezmoiscripts/`:

### Naming convention

- `run_before_` → runs before applying
- `run_after_` → runs after applying
- `run_onchange_` → runs only when content changes

### Required in scripts

```bash
set -euo pipefail
{{ template "common.tmpl" . }}
```

### Available functions from common.tmpl

- `log_info`, `log_success`, `log_warn`, `log_error`
- `check_command`, `require_command`
- `retry` (with exponential backoff)
- `is_mac`, `is_linux`
- `check_file`, `check_command_available`

## External dependencies

Defined in `home/.chezmoiexternal.toml`:

- Use `refreshPeriod = "720h"` (30 days) for non-pinned
- Pin versions for critical tools (tpm, vim-plug)

## Common commands

```bash
chezmoi diff              # Preview changes
chezmoi apply -v          # Apply with verbose
chezmoi cat ~/.file       # Show rendered template
chezmoi data              # Show template variables
chezmoi execute-template  # Debug templates
```
