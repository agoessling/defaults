#!/bin/bash

# Exit on errors, undefined variables, and pipe failures.
set -euo pipefail
trap 'echo "ERROR: ${BASH_SOURCE[0]}:${LINENO}: ${BASH_COMMAND}" >&2' ERR

info()  { printf '\033[1;34m%s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m%s\033[0m\n' "$*"; }

install_if_missing() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"

  if [ -e "$dst" ]; then
    info "Skipping copy: $dst already exists"
  else
    cp "$src" "$dst"
    ok "Installed: $dst"
  fi
}

source "$(dirname "$0")/terminal_config.sh"

# install apt packages.
sudo apt-get update
sudo apt-get -y install --no-install-recommends \
    git \
    python3-pip \
    tmux \
    dconf-cli \
    uuid-runtime \
    npm \
    python3-venv \
    ripgrep \
    libfuse2

# Install tmux configuration.
cp tmux/.tmux.conf ~/
mkdir -p ~/.tmux
cp tmux/tmux-colorscheme.conf ~/.tmux/
if [ ! -d ~/.tmux/plugins/tpm ]; then
  git clone --depth=1 https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

# Install Chrome.
if ! dpkg -s google-chrome-stable >/dev/null 2>&1; then
  tmpdeb="$(mktemp --suffix=.deb)"
  wget -O "$tmpdeb" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  sudo dpkg -i "$tmpdeb" || sudo apt-get -y -f install
  rm -f "$tmpdeb"
fi

# Swap Caps-Lock with Escape.
if ! grep -q 'setxkbmap -option caps:escape' ~/.profile; then
  echo "" >> ~/.profile
  echo "# Make Caps-Lock a second Escape." >> ~/.profile
  echo "setxkbmap -option caps:escape" >> ~/.profile
fi

# Install recent NeoVim (AppImage) - atomic install + basic sanity checks
if ! command -v nvim &> /dev/null; then
  tmp="$(mktemp)"
  url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage"

  # Download to temp first; fail if HTTP error; retry transient issues
  wget --https-only --tries=5 --timeout=20 --waitretry=2 \
       -O "$tmp" "$url"

  # Ensure non-empty file.
  test -s "$tmp"

  # Install atomically with proper permissions.
  sudo install -m 0755 "$tmp" /usr/local/bin/nvim
  rm -f "$tmp"

  # Smoke test.
  /usr/local/bin/nvim --version >/dev/null
fi

# Install NVIM configuration.
if [ ! -d ~/.config/nvim ]; then
  git clone https://github.com/agoessling/nvim_config.git ~/.config/nvim
else
  git -C ~/.config/nvim pull --ff-only
fi

# Install Vscode.
install_vscode() {
  if command -v code >/dev/null 2>&1; then
    echo "VS Code already installed: $(code --version | head -n 1)"
    return 0
  fi

  sudo apt-get update
  sudo apt-get install -y wget gpg apt-transport-https

  # Microsoft signing key
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor \
    | sudo tee /usr/share/keyrings/packages.microsoft.gpg >/dev/null

  # VS Code apt repo
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null

  sudo apt-get update
  sudo apt-get install -y code

  echo "Installed VS Code: $(code --version | head -n 1)"
}

install_vscode

# Download patched fonts.
mkdir -p ~/.local/share/fonts
wget -nc -q --show-progress -P ~/.local/share/fonts https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Hack/Regular/HackNerdFont-Regular.ttf
wget -nc -q --show-progress -P ~/.local/share/fonts https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Hack/Bold/HackNerdFont-Bold.ttf
wget -nc -q --show-progress -P ~/.local/share/fonts https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Hack/Italic/HackNerdFont-Italic.ttf
wget -nc -q --show-progress -P ~/.local/share/fonts https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Hack/BoldItalic/HackNerdFont-BoldItalic.ttf

# Setup terminal colorscheme
setup_gruvbox_colors

# Change default font for gnome terminal
set_font "$uuid" "Hack Nerd Font 10"

# Configure Bash
install_if_missing ".bash_aliases" "$HOME/.bash_aliases"
if ! grep -q 'Custom bashrc additions' ~/.bashrc; then
  cat .bashrc >> ~/.bashrc
fi

# Configure Git
install_if_missing ".gitconfig" "$HOME/.gitconfig"
