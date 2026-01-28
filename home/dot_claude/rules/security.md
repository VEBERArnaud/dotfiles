# Security rules

## Secrets management

- Never hardcode secrets, tokens, API keys, passwords
- Use environment variables for sensitive configuration
- Check for secrets before committing (no .env, credentials.json, etc.)

## File permissions

- Config files with secrets: 600
- Never use `chmod 777` or `chmod -R 777`

## Patterns to avoid

- Logging sensitive data
- Storing secrets in git history
- Exposing internal paths or infrastructure details
- Running untrusted scripts without review

## Verification

- Review diffs for accidental secret exposure
- Use `git diff --staged` before committing
- Check `.gitignore` includes sensitive files
