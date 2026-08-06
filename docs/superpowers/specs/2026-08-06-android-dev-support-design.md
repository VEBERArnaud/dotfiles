# android: native Android development support via with_android

**Date:** 2026-08-06
**Target:** `home/.chezmoi.toml.tmpl`, `home/.chezmoiscripts/`, `home/dot_zprofile.d/`

## Problem

The dotfiles provision toolchains per feature flag (`with_golang`, `with_rust`,
`with_swift`, ...) but have no Android support. Native Kotlin/Java Android
development is starting on the Mega Lap project, which already carries
`with_swift` for the iOS side. Machines need Android Studio, a JDK usable from
the terminal, and shell environment (`ANDROID_HOME`, `adb`/`emulator` in PATH)
without manual setup.

## Goals

1. A `with_android` feature flag following the existing flag conventions,
   enabled for `project_mega_lap` (MacBookPro2023, MacMini2023s).
2. Android Studio and a JDK installed via the Homebrew script.
3. Shell environment ready for terminal workflows (`adb`, `emulator`, Gradle
   wrapper builds) once the SDK exists.

## Design decisions

- **Native Kotlin/Java stack** — no React Native / Flutter / KMP tooling.
- **Android Studio manages the SDK.** The first-launch wizard installs the SDK,
  platform-tools and emulator into `~/Library/Android/sdk`. No headless
  `sdkmanager` scripting, no license automation to maintain.
- **JDK: `temurin@21` cask** (LTS, compatible with current AGP/Gradle). Android
  Studio bundles its own JBR for the IDE; the system JDK serves terminal
  `./gradlew` builds. It is a pkg installer, so `chezmoi apply` may prompt for
  the sudo password once.
- **No extras** (scrcpy, ktlint, standalone gradle) — YAGNI, added later if
  needed.

## Changes

### `home/.chezmoi.toml.tmpl`

- Declare `{{- $with_android := false -}}` in the features block (alphabetical
  position, first).
- Set `{{- $with_android = true -}}` in the `project_mega_lap` block.
- Export `with_android = {{ $with_android }}` in `[data]`.

### `home/.chezmoiscripts/packages/run_before_darwin_homebrew.sh.tmpl`

New conditional block, inserted before `with_aws`:

```
{{- if .with_android -}}
{{-   $casks = concat $casks (list "android-studio" "temurin@21") -}}
{{- end -}}
```

### `home/dot_zprofile.d/24-android.sh.tmpl` (new)

Slot 24 — next free in the 20-29 languages/runtimes range (23 is whisper).

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

- `ANDROID_HOME` points at Android Studio's default SDK location; the PATH
  entries are harmless before the SDK exists and active right after the
  first-launch wizard.
- The `JAVA_HOME` guard avoids exporting an empty variable when the JDK is not
  installed yet.

### `home/.chezmoiscripts/verify/run_after_verify.sh.tmpl`

New conditional block (alphabetical, before `with_aws`):

```
{{ if .with_android -}}
echo ""
log_info "Checking Android tools..."
check_command_available java || errors=$((errors + 1))
{{ end -}}
```

Deliberately no `adb` check: the SDK only exists after the first Android
Studio launch, so an `adb` check would fail on a fresh machine.

### Documentation

- `CLAUDE.md`: add `with_android` to the feature flags list.
- `.claude/rules/chezmoi.md`: add `.with_android` to the feature flags list.

### `.github/workflows/lint.yml`

Add `with_android = true` to the CI mock `[data]` block (before `with_aws`).
Without it, templates referencing `.with_android` fail CI rendering with
"map has no entry for key"; `true` makes CI render and shellcheck the new
conditional blocks.

## Manual step (documented, not automated)

After `chezmoi apply`, launch Android Studio once; its setup wizard installs
the SDK, platform-tools and emulator into `~/Library/Android/sdk`.

## Out of scope

- Headless SDK provisioning (`android-commandlinetools`, `sdkmanager`,
  license acceptance scripting).
- Extra CLI tools (scrcpy, ktlint, standalone gradle).
- Enabling `with_android` for other projects or hosts.

## Testing

- CI must pass: template rendering of all `.tmpl` files, ShellCheck.
- `chezmoi execute-template` renders the new drop-in for a mega_lap host
  (block present) and a non-mega_lap host (empty file).
- On a mega_lap machine after apply: `echo $ANDROID_HOME` set, `java -version`
  works, and after the Studio wizard `adb --version` works.
