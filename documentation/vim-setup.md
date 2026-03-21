# Vim Setup

Vim is configured via `home/dot_vimrc.tmpl` with [vim-plug](https://github.com/junegunn/vim-plug) as plugin manager. Plugins are installed automatically by the `run_onchange_after_vim_plugins.sh.tmpl` script whenever the vimrc content changes.

## Plugins

### Always Installed

| Plugin                           | Description                                   |
| -------------------------------- | --------------------------------------------- |
| `airblade/vim-gitgutter`         | Git diff signs in the gutter                  |
| `bling/vim-airline`              | Status/tabline with powerline fonts           |
| `dense-analysis/ale`             | Asynchronous linting and fixing               |
| `easymotion/vim-easymotion`      | Fast cursor motion                            |
| `editorconfig/editorconfig-vim`  | EditorConfig support                          |
| `edkolev/tmuxline.vim`           | Generate tmux statusline from airline theme   |
| `ervandew/supertab`              | Tab completion in insert mode                 |
| `godlygeek/tabular`              | Text alignment                                |
| `hhff/SpacegrayEighties.vim`     | Color scheme (dark)                           |
| `honza/vim-snippets`             | Snippet collection                            |
| `jiangmiao/auto-pairs`           | Auto-close brackets/quotes                    |
| `jremmen/vim-ripgrep`            | Ripgrep integration (`:Rg`)                   |
| `junegunn/fzf`                   | Fuzzy finder (`:FZF`)                         |
| `junegunn/limelight.vim`         | Focused editing (dims surrounding paragraphs) |
| `MarcWeber/vim-addon-mw-utils`   | Utility library (dependency)                  |
| `markcornick/vim-bats`           | Bats test syntax highlighting                 |
| `ntpeters/vim-better-whitespace` | Highlight trailing whitespace                 |
| `othree/html5.vim`               | HTML5 syntax and completion                   |
| `SirVer/ultisnips`               | Snippet engine                                |
| `terryma/vim-multiple-cursors`   | Multiple cursor editing                       |
| `tomtom/tlib_vim`                | Utility library (dependency)                  |
| `tpope/vim-fugitive`             | Git wrapper (`:Git`, `:Gblame`, etc.)         |
| `tpope/vim-git`                  | Git file types                                |
| `tpope/vim-liquid`               | Liquid template syntax                        |
| `tpope/vim-markdown`             | Markdown syntax and folding                   |
| `tpope/vim-sensible`             | Sensible defaults                             |
| `tpope/vim-surround`             | Surround text objects (cs, ds, ys)            |

### Conditional Plugins

| Plugin                    | Feature Flag       | Description                             |
| ------------------------- | ------------------ | --------------------------------------- |
| `ekalinin/Dockerfile.vim` | `.with_docker`     | Dockerfile syntax                       |
| `fatih/vim-go`            | `.with_golang`     | Go development (auto-installs binaries) |
| `pangloss/vim-javascript` | `.with_javascript` | JavaScript syntax                       |
| `mxw/vim-jsx`             | `.with_javascript` | JSX syntax                              |
| `rust-lang/rust.vim`      | `.with_rust`       | Rust syntax and formatting              |
| `hashivim/vim-terraform`  | `.with_terraform`  | Terraform syntax and fmt                |

## Key Settings

| Setting         | Value                                          | Description                           |
| --------------- | ---------------------------------------------- | ------------------------------------- |
| Color scheme    | SpacegrayEighties                              | Dark theme                            |
| Tab size        | 2 spaces                                       | Expand tabs to spaces                 |
| Color column    | 120                                            | Visual ruler at column 120            |
| Line numbers    | Relative (normal mode), absolute (insert mode) | Auto-toggles                          |
| Font            | Hack 14pt                                      | Powerline-compatible                  |
| Persistent undo | `~/.vimundo`                                   | Undo history survives restart         |
| Swap files      | `~/.vimswap//`                                 | Centralized, not in working directory |

## Key Bindings

| Binding           | Mode   | Action                         |
| ----------------- | ------ | ------------------------------ |
| `,` (leader)      | —      | Leader key                     |
| `jj`              | Insert | Escape to normal mode          |
| `<leader><space>` | Normal | Clear search highlight         |
| `<leader>a`       | Normal | Open ripgrep search (`:Rg`)    |
| `<leader>f`       | Normal | Open fzf (`:FZF`)              |
| `<leader>p`       | Normal | Toggle paste mode              |
| `Ctrl-N`          | Normal | Toggle relative/absolute lines |
| `Ctrl-J/K/L/H`    | Normal | Navigate splits                |
| Arrow keys        | All    | Disabled (use hjkl)            |

## ALE (Linting & Fixing)

- Lints on normal mode text change and insert leave
- Auto-fixes on save
- Signs: `✗` for errors, `⚠` for warnings
- PHP: linters `php`, `phpcs` (PSR2), `phpmd`; fixer `php_cs_fixer`
- Rust: fixer `rustfmt` (when `.with_rust`)
- All files: `remove_trailing_lines`, `trim_whitespace`

## Airline & Tmuxline

- Airline tabline enabled
- Powerline fonts enabled
- Fugitive (git branch) and ALE integration enabled
- Theme: `dark`
- Tmuxline snapshot generated to `~/.tmuxline.conf` on plugin install

## Plugin Installation Script

`run_onchange_after_vim_plugins.sh.tmpl` runs when the vimrc content changes (hash-based). It:

1. Runs `vim +PlugInstall +qall` to install/update plugins
2. Runs `vim +Tmuxline +"TmuxlineSnapshot! ~/.tmuxline.conf" +qall` to regenerate the tmux statusline

## Local Config

`~/.vimrc.local` is sourced at the end of `.vimrc` if it exists, for machine-specific overrides.
