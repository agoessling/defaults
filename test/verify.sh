#!/bin/bash
# Check that setup_linux.sh left the current user's environment in the
# recorded state. Safe to run on a provisioned workstation or in a test
# container; it only reads configuration and starts private tmux/nvim probes.
set -uo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(dirname "$script_dir")"
# shellcheck source=../versions.sh
source "$repo_dir/versions.sh"
export PATH="$HOME/.local/bin:$PATH"

failures=0
pass() { printf '\033[1;32mPASS\033[0m %s\n' "$1"; }
skip() { printf '\033[1;33mSKIP\033[0m %s\n' "$1"; }
fail() { printf '\033[1;31mFAIL\033[0m %s\n' "$1"; failures=$((failures + 1)); }

# check DESCRIPTION COMMAND... passes when COMMAND succeeds.
check() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then pass "$desc"; else fail "$desc"; fi
}

# check_eq DESCRIPTION EXPECTED ACTUAL
check_eq() {
  if [[ "$3" == "$2" ]]; then
    pass "$1"
  else
    fail "$1 (expected '$2', got '$3')"
  fi
}

has_line() { grep -Fxq "$2" "$1"; }

for pkg in tmux git ripgrep fzf fd-find bat xclip; do
  check "apt package installed: $pkg" dpkg -s "$pkg"
done
check "Chrome installed" dpkg -s google-chrome-stable

check_eq "Neovim version" "$NVIM_VERSION" \
  "$(nvim --version 2>/dev/null | sed -n 's/^NVIM v//p' | head -n 1)"
if [[ -n "${NODE_VERSION:-}" ]]; then
  check_eq "Node.js version" "v$NODE_VERSION" "$(/usr/local/bin/node --version 2>/dev/null)"
fi
check_eq "Tree-sitter CLI version" "$TREE_SITTER_VERSION" \
  "$(tree-sitter --version 2>/dev/null | awk '{ print $2; exit }')"
bazel_target="$(readlink -f "$(command -v bazel)" 2>/dev/null)"
if [[ -n "$bazel_target" && "$bazel_target" != /usr/local/bin/bazelisk ]]; then
  skip "bazel is provided elsewhere: $bazel_target"
else
  check_eq "bazel shim points at bazelisk" "/usr/local/bin/bazelisk" \
    "$bazel_target"
fi
check "Codex CLI on PATH" command -v codex

for style in Regular Bold Italic BoldItalic; do
  check "font installed: HackNerdFont-$style" \
    test -s "$HOME/.local/share/fonts/HackNerdFont-$style.ttf"
done
check "fontconfig knows Hack Nerd Font" \
  bash -c 'fc-list : family | grep -q "Hack Nerd Font"'

# Managed files match the repo and are hooked into the local dotfiles.
check "bashrc defaults current" cmp -s "$repo_dir/.bashrc" "$HOME/.bashrc.defaults"
check "bashrc sources defaults" has_line "$HOME/.bashrc" \
  '[ -f "$HOME/.bashrc.defaults" ] && . "$HOME/.bashrc.defaults"'
check "bash_aliases defaults current" \
  cmp -s "$repo_dir/.bash_aliases" "$HOME/.bash_aliases.defaults"
check "bash_aliases sources defaults" has_line "$HOME/.bash_aliases" \
  '[ -f "$HOME/.bash_aliases.defaults" ] && . "$HOME/.bash_aliases.defaults"'
check "gitconfig defaults current" \
  cmp -s "$repo_dir/.gitconfig" "$HOME/.gitconfig.defaults"
check_eq "git aliases resolve through include" "status" \
  "$(git config --global --includes --get alias.st 2>/dev/null)"
check "profile swaps Caps-Lock" has_line "$HOME/.profile" \
  'if command -v setxkbmap >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then setxkbmap -option caps:escape; fi'

# An interactive shell picks up the managed bash configuration.
check "interactive bash loads prompt helpers" \
  env NO_TMUX=1 bash -ic 'declare -F _parse_git_branch'
check "interactive bash loads aliases" \
  env NO_TMUX=1 bash -ic 'alias vim'

# tmux parses the configuration and every locked plugin is at its revision.
check "tmux defaults current" \
  cmp -s "$repo_dir/tmux/.tmux.conf" "$HOME/.tmux.defaults.conf"
check "tmux.conf sources defaults" has_line "$HOME/.tmux.conf" \
  "source-file ~/.tmux.defaults.conf"
for script in tmux-colorscheme.conf tmux-system-stats tmux-status-right; do
  check "tmux file current: $script" \
    cmp -s "$repo_dir/tmux/$script" "$HOME/.tmux/$script"
done
check "tmux status scripts run" "$HOME/.tmux/tmux-system-stats"
tmux_prefix="$(tmux -L defaults-verify -f "$HOME/.tmux.conf" \
  new-session -d \; show-options -gv prefix \; kill-server 2>/dev/null)"
check_eq "tmux loads configuration" "C-a" "$tmux_prefix"
while read -r plugin revision; do
  check_eq "tmux plugin revision: ${plugin##*/}" "$revision" \
    "$(git -C "$HOME/.tmux/plugins/${plugin##*/}" rev-parse HEAD 2>/dev/null)"
done < "$repo_dir/tmux/plugins.lock"

# Neovim config is at the recorded commit and starts without errors.
nvim_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
check_eq "Neovim config revision" "$NVIM_CONFIG_REVISION" \
  "$(git -C "$nvim_config_dir" rev-parse HEAD 2>/dev/null)"
nvim_errors="$(nvim --headless -c 'qall' 2>&1 >/dev/null)"
check_eq "Neovim starts without errors" "" "$nvim_errors"

# Cinnamon is optional; check its recorded layout only where it is installed.
if dpkg -s cinnamon-core >/dev/null 2>&1; then
  check "Cinnamon settings match cinnamon/" python3 "$repo_dir/cinnamon/settings.py" check
else
  skip "Cinnamon not installed"
fi

echo
if ((failures)); then
  printf '\033[1;31m%d check(s) failed\033[0m\n' "$failures"
  exit 1
fi
printf '\033[1;32mAll checks passed\033[0m\n'
