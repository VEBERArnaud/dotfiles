---
name: brew-add
description: Add a Homebrew package to dotfiles
disable-model-invocation: true
allowed-tools: Read, Edit, Bash
argument-hint: [package-name]
---

# Homebrew Package Adder

Add a Homebrew formula or cask to the dotfiles installation script.

## Target file

`home/.chezmoiscripts/packages/run_before_darwin_homebrew.sh.tmpl`

## Process

1. Get package name from arguments: `$ARGUMENTS`
2. Check if package exists: `brew info $ARGUMENTS`
3. Determine package type:
   - Formula (brew): `brew info --json=v2 $ARGUMENTS | jq '.formulae'`
   - Cask: `brew info --json=v2 --cask $ARGUMENTS | jq '.casks'`
4. Read the Homebrew script
5. Find the appropriate list:
   - `$brews` for formulae
   - `$casks` for casks
6. Check if already present
7. Add in alphabetical order within the list
8. If package is tool-specific (e.g., Go tool), add in conditional block:
   ```go
   {{- if .with_golang -}}
   {{-   $brews = concat $brews (list "new-go-tool") -}}
   {{- end -}}
   ```

## Output

- If already present: inform user
- If added: show the edit made
- If package not found: error with suggestion

## Example usage

```
/brew-add htop        # Adds to $brews
/brew-add slack       # Adds to $casks
/brew-add golangci-lint  # Adds to conditional Go block
```

## Notes

- Maintain alphabetical order in lists
- Use existing conditional patterns for tool-specific packages
- Run `chezmoi diff` after to verify change
