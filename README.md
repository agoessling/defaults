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

The tmux status bar reports CPU use and download/upload rates once per second.
Network traffic follows the default-route interface. To select an interface
explicitly, add this after the source line in `~/.tmux.conf`:

```tmux
set -g @status_net_interface "eth0"
```
