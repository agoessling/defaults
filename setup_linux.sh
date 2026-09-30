#!/bin/bash

# Exit on errors, undefined variables, and pipe failures.
set -euo pipefail
trap 'echo "ERROR: ${BASH_SOURCE[0]}:${LINENO}: ${BASH_COMMAND}" >&2' ERR

info()  { printf '\033[1;34m%s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m%s\033[0m\n' "$*"; }

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

install_if_changed() {
  local src="$1" dst="$2" mode="${3:-0644}"
  mkdir -p "$(dirname "$dst")"

  if [ -e "$dst" ] && cmp -s "$src" "$dst" &&
     [ "$(stat -c '%a' "$dst")" = "${mode#0}" ]; then
    info "Up to date: $dst"
  else
    install -m "$mode" "$src" "$dst"
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

if ((EUID == 0)); then
  echo "Run setup_linux.sh as the desktop user; it uses sudo when needed." >&2
  exit 2
fi
if [[ "$(uname -m)" != x86_64 ]]; then
  echo "This desktop setup currently supports x86_64 Linux only." >&2
  exit 2
fi
source "$script_dir/versions.sh"
source "$script_dir/terminal_config.sh"
export PATH="$HOME/.local/bin:$PATH"

# install apt packages.
sudo apt-get update
sudo apt-get -y install --no-install-recommends \
    ca-certificates \
    build-essential \
    curl \
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
    x11-xkb-utils \
    fzf \
    fd-find \
    bat \
    fuse3 \
    libfuse2 \
    unzip \
    wget \
    fontconfig

# Install tmux configuration.
install_if_changed "tmux/.tmux.conf" "$HOME/.tmux.defaults.conf"
mkdir -p ~/.tmux
install_if_changed "tmux/tmux-colorscheme.conf" "$HOME/.tmux/tmux-colorscheme.conf"
install_if_changed "tmux/tmux-system-stats" "$HOME/.tmux/tmux-system-stats" 0755
install_if_changed "tmux/tmux-status-right" "$HOME/.tmux/tmux-status-right" 0755
ensure_line "$HOME/.tmux.conf" "source-file ~/.tmux.defaults.conf"
# Install plugins directly so bootstrap does not depend on a running tmux server.
while read -r plugin revision; do
  plugin_dir="$HOME/.tmux/plugins/${plugin##*/}"
  if [[ ! -e "$plugin_dir" ]]; then
    git clone "https://github.com/$plugin.git" "$plugin_dir"
  fi
  if [[ -n "$(git -C "$plugin_dir" status --porcelain)" ]]; then
    echo "Local tmux plugin changes must be committed first: $plugin_dir" >&2
    exit 1
  fi
  if [[ "$(git -C "$plugin_dir" rev-parse HEAD)" != "$revision" ]]; then
    git -C "$plugin_dir" fetch origin "$revision"
    git -C "$plugin_dir" checkout --detach "$revision"
  fi
done < "$script_dir/tmux/plugins.lock"

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

# Install the recorded Neovim release rather than a moving latest release.
nvim_version="$(nvim --version 2>/dev/null | sed -n 's/^NVIM v//p' | head -n 1 || true)"
if [[ "$nvim_version" != "$NVIM_VERSION" ]]; then
  tmp="$(mktemp)"
  url="https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-linux-x86_64.appimage"
  wget --https-only --tries=5 --timeout=20 --waitretry=2 -O "$tmp" "$url"
  test -s "$tmp"
  chmod 0755 "$tmp"
  "$tmp" --version >/dev/null
  sudo install -m 0755 "$tmp" /usr/local/bin/nvim
  rm -f "$tmp"
fi

# Install the Tree-sitter CLI required by nvim-treesitter's main branch.
install_tree_sitter_cli() {
  local version="$TREE_SITTER_VERSION"
  local installed_version=""
  local arch url tmp_dir

  if command -v tree-sitter >/dev/null 2>&1; then
    installed_version="$(tree-sitter --version 2>/dev/null | awk '{ print $2; exit }')"
    if [ -n "$installed_version" ] &&
       [[ "$installed_version" == "$version" ]]; then
      info "Tree-sitter CLI already installed: $installed_version"
      return 0
    fi
  fi

  case "$(uname -m)" in
    x86_64) arch="x64" ;;
    aarch64|arm64) arch="arm64" ;;
    armv7l) arch="arm" ;;
    *)
      echo "Unsupported architecture for Tree-sitter CLI: $(uname -m)" >&2
      return 1
      ;;
  esac

  url="https://github.com/tree-sitter/tree-sitter/releases/download/v${version}/tree-sitter-cli-linux-${arch}.zip"
  tmp_dir="$(mktemp -d)"

  wget --https-only --tries=5 --timeout=20 --waitretry=2 \
       -O "$tmp_dir/tree-sitter.zip" "$url"
  unzip -q "$tmp_dir/tree-sitter.zip" -d "$tmp_dir"
  test -s "$tmp_dir/tree-sitter"

  sudo install -m 0755 "$tmp_dir/tree-sitter" /usr/local/bin/tree-sitter
  rm -rf "$tmp_dir"

  /usr/local/bin/tree-sitter --version >/dev/null
  ok "Installed Tree-sitter CLI: $(tree-sitter --version)"
}

