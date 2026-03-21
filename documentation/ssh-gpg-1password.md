# SSH & GPG with 1Password

SSH keys and GPG keys are managed through 1Password, avoiding manual key distribution across machines.

## SSH Configuration

The SSH config is deployed from `home/dot_ssh/config.tmpl` to `~/.ssh/config`.

### Host-Specific Settings

Ed25519 keys are configured for SCM providers:

| Host            | Key                 | Keychain | AddKeysToAgent |
| --------------- | ------------------- | -------- | -------------- |
| `github.com`    | `~/.ssh/id_ed25519` | Yes      | Yes            |
| `gitlab.com`    | `~/.ssh/id_ed25519` | Yes      | Yes            |
| `bitbucket.org` | `~/.ssh/id_ed25519` | Yes      | Yes            |

### Global Settings (`Host *`)

| Setting               | Value               | Description                                |
| --------------------- | ------------------- | ------------------------------------------ |
| `AddKeysToAgent`      | `yes`               | Auto-add keys to ssh-agent on first use    |
| `UseKeychain`         | `yes`               | Store passphrases in macOS Keychain        |
| `ServerAliveInterval` | `300`               | Send keepalive every 5 minutes             |
| `ServerAliveCountMax` | `2`                 | Disconnect after 2 missed keepalives       |
| `ControlMaster`       | `auto`              | Reuse existing connections                 |
| `ControlPath`         | `~/.ssh/control-%C` | Socket path for multiplexed connections    |
| `ControlPersist`      | `10m`               | Keep master connection open for 10 minutes |
| `HashKnownHosts`      | `yes`               | Hash hostnames in known_hosts for privacy  |

### Connection Pooling

SSH connection multiplexing is enabled via `ControlMaster auto`. The first connection to a host opens a master socket at `~/.ssh/control-%C` (where `%C` is a hash of host/port/user). Subsequent connections reuse this socket, avoiding repeated authentication. The master persists for 10 minutes after the last connection closes.

### Local Overrides

The config starts with `Include config.local`, allowing machine-specific SSH hosts in `~/.ssh/config.local` (not tracked in git). This file is loaded first, so its settings take precedence.

## GPG Key Import

The GPG key is automatically imported from 1Password by `home/.chezmoiscripts/security/run_after_gpg_import.sh.tmpl`.

### Process

1. Checks if 1Password CLI (`op`) is available
2. Checks if signed in to 1Password (`op whoami`)
3. Checks if key `7D934C83` is already imported (skips if so)
4. Downloads the GPG key document from 1Password: `op document get GPG`
5. Imports via `gpg --import`
6. Sets ultimate trust on the key via `gpg --import-ownertrust`

### Requirements

- 1Password CLI installed (`brew install --cask 1password-cli`)
- Signed in to 1Password (`op signin`)
- GPG key stored as a document named "GPG" in 1Password

### Idempotent

The script is safe to run multiple times — it skips import if the key is already present in the local GPG keyring.

## Adding a New Machine

1. Create an Ed25519 SSH key in 1Password named `SSHKey <hostname>`
2. Deploy the key to `~/.ssh/id_ed25519` (handled by chezmoi)
3. Run `chezmoi apply` — the GPG key is auto-imported, SSH config is deployed
4. First SSH connection to a host will prompt to add the key to the agent and keychain
