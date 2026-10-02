#!/bin/bash
set -euo pipefail

# Unified hook dispatcher for Claude Code

#######################################
# Parse JSON input
#######################################

if [[ -t 0 ]]; then
    input="{}"
else
    input=$(cat)
fi

hook_event=$(echo "${input}" | jq -r '.hook_event_name // empty')
session_id=$(echo "${input}" | jq -r '.session_id // empty')
hook_cwd=$(echo "${input}" | jq -r '.cwd // empty')

#######################################
# Compute context
#######################################

get_subtitle() {
    local project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"

    if [[ -f "${project_dir}/.git" ]]; then
        # Worktree: parent/child
        echo "$(basename "$(dirname "${project_dir}")")/$(basename "${project_dir}")"
    else
        # Regular repo: child only
        basename "${project_dir}"
    fi
}

subtitle=$(get_subtitle)

#######################################
# Notification
#######################################

notify() {
    local message="${1:-Claude Code}"

    if command -v terminal-notifier &> /dev/null; then
        local args=(-title "Claude Code" -subtitle "${subtitle}" -message "${message}")
        [[ -n "${session_id}" ]] && args+=(-group "${session_id}")
        terminal-notifier "${args[@]}" > /dev/null 2>&1
    else
        osascript -e "display notification \"${message}\" with title \"${subtitle}\""
    fi

    mark_tmux_notification
}

mark_tmux_notification() {
    if [[ -n "${TMUX:-}" ]]; then
        tmux set-option @claude-notif 1 2>/dev/null || true
    fi
}

#######################################
# Lefthook quality gates
#
# A repository opts in by carrying a lefthook config (main or -local).
# No config, no lefthook binary or no git repository: the gate is skipped
# silently, so Claude keeps working in any repository.
#######################################

repo_root() {
    git -C "${hook_cwd:-$(pwd)}" rev-parse --show-toplevel 2>/dev/null || true
}

has_lefthook_config() {
    local root="${1}"
    local file

    command -v lefthook &> /dev/null || return 1
    for file in "${root}"/{,.}lefthook{,-local}.{yml,yaml,toml,json}; do
        [[ -f "${file}" ]] && return 0
    done
    return 1
}

# True when git itself already runs lefthook for this hook (lefthook install)
git_hook_installed() {
    local root="${1}"
    local hook="${2}"
    local hooks_dir

    hooks_dir=$(git -C "${root}" rev-parse --path-format=absolute --git-path hooks 2>/dev/null) || return 1
    [[ -f "${hooks_dir}/${hook}" ]] && grep -q lefthook "${hooks_dir}/${hook}"
}

# Uncommitted changes, or commits not pushed to the upstream branch
has_unverified_changes() {
    local root="${1}"
    local upstream

    [[ -n "$(git -C "${root}" status --porcelain 2>/dev/null)" ]] && return 0
    # No upstream yet: nothing has been pushed
    upstream=$(git -C "${root}" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null) || return 0
    [[ "$(git -C "${root}" rev-list --count "${upstream}..HEAD" 2>/dev/null || echo 0)" -gt 0 ]]
}

# Every changed file, staged or not: Claude often stages and commits in the
# same command, so the index alone would miss what the commit will contain
changed_files() {
    git -C "${1}" status --porcelain --untracked-files=all 2>/dev/null \
        | awk '$1 !~ /D/ { print $NF }'
}

# --no-auto-install: the gate only needs the config, it never writes git
# hooks into the clone. Output limited to failures, it ends up in a reason.
run_lefthook_stage() {
    local root="${1}"
    local stage="${2}"
    shift 2

    (cd "${root}" && NO_COLOR=1 LEFTHOOK_OUTPUT=failure,execution_out \
        lefthook run "${stage}" --no-tty --colors off --no-auto-install "$@" 2>&1)
}

# Last 3000 characters of a command output, without ANSI escapes
tail_output() {
    printf '%s' "${1}" | sed -E "s/$(printf '\033')\[[0-9;]*m//g" | tail -c 3000
}

deny_tool_use() {
    jq -n --arg reason "${1}" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: $reason
        }
    }'
}

block_stop() {
    jq -n --arg reason "${1}" '{decision: "block", reason: $reason}'
}

