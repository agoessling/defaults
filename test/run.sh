#!/bin/bash
# Provision a fresh Ubuntu container from the working tree and verify the
# result. Each run downloads a full workstation (~1-2 GB, several minutes), so
# reserve it for changes that cannot be checked on a real machine, such as
# fresh-install behavior or another Ubuntu release. On a provisioned machine,
# run test/verify.sh directly.
#
#   test/run.sh [RELEASE] [COMMAND...]
#
# RELEASE defaults to the supported Ubuntu release. COMMAND replaces the test,
# e.g. `test/run.sh 26.04 bash` opens a shell in a fresh test container.
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
release="${1:-24.04}"
shift || true
image="defaults-test:$release"

docker build --quiet --build-arg "UBUNTU_RELEASE=$release" \
  -t "$image" "$repo_dir/test" >/dev/null

if (($#)); then
  docker_tty=()
  [[ -t 0 ]] && docker_tty=(-it)
  exec docker run --rm "${docker_tty[@]}" -v "$repo_dir:/src:ro" "$image" \
    bash -c 'cp -a /src ~/defaults && cd ~/defaults && exec "$@"' bash "$@"
fi

# Copy rather than mount so setup sees a private, writable checkout.
exec docker run --rm -v "$repo_dir:/src:ro" "$image" bash -c '
  set -euo pipefail
  cp -a /src ~/defaults
  cd ~/defaults
  echo "=== Provision"
  ./setup_linux.sh </dev/null
  echo "=== Verify"
  test/verify.sh
'
