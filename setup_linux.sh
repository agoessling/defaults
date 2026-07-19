#!/bin/bash

# Exit on errors, undefined variables, and pipe failures.
set -euo pipefail
trap 'echo "ERROR: ${BASH_SOURCE[0]}:${LINENO}: ${BASH_COMMAND}" >&2' ERR

info()  { printf '\033[1;34m%s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m%s\033[0m\n' "$*"; }

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

install_if_changed() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"

  if [ -e "$dst" ] && cmp -s "$src" "$dst"; then
    info "Up to date: $dst"
  else
    install -m 0644 "$src" "$dst"
    ok "Updated: $dst"
  fi
}

ensure_line() {
  local file="$1" line="$2"
  mkdir -p "$(dirname "$file")"
  touch "$file"

  if grep -Fxq "$line" "$file"; then
    info "Line already present: $file"
  else
    printf '%s\n' "$line" >> "$file"
    ok "Added line: $file"
  fi
}

ensure_git_defaults_include() {
  local file="$1"
  local include_path="$2"
  mkdir -p "$(dirname "$file")"
  touch "$file"

  if git config --file "$file" --get-all include.path 2>/dev/null | grep -Fxq "$include_path"; then
    info "Git include already present: $file"
  else
    local tmp
    tmp="$(mktemp)"
    {
      printf '[include]\n'
      printf '  path = %s\n\n' "$include_path"
      cat "$file"
    } > "$tmp"
    install -m 0644 "$tmp" "$file"
    rm -f "$tmp"
    ok "Added Git defaults include: $file"
  fi
}

source "$script_dir/terminal_config.sh"

# install apt packages.
sudo apt-get update
sudo apt-get -y install --no-install-recommends \
    git \
    python3-pip \
    tmux \
    dconf-cli \
    gnome-terminal \
    libglib2.0-bin \
    uuid-runtime \
    npm \
    python3-venv \
    ripgrep \
    xclip \
    fzf \
    fd-find \
    bat \
    fuse3 \
    libfuse2

# Install tmux configuration.
install_if_changed "tmux/.tmux.conf" "$HOME/.tmux.defaults.conf"
mkdir -p ~/.tmux
install_if_changed "tmux/tmux-colorscheme.conf" "$HOME/.tmux/tmux-colorscheme.conf"
ensure_line "$HOME/.tmux.conf" "source-file ~/.tmux.defaults.conf"
if [ ! -d ~/.tmux/plugins/tpm ]; then
  git clone --depth=1 https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi
if [ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]; then
  "$HOME/.tmux/plugins/tpm/bin/install_plugins"
fi

# Install Chrome.
if ! dpkg -s google-chrome-stable >/dev/null 2>&1; then
  tmpdeb="$(mktemp --suffix=.deb)"
  wget -O "$tmpdeb" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  sudo dpkg -i "$tmpdeb" || sudo apt-get -y -f install
  rm -f "$tmpdeb"
fi

# Swap Caps-Lock with Escape.
ensure_line "$HOME/.profile" "# Make Caps-Lock a second Escape."
ensure_line "$HOME/.profile" 'if command -v setxkbmap >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then setxkbmap -option caps:escape; fi'

# Install recent NeoVim (AppImage) - atomic install + basic sanity checks
if ! command -v nvim >/dev/null 2>&1 || ! nvim --version >/dev/null 2>&1; then
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

# Install Bazelisk and provide bazel shim.
install_bazelisk() {
  if command -v bazelisk >/dev/null 2>&1; then
    echo "Bazelisk already installed: $(bazelisk version | head -n 1)"
    if ! command -v bazel >/dev/null 2>&1; then
      sudo ln -sf /usr/local/bin/bazelisk /usr/local/bin/bazel
    fi
    return 0
  fi

  local arch url tmp
  case "$(uname -m)" in
    x86_64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *)
      echo "Unsupported architecture for Bazelisk: $(uname -m)" >&2
      return 1
      ;;
  esac

  url="https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-${arch}"
  tmp="$(mktemp)"

  wget --https-only --tries=5 --timeout=20 --waitretry=2 \
       -O "$tmp" "$url"

  test -s "$tmp"
  sudo install -m 0755 "$tmp" /usr/local/bin/bazelisk
  rm -f "$tmp"

  sudo ln -sf /usr/local/bin/bazelisk /usr/local/bin/bazel

  /usr/local/bin/bazelisk version >/dev/null
  echo "Installed Bazelisk: $(bazelisk version | head -n 1)"
}

install_bazelisk

# Download patched fonts.
mkdir -p ~/.local/share/fonts
wget -nc -q --show-progress -P ~/.local/share/fonts https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Hack/Regular/HackNerdFont-Regular.ttf
wget -nc -q --show-progress -P ~/.local/share/fonts https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Hack/Bold/HackNerdFont-Bold.ttf
wget -nc -q --show-progress -P ~/.local/share/fonts https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Hack/Italic/HackNerdFont-Italic.ttf
wget -nc -q --show-progress -P ~/.local/share/fonts https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Hack/BoldItalic/HackNerdFont-BoldItalic.ttf

if ! gnome_terminal_available &&
   [ -f /usr/share/glib-2.0/schemas/org.gnome.Terminal.gschema.xml ] &&
   command -v glib-compile-schemas >/dev/null 2>&1; then
  info "Refreshing GLib schema cache"
  sudo glib-compile-schemas /usr/share/glib-2.0/schemas
fi

if gnome_terminal_available; then
  profile_uuid="$(default_profile_uuid)"

  if [ -n "$profile_uuid" ]; then
    # Setup terminal colorscheme and font.
    setup_gruvbox_colors
    set_font "$profile_uuid" "Hack Nerd Font 10"
    ok "Configured GNOME Terminal profile: $profile_uuid"
  else
    info "Skipping GNOME Terminal configuration: no default profile"
  fi
else
  info "Skipping GNOME Terminal configuration: schema unavailable after refresh"
fi

# Configure Bash
install_if_changed ".bash_aliases" "$HOME/.bash_aliases.defaults"
ensure_line "$HOME/.bash_aliases" '[ -f "$HOME/.bash_aliases.defaults" ] && . "$HOME/.bash_aliases.defaults"'
install_if_changed ".bashrc" "$HOME/.bashrc.defaults"
ensure_line "$HOME/.bashrc" '# Load managed defaults.'
ensure_line "$HOME/.bashrc" '[ -f "$HOME/.bashrc.defaults" ] && . "$HOME/.bashrc.defaults"'

# Configure Git
install_if_changed ".gitconfig" "$HOME/.gitconfig.defaults"
ensure_git_defaults_include "$HOME/.gitconfig" "~/.gitconfig.defaults"
