# repo-sweep Safe Local Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let repo-sweep propose lossless local cleanup of pushed-but-unmerged branches/worktrees by default, and gate lossy deletions (dirty worktrees, unpushed commits) behind an explicit y/N confirmation.

**Architecture:** Single bash script change (`home/dot_local/bin/executable_repo-sweep`). Status detection is extracted into a shared `branch_status()` helper producing five statuses (`DIRTY`, `GONE`, `MERGED`, `PUSHED`, `UNPUSHED`; `ACTIVE` disappears). The candidate line gains a 6th tab-field carrying the status so the deletion phase can partition the selection into safe vs risky items and prompt before deleting risky ones.

**Tech Stack:** bash, git, fzf (0.74 installed; boundary-match query needs ≥ 0.44), existing `wt-remove` helper. Tested via disposable fixture repos and a fake `fzf` test double — no test framework.

**Spec:** `docs/superpowers/specs/2026-08-05-repo-sweep-safe-cleanup-design.md`

## Global Constraints

- Only file modified: `home/dot_local/bin/executable_repo-sweep`. No new repo files besides this plan and the spec.
- Bash conventions (user rules): `set -euo pipefail` (already present), quote all variables `"${var}"`, 4-space indent, lowercase variable names, `local` in functions.
- ShellCheck must stay clean: `shellcheck home/dot_local/bin/executable_repo-sweep` → no output, exit 0.
- Status names, exact: `DIRTY`, `GONE`, `MERGED`, `PUSHED`, `UNPUSHED`. Check order: DIRTY → GONE → MERGED → PUSHED → UNPUSHED.
- Candidate line format, exact (6 tab-separated fields; `_` sentinel on wt_path because tab-IFS collapses empty fields): `<display>\t<type>\t<branch>\t<repo>\t_<wt_path>\t<status>`
- fzf prefilled query, exact: `'GONE' | 'MERGED' | 'PUSHED'` (boundary-quoted so `PUSHED` does not substring-match `UNPUSHED`).
- Commits: conventional format `type(scope): subject`, GPG-signed (automatic via git config), on branch `feature/repo-sweep-safe-cleanup` (already checked out).
- **NEVER run the modified script against the real base dir** (`~/Developer/src/github.com`) during implementation: phase 5 checks out `main` in every repo, including this dotfiles repo — it would yank the working branch out from under you. Always set `REPO_SWEEP_BASE` to the fixture dir.
- Test fixture root: `TESTDIR=/private/tmp/claude-501/-Users-veberarnaud-Developer-src-github-com-VEBERArnaud-dotfiles/125edcfe-6ca9-4804-abe6-49515226e85e/scratchpad/repo-sweep-test` — export this in every shell you use for testing.
- All test invocations run from the repo root: `/Users/veberarnaud/Developer/src/github.com/VEBERArnaud/dotfiles`.

---

### Task 1: `branch_status()` helper, five statuses, 6-field candidate lines

**Files:**
- Modify: `home/dot_local/bin/executable_repo-sweep` (header comment lines 7-8, new helper after `merge_ref()` ~line 78, worktree block lines 149-161, branch block lines 168-185, phase-6 read line 263)
- Test: fixture setup script (created in this task, reused by all tasks)

**Interfaces:**
- Produces: `branch_status <repo> <branch> <cmp_ref>` → echoes one of `GONE|MERGED|PUSHED|UNPUSHED`; candidate lines in the 6-field format from Global Constraints. Task 3 reads the 6th field.
- Consumes: existing `default_branch()`, `merge_ref()` helpers (unchanged).

- [ ] **Step 1: Create the fixture setup script + fake fzf test double**

Write this file to `${TESTDIR%/*}/repo-sweep-setup.sh` (i.e. `.../scratchpad/repo-sweep-setup.sh`, next to — not inside — the wiped `TESTDIR`):

