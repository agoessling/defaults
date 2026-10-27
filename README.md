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

The tmux status bar reports CPU use, memory use, download/upload rates, the
date and time, and the host. When the whole status bar does not fit, the right
side becomes one compact item that rotates every five seconds; if necessary it
is hidden entirely so the window list takes precedence. The bar and its system
statistics update every five seconds. Memory use excludes memory the kernel
reports as available, including reclaimable cache. Network traffic follows the
default-route interface. To select an interface explicitly, add this after the
source line in `~/.tmux.conf`:

```tmux
set -g @status_net_interface "eth0"
```

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
existing desktop and is chosen at the login screen. Its recorded settings in
`cinnamon/dconf.ini` are loaded into the user's dconf database when setup runs
from a desktop session; settings not recorded there are left alone.

Machine-specific provisioning and project-specific hardware setup are maintained
separately from these shared workstation defaults.

Recreate credentials, SSH keys, and application logins separately; these are not
copied into Git. Browser profiles and editor caches are also outside this
configuration backup.

## Testing

- `test/verify.sh` checks a provisioned machine against the recorded
  configuration and versions. It is read-only and takes seconds; run it after
  `setup_linux.sh`.
- `test/lint.sh` syntax-checks and ShellChecks the scripts. Enable it as a
  pre-commit hook with `git config core.hooksPath hooks`.
- `test/run.sh [RELEASE]` provisions a fresh Ubuntu container (Docker) from
  the working tree, then runs `test/verify.sh`. Each run downloads a full
  workstation, so use it only when a real machine cannot answer the question:
  fresh-install behavior or a different Ubuntu release.
  `test/run.sh 24.04 bash` opens a shell in a fresh container instead.
