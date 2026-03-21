# ~/.dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/).

## Features

- 🔐 Automated SSH & GPG key provisioning from 1Password
- 🎨 Modern shell with Starship prompt, zoxide, ripgrep, delta
- 📦 Homebrew package management with conditional installs
- 🔧 Per-machine configuration via feature flags
- ✅ CI validation of all templates

## Quick Start (New Machine)

### 1. Set hostname

```bash
export NAME="VEBERArnaud-MacBookPro2024"  # Choose a name
sudo scutil --set ComputerName "${NAME}"
sudo scutil --set LocalHostName "${NAME}"
sudo scutil --set HostName "${NAME}"
```

### 2. Install prerequisites

```bash
# Command Line Developer Tools
/usr/bin/xcode-select --install

# Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# chezmoi
brew install chezmoi
```

### 3. Setup 1Password CLI

```bash
brew install --cask 1password-cli
op account add
eval $(op signin)
```

### 4. Install dotfiles

```bash
chezmoi init --apply veberarnaud
```

### 5. Change shell to zsh

```bash
which zsh | sudo tee -a /etc/shells
chsh -s $(which zsh)
```

## Identity Model

The repository uses a multi-dimensional identity model based on hostname. Each hostname maps to a combination of layers that determine what gets installed and configured.

### Layer 1: Device Type

| Hostname                   | laptop | desktop | server |
| -------------------------- | :----: | :-----: | :----: |
| VEBERArnaud-MacBookPro2012 |   ✓    |         |        |
| VEBERArnaud-MacBookPro2017 |   ✓    |         |        |
| VEBERArnaud-MacMini2020    |        |    ✓    |        |
| VEBERArnaud-MacBookPro2023 |   ✓    |         |        |
| VEBERArnaud-MacMini2023    |        |    ✓    |        |
| VEBERArnaud-MacMini2023s   |        |    ✓    |        |

### Layer 2: User

| Hostname                   | veberarnaud | emmett |
| -------------------------- | :---------: | :----: |
| VEBERArnaud-MacBookPro2012 |      ✓      |        |
| VEBERArnaud-MacBookPro2017 |      ✓      |        |
| VEBERArnaud-MacMini2020    |      ✓      |        |
| VEBERArnaud-MacBookPro2023 |      ✓      |        |
| VEBERArnaud-MacMini2023    |             |   ✓    |
| VEBERArnaud-MacMini2023s   |      ✓      |        |

- `veberarnaud` — human user (GUI apps, personal tools)
- `emmett` — AI agent (headless, no GUI)

### Layer 3: Projects

| Hostname                   | personal | vbr_tech | eurosport | mega_lap |
| -------------------------- | :------: | :------: | :-------: | :------: |
| VEBERArnaud-MacBookPro2012 |    ✓     |          |           |          |
| VEBERArnaud-MacBookPro2017 |    ✓     |          |           |          |
| VEBERArnaud-MacMini2020    |    ✓     |          |           |          |
| VEBERArnaud-MacBookPro2023 |    ✓     |    ✓     |     ✓     |    ✓     |
| VEBERArnaud-MacMini2023    |          |          |           |          |
| VEBERArnaud-MacMini2023s   |    ✓     |    ✓     |     ✓     |    ✓     |

### Layer 4: Peripherals

| Hostname                   | elgato | insta360 | scanner |
| -------------------------- | :----: | :------: | :-----: |
| VEBERArnaud-MacMini2023s   |   ✓    |    ✓     |    ✓    |

### Layer 5: Tools (derived from projects)

Projects determine which development tools are installed. `VEBERArnaud-MacMini2023` is a special case — it has `with_javascript` set directly (no project).

| Project   | AWS | Docker | Go  | JS  | Nomad | PHP | Rust | Terraform |
| --------- | :-: | :----: | :-: | :-: | :---: | :-: | :--: | :-------: |
| personal  |  ✓  |   ✓    |  ✓  |  ✓  |   ✓   |  ✓  |  ✓   |     ✓     |
| vbr_tech  |  ✓  |   ✓    |     |  ✓  |       |     |      |     ✓     |
| eurosport |  ✓  |   ✓    |     |  ✓  |       |     |      |     ✓     |
| mega_lap  |  ✓  |   ✓    |     |  ✓  |       |     |      |     ✓     |

Configuration is defined in [`home/.chezmoi.toml.tmpl`](home/.chezmoi.toml.tmpl).

## Repository Structure

```
.
├── home/                          # chezmoi source directory
│   ├── .chezmoi.toml.tmpl         # Configuration & feature flags
│   ├── .chezmoiexternal.toml      # External dependencies (zprezto, etc.)
│   ├── .chezmoiignore             # Files to ignore per environment
│   ├── .chezmoiscripts/           # Scripts run during apply
│   │   ├── system/darwin/          # macOS-specific scripts
│   │   └── run_after_*.sh.tmpl    # Post-apply scripts
│   ├── dot_ssh/                   # SSH configuration
│   ├── dot_config/                # ~/.config files
│   └── dot_*                      # Other dotfiles
├── .github/workflows/             # CI validation
└── README.md
```

### Naming conventions

| Prefix          | Description                           |
| --------------- | ------------------------------------- |
| `dot_`          | Maps to `.filename` in home directory |
| `private_`      | File with 600 permissions             |
| `empty_`        | Creates empty file if not exists      |
| `.tmpl`         | Go template, processed by chezmoi     |
| `run_before_`   | Script runs before applying files     |
| `run_after_`    | Script runs after applying files      |
| `run_onchange_` | Script runs when content changes      |

## Adding a New Machine

1. Choose a hostname following the pattern `VEBERArnaud-{Model}{Year}`

2. Add the hostname to [`home/.chezmoi.toml.tmpl`](home/.chezmoi.toml.tmpl):

   ```go
   {{- if eq .chezmoi.hostname "VEBERArnaud-NewMachine" -}}
   {{-   $project_personal = true -}}
   {{- end -}}
   ```

3. Add the hostname to [`home/.chezmoiignore`](home/.chezmoiignore) (for 1Password integration):

   ```go
   {{- $knownHosts := list
       ...
       "VEBERArnaud-NewMachine"
   -}}
   ```

4. Create SSH key in 1Password named `SSHKey VEBERArnaud-NewMachine`

5. Run `chezmoi init --apply veberarnaud` on the new machine

## Local Overrides

Several configuration files support local overrides that are not tracked in git:

| File            | Local Override        | Purpose                       |
| --------------- | --------------------- | ----------------------------- |
| `~/.zshrc`      | `~/.zshrc.local`      | Machine-specific shell config |
| `~/.gitconfig`  | `~/.gitconfig.local`  | Machine-specific git config   |
| `~/.aliases`    | `~/.aliases.local`    | Machine-specific aliases      |
| `~/.ssh/config` | `~/.ssh/config.local` | Private SSH hosts             |

## Development Workflow

For active development, symlink chezmoi's source directory to your working copy:

```bash
rm -rf ~/.local/share/chezmoi
ln -s /path/to/your/dotfiles ~/.local/share/chezmoi
```

Then use `chezmoi apply` to apply local changes immediately.

## Updating

To pull changes from remote:

```bash
chezmoi update
```

## License

MIT
