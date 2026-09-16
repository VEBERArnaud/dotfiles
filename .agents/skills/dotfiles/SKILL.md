---
name: dotfiles
description: Manage dotfiles with chezmoi
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

# Dotfiles Management

Manage this dotfiles repository with chezmoi.

## Repository structure

```
dotfiles/
├── .chezmoiroot          # Points to "home" as source
├── .chezmoiversion       # Minimum chezmoi version
└── home/                 # Source directory
    ├── .chezmoi.toml.tmpl        # Config with template vars
    ├── .chezmoiexternal.toml     # External dependencies
    ├── .chezmoitemplates/        # Reusable templates
    │   └── common.tmpl           # Logging, utilities
    ├── .chezmoiscripts/          # Automation scripts
    │   ├── packages/             # Homebrew, Node.js, Rust
    │   ├── editors/              # VS Code, Vim plugins
    │   ├── security/             # GPG import
    │   ├── system/darwin/        # macOS settings
    │   ├── tools/                # Claude MCP, etc.
    │   └── verify/               # Post-deploy checks
    ├── dot_config/               # ~/.config/ files
    └── [other dotfiles]
```

## Common operations

### Preview changes

```bash
chezmoi diff
```

### Apply changes

```bash
chezmoi apply -v
```

### Add a file to chezmoi

```bash
chezmoi add ~/.newfile
```

### View rendered template

```bash
chezmoi cat ~/.zshrc
```

### Check available template data

```bash
chezmoi data
```

### Force refresh externals

```bash
chezmoi apply --refresh-externals
```

## Creating new scripts

1. Create in appropriate directory under `home/.chezmoiscripts/`
2. Use naming convention: `run_[before|after|onchange]_category_name.sh.tmpl`
3. Include required header:
   ```bash
   {{- if .is_mac -}}
   #!/bin/bash
   set -euo pipefail
   {{ template "common.tmpl" . }}
   # ... script content
   {{- end -}}
   ```

## Template debugging

```bash
chezmoi execute-template '{{ .is_mac }}'
chezmoi execute-template '{{ .with_docker }}'
```
