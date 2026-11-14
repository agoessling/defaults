#!/bin/bash
# Exercise clipboard backends and the real remote shell command in a private cache.
set -euo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$(mktemp -d)"
trap 'rm -rf -- "$fixture_dir"' EXIT
mkdir "$fixture_dir/bin" "$fixture_dir/remote" "$fixture_dir/local"
export CLIP_TEST_SOURCE="$fixture_dir/source.png" CLIP_TEST_RESULT="$fixture_dir/clipboard"
export CLIP_TEST_REMOTE="$fixture_dir/remote" TMPDIR="$fixture_dir/local"
export PATH="$fixture_dir/bin:$PATH"
# A one-pixel PNG; no real clipboard contents are read or modified.
printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=' |
  base64 -d > "$CLIP_TEST_SOURCE"
cat > "$fixture_dir/bin/xclip" <<'MOCK'
#!/bin/bash
if [[ " $* " == *' -o '* ]]; then
  [[ "${CLIP_TEST_EXPORT_FAIL:-0}" == 0 ]] || exit 1
  cat "$CLIP_TEST_SOURCE"
else
  if [[ " $* " == *' -selection primary '* ]]; then
    cat > "$CLIP_TEST_RESULT.primary"
  else
    cat > "$CLIP_TEST_RESULT"
  fi
fi
MOCK
cat > "$fixture_dir/bin/ssh" <<'MOCK'
#!/bin/bash
[[ "${CLIP_TEST_UPLOAD_FAIL:-0}" == 0 ]] || exit 1
XDG_CACHE_HOME="$CLIP_TEST_REMOTE" bash -c "${!#}"
MOCK
cat > "$fixture_dir/bin/wl-paste" <<'MOCK'
#!/bin/bash
cat "$CLIP_TEST_SOURCE"
MOCK
cat > "$fixture_dir/bin/wl-copy" <<'MOCK'
#!/bin/bash
if [[ " $* " == *' --primary '* ]]; then
  cat > "$CLIP_TEST_RESULT.primary"
else
  cat > "$CLIP_TEST_RESULT"
fi
MOCK
cat > "$fixture_dir/bin/notify-send" <<'MOCK'
#!/bin/bash
exit 0
MOCK
chmod +x "$fixture_dir/bin/"*
helper="$repo_dir/bin/clip-to-remote"

first="$(DISPLAY=:test WAYLAND_DISPLAY= "$helper" nucky)"
[[ "$first" == "$(cat "$CLIP_TEST_RESULT")" ]]
cmp "$first" "$CLIP_TEST_SOURCE"
[[ "$first" == "$(cat "$CLIP_TEST_RESULT.primary")" ]]
[[ "$(stat -c %a "$first")" == 600 ]]
second="$(DISPLAY=:test WAYLAND_DISPLAY= "$helper" nucky)"
[[ "$first" != "$second" ]]
third="$(WAYLAND_DISPLAY=wayland-test "$helper" nucky)"
cmp "$third" "$CLIP_TEST_SOURCE"
[[ "$third" == "$(cat "$CLIP_TEST_RESULT")" ]]
[[ "$third" == "$(cat "$CLIP_TEST_RESULT.primary")" ]]

# Failures preserve the previous clipboard and leave no local temporary image.
for failure in export upload invalid-image; do
  printf 'unchanged' > "$CLIP_TEST_RESULT"
  printf 'unchanged' > "$CLIP_TEST_RESULT.primary"
  export CLIP_TEST_EXPORT_FAIL=0 CLIP_TEST_UPLOAD_FAIL=0
  case "$failure" in
    export) CLIP_TEST_EXPORT_FAIL=1 ;;
    upload) CLIP_TEST_UPLOAD_FAIL=1 ;;
    invalid-image) printf 'not a PNG' > "$CLIP_TEST_SOURCE" ;;
  esac
  if DISPLAY=:test WAYLAND_DISPLAY= "$helper" nucky > /dev/null 2>&1; then
    echo "Expected $failure to fail" >&2; exit 1
  fi
  [[ "$(cat "$CLIP_TEST_RESULT")" == unchanged ]]
  [[ "$(cat "$CLIP_TEST_RESULT.primary")" == unchanged ]]
  [[ -z "$(ls -A "$TMPDIR")" ]]
done
if "$helper" '-oProxyCommand=bad' > /dev/null 2>&1; then
  echo 'An SSH option was accepted as the host' >&2; exit 1
fi
printf 'PASS: X11/Wayland upload, unique private files, clipboard preservation, and cleanup.\n'
