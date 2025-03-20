# My dotfiles

This directory contains the dotfiles for my system

## Requirements

```
pacman -S stow
```

## Installation

First, check out the dotfiles repo in your $HOME directory using git

```
$ git clone https://github.com/sinsenti/dotfiles.git
```
```
$ cd dotfiles
```

then use GNU stow to create symlinks
```
$ stow .
```
to undo:
```
stow -D .
```