```bash
#!/usr/bin/env bash
# Build disposable fixture repos for repo-sweep testing.
# Usage: repo-sweep-setup.sh <testdir>   (wipes and recreates <testdir>)
set -euo pipefail

testdir="${1:?usage: repo-sweep-setup.sh <testdir>}"
rm -rf "${testdir}"
mkdir -p "${testdir}/bin" "${testdir}/base/acme"

# --- fake fzf test double ---
# Captures the candidate list to FZF_FAKE_CAPTURE, dumps its args to
# FZF_FAKE_ARGS, and "selects" lines matching the FZF_FAKE_SELECT regex.
# Without FZF_FAKE_SELECT it behaves like the user pressing Esc (exit 130).
cat > "${testdir}/bin/fzf" <<'FAKE'
#!/usr/bin/env bash
capture="${FZF_FAKE_CAPTURE:-/dev/null}"
cat > "${capture}"
if [[ -n "${FZF_FAKE_ARGS:-}" ]]; then
    printf '%s\n' "$@" > "${FZF_FAKE_ARGS}"
fi
if [[ -n "${FZF_FAKE_SELECT:-}" ]]; then
    grep -E "${FZF_FAKE_SELECT}" "${capture}"
else
    exit 130
fi
FAKE
chmod +x "${testdir}/bin/fzf"

# --- origin + working clone ---
git init --bare -b main "${testdir}/origin.git" >/dev/null
repo="${testdir}/base/acme/widget"
git clone "${testdir}/origin.git" "${repo}" >/dev/null 2>&1
git -C "${repo}" config user.email test@example.com
git -C "${repo}" config user.name "Test"
git -C "${repo}" config commit.gpgsign false
echo one > "${repo}/README.md"
git -C "${repo}" add README.md
git -C "${repo}" commit -qm "chore: initial commit"
git -C "${repo}" push -qu origin main

new_branch() {  # <name> <file> — branch off main with one commit
    git -C "${repo}" checkout -qb "$1" main
    echo "$1" > "${repo}/$2"
    git -C "${repo}" add "$2"
    git -C "${repo}" commit -qm "feat: $1"
}

# MERGED: tip is an ancestor of origin/main
git -C "${repo}" branch merged-branch main

# GONE: pushed with upstream, then deleted on the remote
new_branch feat-gone gone.txt
git -C "${repo}" push -qu origin feat-gone
git -C "${repo}" push -q origin :feat-gone

# PUSHED: pushed and in sync, but not merged
new_branch feat-pushed pushed.txt
git -C "${repo}" push -qu origin feat-pushed

# UNPUSHED (ahead): pushed, then one extra local commit
new_branch feat-ahead ahead.txt
git -C "${repo}" push -qu origin feat-ahead
echo more > "${repo}/ahead2.txt"
git -C "${repo}" add ahead2.txt
git -C "${repo}" commit -qm "feat: ahead again"

# UNPUSHED (no upstream): never pushed
new_branch feat-noup noup.txt
git -C "${repo}" checkout -q main

# Worktrees: PUSHED (clean+synced), DIRTY (untracked file), detached
new_branch feat-wtpushed wtpushed.txt
git -C "${repo}" push -qu origin feat-wtpushed
git -C "${repo}" checkout -q main
git -C "${repo}" worktree add -q "${testdir}/base/acme/widget.wt/feat-wtpushed" feat-wtpushed
git -C "${repo}" worktree add -q -b feat-wtdirty "${testdir}/base/acme/widget.wt/feat-wtdirty" main
touch "${testdir}/base/acme/widget.wt/feat-wtdirty/scratch.txt"
git -C "${repo}" worktree add -q --detach "${testdir}/base/acme/widget.wt/detached" main

echo "fixtures ready under ${testdir}"
```

Then make it executable and build the fixtures:

```bash
export TESTDIR=/private/tmp/claude-501/-Users-veberarnaud-Developer-src-github-com-VEBERArnaud-dotfiles/125edcfe-6ca9-4804-abe6-49515226e85e/scratchpad/repo-sweep-test
export SETUP="${TESTDIR%/*}/repo-sweep-setup.sh"
chmod +x "${SETUP}"
bash "${SETUP}" "${TESTDIR}"
```

Expected: `fixtures ready under .../repo-sweep-test`

