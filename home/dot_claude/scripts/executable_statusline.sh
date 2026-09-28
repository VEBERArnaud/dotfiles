#!/usr/bin/env bash
# Claude Code status line: model, location, context, cost, rate limits.
# Receives the session JSON on stdin, prints one line.
# Fields: https://code.claude.com/docs/en/statusline

set -euo pipefail
export LC_ALL=C

input=$(cat)

field() {
    echo "${input}" | jq -r "${1} // empty"
}

model=$(field '.model.display_name')
cwd=$(field '.workspace.current_dir')
worktree=$(field '.workspace.git_worktree')
context=$(field '.context_window.used_percentage')
cost=$(field '.cost.total_cost_usd')
five_hour=$(field '.rate_limits.five_hour.used_percentage')
seven_day=$(field '.rate_limits.seven_day.used_percentage')

#######################################
# Location: repo, or parent/child for a worktree, then the branch
#######################################

location=$(basename "${cwd:-?}")
if [[ -n "${worktree}" ]]; then
    location="$(basename "$(dirname "${cwd}")")/${location}"
fi
branch=$(git -C "${cwd:-.}" branch --show-current 2>/dev/null || true)
[[ -n "${branch}" ]] && location="${location} ${branch}"

#######################################
# Colours: green under 50 %, yellow under 80 %, red above
#######################################

reset=$'\033[0m'
dim=$'\033[2m'

colour_for() {
    local value="${1%.*}"
    if (( value >= 80 )); then
        printf '\033[31m'
    elif (( value >= 50 )); then
        printf '\033[33m'
    else
        printf '\033[32m'
    fi
}

#######################################
# Assemble
#######################################

parts=("${model:-Claude}" "${location}")

if [[ -n "${context}" ]]; then
    parts+=("$(colour_for "${context}")ctx ${context%.*}%${reset}")
fi

if [[ -n "${cost}" ]]; then
    parts+=("$(printf '$%.2f' "${cost}")")
fi

if [[ -n "${five_hour}" ]]; then
    limits="5h ${five_hour%.*}%"
    [[ -n "${seven_day}" ]] && limits="${limits} 7d ${seven_day%.*}%"
    parts+=("$(colour_for "${five_hour}")${limits}${reset}")
fi

separator=" ${dim}·${reset} "
line="${parts[0]}"
for part in "${parts[@]:1}"; do
    line="${line}${separator}${part}"
done

printf '%s\n' "${line}"
