# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal dotfiles repository managed by [chezmoi](https://www.chezmoi.io/) (v2.24.0+), a dotfile manager that uses Go templating to handle multiple machines with different configurations. The repository configures a complete development environment for macOS, including shell (zsh with Prezto), editor (vim with vim-plug), terminal (Ghostty), terminal multiplexer (tmux), and various development tools.

## Repository Structure

```
dotfiles/
├── .chezmoiroot              # Points to "home" as source directory
├── .chezmoiversion           # Requires chezmoi 2.24.0+
├── .github/workflows/        # CI validation (shellcheck, templates, linting)
├── .claude/                  # Project-scoped Claude Code config
│   ├── rules/chezmoi.md      # Chezmoi conventions for this repo
│   └── skills/               # Project-specific skills
│       ├── dotfiles/         # /dotfiles skill
│       └── brew-add/         # /brew-add skill
└── home/                     # Source directory for all dotfiles
    ├── .chezmoi.toml.tmpl            # Main config with feature flags
    ├── .chezmoiexternal.toml         # External dependencies (zprezto, tpm, vim-plug)
    ├── .chezmoiscripts/              # Automation scripts
    │   ├── packages/                 # Package installation
    │   ├── mac/                      # macOS-specific scripts
    │   └── tools/                    # Tool configuration (Claude MCP, etc.)
    ├── dot_claude/                   # Global Claude Code config (~/.claude/)
    │   ├── CLAUDE.md.tmpl            # User preferences (language, tools, stack)
    │   ├── settings.json             # Permissions and hooks
    │   ├── rules/                    # Modular instructions
    │   │   ├── git.md                # Git conventions
    │   │   ├── shell.md              # Shell scripting conventions
    │   │   └── security.md           # Security rules
    │   └── skills/                   # Global custom skills
    │       ├── changelog/            # /changelog skill
    │       ├── commit-conventional/  # /commit-conventional skill
    │       └── review/               # /review skill
    ├── dot_config/                   # ~/.config/ files
    │   ├── ghostty/config            # Ghostty terminal configuration
    │   └── starship.toml             # Starship prompt configuration
    ├── dot_ssh/                      # SSH config with 1Password integration
    └── [dotfiles...]                 # Shell, vim, tmux, git configurations
```

### Chezmoi File Naming Conventions

- `dot_` prefix → `.filename` (e.g., `dot_zshrc` → `~/.zshrc`)
- `empty_` prefix → creates empty file
- `.tmpl` suffix → Go template processed by chezmoi
- `private_` prefix → file with restricted permissions (600)
- `executable_` prefix → file with execute permission

## Template Variables

The configuration uses Go templates with variables defined in `.chezmoi.toml.tmpl`:

### OS/Architecture Flags

- `is_mac`, `is_linux`, `is_windows`, `is_unix`
- `is_apple_silicon` - True for ARM64 Macs

### Device Type Flags (hostname-based)

- `type_laptop` - Portable machines (MacBook Pro, MacBook Air)
- `type_desktop` - Stationary machines (Mac mini, iMac, Mac Studio, Mac Pro)
- `type_server` - Server machines (headless)

### Project Flags (hostname-based)

- `project_personal` - Personal machines
- `project_eurosport` - Eurosport work machines
- `project_mega_lap` - Mega Lap project machines
- `project_vbr_tech` - VBR Tech project machines

### Feature Flags (conditional installation)

- `with_aws` - AWS CLI and tools
- `with_docker` - Docker and related tools
- `with_golang` - Go development environment
- `with_javascript` - Node.js via nvm
- `with_php` - PHP development tools
- `with_rust` - Rust development environment
- `with_terraform` - Terraform infrastructure tools

## Key Components

### Shell Environment

- **zsh** with Prezto framework
- **Starship** prompt (modern, fast, cross-shell)
- **zoxide** for smart directory jumping (replaces z)
- **direnv** for per-directory environment variables
- **fzf** with ripgrep integration for fuzzy finding

### Terminal & Editor

- **Ghostty** terminal emulator (fast, modern)
- **vim** with vim-plug and 30+ plugins
- **tmux** with TPM (Tmux Plugin Manager)
- **delta** for enhanced git diffs

### Security & SSH

- SSH keys managed via **1Password** (Ed25519)
- GPG key auto-imported from 1Password
- Global SSH config with connection pooling
- Support for local overrides (`~/.ssh/config.local`)

