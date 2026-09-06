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

w() {
  # Direct passthrough if arguments are provided (e.g. 'w list')
  if [ $# -gt 0 ]; then
    wt "$@"
    return
  fi

  while true; do
    echo "── Worktrees Status ──"
    wt list
    echo ""
    echo "── Worktrunk (wt) Menu ──"
    echo "1) Refresh list (wt list)"
    echo "2) Switch worktree / branch (wt switch)"
    echo "3) Create new worktree (wt switch --create)"
    echo "4) Remove worktree (wt remove)"
    echo "5) Merge worktree branch (wt merge)"
    echo "6) Run hook (wt hook)"
    echo "7) Config (wt config)"
    echo "q/Esc) Quit"
    printf "Select [1-7 / q / Esc]: "

    # Read single keypress without requiring Enter
    if [ -n "$ZSH_VERSION" ]; then
      read -k 1 choice
    else
      read -n 1 -r -s choice
    fi
    echo ""

    case "$choice" in
      q|Q|$'\x1b'|$'\e')
        break
        ;;
      1)
        # Loop will naturally run 'wt list' at the top
        ;;
      2)
        wt switch
        ;;
      3)
        read -r "branch?Enter new branch name: " 2>/dev/null || read -r -p "Enter new branch name: " branch
        if [ -n "$branch" ]; then
          wt switch --create "$branch"
        fi
        ;;
      4)
        wt remove
        ;;
      5)
        wt merge
        ;;
      6)
        wt hook
        ;;
      7)
        wt config
        ;;
      *)
        echo "Invalid option."
        ;;
    esac
    echo ""
  done
}
