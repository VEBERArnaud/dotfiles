# Shell scripting conventions

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
