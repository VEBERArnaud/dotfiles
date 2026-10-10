# Shell scripting conventions

## Interactive aliases

- In the user's interactive zsh, `rm`, `cp`, `mv` and `ln` are aliased to their `-i` form and ask for confirmation. In an agent shell nobody answers: the command hangs until the tool timeout, then keeps running in the background and can block the end of the session.
- These aliases are skipped when `CLAUDECODE` is set, but never rely on it: in a shell command, use `rm -f`, `cp -f`, `mv -f`, `ln -f`, or `command rm` (`command cp`...) to bypass any alias.

## Bash scripts

- Always start with `set -euo pipefail`
- Use `#!/bin/bash` or `#!/usr/bin/env bash`
- ShellCheck compatible (no SC2086, SC2046 warnings)

## Variable quoting

- Always quote variables: `"${var}"` not `$var`
- Exception: inside `[[ ]]` tests where word splitting doesn't occur

## Functions

- Use `function_name() { }` syntax
- Prefer local variables: `local var="value"`
- Return exit codes, not strings

## Error handling

- Use `trap` for cleanup on error
- Check command existence before use
- Provide meaningful error messages

## Style

- Indent with 4 spaces
- Use lowercase for variables, UPPERCASE for constants
- Descriptive function and variable names