- [ ] **Step 2: Run the CURRENT script against the fixtures to see the failing state (red)**

```bash
cd /Users/veberarnaud/Developer/src/github.com/VEBERArnaud/dotfiles
PATH="${TESTDIR}/bin:${PATH}" REPO_SWEEP_BASE="${TESTDIR}/base" \
    FZF_FAKE_CAPTURE="${TESTDIR}/capture" \
    bash home/dot_local/bin/executable_repo-sweep </dev/null
awk -F'\t' '{print $1}' "${TESTDIR}/capture" | grep -E 'feat-(pushed|ahead|noup)'
```

Expected (RED): the three greps show `ACTIVE` — the current script cannot tell a safely-pushed branch from unpushed local work.

- [ ] **Step 3: Update the script header comment**

In `home/dot_local/bin/executable_repo-sweep`, replace lines 7-8:

```bash
#   3. Detect cleanup candidates (worktrees + local branches) with status:
#      GONE (upstream deleted), MERGED (in default branch), DIRTY, ACTIVE
```

with:

```bash
#   3. Detect cleanup candidates (worktrees + local branches) with status:
#      GONE (upstream deleted), MERGED (in default branch), PUSHED (synced
#      with upstream), UNPUSHED (local-only work), DIRTY (uncommitted files)
```

- [ ] **Step 4: Add the `branch_status()` helper**

Insert after the closing `}` of `merge_ref()` (line 78), before the `Phase 1` banner:

```bash
# Classify a branch: GONE, MERGED, PUSHED or UNPUSHED
# (DIRTY is a worktree-level status handled by the caller)
branch_status() {
    local repo="$1" branch="$2" cmp_ref="$3" upstream track
    upstream=$(git -C "${repo}" for-each-ref --format='%(upstream:short)' "refs/heads/${branch}")
    track=$(git -C "${repo}" for-each-ref --format='%(upstream:track)' "refs/heads/${branch}")
    if [[ "${track}" == "[gone]" ]]; then
        echo "GONE"
    elif [[ -n "${cmp_ref}" ]] && git -C "${repo}" merge-base --is-ancestor "${branch}" "${cmp_ref}" 2>/dev/null; then
        echo "MERGED"
    elif [[ -n "${upstream}" && "${track}" != *ahead* ]]; then
        echo "PUSHED"
    else
        echo "UNPUSHED"
    fi
}
```

Note: `track` values look like `[behind 2]`, `[ahead 1]`, `[ahead 1, behind 2]` or empty — anything without `ahead` on an existing upstream means no local-only commits, hence `PUSHED`.

- [ ] **Step 5: Rewire the worktree block**

Replace lines 149-161 (from `status="ACTIVE"` through the `printf ... >> "${tmp}/candidates"`):

```bash
                    status="ACTIVE"
                    if [[ -n "$(git -C "${wt_path}" status --porcelain 2>/dev/null)" ]]; then
                        status="DIRTY"
                    elif [[ -n "${wt_branch}" ]]; then
                        track=$(git -C "${repo}" for-each-ref --format='%(upstream:track)' "refs/heads/${wt_branch}")
                        if [[ "${track}" == "[gone]" ]]; then
                            status="GONE"
                        elif [[ -n "${cmp_ref}" ]] && git -C "${repo}" merge-base --is-ancestor "${wt_branch}" "${cmp_ref}" 2>/dev/null; then
                            status="MERGED"
                        fi
                    fi
                    display=$(printf '%-42s %-9s %-36s %s' "${rel}" "worktree" "${name}" "${status}")
                    printf '%s\t%s\t%s\t%s\t%s\n' "${display}" "worktree" "${name}" "${repo}" "${wt_path}" >> "${tmp}/candidates"
```

with:

