# DMC host

The `dmc` host (`user_dmc`) runs the [DMC](https://github.com/dmc-ai/dmc) orchestrator instance. DMC's own documentation covers Linux and systemd (`docs/operations/deployment.md`, `maintenance.md`); this page is the macOS and chezmoi counterpart for this host.

The unattended boot it relies on (automatic restart, no sleep, automatic login, FileVault off, SSH) is described in the README, [Headless hosts](../README.md#headless-hosts-dmc-emmett).

## 1. What runs where

| What | Where | Managed by |
|---|---|---|
| Instance (`.env`, `data/data.db`) | `~/.local/share/dmc/` | by hand (state and the auth secret, never in the repository) |
| CLI `@dmc-ai/cli` | global npm package of the default nvm Node | `dot_nvm/default-packages.tmpl`, held back from `npm update -g` |
| Server: `dmcli start` | launch agent `pw.veber.dmc`, user session | `private_Library/private_LaunchAgents/pw.veber.dmc.plist.tmpl`, loaded by `run_onchange_after_dmc_agent` |
| Logs | `~/.local/share/dmc/logs/dmc.log` | written by launchd (`StandardOutPath`) |
| Log rotation | daily at 04:00, 14 archives `dmc.log.N.gz` | launch agent `pw.veber.dmc-logrotate` running `~/.local/bin/dmc-logrotate` |
| Project checkouts | `DMC_WORKDIR_ROOT` (`~/Developer/src/github.com`) | DMC (worktrees per run), cloned at project creation only |
| Network access | port `3001` (`PORT`), behind the LAN reverse proxy listed in `DMC_TRUSTED_PROXIES` | `.env`, and the proxy by hand |

A user agent rather than a daemon: Claude Code keeps its OAuth session in the login keychain, only available in the user session. The agent runs `dmcli` through a login shell (`zsh -l`) so nvm, Homebrew, `claude`, `codex` and `gh` are on `PATH`, outside tmux and with no TTY: an agent session reaching a tmux server that hosts `dmcli` can freeze it.

The log is copied then truncated, not renamed: launchd keeps it open in append mode and DMC never reopens it, so `newsyslog` would leave DMC writing to the rotated file.

## 2. Day-to-day

```bash
launchctl print gui/$(id -u)/pw.veber.dmc | rg 'state =|pid ='   # status
tail -f ~/.local/share/dmc/logs/dmc.log                         # logs (JSON, one line per request)
(cd ~/.local/share/dmc && dmcli doctor)                          # health check
launchctl kickstart -k gui/$(id -u)/pw.veber.dmc                 # restart (fails the runs in flight)
launchctl bootout gui/$(id -u)/pw.veber.dmc                      # stop until the next login
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/pw.veber.dmc.plist   # start again
```

A plain `kill` is not a stop: `KeepAlive` restarts DMC when it exits with an error.

## 3. Upgrading DMC

`dmcli upgrade` only replaces the global CLI (`npm install -g @dmc-ai/cli@latest`, after a confirmation): it does not stop DMC, and the database migrations run at the next start. No command rolls a migration back, so take a backup first. See DMC's `docs/operations/maintenance.md` §4.

1. Check that no run is in flight (web UI, or `get_stats` through the `dmc` MCP server): the restart fails every running run
2. Back up the database:

   ```bash
   sqlite3 ~/.local/share/dmc/data/data.db ".backup '$HOME/.local/share/dmc/data/backup-$(date +%Y%m%d%H%M%S).db'"
   ```

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

## 4. Rolling back an upgrade

1. Stop the agent: `launchctl bootout gui/$(id -u)/pw.veber.dmc`
2. Copy the backup over `data/data.db`, and remove `data/data.db-wal` and `data/data.db-shm`
3. Reinstall the previous version: `npm install -g @dmc-ai/cli@<version>`
4. Start the agent: `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/pw.veber.dmc.plist`

## 5. Moving the instance to another host

The new host gets the `user_dmc` flag in `home/.chezmoi.toml.tmpl`; `chezmoi apply` then installs the CLI and loads the agent, which waits for an instance.

1. On the new host, authenticate `claude`, `codex` and `gh` as the user that runs DMC, and check SSH access to GitHub (`ssh -T git@github.com`): the checkouts use SSH remotes
2. On the old host, export the configuration as a readable backup (`export_config`), check that no run is in flight, then stop DMC
3. Copy a consistent backup of the database and the `.env`, nothing else:

   ```bash
   sqlite3 data/data.db ".backup '/tmp/data.db'"   # on the old host, DMC stopped
   ```

   - Into `~/.local/share/dmc/` on the new host: `data/data.db` and `.env`, then `chmod 600 .env data/data.db`
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
