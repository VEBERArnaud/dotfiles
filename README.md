# ~/.dotfiles

## dotfiles

### Installation

Using [GNU Stow](http://www.gnu.org/software/stow/):

```bash
git clone https://github.com/VEBERArnaud/dotfiles ~/.dotfiles
cd ~/.dotfiles
make install
```

### Uninstallation

```bash
cd ~/.dotfiles
make uninstall
```

## Mac setup

### Sensible macOS defaults

When setting up a new Mac, you may want to set some sensible macOS defaults:

```bash
./.macos
```

### Install Homebrew Formulae/Native apps

```bash
./.brew 2>/dev/null
```
