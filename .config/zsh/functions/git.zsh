T() {
    nvim -c 'lua vim.schedule(function() require("persistence").load(); require("neogit").open({ kind = "replace" }) end)'
}

unalias gco 2>/dev/null
gco() {
  # If arguments were provided, directly perform git checkout
  if [ -n "$1" ]; then
    git checkout "$@"
    return
  fi

  # Otherwise, open fzf branch picker
  local branch
  branch=$(git branch -a --color=always | grep -v '/HEAD' | \
      fzf --layout=reverse --ansi --preview 'git log --graph --color=always --oneline --decorate -n 20 $(echo {} | tr -d " *")' | \
      tr -d ' *' | sed 's#remotes/origin/##')

  if [ -n "$branch" ]; then
      git checkout "$branch"
  fi
}
