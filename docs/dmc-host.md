# DMC host

The `dmc` host (`user_dmc`) runs the [DMC](https://github.com/dmc-ai/dmc) orchestrator instance. DMC's own documentation covers Linux and systemd (`docs/operations/deployment.md`, `maintenance.md`); this page is the macOS and chezmoi counterpart for this host.

The unattended boot it relies on (automatic restart, no sleep, automatic login, FileVault off, SSH) is described in the README, [Headless hosts](../README.md#headless-hosts-dmc-emmett).

## 1. What runs where

| What | Where | Managed by |
|---|---|---|
| Instance (`.env`, `data/data.db`) | `~/.local/share/dmc/` | by hand (state and the auth secret, never in the repository); a copy of `.env` in 1Password, `op://Personal/DMC/Instance/env` |
| CLI `@dmc-ai/cli` | global npm package of the default nvm Node | `dot_nvm/default-packages.tmpl`, held back from `npm update -g` |
| Server: `dmcli start` | launch agent `pw.veber.dmc`, user session | `private_Library/private_LaunchAgents/pw.veber.dmc.plist.tmpl`, loaded by `run_onchange_after_dmc_agent` |
| Logs | `~/.local/share/dmc/logs/dmc.log` | written by launchd (`StandardOutPath`) |
| Log rotation | daily at 04:00, 14 archives `dmc.log.N.gz` | launch agent `pw.veber.dmc-logrotate` running `~/.local/bin/dmc-logrotate` |
| Database backups | daily at 03:30, 7 copies `~/.local/share/dmc/backups/data-<date>.db.gz` | launch agent `pw.veber.dmc-backup` running `~/.local/bin/dmc-backup` |
| Project checkouts | `DMC_WORKDIR_ROOT` (`~/Developer/src/github.com`) | DMC (worktrees per run), cloned at project creation only |
| Network access | port `3001` (`PORT`), behind the LAN reverse proxy listed in `DMC_TRUSTED_PROXIES` | `.env`, and the proxy by hand |

A user agent rather than a daemon: Claude Code keeps its OAuth session in the login keychain, only available in the user session. The agent runs `dmcli` through a login shell (`zsh -l`) so nvm, Homebrew, `claude`, `codex` and `gh` are on `PATH`, outside tmux and with no TTY: an agent session reaching a tmux server that hosts `dmcli` can freeze it.

The backup is a `sqlite3 .backup` copy, consistent while DMC keeps writing, kept only if it passes `pragma integrity_check`, switched to a rollback journal so the archive is self-contained, then gzipped (about a quarter of the database size). The copies stay on the host: they cover a failed upgrade, a corrupted database or a mistake, not the loss of the disk.

The `.env` holds `BETTER_AUTH_SECRET`, which encrypts the secrets stored in DMC and signs its sessions and API keys: a database restored without it loses every stored secret and API key. Its copy lives in 1Password, attached to the `DMC` item (section `Instance`, file `env`), the off-host backup of the instance configuration:

```bash
op read --force --out-file "$HOME/.local/share/dmc/.env" "op://Personal/DMC/Instance/env"   # restore (written as 600)
op item edit DMC --vault Personal "Instance.env[file]=$HOME/.local/share/dmc/.env"            # update after editing .env
```

The log is copied then truncated, not renamed: launchd keeps it open in append mode and DMC never reopens it, so `newsyslog` would leave DMC writing to the rotated file.

## 2. Day-to-day

```bash
launchctl print gui/$(id -u)/pw.veber.dmc | rg 'state =|pid ='   # status
tail -f ~/.local/share/dmc/logs/dmc.log                         # logs (JSON, one line per request)
(cd ~/.local/share/dmc && dmcli doctor)                          # health check
dmc-backup                                                       # back up the database now (prints the archive)
tail ~/.local/share/dmc/logs/backup.log                          # last scheduled backups
launchctl kickstart -k gui/$(id -u)/pw.veber.dmc                 # restart (fails the runs in flight)
launchctl bootout gui/$(id -u)/pw.veber.dmc                      # stop until the next login
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/pw.veber.dmc.plist   # start again
```

A plain `kill` is not a stop: `KeepAlive` restarts DMC when it exits with an error.

## 3. Upgrading DMC

`dmcli upgrade` only replaces the global CLI (`npm install -g @dmc-ai/cli@latest`, after a confirmation): it does not stop DMC, and the database migrations run at the next start. No command rolls a migration back, so take a backup first. See DMC's `docs/operations/maintenance.md` §4.

1. Check that no run is in flight (web UI, or `get_stats` through the `dmc` MCP server): the restart fails every running run
2. Back up the database: `dmc-backup`, and note the archive it prints
3. Upgrade the CLI and note the previous version it prints: `dmcli upgrade`
4. Check the auth stack before restarting, a single `@better-auth/core` version is expected (dmc-ai/dmc#479):

   ```bash
   (cd "$(npm root -g)/@dmc-ai/cli" && npm ls better-auth @better-auth/core)
   ```

5. Restart DMC, which applies the migrations, then check it:

   ```bash
   launchctl kickstart -k gui/$(id -u)/pw.veber.dmc
   tail -f ~/.local/share/dmc/logs/dmc.log   # "API server running"
   (cd ~/.local/share/dmc && dmcli doctor)
   ```

## 4. Restoring a backup

Every run, session and configuration change since the backup is lost.

1. Check that no run is in flight, then stop the agent: `launchctl bootout gui/$(id -u)/pw.veber.dmc`
2. Keep the current database aside, then restore the archive:

   ```bash
   cd ~/.local/share/dmc/data
   mv data.db "data.db.replaced-$(date +%Y%m%d-%H%M%S)"
   rm -f data.db-wal data.db-shm
   gzcat ../backups/data-<date>.db.gz > data.db && chmod 600 data.db
   ```

3. If `.env` is lost too, restore it from 1Password (see §1): the archive is useless without its `BETTER_AUTH_SECRET`
4. Start the agent: `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/pw.veber.dmc.plist`, then check the log and `dmcli doctor`

To roll back an upgrade, restore the backup taken before it and reinstall the previous version (`npm install -g @dmc-ai/cli@<version>`) before step 4.

## 5. Moving the instance to another host

The new host gets the `user_dmc` flag in `home/.chezmoi.toml.tmpl`; `chezmoi apply` then installs the CLI and loads the agent, which waits for an instance.

1. On the new host, authenticate `claude`, `codex` and `gh` as the user that runs DMC, and check SSH access to GitHub (`ssh -T git@github.com`): the checkouts use SSH remotes
2. On the old host, export the configuration as a readable backup (`export_config`), check that no run is in flight, then stop DMC
3. Copy a consistent backup of the database and the `.env`, nothing else:

   ```bash
   sqlite3 data/data.db ".backup '/tmp/data.db'"   # on the old host, DMC stopped
   ```

   - Into `~/.local/share/dmc/` on the new host: `data/data.db` and `.env` (or restore it from 1Password, see §1), then `chmod 600 .env data/data.db`
   - Not `dmc.yaml` (no longer read by DMC), nor a `.nvmrc` (it would switch Node away from the version the CLI is installed under)
   - Remove `CONFIG_PATH` and `DATABASE_PATH` from `.env`: both are ignored by current DMC
4. Clone the missing project checkouts. DMC clones a project only when it is created or imported, never at run time, so a run on a missing checkout fails:

   ```bash
   sqlite3 ~/.local/share/dmc/data/data.db \
     "select key || ' ' || json_extract(definition, '\$.path') from managed_projects" |
     while read -r key path; do [[ -e "${path}/.git" ]] || gh repo clone "${key}" "${path}"; done
   ```

5. Start DMC: `launchctl kickstart gui/$(id -u)/pw.veber.dmc`. At boot it recomputes the project paths from `DMC_WORKDIR_ROOT`
6. Test before switching the proxy:
   - API key: `curl -H "x-api-key: $(cat ~/.config/dmc/api-key)" http://127.0.0.1:3001/api/adapters` returns `200`
   - Web sign-in through a tunnel, from another machine: `ssh -N -L 5173:localhost:3001 <host>`, then `http://localhost:5173` (an origin of `WEB_URLS`)
7. Point the reverse proxy at the new host (`DMC_TRUSTED_PROXIES` does not change while the proxy stays the same), then check the public URL and the `dmc` MCP server
8. On the old host, rename the instance `.env` (for instance to `.env.disabled`) so it cannot start again

Never run two instances from copies of the same database at the same time: both schedule the same cron triggers and resume the same queue, so every run happens twice (commits, PRs, comments).

## 6. DMC menu bar app (human hosts)

The macOS menu bar app (`DMC.app`, bundle id `ai.dmc.menubar`) is installed and updated on the `user_veberarnaud` Apple Silicon Macs by `system/darwin/run_onchange_after_dmc_app.sh.tmpl`. The version and the SHA-256 of the release zip are pinned in `home/.chezmoidata/dmc.toml` (`dmc.app.version`, `dmc.app.sha256`).

### What the script does

- Writes the instance URL (`defaults write ai.dmc.menubar baseURL`), read from `op://Personal/DMC/website` at run time, never stored in the repository. Without `op`, or when it is not signed in, the step is skipped with a warning. This runs on every apply and re-asserts the pinned URL: see the note below
- Exits if `/Applications/DMC.app` is already at the pinned version
- Without `gh`, or with `gh` not authenticated, prints a warning (run `gh auth login`, then `chezmoi apply`) and exits 0: it never fails `chezmoi apply`
- If a previous run was interrupted between staging and swapping the app, leaving only `/Applications/.DMC.app.old` and no `DMC.app`, restores it first so a failure can never leave the host without an app
- Downloads `DMC-<version>-macOS-arm64.zip` from the private release `v<version>` of `dmc-ai/dmc` into a temporary directory, checks its SHA-256 (a mismatch aborts and leaves the installed app untouched) and unpacks it with `ditto`
- Quits the running app (`osascript`, up to 15 s), copies the new bundle next to the old one, swaps them with a rename (the old one is put back and relaunched on failure), clears the quarantine flag and relaunches the app if it was running
- While the app is not at the pinned version the script is stamped with the time, so it runs again on every `chezmoi apply` (a failed download or checksum is retried)
- `run_onchange_after_autostart.sh.tmpl` adds `/Applications/DMC.app` to the login items, matching by path rather than by name: a login item left over from a manual install elsewhere (for example `~/Downloads/DMC.app`) is replaced rather than mistaken for the real one. It runs before the install: on a first apply the app is missing, so run `chezmoi apply` a second time to register it

### First steps on each host

1. `gh auth login` with an account that can read `dmc-ai/dmc`, and `op` signed in (`eval $(op signin)`)
2. `chezmoi apply`; allow the terminal to control System Events when asked (login item). If refused, add the app in System Settings > General > Login Items
3. Open the app, Settings, paste the API key (scope `operate`) once. It is kept in the Keychain and survives updates
4. Click **Always Allow** when macOS asks for Keychain access

Note: the script re-asserts `baseURL` from 1Password on every apply, so pointing the app at a different instance by hand (for a test, for example) is reverted on the next `chezmoi apply`.

### Migrating from a manual install

If the app was previously installed by hand elsewhere (for example `~/Downloads/DMC.app`), its login item is replaced automatically by `run_onchange_after_autostart.sh.tmpl` (see above). Once `/Applications/DMC.app` is in place, delete the old copy by hand; the script never does this for you.

### Out of scope

The script never touches the Keychain or the API key: seeding the Keychain from the command line makes an ad-hoc signed app hang on an invisible prompt. The bundle is ad-hoc signed, so its signature changes with every release and macOS asks for Keychain access once after each update: click Always Allow.

### Moving to a new release

1. Download `DMC-<version>-macOS-arm64.zip` from the GitHub release `v<version>` of `dmc-ai/dmc`
2. `shasum -a 256 DMC-<version>-macOS-arm64.zip`
3. Set `version` and `sha256` in `home/.chezmoidata/dmc.toml`
4. After the merge, `chezmoi apply` on each host

`tests/dmc-app.sh` exercises the install script offline (stubbed `gh`, `op`, `osascript`, a temporary `/Applications`): run it after changing the script.
