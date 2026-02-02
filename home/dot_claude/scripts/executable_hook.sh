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
}

#######################################
# Hook handlers
#######################################

handle_stop() {
    local stop_hook_active
    stop_hook_active=$(echo "${input}" | jq -r '.stop_hook_active // false')

    if [[ "${stop_hook_active}" != "true" ]]; then
        notify "Claude has finished"
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

#######################################
# Main routing
#######################################

case "${hook_event}" in
    "Stop")              handle_stop ;;
    "PermissionRequest") handle_permission_request ;;
    "Notification")      handle_notification ;;
    *)
        # Fallback for direct invocation
        [[ -n "${1:-}" ]] && notify "$1"
        ;;
esac

exit 0