install_tree_sitter_cli

# Restore the recorded config without overwriting local editor changes.
nvim_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
mkdir -p "$(dirname "$nvim_config_dir")"
if [[ ! -e "$nvim_config_dir" ]]; then
  git clone https://github.com/agoessling/nvim_config.git "$nvim_config_dir"
fi
if [[ "$(git -C "$nvim_config_dir" rev-parse --show-toplevel)" != "$(realpath "$nvim_config_dir")" ]]; then
  echo "Neovim config must be its own Git checkout: $nvim_config_dir" >&2
  exit 1
fi
if [[ -n "$(git -C "$nvim_config_dir" status --porcelain)" ]]; then
  echo "Neovim config has local changes; commit them before provisioning." >&2
  exit 1
fi
if [[ "$(git -C "$nvim_config_dir" rev-parse HEAD)" != "$NVIM_CONFIG_REVISION" ]]; then
  git -C "$nvim_config_dir" fetch origin "$NVIM_CONFIG_REVISION"
  git -C "$nvim_config_dir" checkout --detach "$NVIM_CONFIG_REVISION"
fi
"$nvim_config_dir/setup.sh"

# Preserve an existing Codex installation; bootstrap the CLI for a fresh user.
if ! command -v codex >/dev/null 2>&1; then
  npm install --global --prefix "$HOME/.local" "@openai/codex@$CODEX_VERSION"
fi

# Install Bazelisk and provide bazel shim.
install_bazelisk() {
  if command -v bazelisk >/dev/null 2>&1 &&
     [[ "$(bazelisk version 2>/dev/null | sed -n '1p')" == "Bazelisk version: v$BAZELISK_VERSION" ]]; then
    echo "Bazelisk already installed: $(bazelisk version | sed -n '1p')"
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

  url="https://github.com/bazelbuild/bazelisk/releases/download/v${BAZELISK_VERSION}/bazelisk-linux-${arch}"
  tmp="$(mktemp)"

  wget --https-only --tries=5 --timeout=20 --waitretry=2 \
       -O "$tmp" "$url"

  test -s "$tmp"
  sudo install -m 0755 "$tmp" /usr/local/bin/bazelisk
  rm -f "$tmp"

  sudo ln -sf /usr/local/bin/bazelisk /usr/local/bin/bazel

  /usr/local/bin/bazelisk version >/dev/null
  echo "Installed Bazelisk: $(bazelisk version | sed -n '1p')"
}

install_bazelisk

# Download patched fonts; skipping existing files is successful on reruns.
mkdir -p "$HOME/.local/share/fonts"
for style in Regular Bold Italic BoldItalic; do
  font="HackNerdFont-${style}.ttf"
  if [[ ! -f "$HOME/.local/share/fonts/$font" ]]; then
    tmp="$(mktemp)"
    wget --https-only --tries=5 --timeout=20 -O "$tmp" \
      "https://github.com/ryanoasis/nerd-fonts/raw/v${NERD_FONTS_VERSION}/patched-fonts/Hack/$style/$font"
    install_if_changed "$tmp" "$HOME/.local/share/fonts/$font"
    rm -f "$tmp"
  fi
done

fc-cache -f "$HOME/.local/share/fonts"

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