```bash
                    if [[ -n "$(git -C "${wt_path}" status --porcelain 2>/dev/null)" ]]; then
                        status="DIRTY"
                    elif [[ -n "${wt_branch}" ]]; then
                        status=$(branch_status "${repo}" "${wt_branch}" "${cmp_ref}")
                    else
                        # detached HEAD: commit reachability unknown, treat as risky
                        status="UNPUSHED"
                    fi
                    display=$(printf '%-42s %-9s %-36s %s' "${rel}" "worktree" "${name}" "${status}")
                    printf '%s\t%s\t%s\t%s\t_%s\t%s\n' "${display}" "worktree" "${name}" "${repo}" "${wt_path}" "${status}" >> "${tmp}/candidates"
```

- [ ] **Step 6: Rewire the branch block**

Replace lines 168-185 (the whole `--- local branches ---` section):

```bash
    # --- local branches (skip default and branches living in a worktree) ---
    # "_" sentinel keeps empty fields from collapsing under tab IFS
    repo_root=$(git -C "${repo}" rev-parse --show-toplevel)
    while IFS=$'\t' read -r name track wtpath; do
        track="${track#_}"
        wtpath="${wtpath#_}"
        [[ -z "${name}" || "${name}" == "${db}" ]] && continue
        [[ -n "${wtpath}" && "${wtpath}" != "${repo_root}" ]] && continue
        status="ACTIVE"
        if [[ "${track}" == "[gone]" ]]; then
            status="GONE"
        elif [[ -n "${cmp_ref}" ]] && git -C "${repo}" merge-base --is-ancestor "${name}" "${cmp_ref}" 2>/dev/null; then
            status="MERGED"
        fi
        display=$(printf '%-42s %-9s %-36s %s' "${rel}" "branch" "${name}" "${status}")
        printf '%s\t%s\t%s\t%s\t%s\n' "${display}" "branch" "${name}" "${repo}" "" >> "${tmp}/candidates"
    done < <(git -C "${repo}" for-each-ref refs/heads \
        --format='%(refname:short)%09_%(upstream:track)%09_%(worktreepath)')
```

with:

```bash
    # --- local branches (skip default and branches living in a worktree) ---
    # "_" sentinel keeps empty fields from collapsing under tab IFS
    repo_root=$(git -C "${repo}" rev-parse --show-toplevel)
    while IFS=$'\t' read -r name wtpath; do
        wtpath="${wtpath#_}"
        [[ -z "${name}" || "${name}" == "${db}" ]] && continue
        [[ -n "${wtpath}" && "${wtpath}" != "${repo_root}" ]] && continue
        status=$(branch_status "${repo}" "${name}" "${cmp_ref}")
        display=$(printf '%-42s %-9s %-36s %s' "${rel}" "branch" "${name}" "${status}")
        printf '%s\t%s\t%s\t%s\t_%s\t%s\n' "${display}" "branch" "${name}" "${repo}" "" "${status}" >> "${tmp}/candidates"
    done < <(git -C "${repo}" for-each-ref refs/heads \
        --format='%(refname:short)%09_%(worktreepath)')
```

- [ ] **Step 7: Adapt the phase-6 read to the 6-field format**

The deletion loop (line 263) still parses 5 fields; with 6 fields `wt_path` would swallow the status. Replace:

```bash
    while IFS=$'\t' read -r _ type name repo wt_path; do
        rel="${repo#"${base_dir}"/}"
```

with (trailing `_` discards the status — Task 3 will consume it):

```bash
    while IFS=$'\t' read -r _ type name repo wt_path _; do
        wt_path="${wt_path#_}"
        rel="${repo#"${base_dir}"/}"
```

- [ ] **Step 8: Run the fixture test to verify statuses (green)**

```bash
bash "${SETUP}" "${TESTDIR}"
cd /Users/veberarnaud/Developer/src/github.com/VEBERArnaud/dotfiles
PATH="${TESTDIR}/bin:${PATH}" REPO_SWEEP_BASE="${TESTDIR}/base" \
    FZF_FAKE_CAPTURE="${TESTDIR}/capture" \
    bash home/dot_local/bin/executable_repo-sweep </dev/null
awk -F'\t' '{print $2, $3, $6}' "${TESTDIR}/capture" | sort
```

Expected output, exactly:

