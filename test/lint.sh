#!/bin/bash
# Syntax-check the repo's shell scripts, then lint them with a local
# ShellCheck when installed or the ShellCheck container image otherwise.
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

scripts=(
  setup_linux.sh versions.sh terminal_config.sh .bashrc .bash_aliases
  tmux/build-status.sh
  test/*.sh hooks/*
)

# Compile in memory so lint does not create cache files beside executables.
python3 - <<'PYTHON'
from pathlib import Path
for path in [Path("bin/clip-to-remote"), *Path("test").glob("*.py")]:
    compile(path.read_bytes(), str(path), "exec")
PYTHON

cc -std=c11 -Wall -Wextra -Werror -fsyntax-only tmux/tmux-status.c

for script in "${scripts[@]}"; do
  bash -n "$script"
done

# Sourced files have no shebang; shellcheck must be told they are bash.
shellcheck_args=(--shell=bash --external-sources --severity=warning)
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck "${shellcheck_args[@]}" "${scripts[@]}"
elif command -v docker >/dev/null 2>&1; then
  docker run --rm -v "$repo_dir:/mnt:ro" -w /mnt koalaman/shellcheck:stable \
    "${shellcheck_args[@]}" "${scripts[@]}"
else
  echo "shellcheck unavailable; ran syntax checks only." >&2
fi
