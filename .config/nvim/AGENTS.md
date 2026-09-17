# Neovim configuration instructions

Read this file before changing anything under `.config/nvim/`.

## Configuration shape

- This is a LazyVim configuration using `lazy.nvim`.
- `init.lua` loads `lua/config/lazy.lua`.
- `lua/config/lazy.lua` bootstraps lazy.nvim, imports LazyVim, enables the extras in `lazyvim.json`, and imports `lua/plugins/`.
- Global options belong in `lua/config/options.lua`.
- Global mappings belong in `lua/config/keymaps.lua`.
- Reusable Lua actions belong in `lua/config/functions/` and are re-exported by `lua/config/functions.lua`.
- Plugin-specific mappings and options belong in the corresponding file under `lua/plugins/`.
- `ftplugin/markdown.lua` contains Markdown buffer-local behavior.

## Editing rules

- Work on repository files, not separate files under `$HOME`; Stow normally links this configuration into `~/.config/nvim`.
- Inspect `git status --short` and existing diffs before editing. Preserve unrelated user changes.
- Before changing a mapping, search both `lua/config/keymaps.lua` and plugin specs for the same key. Mappings are case-sensitive and mode-specific.
- Keep changes targeted. Do not broadly rewrite generated-style or unrelated plugin configuration.
- Do not update `lazy-lock.json` unless a dependency revision update is intentional.
- Do not start normal Neovim, bootstrap plugins, reload tmux sessions, or run desktop/service actions merely to validate syntax.
- Do not read or document secrets from environment files, clipboard contents, shell history, or personal data paths.

## Formatting and validation

- Lua uses StyLua configuration from `stylua.toml`: two-space indentation and a 120-column limit.
- Prefer non-executing checks after edits:

```sh
git diff --check
nvim --headless -u NONE -i NONE --noplugin \
  '+lua for _, f in ipairs(vim.fn.glob(".config/nvim/**/*.lua", false, true)) do local chunk, err = loadfile(f); if not chunk then print(err); vim.cmd("cquit") end end' \
  +qa
```

- Syntax checks do not verify plugin APIs, external binaries, Docker, Workmux, tmux, or live keymap precedence.
- StyLua may not be installed; report that instead of silently using a different formatter.

## Terminal and project workflow

Snacks owns the persistent terminal collection during the current Neovim session. A full Neovim restart cannot preserve terminal processes; tmux or another external process manager is required for that.

Current terminal mappings are defined in `lua/config/keymaps.lua`:

- `t/`: toggle the fullscreen Snacks terminal. A count selects a terminal slot, e.g. `2t/`.
- `t.`: open the terminal picker.
- `t?`: no mapping is currently defined; do not assume the older `t?` picker mapping still exists.
- `t[` / `t]`: previous/next terminal.
- `tK`: close the current terminal.
- `TA`: A1AWS menu.
- `TD`: A1Labs Docker menu.
- `TW`: open/focus or hide the A1Labs Workmux dashboard; it works in Normal and Terminal mode.
- `t'`: search tmux windows; it works in Normal and Terminal mode.

The standalone `t` key is disabled so these sequences can act as a command namespace. Preserve the distinction between `tD`, `TD`, `TW`, and other case-sensitive mappings.

`lua/config/functions/terminal.lua` provides the Snacks terminal wrapper, named terminal metadata, terminal picking, and focus/toggle behavior. The picker intentionally lists Snacks-managed terminals and excludes plain `:terminal` buffers such as `term://...` shells. Keep terminal names and working directories visible in picker entries.

## A1Labs integrations

- The A1Labs root defaults to `~/git/project/a1labs` and can be overridden with `A1LABS_ROOT`.
- `lua/config/functions/docker.lua` implements the `TD` menu. It selects Git worktrees from the fixed A1Labs repository, copies `.env` from the main worktree when needed, and offers Compose logs, build/start, status, container shell, and custom Compose commands.
- A1Labs logs default to all services and use `jq --unbuffered -RrC 'fromjson? // .'` for JSON-aware formatting. Keep this behavior unless explicitly requested otherwise.
- `lua/config/functions/tmux.lua` implements the `TW` Workmux dashboard action. It runs `workmux dashboard` with the A1Labs root as `cwd` through the Snacks terminal and uses focus semantics: focus it from another buffer, hide it from inside the dashboard.
- Workmux defaults and dashboard behavior are in `.config/workmux/config.yaml`; do not duplicate those settings in Lua without a reason.

## tmux boundary

- `<C-h>`, `<C-j>`, `<C-k>`, and `<C-l>` currently call TmuxNavigate commands so navigation can cross Neovim/tmux boundaries.
- Other tmux actions are in `lua/config/functions/tmux.lua`. Keep external tmux commands guarded by `vim.env.TMUX` and notify when tmux is unavailable.
- `t'` is allowed in terminal mode because it should launch the tmux-window picker instead of sending the key sequence to the shell.