```
branch feat-ahead UNPUSHED
branch feat-gone GONE
branch feat-noup UNPUSHED
branch feat-pushed PUSHED
branch merged-branch MERGED
worktree (detached) UNPUSHED
worktree feat-wtdirty DIRTY
worktree feat-wtpushed PUSHED
```

- [ ] **Step 9: ShellCheck**

Run: `shellcheck home/dot_local/bin/executable_repo-sweep`
Expected: no output, exit 0.

- [ ] **Step 10: Commit**

```bash
git add home/dot_local/bin/executable_repo-sweep
git commit -m "feat(repo-sweep): add PUSHED/UNPUSHED statuses via branch_status helper"
```

---

### Task 2: Default fzf filter includes PUSHED

**Files:**
- Modify: `home/dot_local/bin/executable_repo-sweep` (header comment line ~10, fzf call in phase 4)

**Interfaces:**
- Consumes: candidate lines with the status word at the end of the display field (Task 1).
- Produces: fzf prefilled query `'GONE' | 'MERGED' | 'PUSHED'` — boundary-quoted terms (fzf ≥ 0.44; 0.74 installed) so `PUSHED` does not match `UNPUSHED`. This refines the spec's plain `GONE | MERGED | PUSHED`, which would substring-match `UNPUSHED`.

- [ ] **Step 1: Show the failing behavior of the naive query (red)**

Using the capture from Task 1 Step 8 (regenerate it if the file is gone):

```bash
fzf --filter 'GONE | MERGED | PUSHED' < "${TESTDIR}/capture" | awk -F'\t' '{print $3, $6}' | sort
```

Expected (RED): `feat-ahead UNPUSHED`, `feat-noup UNPUSHED` and `(detached) UNPUSHED` appear — the unquoted query leaks risky items into the default view.

- [ ] **Step 2: Update the header comment**

