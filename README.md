# My dotfiles

This directory contains the dotfiles for my system

## Requirements

```
pacman -S stow tmux git bash
```

## Installation

First, check out the dotfiles repo in your $HOME directory using git

```
git clone https://github.com/sinsenti/dotfiles.git
```
```
cd dotfiles
```

then use GNU stow to create symlinks
```
stow --ignore='^AGENTS\.md$' .
```
to undo:
```
stow -D --ignore='^AGENTS\.md$' .
```

## Tmux

`.tmux.conf` is stowed to `~/.tmux.conf`, tmux's default user configuration
path. On the first tmux start, the config bootstraps TPM in
`~/.tmux/plugins/tpm` and installs all configured plugins. Later additions can
be installed with the TPM `prefix + I` binding.

Plugin features additionally use tools such as `fzf`, `bat`, `zoxide`,
`wl-copy`, and `curl`; `tmux-thumbs` also needs Rust/Cargo or its downloadable
prebuilt binary on first use.
