---
name: brew-add
description: Add a Homebrew package or Mac App Store app to dotfiles
disable-model-invocation: true
allowed-tools: Read, Edit, Bash, AskUserQuestion
argument-hint: [package-name or mas app name/id]
---

# Homebrew Package Adder

Add a Homebrew formula, cask, or Mac App Store app to the dotfiles installation script.

## Target file

`home/.chezmoiscripts/packages/run_before_darwin_homebrew.sh.tmpl`

## Process

1. Get package name from arguments: `$ARGUMENTS`
2. Check all sources in parallel to determine availability:
   - Formula (brew): `brew info --json=v2 $ARGUMENTS | jq '.formulae'`
   - Cask: `brew info --json=v2 --cask $ARGUMENTS | jq '.casks'`
   - Mac App Store: `mas search $ARGUMENTS` or `mas info $ARGUMENTS` (if numeric ID)
3. If available in multiple sources (e.g., brew and cask, cask and mas, or all three), ask the user which one they prefer using AskUserQuestion with the available options
4. Read the Homebrew script
5. Find the appropriate list:
   - `$brews` for formulae
   - `$casks` for casks
   - `$mas_apps` for Mac App Store apps (dict with ID as key, app name as value)
6. Check if already present
7. Add in alphabetical order within the list
8. If package is tool-specific (e.g., Go tool), add in conditional block:
   ```go
   {{- if .with_golang -}}
   {{-   $brews = concat $brews (list "new-go-tool") -}}
   {{- end -}}
   ```

## Mac App Store apps

The `$mas_apps` variable is a `dict` mapping app ID (string) to app name:

```go
{{- $mas_apps := dict
    "904280696" "Things 3"
-}}
```

To add a new entry, add a new `"id" "Name"` pair in the dict, sorted by ID.

## Output

- If already present: inform user
- If added: show the edit made
- If package not found: error with suggestion

## Example usage

```
/brew-add htop           # Adds to $brews
/brew-add slack          # Adds to $casks
/brew-add golangci-lint  # Adds to conditional Go block
/brew-add Things         # Search mas, adds to $mas_apps
/brew-add 904280696      # Add mas app by ID
```

## Notes

- Maintain alphabetical order in lists (by ID for mas apps)
- Use existing conditional patterns for tool-specific packages
- Always include app name in `$mas_apps` dict for readability
- Run `chezmoi diff` after to verify change
