# Git conventions

## Commit format

Use conventional commits: `type(scope): subject`

### Types

- `feat`: new feature
- `fix`: bug fix
- `docs`: documentation only
- `style`: formatting, no code change
- `refactor`: code change without feat/fix
- `perf`: performance improvement
- `test`: adding or fixing tests
- `chore`: maintenance, build, tooling

### Subject rules

- Imperative mood: "add" not "added" or "adds"
- Lowercase first letter
- No trailing period
- Max 72 characters
- Describe what, not how

### Examples

```
feat(auth): add OAuth2 login support
fix(api): handle null response from server
docs(readme): update installation instructions
refactor(utils): extract date formatting logic
```

## Branching

- Main branch: `main`
- Feature branches: `feature/short-description`
- Bugfix branches: `fix/short-description`
- Prefer rebase over merge for feature branches

## Safety rules

- Never force push on main/master
- Always sign commits with GPG
- Review changes before committing
