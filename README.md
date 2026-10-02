# My dotfiles

This directory contains the dotfiles for my system

## Requirements

```
pacman -S stow tmux git bash
```

## Installation

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