### Claude Code Configuration

Global user config deployed to `~/.claude/`:

- **CLAUDE.md.tmpl** - User preferences (French responses, English code, preferred tools)
- **settings.json** - Hardened permissions (minimal allow list) and Stop hook for notifications
- **rules/** - Modular instructions for git, shell, and security conventions
- **skills/** - Custom slash commands (`/changelog`, `/commit-conventional`, `/review`)

MCP servers configured via `run_onchange_after_claude_mcp.sh.tmpl`:
- **chrome-devtools** - Browser automation
- **context7** - Up-to-date library documentation (API key from 1Password)

## Scripts

### Pre-apply (`run_before_`)

- **`packages/run_before_darwin_homebrew.sh.tmpl`** - Installs Homebrew packages
  - Packages defined inline as Go template lists (no separate Brewfile)
  - Conditional packages based on feature flags
  - Node.js LTS versions via nvm

### Post-apply (`run_after_`)

- **`run_after_install_vim_plugins.sh.tmpl`** - Installs vim-plug plugins, generates tmuxline
- **`run_after_import-gpg-key.sh.tmpl`** - Imports GPG key from 1Password
- **`run_after_verify.sh.tmpl`** - Validates deployment (files exist, commands work, syntax valid)

### On-change (`run_onchange_`)

- **`mac/run_onchange_after_configure_macos.sh.tmpl`** - macOS system preferences
- **`tools/run_onchange_after_claude_mcp.sh.tmpl`** - Claude Code MCP servers

## Common Commands

```bash
# Preview changes without applying
chezmoi diff

# Apply all changes
chezmoi apply

# Apply with verbose output
chezmoi apply -v

# Force re-run all scripts and refresh externals
chezmoi apply --force --refresh-externals

# Preview rendered template
chezmoi cat ~/.zprofile

# Check available template data
chezmoi data

# Edit and apply immediately
chezmoi edit --apply ~/.zshrc

# Add new file to chezmoi
chezmoi add ~/.newfile

# Debug template rendering
chezmoi execute-template '{{ .is_mac }}'
```

## Local Overrides

Machine-specific configurations that are not tracked in git:

- `~/.zshrc.local` - Shell customizations
- `~/.zshenv.local` - Environment variables
- `~/.aliases.local` - Custom aliases
- `~/.gitconfig.local` - Git settings
- `~/.ssh/config.local` - Private SSH hosts

## External Dependencies

Managed via `.chezmoiexternal.toml` with 168h (7 day) refresh:

- **zprezto** - Zsh framework
- **tpm** - Tmux Plugin Manager
- **vim-plug** - Vim plugin manager

## CI/CD

GitHub Actions workflow validates on every push:

- Template rendering (all `.tmpl` files)
- ShellCheck for all shell scripts
- TOML validation (taplo)
- YAML validation (yamllint)
- Vimscript validation (vim-vint)

## Adding New Packages

1. Edit `home/.chezmoiscripts/packages/run_before_darwin_homebrew.sh.tmpl`
2. Add to appropriate list: `$brews`, `$casks`, or conditional blocks
3. Run `chezmoi apply` to install

## Initial Setup

```bash
# Set computer name
export NAME="<hostname>"
sudo scutil --set ComputerName "${NAME}"
sudo scutil --set LocalHostName "${NAME}"
sudo scutil --set HostName "${NAME}"

# Install Xcode CLI tools
xcode-select --install

# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install chezmoi
brew install chezmoi

# Setup 1Password CLI (required for SSH/GPG keys and Claude MCP API keys)
brew install --cask 1password-cli
op account add
eval $(op signin)

# Apply dotfiles
chezmoi init --apply veberarnaud

# Set zsh as default shell
which zsh | sudo tee -a /etc/shells
chsh -s $(which zsh)
```

## Important Notes

- Source directory is `home/` (not repo root) as specified in `.chezmoiroot`
- Requires chezmoi 2.24.0+ (specified in `.chezmoiversion`)
- 1Password CLI is required for SSH keys, GPG key import, and Claude MCP API keys
- Scripts with `run_onchange_` prefix only re-run when their content changes
- Post-apply verification script checks critical files and commands
- Claude Code global config (`~/.claude/`) is deployed via `home/dot_claude/`
- Project-scoped Claude config (`.claude/`) contains repo-specific rules and skills
