#!/usr/bin/env bash
#
# Tests for the DMC.app install (run_onchange_after_dmc_app.sh.tmpl) and its
# companions (autostart, verify, pinned data, docs).
#
# Nothing touches /Applications, the preferences, the Keychain or a running
# app: the template is rendered, /Applications is redirected to a temporary
# directory, and gh, op, osascript, pgrep, open, defaults, xattr, sleep, mv
# and security are stubs. Needs macOS (ditto, PlistBuddy) and chezmoi.
#
# Usage: tests/dmc-app.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ROOT}/home"
DARWIN="${SRC}/.chezmoiscripts/system/darwin"
TMPL="${DARWIN}/run_onchange_after_dmc_app.sh.tmpl"
AUTOSTART="${DARWIN}/run_onchange_after_autostart.sh.tmpl"
VERIFY="${SRC}/.chezmoiscripts/verify/run_after_verify.sh.tmpl"

REAL_HOME="${HOME}"
WORK="$(mktemp -d)"
trap 'command rm -rf "${WORK}"' EXIT

pass=0
fail=0

ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
ko() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; }

assert_eq() { # expected actual label
    if [[ "$1" == "$2" ]]; then ok "$3"; else ko "$3 (expected '$1', got '$2')"; fi
}
assert_has() { # file pattern label
    if grep -qF -- "$2" "$1"; then ok "$3"; else ko "$3 (no '$2' in $1)"; fi
}
assert_lacks() { # file pattern label
    if grep -qF -- "$2" "$1"; then ko "$3 ('$2' found in $1)"; else ok "$3"; fi
}

render() { # template override-json
    chezmoi --source "${SRC}" execute-template --override-data "$2" < "$1"
}

# --- fixtures ---------------------------------------------------------------

VERSION="9.9.9"
mkapp() { # dir version [with-executable]
    mkdir -p "$1/Contents/MacOS"
    cat > "$1/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleShortVersionString</key>
<string>$2</string>
</dict></plist>
PLIST
    if [[ "${3:-yes}" == yes ]]; then
        printf '#!/bin/sh\n' > "$1/Contents/MacOS/DMCMenuBar"
        chmod +x "$1/Contents/MacOS/DMCMenuBar"
    fi
}

FIX="${WORK}/fixtures"
mkdir -p "${FIX}/good" "${FIX}/noexe"
mkapp "${FIX}/good/DMC.app" "${VERSION}"
mkapp "${FIX}/noexe/DMC.app" "${VERSION}" no
ditto -c -k --keepParent "${FIX}/good/DMC.app" "${FIX}/good.zip"
ditto -c -k --keepParent "${FIX}/noexe/DMC.app" "${FIX}/noexe.zip"
GOOD_SHA="$(shasum -a 256 "${FIX}/good.zip" | awk '{print $1}')"
NOEXE_SHA="$(shasum -a 256 "${FIX}/noexe.zip" | awk '{print $1}')"

# --- stubs ------------------------------------------------------------------

