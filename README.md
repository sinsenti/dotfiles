# My dotfiles

This directory contains the dotfiles for my system

## Ubuntu dependencies

For an Ubuntu workstation, review the installer plan first, then run the installer:

```sh
bash install-ubuntu.sh --dry-run
bash install-ubuntu.sh
```

The default profile installs the shell/editor/terminal foundation, common CLI and
language tools, and optional desktop/PDF/OCR/media dependencies. Use
`--minimal` to skip desktop/media and Java/Go APT packages; the core CLI setup
still installs the runtimes needed by configured tools. The script
uses Ubuntu APT packages where appropriate and upstream installation methods
for tools such as Pi, Neovim, Atuin, uv, Workmux, and Worktrunk. It does not
install dependencies into the system Python with `pip`.

Optional host-level features require explicit flags:

```sh
bash install-ubuntu.sh --with-docker  # official Docker APT repo; may start daemon
bash install-ubuntu.sh --with-wifi    # NetworkManager/nmcli helpers
bash install-ubuntu.sh --with-voxtype # Ubuntu 24.04+; app only, no speech model
```

The installer does not stow these files, change the login shell, explicitly
manage systemd services, add the user to the root-equivalent `docker` group,
download large Voxtype models, or install private/project-specific commands.
APT package hooks may start services (especially with `--with-docker`). It runs
trusted upstream installers for some user-local tools; inspect the script and
its source URLs before running it. On first use, Zsh, Neovim, and tmux may
bootstrap their plugins and Neovim language tools.

Some integrations are environment-specific and need separate setup: the custom
GNOME Window Calls extension, Hyprland commands, ydotool service/permissions,
the XDG terminal-file-chooser helper, `a1aws`, `tuicr`, browser tools, and the
personal project directories referenced by the configs. Review hard-coded
`/home/...` paths before using this setup under a different account. Optional
PDF, Wi-Fi, OCR, Docker, GUI, and language tools are not needed for the basic
shell/editor.

## Dotfile installation

Clone the repository into your home directory, then enter it:

```sh
git clone https://github.com/sinsenti/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

The repository mirrors paths under `$HOME`: for example,
`.config/kitty/kitty.conf` becomes `~/.config/kitty/kitty.conf`. No separate
Stow configuration is needed when adding files under `.config/`.

Preview the links first and resolve any conflicts with existing files or links:

```sh
stow -n -v --ignore='^AGENTS\.md$' .
```

If the preview is clear, create the links:

```sh
stow --ignore='^AGENTS\.md$' .
```

To unlink them:

```sh
stow -D --ignore='^AGENTS\.md$' .
```

Review new application configs before committing them; keep caches, runtime
state, and unrelated downloaded files out of the repository.

## Tmux

`.tmux.conf` is stowed to `~/.tmux.conf`, tmux's default user configuration
path. On the first tmux start, the config bootstraps TPM in
`~/.tmux/plugins/tpm` and installs all configured plugins. Later additions can
be installed with the TPM `prefix + I` binding.

Plugin features additionally use tools such as `fzf`, `bat`, `zoxide`,
`wl-copy`, and `curl`; `tmux-thumbs` also needs Rust/Cargo or its downloadable
prebuilt binary on first use.
