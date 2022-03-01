# ~/.dotfiles

```
# Change ComputerName, LocalHostName & HostName
export NAME="<name>"
sudo scutil --set ComputerName "${NAME}"
sudo scutil --set LocalHostName "${NAME}"
sudo scutil --set HostName "${NAME}"

# install Command Line Developer Tool
/usr/bin/xcode-select --install

# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install chezmoi
brew install chezmoi

# Install & setup 1password-cli
brew install --cask 1password-cli
op account add
eval $(op signin)

# Install dotfiles
chezmoi init --apply veberarnaud

# Change shell to zsh
which zsh | sudo tee -a /etc/shells
chsh -s `which zsh`
```