write_stubs() { # bin-dir
    local b="$1"
    mkdir -p "${b}"
    cat > "${b}/gh" <<'STUB'
#!/bin/bash
echo "gh $*" >> "${T}/calls.log"
if [[ "$1 $2" == "auth status" ]]; then [[ "${GH_AUTH:-1}" == 1 ]]; exit; fi
if [[ "$1 $2" == "release download" ]]; then
    [[ "${GH_DL_FAIL:-0}" == 0 ]] || exit 1
    dest=""
    while [[ $# -gt 0 ]]; do [[ "$1" == -D ]] && dest="$2"; shift; done
    cp "${ZIP}" "${dest}/DMC-${VERSION}-macOS-arm64.zip"
fi
STUB
    cat > "${b}/op" <<'STUB'
#!/bin/bash
echo "op $*" >> "${T}/calls.log"
if [[ "$1" == whoami ]]; then [[ "${OP_SIGNED:-1}" == 1 ]]; exit; fi
printf '%s\n' "${OP_URL:-}"
STUB
    cat > "${b}/defaults" <<'STUB'
#!/bin/bash
echo "defaults $*" >> "${T}/calls.log"
if [[ "$1" == read ]]; then [[ -f "${T}/baseurl" ]] && cat "${T}/baseurl"; exit; fi
if [[ "$1" == write ]]; then printf '%s\n' "$4" > "${T}/baseurl"; fi
STUB
    cat > "${b}/osascript" <<'STUB'
#!/bin/bash
echo "osascript $*" >> "${T}/calls.log"
[[ "${QUIT_OK:-1}" == 1 ]] && command rm -f "${T}/running"
exit 0
STUB
    cat > "${b}/pgrep" <<'STUB'
#!/bin/bash
echo "pgrep $*" >> "${T}/calls.log"
[[ -f "${T}/running" ]]
STUB
    cat > "${b}/open" <<'STUB'
#!/bin/bash
echo "open $*" >> "${T}/calls.log"
STUB
    cat > "${b}/xattr" <<'STUB'
#!/bin/bash
echo "xattr $*" >> "${T}/calls.log"
exit 1
STUB
    cat > "${b}/security" <<'STUB'
#!/bin/bash
echo "security $*" >> "${T}/calls.log"
STUB
    cat > "${b}/sleep" <<'STUB'
#!/bin/bash
echo "sleep $*" >> "${T}/calls.log"
STUB
    cat > "${b}/mv" <<'STUB'
#!/bin/bash
if [[ "${MV_FAIL:-0}" == 1 && "$*" == *".DMC.app.new "*"/DMC.app" ]]; then
    echo "mv $* (failed)" >> "${T}/calls.log"
    exit 1
fi
if [[ "${MV_FAIL:-0}" == 2 && "$*" == *"/DMC.app "*".DMC.app.old" ]]; then
    echo "mv $* (failed)" >> "${T}/calls.log"
    exit 1
fi
exec /bin/mv "$@"
STUB
    chmod +x "${b}"/*
}

# --- the install script -------------------------------------------------------

# run_case: sets up T, runs the rendered script, leaves $OUT, $RC, $T, $APPS.
# Knobs (env, set by the caller): ZIP_KIND, SHA, INSTALLED, RUNNING, NO_GH,
# NO_OP, GH_AUTH, GH_DL_FAIL, OP_SIGNED, OP_URL, QUIT_OK, MV_FAIL, CURRENT_URL
run_case() {
    T="$(mktemp -d "${WORK}/case.XXXXXX")"
    APPS="${T}/apps"
    mkdir -p "${APPS}" "${T}/tmp" "${T}/home"
    write_stubs "${T}/bin"
    [[ -z "${NO_GH:-}" ]] || command rm -f "${T}/bin/gh"
    [[ -z "${NO_OP:-}" ]] || command rm -f "${T}/bin/op"
    : > "${T}/calls.log"
    if [[ -n "${INSTALLED:-}" ]]; then
        mkapp "${APPS}/DMC.app" "${INSTALLED}"
        touch "${APPS}/DMC.app/marker"
    fi
    [[ -z "${RUNNING:-}" ]] || touch "${T}/running"
    [[ -z "${CURRENT_URL:-}" ]] || printf '%s\n' "${CURRENT_URL}" > "${T}/baseurl"

    local sha="${SHA:-${GOOD_SHA}}" zip="${FIX}/${ZIP_KIND:-good}.zip"
    render "${TMPL}" "{\"is_mac\":true,\"is_apple_silicon\":true,\"user_veberarnaud\":true,\"dmc\":{\"app\":{\"version\":\"${VERSION}\",\"sha256\":\"${sha}\"}}}" \
        | sed "s#readonly APPS_DIR=\"/Applications\"#readonly APPS_DIR=\"${APPS}\"#" > "${T}/script.sh"

    RC=0
    export T ZIP="${zip}" VERSION HOME="${T}/home" TMPDIR="${T}/tmp"
    OUT="$(GH_AUTH="${GH_AUTH:-1}" GH_DL_FAIL="${GH_DL_FAIL:-0}" OP_SIGNED="${OP_SIGNED:-1}" \
        OP_URL="${OP_URL-}" QUIT_OK="${QUIT_OK:-1}" MV_FAIL="${MV_FAIL:-0}" \
        PATH="${T}/bin:/usr/bin:/bin:/usr/sbin:/sbin" bash "${T}/script.sh" 2>&1)" || RC=$?
    HOME="${REAL_HOME}"; unset ZIP TMPDIR
    printf '%s\n' "${OUT}" > "${T}/out.log"
    unset ZIP_KIND SHA INSTALLED RUNNING NO_GH NO_OP GH_AUTH GH_DL_FAIL OP_SIGNED OP_URL QUIT_OK MV_FAIL CURRENT_URL
}

app_version() {
    /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${APPS}/DMC.app/Contents/Info.plist" 2>/dev/null || echo none
}
leftovers() { find "${APPS}" -mindepth 1 -maxdepth 1 ! -name DMC.app -exec basename {} \;; }

echo "AC1 pinned data"
assert_eq "8.0.0" "$(chezmoi --source "${SRC}" execute-template '{{ .dmc.app.version }}')" "dmc.app.version is exposed"
assert_eq "64" "$(chezmoi --source "${SRC}" execute-template '{{ .dmc.app.sha256 }}' | tr -d '\n' | wc -c | tr -d ' ')" "dmc.app.sha256 is 64 hex chars"
assert_eq "yes" "$(chezmoi --source "${SRC}" execute-template '{{ .dmc.app.sha256 }}' | grep -qE '^[0-9a-f]{64}$' && echo yes || echo no)" "dmc.app.sha256 is lowercase hex"

echo "AC2 template gating and rerun"
G='{"is_mac":true,"is_apple_silicon":true,"user_veberarnaud":true}'
render "${TMPL}" "${G}" > "${WORK}/gated.sh"
if [[ -s "${WORK}/gated.sh" ]]; then ok "gated host renders a script"; else ko "gated host renders a script"; fi
assert_has "${WORK}/gated.sh" "$(chezmoi --source "${SRC}" execute-template '{{ .dmc.app.sha256 }}')" "script embeds the pinned sha256"
assert_has "${WORK}/gated.sh" 'readonly VERSION="8.0.0"' "script embeds the pinned version"
for off in '{"user_veberarnaud":false}' '{"is_apple_silicon":false}' '{"is_mac":false}' '{"user_veberarnaud":false,"user_dmc":true}'; do
    n="$(render "${TMPL}" "${off}" | tr -d '[:space:]' | wc -c | tr -d ' ')"
    assert_eq "0" "${n}" "non-gated host renders nothing: ${off}"
done
v1="$(render "${TMPL}" '{"is_mac":true,"is_apple_silicon":true,"user_veberarnaud":true,"dmc":{"app":{"version":"1.0.0","sha256":"aa"}}}' | shasum | awk '{print $1}')"
v2="$(render "${TMPL}" '{"is_mac":true,"is_apple_silicon":true,"user_veberarnaud":true,"dmc":{"app":{"version":"1.0.1","sha256":"aa"}}}' | shasum | awk '{print $1}')"
if [[ "${v1}" != "${v2}" ]]; then ok "bumping the version changes the rendered script (reruns)"; else ko "bumping the version changes the rendered script"; fi
s1="$(render "${TMPL}" '{"is_mac":true,"is_apple_silicon":true,"user_veberarnaud":true,"dmc":{"app":{"version":"1.0.0","sha256":"aa"}}}' | shasum | awk '{print $1}')"
s2="$(render "${TMPL}" '{"is_mac":true,"is_apple_silicon":true,"user_veberarnaud":true,"dmc":{"app":{"version":"1.0.0","sha256":"bb"}}}' | shasum | awk '{print $1}')"
if [[ "${s1}" != "${s2}" ]]; then ok "bumping the sha256 changes the rendered script (reruns)"; else ko "bumping the sha256 changes the rendered script"; fi

echo "AC3 already at the pinned version"
INSTALLED="${VERSION}" run_case
assert_eq "0" "${RC}" "exit 0"
assert_has "${T}/out.log" "already installed" "reports already installed"
assert_lacks "${T}/calls.log" "release download" "no download"
assert_eq "yes" "$([[ -f "${APPS}/DMC.app/marker" ]] && echo yes || echo no)" "installed bundle untouched"

echo "AC4 gh missing or not authenticated"
INSTALLED="1.0.0" NO_GH=1 run_case
assert_eq "0" "${RC}" "no gh: exit 0"
assert_has "${T}/out.log" "run \`gh auth login\`, then \`chezmoi apply\`" "no gh: one-line warning"
assert_eq "1.0.0" "$(app_version)" "no gh: app untouched"
INSTALLED="1.0.0" GH_AUTH=0 run_case
assert_eq "0" "${RC}" "gh unauthenticated: exit 0"
assert_has "${T}/out.log" "run \`gh auth login\`, then \`chezmoi apply\`" "gh unauthenticated: warning"
assert_lacks "${T}/calls.log" "release download" "gh unauthenticated: no download"
assert_eq "1.0.0" "$(app_version)" "gh unauthenticated: app untouched"
GH_DL_FAIL=1 INSTALLED="1.0.0" run_case
assert_eq "0" "${RC}" "download failure: exit 0"
assert_has "${T}/out.log" "Could not download" "download failure: warning"
assert_eq "1.0.0" "$(app_version)" "download failure: app untouched"

echo "AC5/AC9 fresh install, download call, cleanup"
run_case
assert_eq "0" "${RC}" "exit 0"
assert_has "${T}/calls.log" "gh release download v${VERSION} -R dmc-ai/dmc -p DMC-${VERSION}-macOS-arm64.zip" "gh release download arguments"
assert_eq "${VERSION}" "$(app_version)" "app installed at the pinned version"
assert_eq "" "$(leftovers)" "no .new/.old leftovers in the apps dir"
assert_eq "" "$(ls -A "${T}/tmp")" "mktemp dir removed by the trap"
assert_lacks "${T}/calls.log" "osascript" "app not running: no quit"
assert_lacks "${T}/calls.log" "open " "app not running: no relaunch"
assert_has "${T}/calls.log" "xattr -dr com.apple.quarantine ${APPS}/DMC.app" "quarantine flag cleared (xattr failure tolerated)"
assert_has "${T}/out.log" "Always Allow" "mentions the Keychain prompt"

echo "AC6 checksum mismatch"
SHA="$(printf 'x%.0s' {1..64})" INSTALLED="1.0.0" run_case
assert_eq "0" "${RC}" "exit 0"
assert_has "${T}/out.log" "Checksum mismatch" "log_error on mismatch"
assert_eq "1.0.0" "$(app_version)" "installed app untouched"
assert_eq "yes" "$([[ -f "${APPS}/DMC.app/marker" ]] && echo yes || echo no)" "installed bundle is the original one"
assert_eq "" "$(leftovers)" "nothing staged in the apps dir"
assert_eq "" "$(ls -A "${T}/tmp")" "mktemp dir removed on abort"

echo "AC7 bundle without the executable"
ZIP_KIND=noexe SHA="${NOEXE_SHA}" INSTALLED="1.0.0" run_case
assert_eq "0" "${RC}" "exit 0"
assert_has "${T}/out.log" "does not contain" "warns about the missing executable"
assert_eq "1.0.0" "$(app_version)" "installed app untouched"

echo "AC8/AC10 update while the app runs"
RUNNING=1 INSTALLED="1.0.0" run_case
assert_eq "0" "${RC}" "exit 0"
assert_has "${T}/calls.log" 'osascript -e quit app id "ai.dmc.menubar"' "graceful quit through osascript"
assert_has "${T}/calls.log" "open ${APPS}/DMC.app" "relaunched after the update"
assert_eq "${VERSION}" "$(app_version)" "updated"
assert_eq "no" "$([[ -f "${APPS}/DMC.app/marker" ]] && echo yes || echo no)" "old bundle replaced"
assert_eq "" "$(leftovers)" "old bundle removed once the new one is in place"

echo "AC8 app refuses to quit"
RUNNING=1 QUIT_OK=0 INSTALLED="1.0.0" run_case
assert_eq "0" "${RC}" "exit 0"
assert_has "${T}/out.log" "did not quit" "warns after the bounded wait"
assert_eq "15" "$(grep -c '^sleep' "${T}/calls.log")" "waits 15 times (bounded)"
assert_eq "1.0.0" "$(app_version)" "app untouched"
assert_eq "" "$(leftovers)" "staged bundle cleaned"
assert_lacks "${T}/calls.log" "open " "no relaunch when aborting"

echo "AC9 failure while swapping"
MV_FAIL=1 INSTALLED="1.0.0" run_case
assert_eq "0" "${RC}" "exit 0"
assert_has "${T}/out.log" "Restoring the previous one" "warns and restores"
assert_eq "1.0.0" "$(app_version)" "previous app back in place"
assert_eq "yes" "$([[ -f "${APPS}/DMC.app/marker" ]] && echo yes || echo no)" "previous bundle is the original one"
assert_eq "" "$(leftovers)" "no leftovers"
MV_FAIL=1 RUNNING=1 INSTALLED="1.0.0" run_case
assert_eq "1.0.0" "$(app_version)" "swap failure while running: still has an app"
assert_has "${T}/calls.log" "open ${APPS}/DMC.app" "swap failure while running: previous app relaunched"

echo "AC9 cannot move the installed app aside"
MV_FAIL=2 RUNNING=1 INSTALLED="1.0.0" run_case
assert_eq "0" "${RC}" "exit 0"
assert_has "${T}/out.log" "Could not move the installed DMC.app aside" "warns"
assert_eq "1.0.0" "$(app_version)" "installed app untouched"
assert_eq "yes" "$([[ -f "${APPS}/DMC.app/marker" ]] && echo yes || echo no)" "installed bundle is the original one"
assert_eq "" "$(leftovers)" "staged bundle cleaned"
assert_has "${T}/calls.log" "open ${APPS}/DMC.app" "app relaunched after the quit"

echo "AC11 baseURL from 1Password"
INSTALLED="${VERSION}" OP_URL="https://dmc.example.invalid/" run_case
assert_has "${T}/calls.log" "op read op://Personal/DMC/website" "reads op://Personal/DMC/website"
assert_has "${T}/calls.log" "defaults write ai.dmc.menubar baseURL -string https://dmc.example.invalid" "defaults write with the trailing slash stripped"
assert_lacks "${T}/out.log" "dmc.example.invalid" "URL is not logged"
INSTALLED="${VERSION}" OP_URL="https://dmc.example.invalid/" CURRENT_URL="https://dmc.example.invalid" run_case
assert_lacks "${T}/calls.log" "defaults write" "no write when already set"
INSTALLED="${VERSION}" NO_OP=1 run_case
assert_eq "0" "${RC}" "no op: exit 0"
assert_has "${T}/out.log" "1Password CLI not found" "no op: warning"
assert_lacks "${T}/calls.log" "defaults write" "no op: no write"
INSTALLED="${VERSION}" OP_SIGNED=0 run_case
assert_eq "0" "${RC}" "op signed out: exit 0"
assert_has "${T}/out.log" "Not signed in to 1Password" "op signed out: warning"
assert_lacks "${T}/calls.log" "op read" "op signed out: no read"
INSTALLED="${VERSION}" OP_URL="" run_case
assert_eq "0" "${RC}" "empty URL: exit 0"
assert_has "${T}/out.log" "DMC URL not found" "empty URL: warning"
assert_lacks "${T}/calls.log" "defaults write" "empty URL: no write"
OP_SIGNED=0 INSTALLED="1.0.0" run_case
assert_eq "${VERSION}" "$(app_version)" "baseURL skipped: install still happens"

echo "AC13 no Keychain access"
OP_URL="https://dmc.example.invalid" run_case
assert_lacks "${T}/calls.log" "security" "security never called"
if grep -nE '(^|[^a-z_])security (add|find|delete|import|unlock)|SecItem|keychain' "${WORK}/gated.sh" | grep -v '^[0-9]*:#' | grep -qv 'Keychain access once'; then
    ko "script has no Keychain command"
else
    ok "script has no Keychain command"
fi
assert_eq "0" "$(grep -cE 'https?://' "${WORK}/gated.sh")" "no URL hard-coded in the rendered script"

echo "AC12 login item block"
for f in ${AUTOSTART}; do
    n="$(render "${f}" '{"is_mac":true,"is_apple_silicon":true,"user_veberarnaud":true}' | grep -c 'DMC' || true)"
    if [[ "${n}" -gt 0 ]]; then ok "gated host: autostart has a DMC block"; else ko "gated host: autostart has a DMC block"; fi
    n="$(render "${f}" '{"is_mac":true,"is_apple_silicon":true,"user_veberarnaud":false}' | grep -c 'DMC' || true)"
    assert_eq "0" "${n}" "non-gated host: autostart has no DMC block"
    n="$(render "${f}" '{"is_mac":true,"is_apple_silicon":false,"user_veberarnaud":true}' | grep -c 'DMC' || true)"
    assert_eq "0" "${n}" "Intel host: autostart has no DMC block"
done
assert_has "${AUTOSTART}" 'make login item at end with properties {path:"/Applications/DMC.app"' "adds a login item with the app path"
assert_has "${AUTOSTART}" 'get the name of every login item' "checks existing login items first (idempotent)"
assert_has "${AUTOSTART}" 'Could not add DMC.app to the login items' "warns instead of failing"
if render "${AUTOSTART}" '{"is_mac":true,"is_apple_silicon":true,"user_veberarnaud":true}' | bash -n; then ok "rendered autostart parses"; else ko "rendered autostart parses"; fi

echo "AC12 login item block, executed"
# The block is only rendered once the app exists, so run it from the source
# with stubbed log helpers and osascript.
li_dir="${WORK}/loginitem"
mkdir -p "${li_dir}/bin"
awk '/^\{\{ if stat "\/Applications\/DMC.app" -\}\}/{on=1;next} /^\{\{ else -\}\}/{on=0} on' "${AUTOSTART}" > "${li_dir}/block.sh"
if [[ -s "${li_dir}/block.sh" ]]; then ok "login item block extracted"; else ko "login item block extracted"; fi
cat > "${li_dir}/bin/osascript" <<'STUB'
#!/bin/bash
echo "osascript $*" >> "${LI_LOG}"
case "$*" in
    *"get the name of every login item"*) printf '%s\n' "${LI_ITEMS:-}" ;;
    *"make login item"*) [[ "${LI_ADD_FAIL:-0}" == 0 ]] ;;
esac
STUB
chmod +x "${li_dir}/bin/osascript"
run_li() { # items add-fail
    LI_LOG="${li_dir}/log"; : > "${LI_LOG}"
    export LI_LOG LI_ITEMS="$1" LI_ADD_FAIL="$2"
    LI_RC=0
    LI_OUT="$(PATH="${li_dir}/bin:${PATH}" bash -c 'set -euo pipefail
log_info() { echo "INFO $*"; }; log_success() { echo "OK $*"; }; log_warn() { echo "WARN $*"; }
'"$(cat "${li_dir}/block.sh")" 2>&1)" || LI_RC=$?
}
run_li "Dock, Other" 0
assert_eq "0" "${LI_RC}" "not registered: exit 0"
assert_has "${LI_LOG}" 'make login item at end with properties {path:"/Applications/DMC.app"' "not registered: adds the login item"
assert_eq "OK DMC.app set to start at login" "${LI_OUT}" "not registered: reports success"
run_li "Dock, DMC" 0
assert_eq "0" "${LI_RC}" "already registered: exit 0"
assert_lacks "${LI_LOG}" "make login item" "already registered: no second login item (idempotent)"
assert_eq "INFO DMC.app already starts at login" "${LI_OUT}" "already registered: reports it"
run_li "" 1
assert_eq "0" "${LI_RC}" "Automation refused: exit 0"
if [[ "${LI_OUT}" == "WARN Could not add DMC.app to the login items"* ]]; then ok "Automation refused: warns"; else ko "Automation refused: warns (${LI_OUT})"; fi

echo "AC14 verify"
render "${VERIFY}" "${G}" > "${WORK}/verify.sh"
assert_has "${WORK}/verify.sh" 'Print :CFBundleShortVersionString' "gated: reads the installed version"
assert_has "${WORK}/verify.sh" 'is missing' "gated: warns when missing"
assert_has "${WORK}/verify.sh" 'pinned version is' "gated: warns on a version mismatch"
if awk '/Checking DMC.app/,/External dependencies/' "${WORK}/verify.sh" | grep -q 'errors='; then
    ko "verify: DMC.app check never increments errors"
else
    ok "verify: DMC.app check never increments errors"
fi
render "${VERIFY}" '{"user_veberarnaud":false}' > "${WORK}/verify-off.sh"
assert_lacks "${WORK}/verify-off.sh" "DMC.app" "non-gated: no DMC.app check"

echo "AC15/AC16 docs"
D="${ROOT}/docs/dmc-host.md"
assert_has "${D}" "6. DMC menu bar app" "docs/dmc-host.md has the section"
for p in 'gh auth login' 'Always Allow' 'shasum -a 256' 'Keychain' '.chezmoidata/dmc.toml' 'chezmoi apply'; do
    assert_has "${D}" "${p}" "docs/dmc-host.md mentions ${p}"
done
assert_has "${ROOT}/CLAUDE.md" "run_onchange_after_dmc_app.sh.tmpl" "CLAUDE.md lists the script"
assert_has "${ROOT}/CLAUDE.md" ".chezmoidata/" "CLAUDE.md lists .chezmoidata/"
assert_has "${ROOT}/.claude/rules/chezmoi.md" ".dmc.app.version" "chezmoi rules list the pinned data"
assert_has "${ROOT}/README.md" "run_onchange_after_dmc_app.sh.tmpl" "README mentions the install script"

echo
printf '%d passed, %d failed\n' "${pass}" "${fail}"
[[ "${fail}" -eq 0 ]]