# A DMC run worktree (<repo>.wt/dmc-<workflow>-<run>): the workflow gates on
# its own (validate, create-pr), and a blocked stop would replace the agent's
# final reply, whose STATUS line the orchestrator routes on
is_dmc_worktree() {
    [[ "$(basename "${1}")" == dmc-* && "$(dirname "${1}")" == *.wt ]]
}

#######################################
# Hook handlers
#######################################

handle_stop() {
    local root output stop_hook_active

    root=$(repo_root)
    if [[ -n "${root}" ]] && ! is_dmc_worktree "${root}" \
        && has_lefthook_config "${root}" && has_unverified_changes "${root}"; then
        # --force: run even when nothing is pending for push
        if ! output=$(run_lefthook_stage "${root}" pre-push --force); then
            # Only the last reply reaches an orchestrator: it must carry the
            # original conclusion, not just the fix
            block_stop "pre-push checks failed, fix them before finishing, then restate your complete final reply:
$(tail_output "${output}")"
            return 0
        fi
    fi

    stop_hook_active=$(echo "${input}" | jq -r '.stop_hook_active // false')
    if [[ "${stop_hook_active}" != "true" ]]; then
        notify "Claude has finished"
    fi
}

handle_pre_tool_use() {
    local tool_name command root output file

    tool_name=$(echo "${input}" | jq -r '.tool_name // empty')
    [[ "${tool_name}" == "Bash" ]] || return 0

    command=$(echo "${input}" | jq -r '.tool_input.command // empty')
    [[ "${command}" =~ (^|[^[:alnum:]_.-])git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?commit([[:space:]]|$) ]] || return 0

    # Only the lines that run git commit are inspected: a commit message or
    # a heredoc mentioning the flag must not trigger a denial
    if grep -E 'git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?commit([[:space:]]|$)' <<< "${command}" \
        | grep -qE -- '--no-verify|[[:space:]]-n([[:space:]]|$)'; then
        deny_tool_use "Commit with --no-verify is not allowed: the pre-commit checks must run"
        return 0
    fi

    root=$(repo_root)
    [[ -n "${root}" ]] || return 0
    has_lefthook_config "${root}" || return 0
    # Installed git hook: git runs pre-commit itself, no need to run it twice
    git_hook_installed "${root}" pre-commit && return 0

    local files=()
    while IFS= read -r file; do
        [[ -n "${file}" ]] && files+=(--file "${file}")
    done < <(changed_files "${root}")
    [[ ${#files[@]} -gt 0 ]] || return 0

    if ! output=$(run_lefthook_stage "${root}" pre-commit "${files[@]}"); then
        deny_tool_use "pre-commit checks failed, fix them before committing:
$(tail_output "${output}")"
    fi
}

handle_permission_request() {
    local tool_name
    tool_name=$(echo "${input}" | jq -r '.tool_name // "unknown"')
    notify "Permission needed: ${tool_name}"
}

handle_notification() {
    local notif_type
    notif_type=$(echo "${input}" | jq -r '.notification_type // empty')

    case "${notif_type}" in
        "elicitation_dialog") notify "Claude needs your input" ;;
        # Other types ignored (redundant with PermissionRequest or not useful)
        *) ;;
    esac
}

handle_worktree_create() {
    local name cwd
    name=$(echo "${input}" | jq -r '.name // empty')
    cwd=$(echo "${input}" | jq -r '.cwd // empty')

    [[ -z "${name}" ]] && { echo "Missing name" >&2; exit 1; }

    # Delegate to standalone script
    # stdout passthrough: wt-create prints the path, hook forwards it to Claude
    wt-create --cwd "${cwd}" "${name}"
}

handle_worktree_remove() {
    local worktree_path
    worktree_path=$(echo "${input}" | jq -r '.worktree_path // empty')

    [[ -z "${worktree_path}" ]] && return 0

    # Delegate to standalone script (tolerant to failures)
    wt-remove --force "${worktree_path}" 2>/dev/null || true
}

#######################################
# Main routing
#######################################

case "${hook_event}" in
    "Stop")              handle_stop ;;
    "PreToolUse")        handle_pre_tool_use ;;
    "PermissionRequest") handle_permission_request ;;
    "Notification")      handle_notification ;;
    "WorktreeCreate")    handle_worktree_create ;;
    "WorktreeRemove")    handle_worktree_remove ;;
    *)
        # Fallback for direct invocation
        [[ -n "${1:-}" ]] && notify "$1"
        ;;
esac

exit 0
