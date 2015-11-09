#!/bin/bash

# Install basic programs.
sudo apt-get update

sudo apt-get -y install vim
sudo apt-get -y install git
sudo apt-get -y install screen

if ! dpkg -s google-chrome-stable | grep -q 'Status: install ok installed'; then
  wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  sudo dpkg -i google-chrome-stable_current_amd64.deb
  sudo apt-get -y -f install
  rm google-chrome-stable_current_amd64.deb
fi

# Swap Caps-Lock with Escape.
if ! grep -q 'setxkbmap -option caps:swapescape' ~/.profile; then
  echo "" >> ~/.profile
  echo "# Swap Caps-Lock with Escape." >> ~/.profile
  echo "setxkbmap -option caps:swapescape" >> ~/.profile
fi

# Install solarized color-scheme.
sudo apt-get install dconf-cli
git clone https://github.com/Anthony25/gnome-terminal-colors-solarized.git
cd gnome-terminal-colors-solarized
read -n1 -r -p 'Create "Solarized" terminal profile.  Press any key to continue.'
./install.sh
cd ..
rm -rf gnome-terminal-colors-solarized

# Configure terminal and Git.
cp -i .bash_aliases ~/
cp -i .gitconfig ~/
cp -i .screenrc ~/
if [[ ! -d ~/.vim/bundle/Vundle.vim ]]; then
  git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
fi
vim +PluginInstall +qall
cp -i .vimrc ~/
if ! grep -q 'Custom bashrc additions' ~/.bashrc; then
  cat .bashrc_additions >> ~/.bashrc
fi
