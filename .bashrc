
# Custom bashrc additions

# Set default editor
export VISUAL=nvim
export EDITOR=$VISUAL

# git prompt
function _parse_git_dirty {
    [[ $(git status 2> /dev/null | tail -n1) != "nothing to commit, working tree clean" ]] && echo "*"
}
function _parse_git_branch {
    git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e "s/* \(.*\)/[\1$(_parse_git_dirty)] /"
}
PS1='$(_parse_git_branch)'$PS1

# Tmux -- Attach to existing detached session or create new session.
# Skip non-TTY shells (for example VS Code environment probes).
if [ -n "$PS1" ] && [ -z "$TMUX" ] && [ -t 0 ] && [ -t 1 ] && command -v tmux >/dev/null 2>&1; then
  ATTACH_OPT=$(tmux ls 2>/dev/null | grep -vq attached && echo "attach -d")
  exec tmux $ATTACH_OPT
fi
