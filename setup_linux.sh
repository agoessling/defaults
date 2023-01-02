#!/bin/bash

# Exit on errors, undefined variables, and pipe failures.
set -euo pipefail

source "$(dirname "$0")/terminal_config.sh"

# Install APT packages.
sudo apt-get update
sudo apt-get -y install \
    git \
    pip \
    tmux \
    dconf-cli \
    uuid-runtime \
    clangd

# Install tmux configuration.
cp tmux/.tmux.conf ~/
mkdir -p ~/.tmux
cp tmux/tmux-colorscheme.conf ~/.tmux/
if [ ! -d ~/.tmux/plugins/tpm ]; then
  git clone --depth=1 https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

# Install Chrome.
if ! dpkg -s google-chrome-stable | grep -q 'Status: install ok installed'; then
  wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  sudo dpkg -i google-chrome-stable_current_amd64.deb
  sudo apt-get -y -f install
  rm google-chrome-stable_current_amd64.deb
fi

# Install pyright for NeoVim LSP.
pip install pyright

# Swap Caps-Lock with Escape.
if ! grep -q 'setxkbmap -option caps:escape' ~/.profile; then
  echo "" >> ~/.profile
  echo "# Make Caps-Lock a second Escape." >> ~/.profile
  echo "setxkbmap -option caps:escape" >> ~/.profile
fi

# Install recent NeoVim
if ! command -v nvim &> /dev/null; then
  wget -q --show-progress -O /tmp/nvim.deb https://github.com/neovim/neovim/releases/download/stable/nvim-linux64.deb
  sudo apt-get install /tmp/nvim.deb
  rm -f /tmp/nvim.deb
fi

# Install NeoVim configuration
mkdir -p ~/.config/nvim
cp -r nvim/* ~/.config/nvim

# Download patched fonts.
mkdir -p ~/.local/share/fonts
wget -nc -q --show-progress -P ~/.local/share/fonts https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Hack/Regular/complete/Hack%20Regular%20Nerd%20Font%20Complete.ttf
wget -nc -q --show-progress -P ~/.local/share/fonts https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Hack/Bold/complete/Hack%20Bold%20Nerd%20Font%20Complete.ttf
wget -nc -q --show-progress -P ~/.local/share/fonts https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Hack/Italic/complete/Hack%20Italic%20Nerd%20Font%20Complete.ttf
wget -nc -q --show-progress -P ~/.local/share/fonts https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Hack/BoldItalic/complete/Hack%20Bold%20Italic%20Nerd%20Font%20Complete.ttf

# Setup terminal colorscheme
setup_gruvbox_colors

# Change default font for gnome terminal
set_font "$uuid" "Hack Nerd Font 10"

# Configure Bash
cp -i .bash_aliases ~/
if ! grep -q 'Custom bashrc additions' ~/.bashrc; then
  cat .bashrc >> ~/.bashrc
fi

# Configure Git
cp -i .gitconfig ~/
