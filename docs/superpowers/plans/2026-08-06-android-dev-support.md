# Android Dev Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `with_android` feature flag that provisions Android Studio, a Temurin 21 JDK and the Android shell environment on `project_mega_lap` machines.

**Architecture:** Follows the existing chezmoi feature-flag pattern: flag declared/derived in `home/.chezmoi.toml.tmpl`, packages added conditionally in the Homebrew script, shell env in a numbered `dot_zprofile.d` drop-in, post-apply check in the verify script. Android Studio's first-launch wizard owns SDK installation (no headless `sdkmanager`).

**Tech Stack:** chezmoi Go templates, bash, Homebrew, GitHub Actions (lint.yml).

**Spec:** `docs/superpowers/specs/2026-08-06-android-dev-support-design.md`

## Global Constraints

- Work in the existing worktree on branch `feature/android-dev-support`; never commit to `main`; final delivery is a PR.
- Conventional commits `type(scope): subject` — imperative, lowercase, no trailing period, ≤72 chars. Commits are GPG signed (repo default, no extra flag needed).
- Casks: exactly `android-studio` and `temurin@21`. No brews, no extras (no scrcpy, ktlint, gradle).
- Drop-in file name: exactly `home/dot_zprofile.d/24-android.sh.tmpl` (slot 24; 23 is whisper).
- Alphabetical insertion: every new `with_android` block/entry goes immediately BEFORE the corresponding `with_aws` block/entry.
- `ANDROID_HOME` is `$HOME/Library/Android/sdk` (Android Studio's default SDK location).
- Verify script checks `java` only — deliberately NOT `adb` (SDK does not exist until first Studio launch).
- CI mock data (`.github/workflows/lint.yml`) must define `with_android = true` so CI renders and shellchecks the new blocks.

### Template render harness (used by several verification steps)

Each verification step is self-contained: it writes a mock chezmoi config to a
temp dir and renders templates with it, mirroring what CI does. The function
below is repeated verbatim in the steps that need it.

```bash
mkcfg() {
    # usage: mkcfg true|false  → echoes path of a chezmoi config with with_android set to $1
    local dir
    dir="$(mktemp -d)"
    cat > "${dir}/chezmoi.toml" << EOF
sourceDir = "${PWD}/home"
[data]
    is_mac = true
    is_linux = false
    is_windows = false
    is_unix = true
    is_apple_silicon = true
    type_laptop = true
    type_desktop = false
    type_server = false
    user_emmett = false
    user_veberarnaud = true
    project_personal = true
    project_vbr_tech = false
    project_eurosport = false
    project_mega_lap = false
    has_elgato = false
    has_insta360 = false
    has_scanner = false
    with_android = ${1}
    with_aws = true
    with_consul = false
    with_docker = true
    with_golang = true
    with_javascript = true
    with_nomad = false
    with_packer = false
    with_php = false
    with_terraform = true
    with_rust = true
    with_swift = true
EOF
    echo "${dir}/chezmoi.toml"
}
```

All commands run from the worktree root
(`/Users/veberarnaud/Developer/src/github.com/VEBERArnaud/dotfiles.wt/feature-android-dev-support`).

---

### Task 1: `with_android` flag in chezmoi config and CI mock data

**Files:**
- Modify: `home/.chezmoi.toml.tmpl`
- Modify: `.github/workflows/lint.yml`
- Modify: `docs/superpowers/specs/2026-08-06-android-dev-support-design.md`

**Interfaces:**
- Produces: template variable `.with_android` (bool), available to every `.tmpl` file. Tasks 2-4 consume it.

- [ ] **Step 1: Verify current state (failing check)**

Run:
```bash
chezmoi execute-template < home/.chezmoi.toml.tmpl | grep -c 'with_android' || echo "ABSENT"
```
Expected: `0` followed by `ABSENT` (grep finds nothing).

- [ ] **Step 2: Declare the flag in `home/.chezmoi.toml.tmpl`**

In the `{{/* features */}}` block, insert before the `$with_aws` line:

```
{{- $with_android := false -}}
```

In the `{{- if $project_mega_lap -}}` block, insert before the `$with_aws` line:

```
{{-   $with_android = true -}}
```

In the `[data]` section, insert before the `with_aws` line (indentation: 4 spaces, matching neighbors):

```
    with_android = {{ $with_android }}
```

- [ ] **Step 3: Add the flag to CI mock data in `.github/workflows/lint.yml`**

In the `Initialize chezmoi with mock data` step's heredoc, insert before the `with_aws = true` line (same indentation as neighbors):

```
    with_android = true
```

- [ ] **Step 4: Sync the spec**

In `docs/superpowers/specs/2026-08-06-android-dev-support-design.md`, in the `## Changes` section, add a subsection after the `### Documentation` subsection:

```markdown
### `.github/workflows/lint.yml`

Add `with_android = true` to the CI mock `[data]` block (before `with_aws`).
Without it, templates referencing `.with_android` fail CI rendering with
"map has no entry for key"; `true` makes CI render and shellcheck the new
conditional blocks.
```

- [ ] **Step 5: Verify the flag renders**

Run:
```bash
chezmoi execute-template < home/.chezmoi.toml.tmpl | grep -E '^\s*with_android = (true|false)$'
```
Expected: exactly one line, `with_android = true` or `with_android = false` depending on the local hostname (true on mega_lap hosts). Any template error means the edit broke the config template.

Also confirm CI mock stays valid TOML-ish and complete:
```bash
grep -n 'with_android = true' .github/workflows/lint.yml
```
Expected: one match inside the mock data heredoc.

- [ ] **Step 6: Commit**

```bash
git add home/.chezmoi.toml.tmpl .github/workflows/lint.yml docs/superpowers/specs/2026-08-06-android-dev-support-design.md
git commit -m "feat(android): add with_android feature flag"
```

---

### Task 2: Homebrew packages (android-studio, temurin@21)

**Files:**
- Modify: `home/.chezmoiscripts/packages/run_before_darwin_homebrew.sh.tmpl`

**Interfaces:**
- Consumes: `.with_android` (Task 1).
- Produces: rendered Brewfile lines `cask "android-studio"` and `cask "temurin@21"` when the flag is true.

- [ ] **Step 1: Verify current state (failing check)**

```bash
mkcfg() {
    local dir
    dir="$(mktemp -d)"
    cat > "${dir}/chezmoi.toml" << EOF
sourceDir = "${PWD}/home"
[data]
    is_mac = true
    is_linux = false
    is_windows = false
    is_unix = true
    is_apple_silicon = true
    type_laptop = true
    type_desktop = false
    type_server = false
    user_emmett = false
    user_veberarnaud = true
    project_personal = true
    project_vbr_tech = false
    project_eurosport = false
    project_mega_lap = false
    has_elgato = false
    has_insta360 = false
    has_scanner = false
    with_android = ${1}
    with_aws = true
    with_consul = false
    with_docker = true
    with_golang = true
    with_javascript = true
    with_nomad = false
    with_packer = false
    with_php = false
    with_terraform = true
    with_rust = true
    with_swift = true
EOF
    echo "${dir}/chezmoi.toml"
}
chezmoi --config "$(mkcfg true)" execute-template \
    < home/.chezmoiscripts/packages/run_before_darwin_homebrew.sh.tmpl \
    | grep -c 'android-studio' || echo "ABSENT"
```
Expected: `0` followed by `ABSENT`.

- [ ] **Step 2: Add the conditional block**

In `home/.chezmoiscripts/packages/run_before_darwin_homebrew.sh.tmpl`, insert immediately before the `{{- if .with_aws -}}` block:

```
{{- if .with_android -}}
{{-   $casks = concat $casks (list
        "android-studio"
        "temurin@21"
    ) -}}
{{- end -}}

```

(Trailing blank line matches the spacing between existing blocks.)

- [ ] **Step 3: Verify rendering, both flag values, and shellcheck**

```bash
mkcfg() {
    local dir
    dir="$(mktemp -d)"
    cat > "${dir}/chezmoi.toml" << EOF
sourceDir = "${PWD}/home"
[data]
    is_mac = true
    is_linux = false
    is_windows = false
    is_unix = true
    is_apple_silicon = true
    type_laptop = true
    type_desktop = false
    type_server = false
    user_emmett = false
    user_veberarnaud = true
    project_personal = true
    project_vbr_tech = false
    project_eurosport = false
    project_mega_lap = false
    has_elgato = false
    has_insta360 = false
    has_scanner = false
    with_android = ${1}
    with_aws = true
    with_consul = false
    with_docker = true
    with_golang = true
    with_javascript = true
    with_nomad = false
    with_packer = false
    with_php = false
    with_terraform = true
    with_rust = true
    with_swift = true
EOF
    echo "${dir}/chezmoi.toml"
}
tmpl=home/.chezmoiscripts/packages/run_before_darwin_homebrew.sh.tmpl
chezmoi --config "$(mkcfg true)" execute-template < "$tmpl" | grep 'cask "android-studio"'
chezmoi --config "$(mkcfg true)" execute-template < "$tmpl" | grep 'cask "temurin@21"'
chezmoi --config "$(mkcfg false)" execute-template < "$tmpl" | grep -c 'android' || echo "OK-ABSENT-WHEN-FALSE"
chezmoi --config "$(mkcfg true)" execute-template < "$tmpl" | shellcheck -s bash -e SC1091 -
```
Expected: the two casks greps match one line each; then `0` followed by `OK-ABSENT-WHEN-FALSE`; shellcheck exits 0 with no output.

- [ ] **Step 4: Commit**

```bash
git add home/.chezmoiscripts/packages/run_before_darwin_homebrew.sh.tmpl
git commit -m "feat(android): install android studio and temurin jdk via brew"
```

---

### Task 3: Shell environment drop-in

**Files:**
- Create: `home/dot_zprofile.d/24-android.sh.tmpl`

**Interfaces:**
- Consumes: `.with_android` (Task 1).
- Produces: `~/.zprofile.d/24-android.sh` exporting `ANDROID_HOME`, PATH entries, `JAVA_HOME` (empty file when flag is false).

- [ ] **Step 1: Create `home/dot_zprofile.d/24-android.sh.tmpl`**

Exact content:

```bash
{{- if .with_android }}
# Android
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator"
if JAVA_HOME="$(/usr/libexec/java_home -v 21 2>/dev/null)"; then
    export JAVA_HOME
fi
{{- end }}
```

- [ ] **Step 2: Verify rendering for both flag values**

```bash
mkcfg() {
    local dir
    dir="$(mktemp -d)"
    cat > "${dir}/chezmoi.toml" << EOF
sourceDir = "${PWD}/home"
[data]
    with_android = ${1}
EOF
    echo "${dir}/chezmoi.toml"
}
tmpl=home/dot_zprofile.d/24-android.sh.tmpl
chezmoi --config "$(mkcfg true)" execute-template < "$tmpl" | grep 'ANDROID_HOME'
chezmoi --config "$(mkcfg true)" execute-template < "$tmpl" | shellcheck -s bash -
test -z "$(chezmoi --config "$(mkcfg false)" execute-template < "$tmpl" | tr -d '[:space:]')" && echo "EMPTY-WHEN-FALSE"
```
Expected: two `ANDROID_HOME` grep hits (export + PATH lines), shellcheck silent, `EMPTY-WHEN-FALSE` printed.

(The minimal `[data]` block works here because this template only references `.with_android`.)

- [ ] **Step 3: Commit**

```bash
git add home/dot_zprofile.d/24-android.sh.tmpl
git commit -m "feat(android): add android shell environment drop-in"
```

---

### Task 4: Post-apply verification check

**Files:**
- Modify: `home/.chezmoiscripts/verify/run_after_verify.sh.tmpl`

**Interfaces:**
- Consumes: `.with_android` (Task 1); `check_command_available` and `log_info` from `common.tmpl` (already used throughout the file).

Amended after final review: the check uses `/usr/libexec/java_home -v 21` because macOS's `/usr/bin/java` stub makes `command -v java` always succeed.

- [ ] **Step 1: Add the conditional block**

In `home/.chezmoiscripts/verify/run_after_verify.sh.tmpl`, in the `# Conditional commands` section, insert immediately before the `{{ if .with_aws -}}` block:

```
{{ if .with_android -}}
echo ""
log_info "Checking Android tools..."
if /usr/libexec/java_home -v 21 &>/dev/null; then
    log_success "java 21 available"
else
    log_error "java 21 not found"
    errors=$((errors + 1))
fi
{{ end -}}
```

- [ ] **Step 2: Verify rendering, both flag values, and shellcheck**

```bash
mkcfg() {
    local dir
    dir="$(mktemp -d)"
    cat > "${dir}/chezmoi.toml" << EOF
sourceDir = "${PWD}/home"
[data]
    is_mac = true
    is_linux = false
    is_windows = false
    is_unix = true
    is_apple_silicon = true
    type_laptop = true
    type_desktop = false
    type_server = false
    user_emmett = false
    user_veberarnaud = true
    project_personal = true
    project_vbr_tech = false
    project_eurosport = false
    project_mega_lap = false
    has_elgato = false
    has_insta360 = false
    has_scanner = false
    with_android = ${1}
    with_aws = true
    with_consul = false
    with_docker = true
    with_golang = true
    with_javascript = true
    with_nomad = false
    with_packer = false
    with_php = false
    with_terraform = true
    with_rust = true
    with_swift = true
EOF
    echo "${dir}/chezmoi.toml"
}
tmpl=home/.chezmoiscripts/verify/run_after_verify.sh.tmpl
chezmoi --config "$(mkcfg true)" execute-template < "$tmpl" | grep 'Checking Android tools'
chezmoi --config "$(mkcfg false)" execute-template < "$tmpl" | grep -c 'Android' || echo "OK-ABSENT-WHEN-FALSE"
chezmoi --config "$(mkcfg true)" execute-template < "$tmpl" | shellcheck -s bash -e SC1091 -
```
Expected: first grep matches; then `0` followed by `OK-ABSENT-WHEN-FALSE`; shellcheck silent.

- [ ] **Step 3: Commit**

```bash
git add home/.chezmoiscripts/verify/run_after_verify.sh.tmpl
git commit -m "feat(android): check java in post-apply verification"
```

---

### Task 5: Documentation (flag lists)

**Files:**
- Modify: `CLAUDE.md`
- Modify: `.claude/rules/chezmoi.md`

**Interfaces:** none (documentation only).

- [ ] **Step 1: Update `CLAUDE.md`**

In the `### Feature Flags (conditional installation)` section, insert before the `with_aws` line:

```markdown
- `with_android` - Android development environment (Android Studio, Temurin JDK)
```

- [ ] **Step 2: Update `.claude/rules/chezmoi.md`**

In the `### Feature flags` section, the current first line is:

```markdown
- `.with_aws`, `.with_docker`, `.with_golang`, `.with_javascript`
```

Replace it with:

```markdown
- `.with_android`, `.with_aws`, `.with_docker`, `.with_golang`, `.with_javascript`
```

- [ ] **Step 3: Verify**

```bash
grep -n 'with_android' CLAUDE.md .claude/rules/chezmoi.md
```
Expected: one match in each file.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md .claude/rules/chezmoi.md
git commit -m "docs(android): document with_android feature flag"
```

---

### Task 6: Push branch and open PR

**Files:** none (git/GitHub only).

- [ ] **Step 1: Full local validation sweep (mirror CI)**

```bash
mkcfg() {
    local dir
    dir="$(mktemp -d)"
    cat > "${dir}/chezmoi.toml" << EOF
sourceDir = "${PWD}/home"
[data]
    is_mac = true
    is_linux = false
    is_windows = false
    is_unix = true
    is_apple_silicon = true
    type_laptop = true
    type_desktop = false
    type_server = false
    user_emmett = false
    user_veberarnaud = true
    project_personal = true
    project_vbr_tech = false
    project_eurosport = false
    project_mega_lap = false
    has_elgato = false
    has_insta360 = false
    has_scanner = false
    with_android = true
    with_aws = true
    with_consul = false
    with_docker = true
    with_golang = true
    with_javascript = true
    with_nomad = false
    with_packer = false
    with_php = false
    with_terraform = true
    with_rust = true
    with_swift = true
EOF
    echo "${dir}/chezmoi.toml"
}
cfg="$(mkcfg true)"
chezmoi --config "${cfg}" diff > /dev/null && echo "TEMPLATES-OK"
find home/.chezmoiscripts -name "*.sh.tmpl" | while read -r tmpl; do
    chezmoi --config "${cfg}" execute-template < "${tmpl}" | shellcheck -s bash -e SC1091 - || echo "FAIL: ${tmpl}"
done
echo "SHELLCHECK-DONE"
```
Expected: `TEMPLATES-OK`, then `SHELLCHECK-DONE` with no `FAIL:` lines.

Note: `chezmoi diff` with the mock config compares against the real `$HOME` — output content is irrelevant, only a zero exit (no template error) matters, hence `> /dev/null`.

- [ ] **Step 2: Push and open the PR**

```bash
git push -u origin feature/android-dev-support
gh pr create \
    --title "feat(android): add with_android feature for native android dev" \
    --body "$(cat << 'EOF'
## Summary

Adds a `with_android` feature flag (enabled for `project_mega_lap`) that
provisions native Android development:

- Casks `android-studio` + `temurin@21` via the Homebrew script
- `~/.zprofile.d/24-android.sh`: `ANDROID_HOME`, platform-tools/emulator in
  PATH, guarded `JAVA_HOME`
- `java` check in the post-apply verify script (no `adb` check — the SDK only
  exists after Android Studio's first-launch wizard)
- CI mock data gains `with_android = true` so the new blocks are rendered and
  shellchecked

Spec: `docs/superpowers/specs/2026-08-06-android-dev-support-design.md`
Plan: `docs/superpowers/plans/2026-08-06-android-dev-support.md`

## Manual step after merge + chezmoi apply

Launch Android Studio once; its setup wizard installs the SDK,
platform-tools and emulator into `~/Library/Android/sdk`.
EOF
)"
```
Expected: PR created against `main`, CI (Lint & Validate) green.
