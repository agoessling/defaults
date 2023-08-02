#!/bin/bash

# Exit on errors, undefined variables, and pipe failures.
set -euo pipefail

source "$(dirname "$0")/terminal_config.sh"

# install apt packages.
sudo apt-get update
sudo apt-get -y install \
    git \
    pip \
    tmux \
    dconf-cli \
    uuid-runtime \
    npm \
    python3-venv \
    ripgrep \

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

# Swap Caps-Lock with Escape.
if ! grep -q 'setxkbmap -option caps:escape' ~/.profile; then
  echo "" >> ~/.profile
  echo "# Make Caps-Lock a second Escape." >> ~/.profile
  echo "setxkbmap -option caps:escape" >> ~/.profile
fi

# Install recent NeoVim
if ! command -v nvim &> /dev/null; then
  sudo wget -q --show-progress -O /usr/local/bin/nvim https://github.com/neovim/neovim/releases/download/stable/nvim.appimage
  sudo chmod +x /usr/local/bin/nvim
fi

# Install NVIM configuration.
if [ ! -d ~/.config/nvim ]; then
  git clone git@github.com:agoessling/nvim_config.git ~/.config/nvim
else
  git pull origin master
fi

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
cp -i .bash_aliases ~/
if ! grep -q 'Custom bashrc additions' ~/.bashrc; then
  cat .bashrc >> ~/.bashrc
fi

# Configure Git
cp -i .gitconfig ~/
