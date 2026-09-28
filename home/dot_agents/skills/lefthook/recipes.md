# Lefthook recipes

Job snippets per ecosystem, composed into a `lefthook.yml` by the [lefthook skill](SKILL.md). Every snippet uses the `jobs:` syntax. `root:` keeps a trailing slash: the command runs from that directory and `{staged_files}` is filtered to the files under it, passed relative to it; the job is skipped when no staged file is under it. Globs always match from the git root, whatever `root` says. A `glob` without a slash matches the file name in any directory; `**` matches one or more directories, so `tf/**/*.tf` misses `tf/main.tf` (use `root: "tf/"` with `glob: "*.tf"` instead).

## Where to look, per unit

| Marker | Runner | Formatter | Lint and types | Tests |
| --- | --- | --- | --- | --- |
| `package.json` | `packageManager` field, else the lockfile: `bun.lock` or `bun.lockb` → bun, `pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, else npm | `biome.json` → biome; `.prettierrc*` or `prettier.config.*` → prettier | scripts `lint` or `check`; `typecheck`, `type-check` or `check-types`; an eslint config | scripts `test:unit` or `test`; a vitest or jest config |
| `Cargo.toml` | cargo | rustfmt | cargo clippy | cargo test |
| `go.mod` | go | gofmt | go vet; golangci-lint when `.golangci.*` exists | go test |
| `composer.json` | composer | pint or php-cs-fixer, by config file | phpstan when `phpstan.neon*` exists | composer script `test`, else phpunit |
| `*.tf` directory | terraform | terraform fmt | tflint when `.tflint.hcl` exists; `validate` only when `.terraform/` exists (needs init) | none |
| `Package.swift` | swift | swift-format when installed | swift build | swift test |
| shell scripts (bash shebang or `.sh`) | | shfmt when installed | shellcheck | |
| `*.yml`, `*.yaml` | | | yamllint | |
| `*.toml` | | | taplo | |

Exec forms: bun → `bun run <script>` and `bunx <tool>`; pnpm → `pnpm run` and `pnpm exec`; yarn → `yarn run` and `yarn exec`; npm → `npm run` and `npx`.

## JavaScript with biome

```yaml
pre-commit:
  parallel: true
  jobs:
    - name: biome
      glob: "*.{js,jsx,ts,tsx,json,jsonc}"
      run: pnpm exec biome check --write {staged_files}
      stage_fixed: true
    - name: typecheck
      glob: "*.{ts,tsx}"
      run: pnpm run typecheck

pre-push:
  parallel: true
  jobs:
    - name: tests
      run: pnpm test
```

## JavaScript with prettier, eslint and tsc

```yaml
pre-commit:
  parallel: true
  jobs:
    - name: prettier
      glob: "*.{js,jsx,ts,tsx,json,md,yml,yaml,css}"
      run: pnpm exec prettier --write {staged_files}
      stage_fixed: true
    - name: eslint
      glob: "*.{js,jsx,ts,tsx}"
      run: pnpm exec eslint {staged_files}
    - name: typecheck
      glob: "*.{ts,tsx}"
      run: pnpm run type-check
```

## Monorepo: one job per unit with root

```yaml
pre-commit:
  parallel: true
  jobs:
    - name: backend eslint
      root: "backend/"
      glob: "*.ts"
      run: pnpm exec eslint {staged_files}
    - name: frontend eslint
      root: "frontend/"
      glob: "*.{ts,tsx}"
      run: pnpm exec eslint {staged_files}

pre-push:
  parallel: true
  jobs:
    - name: backend tests
      root: "backend/"
      run: pnpm test
    - name: frontend tests
      root: "frontend/"
      run: pnpm test
```

## Rust

```yaml
pre-commit:
  parallel: true
  jobs:
    - name: rustfmt
      glob: "*.rs"
      run: cargo fmt -- {staged_files}
      stage_fixed: true
    - name: clippy
      glob: "*.rs"
      run: cargo clippy --all-targets -- -D warnings

pre-push:
  jobs:
    - name: tests
      run: cargo test
```

## Go

```yaml
pre-commit:
  parallel: true
  jobs:
    - name: gofmt
      glob: "*.go"
      run: gofmt -l -w {staged_files}
      stage_fixed: true
    - name: go vet
      glob: "*.go"
      run: go vet ./...

pre-push:
  jobs:
    - name: tests
      run: go test ./...
```

## PHP

```yaml
pre-commit:
  parallel: true
  jobs:
    - name: pint
      glob: "*.php"
      run: vendor/bin/pint {staged_files}
      stage_fixed: true
    - name: phpstan
      glob: "*.php"
      run: vendor/bin/phpstan analyse --no-progress {staged_files}

pre-push:
  jobs:
    - name: tests
      run: composer test
```

## Terraform in a subdirectory of another project

```yaml
pre-commit:
  parallel: true
  jobs:
    - name: terraform fmt
      root: "tf/"
      glob: "*.tf"
      run: terraform fmt {staged_files}
      stage_fixed: true
    - name: tflint
      root: "tf/"
      glob: "*.tf"
      run: tflint
```

## Shell, YAML and TOML

```yaml
pre-commit:
  parallel: true
  jobs:
    - name: shellcheck
      glob: "*.sh"
      run: shellcheck -s bash {staged_files}
    - name: yamllint
      glob: "*.{yml,yaml}"
      run: yamllint -d relaxed {staged_files}
    - name: taplo
      glob: "*.toml"
      run: taplo lint {staged_files}
```

## Worked example

The dotfiles repository's `lefthook.yml`: chezmoi templates rendered with `chezmoi execute-template` before shellcheck, taplo and yamllint scoped like its CI workflow, whole-source validation in pre-push.
