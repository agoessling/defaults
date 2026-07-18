# Custom bashrc additions

# Set default editor
if command -v nvim >/dev/null 2>&1; then
  export VISUAL=nvim
  export EDITOR=nvim
fi

# git prompt
function _parse_git_dirty {
  ! git diff --quiet --ignore-submodules -- 2>/dev/null && echo "*" && return
  ! git diff --cached --quiet --ignore-submodules -- 2>/dev/null && echo "*"
}

function _parse_git_branch {
  local branch
  branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null) || return
  printf '[%s%s] ' "$branch" "$(_parse_git_dirty)"
}

case "$PS1" in
  *'_parse_git_branch'*) ;;
  *) PS1='$(_parse_git_branch)'"$PS1" ;;
esac

# Fuzzy history, file, and directory selection.
if [[ $- == *i* ]] && command -v fzf >/dev/null 2>&1; then
  if command -v fdfind >/dev/null 2>&1; then
    export FZF_CTRL_T_COMMAND='fdfind --type f --type d --hidden --follow --exclude .git'
    export FZF_ALT_C_COMMAND='fdfind --type d --hidden --follow --exclude .git'
  fi

  if command -v batcat >/dev/null 2>&1; then
    export FZF_CTRL_T_OPTS='--preview "batcat --style=numbers --color=always --line-range=:200 {} 2>/dev/null || ls -la {}"'
  fi

  if [ -f /usr/share/doc/fzf/examples/key-bindings.bash ]; then
    # shellcheck source=/usr/share/doc/fzf/examples/key-bindings.bash
    source /usr/share/doc/fzf/examples/key-bindings.bash
  fi
fi

# Tmux -- attach to a named session for real terminals.
# Set NO_TMUX=1 to bypass. IDE terminals and probes should not be captured.
if [[ -z "${NO_TMUX:-}" && -z "${TMUX:-}" && -t 0 && -t 1 ]] &&
   command -v tmux >/dev/null 2>&1 &&
   [[ -z "${VSCODE_INJECTION:-}" && "${TERM_PROGRAM:-}" != "vscode" ]]; then
  exec tmux new-session -A -s main
fi
