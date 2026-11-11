#!/bin/bash
# Compile locally and atomically replace the executable, even while it is running.
set -euo pipefail
source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
destination="${1:?Usage: build-status.sh DESTINATION}"
mkdir -p -- "$(dirname -- "$destination")"
build_file="$(mktemp "${destination}.XXXXXX")"
trap 'rm -f -- "$build_file"' EXIT
"${CC:-cc}" -O2 -std=c11 -Wall -Wextra -Werror \
  "$source_dir/tmux-status.c" -o "$build_file"
chmod 0755 "$build_file"
if ! cmp -s -- "$build_file" "$destination" || [ ! -x "$destination" ]; then
  mv -f -- "$build_file" "$destination"
fi
