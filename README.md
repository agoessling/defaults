# defaults
Provision base Linux install.

`setup_linux.sh` installs managed defaults beside the normal dotfiles, then adds
a source/include line to the normal local dotfiles. Edit the normal files for
machine-local changes:

- `~/.bashrc` sources `~/.bashrc.defaults`
- `~/.bash_aliases` sources `~/.bash_aliases.defaults`
- `~/.tmux.conf` sources `~/.tmux.defaults.conf`
- `~/.gitconfig` includes `~/.gitconfig.defaults`

The `*.defaults` files are managed by this repo and may be replaced on rerun.
For settings that must run before managed bash defaults, such as `NO_TMUX=1`,
place them above the source line in `~/.bashrc`.

The tmux status bar shows CPU, memory, network rates, date/time, and hostname
in a fixed layout, updated every second. Memory use excludes reclaimable cache;
network rates follow the default-route interface. To select another interface,
add this after the source line in `~/.tmux.conf`:

```tmux
set -g @status_net_interface "eth0"
```

Setup compiles `tmux/tmux-status.c` locally. Tmux owns the persistent worker;
it needs no separate service or boot setup. To rebuild it without full setup,
run `bash tmux/build-status.sh ~/.tmux/tmux-status-right`, then detach and
reattach clients to use the new executable.

## Recreate the workstation

Start with Ubuntu 26.04 on x86_64, a normal desktop user with sudo access,
and a connected network; install Git, then run as that user:

```bash
git clone https://github.com/agoessling/defaults.git ~/defaults
cd ~/defaults
./setup_linux.sh
```

`versions.sh` records Neovim, Tree-sitter, Bazelisk, Codex CLI, fonts, and the
Neovim configuration commit. `tmux/plugins.lock` records installed tmux plugin
commits. Neovim setup restores its plugin lockfile and the recorded Mason
language-server/formatter versions, including TypeScript, Biome, Prettier,
and StyLua. Dirty configuration/plugin checkouts stop setup rather than being
overwritten; clean checkouts move to the recorded commits when needed.

Apt packages and Chrome follow their distribution repositories; this
reproduces configuration and pinned developer tools, not a disk image or an
exact historical package snapshot. Existing Codex installations are kept, as
is a `bazel` that something else installed (such as a work repository's own
Bazelisk); a fresh account gets the pinned CLI through the [official npm
installation method](https://learn.chatgpt.com/docs/codex/cli). Sign in
separately after installation; this does not restore the original standalone
app distribution. The managed Bash configuration adds `~/.local/bin` before
starting tmux.

When run from a terminal, setup asks whether to install and configure the
Cinnamon desktop (with Blueman for Bluetooth); set `DEFAULTS_CINNAMON=yes` or
`DEFAULTS_CINNAMON=no` to answer in advance. Cinnamon is installed beside the
existing desktop and is chosen at the login screen. When setup runs from a
desktop session it applies the recorded panel layout: menu and launchers on
top and a window list on the bottom, repeated on a second monitor. Panels for
a missing second monitor stay dormant. Print opens Flameshot to select and
annotate an area, then copy it (Ctrl+C) or save it (Ctrl+S). Super+Shift+S
is an alternate Flameshot shortcut. Setup disables all six Cinnamon system
screenshot bindings so existing assignments cannot compete with Flameshot.
If Print is still intercepted by another application or a remote desktop, use
the alternate shortcut; logging out and back in can clear stale key grabs.

Setup also asks for a linked text and panel size (50–200%). The default is
100%: normal text, 30-pixel panels, and a 24-pixel cursor. Panel icons and
cursor size follow the same percentage. The choice is saved per user in
`~/.config/defaults/cinnamon-scale` (under `XDG_CONFIG_HOME` when set) and
reused on reruns and by verification. Set `DEFAULTS_CINNAMON_SCALE=125` to
answer in advance. Noninteractive runs use the saved size, or 100% on a fresh
account. Display scaling is left alone.

To change only the linked size without running full setup:

```bash
python3 cinnamon/settings.py scale --scale 100
```

Settings not recorded are left alone. `cinnamon/dconf.ini` retains the original
125% layout as the reference from which sizes are calculated.

To record a changed layout, copy the panel keys from `dconf dump
/org/cinnamon/` into `cinnamon/dconf.ini` and changed applet settings from
`~/.config/cinnamon/spices/<applet>/<id>.json` into `cinnamon/applets.json`;
`cinnamon/settings.py check` lists what differs.

Machine-specific provisioning and project-specific hardware setup are maintained
separately from these shared workstation defaults.

Recreate credentials, SSH keys, and application logins separately; these are not
copied into Git. Browser profiles and editor caches are also outside this
configuration backup.

## Testing

- `test/verify.sh` checks a provisioned machine against the recorded
  configuration and versions. It is read-only and takes seconds; run it after
  `setup_linux.sh`.
- `python3 test/status.py` checks the status worker's output, build safety, and
  process lifetime using a private tmux server.
- `test/lint.sh` syntax-checks and ShellChecks the scripts. Enable it as a
  pre-commit hook with `git config core.hooksPath hooks`.
- `test/run.sh [RELEASE]` provisions a fresh Ubuntu container (Docker) from
  the working tree, then runs `test/verify.sh`. Each run downloads a full
  workstation, so use it only when a real machine cannot answer the question:
  fresh-install behavior or a different Ubuntu release.
  `test/run.sh 24.04 bash` opens a shell in a fresh container instead.