Replace line (now shifted by Task 1's header edit):

```bash
#   4. Global fzf multi-select (query prefilled with GONE | MERGED)
```

with:

```bash
#   4. Global fzf multi-select (query prefilled with GONE | MERGED | PUSHED)
```

- [ ] **Step 3: Update the fzf call**

In phase 4, replace:

```bash
        --query 'GONE | MERGED' \
        --bind 'ctrl-a:select-all,ctrl-d:deselect-all' \
        --header 'TAB: toggle | ctrl-a: select all matched | Enter: confirm | Esc: skip cleanup' \
```

with:

```bash
        --query "'GONE' | 'MERGED' | 'PUSHED'" \
        --bind 'ctrl-a:select-all,ctrl-d:deselect-all' \
        --header 'TAB: toggle | ctrl-a: select all | Enter: confirm | Esc: skip | clear query to reveal DIRTY/UNPUSHED' \
```

- [ ] **Step 4: Verify the boundary-quoted filter (green)**

```bash
fzf --filter "'GONE' | 'MERGED' | 'PUSHED'" < "${TESTDIR}/capture" | awk -F'\t' '{print $3, $6}' | sort
```

Expected output, exactly:

```
feat-gone GONE
feat-pushed PUSHED
feat-wtpushed PUSHED
merged-branch MERGED
```

Then confirm the script passes that exact query to fzf:

```bash
bash "${SETUP}" "${TESTDIR}"
cd /Users/veberarnaud/Developer/src/github.com/VEBERArnaud/dotfiles
PATH="${TESTDIR}/bin:${PATH}" REPO_SWEEP_BASE="${TESTDIR}/base" \
    FZF_FAKE_CAPTURE="${TESTDIR}/capture" FZF_FAKE_ARGS="${TESTDIR}/args" \
    bash home/dot_local/bin/executable_repo-sweep </dev/null
grep -A1 -- '--query' "${TESTDIR}/args" | tail -1
```

Expected: `'GONE' | 'MERGED' | 'PUSHED'`

- [ ] **Step 5: ShellCheck**

Run: `shellcheck home/dot_local/bin/executable_repo-sweep`
Expected: no output, exit 0.

- [ ] **Step 6: Commit**

```bash
git add home/dot_local/bin/executable_repo-sweep
git commit -m "feat(repo-sweep): include PUSHED items in default fzf filter"
```

---

### Task 3: Confirmation gate for DIRTY/UNPUSHED deletions

**Files:**
- Modify: `home/dot_local/bin/executable_repo-sweep` (header comment line ~11, new `lost_commits()` helper after `branch_status()`, phase 6 rewrite, phase 7 report)

**Interfaces:**
- Consumes: 6-field candidate lines (Task 1); `branch_status()`, `default_branch()`, `merge_ref()`.
- Produces: `lost_commits <repo> <branch>` → echoes an unpushed-commit count or `?`; report section `Skipped (declined)`; confirmation prompt text `Delete these too? [y/N] ` reading from the script's stdin (a terminal in normal use — fzf reads its keyboard from /dev/tty, so stdin stays intact; in tests we pipe `y`/`n` in).

- [ ] **Step 1: Show the missing safety (red)**

```bash
bash "${SETUP}" "${TESTDIR}"
cd /Users/veberarnaud/Developer/src/github.com/VEBERArnaud/dotfiles
printf 'n\n' | PATH="${TESTDIR}/bin:${PATH}" REPO_SWEEP_BASE="${TESTDIR}/base" \
    FZF_FAKE_CAPTURE="${TESTDIR}/capture" FZF_FAKE_SELECT=$'\tbranch\tfeat-noup\t' \
    bash home/dot_local/bin/executable_repo-sweep
git -C "${TESTDIR}/base/acme/widget" show-ref --verify --quiet refs/heads/feat-noup && echo "still there" || echo "DELETED"
```

Expected (RED): `DELETED` — the user answered `n` but the branch with an unpushed commit is gone anyway, because no confirmation exists.

- [ ] **Step 2: Update the header comment**

Replace:

```bash
#   6. Delete selected worktrees (via wt-remove) and branches
```

with:

```bash
#   6. Delete selected worktrees (via wt-remove) and branches; deleting
#      DIRTY/UNPUSHED items requires an explicit y/N confirmation
```

- [ ] **Step 3: Add the `lost_commits()` helper**

Insert after the closing `}` of `branch_status()`:

```bash
# Commits on <branch> not pushed anywhere ("?" when it cannot be determined)
lost_commits() {
    local repo="$1" branch="$2" upstream db cmp
    if [[ -z "${branch}" || "${branch}" == "(detached)" ]]; then
        echo "?"
        return 0
    fi
    upstream=$(git -C "${repo}" for-each-ref --format='%(upstream:short)' "refs/heads/${branch}")
    if [[ -n "${upstream}" ]] && git -C "${repo}" show-ref --verify --quiet "refs/remotes/${upstream}"; then
        git -C "${repo}" rev-list --count "${upstream}..${branch}" 2>/dev/null || echo "?"
        return 0
    fi
    if db=$(default_branch "${repo}"); then
        cmp=$(merge_ref "${repo}" "${db}")
        git -C "${repo}" rev-list --count "${cmp}..${branch}" 2>/dev/null || echo "?"
        return 0
    fi
    echo "?"
}
```

- [ ] **Step 4: Rewrite phase 6**

Replace the entire phase 6 block — from the `# Phase 6:` banner comment through the `done < "${tmp}/selected"` and its closing `fi` — with:

```bash
#######################################
# Phase 6: delete selected worktrees and branches (confirm risky ones)
#######################################

: > "${tmp}/deleted"
: > "${tmp}/declined"
if [[ -s "${tmp}/selected" ]]; then
    # Partition selection: deleting DIRTY/UNPUSHED items loses local work
    : > "${tmp}/safe"
    : > "${tmp}/risky"
    while IFS= read -r line; do
        case "${line##*$'\t'}" in
            DIRTY|UNPUSHED) printf '%s\n' "${line}" >> "${tmp}/risky" ;;
            *)              printf '%s\n' "${line}" >> "${tmp}/safe" ;;
        esac
    done < "${tmp}/selected"

    to_delete="${tmp}/safe"
    if [[ -s "${tmp}/risky" ]]; then
        echo ""
        echo "!! These selected items contain local work that would be lost:"
        while IFS=$'\t' read -r _ type name repo wt_path status; do
            wt_path="${wt_path#_}"
            rel="${repo#"${base_dir}"/}"
            loss=""
            if [[ "${status}" == "DIRTY" ]]; then
                dirty_count=$(git -C "${wt_path}" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
                loss="${dirty_count} uncommitted/untracked file(s)"
            fi
            commits=$(lost_commits "${repo}" "${name}")
            if [[ "${commits}" != "0" ]]; then
                loss="${loss:+${loss}, }${commits} unpushed commit(s)"
            fi
            echo "  ${rel}: ${type} ${name} [${status}] - ${loss:-nothing detected}"
        done < "${tmp}/risky"
        reply=""
        read -r -p "Delete these too? [y/N] " reply || reply=""
        if [[ "${reply}" == "y" || "${reply}" == "Y" ]]; then
            cat "${tmp}/safe" "${tmp}/risky" > "${tmp}/to_delete_all"
            to_delete="${tmp}/to_delete_all"
        else
            while IFS=$'\t' read -r _ type name repo _ _; do
                rel="${repo#"${base_dir}"/}"
                echo "${rel}: ${type} ${name}" >> "${tmp}/declined"
            done < "${tmp}/risky"
        fi
    fi

    if [[ -s "${to_delete}" ]]; then
        echo "==> Cleaning $(wc -l < "${to_delete}" | tr -d ' ') selected item(s)..."
        while IFS=$'\t' read -r _ type name repo wt_path status; do
            wt_path="${wt_path#_}"
            rel="${repo#"${base_dir}"/}"
            case "${type}" in
                worktree)
                    if [[ "${status}" == "DIRTY" ]]; then
                        wt-remove --force "${wt_path}" >/dev/null 2>&1 || true
                    else
                        wt-remove "${wt_path}" >/dev/null 2>&1 || true
                    fi
                    # wt-remove uses branch -d; force-delete leftovers (squash-merged)
                    if [[ "${name}" != "(detached)" ]]; then
                        git -C "${repo}" branch -D "${name}" >/dev/null 2>&1 || true
                    fi
                    echo "${rel}: worktree ${name}" >> "${tmp}/deleted"
                    ;;
                branch)
                    if git -C "${repo}" branch -D "${name}" >/dev/null 2>&1; then
                        echo "${rel}: branch ${name}" >> "${tmp}/deleted"
                    else
                        echo "${rel}: cannot delete branch ${name} (checked out?)" >> "${tmp}/errors"
                    fi
                    ;;
            esac
        done < "${to_delete}"
    fi
fi
```

- [ ] **Step 5: Add the report section**

In phase 7, after `report_section "Skipped (dirty)" "${tmp}/skipped"`, add:

```bash
report_section "Skipped (declined)" "${tmp}/declined"
```

- [ ] **Step 6: Scenario A — decline preserves the branch (green)**

```bash
bash "${SETUP}" "${TESTDIR}"
cd /Users/veberarnaud/Developer/src/github.com/VEBERArnaud/dotfiles
printf 'n\n' | PATH="${TESTDIR}/bin:${PATH}" REPO_SWEEP_BASE="${TESTDIR}/base" \
    FZF_FAKE_CAPTURE="${TESTDIR}/capture" FZF_FAKE_SELECT=$'\tbranch\tfeat-noup\t' \
    bash home/dot_local/bin/executable_repo-sweep | tee "${TESTDIR}/out-a"
git -C "${TESTDIR}/base/acme/widget" show-ref --verify --quiet refs/heads/feat-noup && echo "still there"
grep -c "1 unpushed commit" "${TESTDIR}/out-a"
grep -c "Skipped (declined)" "${TESTDIR}/out-a"
```

Expected: `still there`, and both greps ≥ 1.

- [ ] **Step 7: Scenario B — confirm deletes the branch**

```bash
bash "${SETUP}" "${TESTDIR}"
printf 'y\n' | PATH="${TESTDIR}/bin:${PATH}" REPO_SWEEP_BASE="${TESTDIR}/base" \
    FZF_FAKE_CAPTURE="${TESTDIR}/capture" FZF_FAKE_SELECT=$'\tbranch\tfeat-noup\t' \
    bash home/dot_local/bin/executable_repo-sweep >/dev/null
git -C "${TESTDIR}/base/acme/widget" show-ref --verify --quiet refs/heads/feat-noup || echo "deleted as confirmed"
```

Expected: `deleted as confirmed`

- [ ] **Step 8: Scenario C — safe-only selection prompts nothing**

```bash
bash "${SETUP}" "${TESTDIR}"
PATH="${TESTDIR}/bin:${PATH}" REPO_SWEEP_BASE="${TESTDIR}/base" \
    FZF_FAKE_CAPTURE="${TESTDIR}/capture" FZF_FAKE_SELECT=$'\tbranch\tfeat-pushed\t' \
    bash home/dot_local/bin/executable_repo-sweep </dev/null | tee "${TESTDIR}/out-c"
git -C "${TESTDIR}/base/acme/widget" show-ref --verify --quiet refs/heads/feat-pushed || echo "deleted without prompt"
grep -c "Delete these too" "${TESTDIR}/out-c" || echo "no prompt shown"
```

Expected: `deleted without prompt` and `no prompt shown` (stdin is /dev/null: had the prompt existed, `read` would still have defaulted to No and the branch would survive — its deletion proves no prompt fired).

- [ ] **Step 9: Scenario D — confirmed dirty worktree is force-removed**

```bash
bash "${SETUP}" "${TESTDIR}"
printf 'y\n' | PATH="${TESTDIR}/bin:${PATH}" REPO_SWEEP_BASE="${TESTDIR}/base" \
    FZF_FAKE_CAPTURE="${TESTDIR}/capture" FZF_FAKE_SELECT=$'\tworktree\tfeat-wtdirty\t' \
    bash home/dot_local/bin/executable_repo-sweep | grep -c "uncommitted/untracked file(s)"
[[ ! -d "${TESTDIR}/base/acme/widget.wt/feat-wtdirty" ]] && echo "worktree removed"
```

Expected: grep ≥ 1 (the recap listed the dirty files), then `worktree removed`.

- [ ] **Step 10: ShellCheck**

Run: `shellcheck home/dot_local/bin/executable_repo-sweep`
Expected: no output, exit 0.

- [ ] **Step 11: Commit**

```bash
git add home/dot_local/bin/executable_repo-sweep
git commit -m "feat(repo-sweep): confirm before deleting dirty or unpushed items"
```

---

### Task 4: Deploy via chezmoi and final verification

**Files:**
- No source changes — deployment and end-to-end verification only.

**Interfaces:**
- Consumes: the finished script from Tasks 1-3.

- [ ] **Step 1: Full fixture regression pass**

Re-run Task 1 Step 8, Task 2 Step 4 and Task 3 Scenarios A-D from scratch (each regenerates fixtures via `bash "${SETUP}" "${TESTDIR}"`). All expected outputs must match.

- [ ] **Step 2: Deploy the script**

```bash
cd /Users/veberarnaud/Developer/src/github.com/VEBERArnaud/dotfiles
chezmoi apply -v ~/.local/bin/repo-sweep
cmp home/dot_local/bin/executable_repo-sweep ~/.local/bin/repo-sweep && echo "deployed"
```

Expected: `deployed`

- [ ] **Step 3: Hand the interactive check to the user**

Do NOT run `repo-sweep` against the real base dir from this session (it would check out `main` in this dotfiles repo, which sits on the feature branch). Tell the user the real-world check is theirs: run `repo-sweep`, verify the 16 `evergreen/*` branches of `vbr-tech/laminutebaseball.fr` show `PUSHED` in the default filter, `feature/231-evergreen` shows `UNPUSHED` only after clearing the query, and press Esc (or clean for real if they want).

- [ ] **Step 4: Clean up test fixtures**

```bash
rm -rf "${TESTDIR}" "${SETUP}"
```
