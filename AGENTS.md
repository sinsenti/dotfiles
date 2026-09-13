# Agent guide to these dotfiles

## Scope and working rules

This is a personal Linux workstation configuration, not a single application. Prefer small, targeted changes that preserve existing keybindings, interactive behavior, and startup performance. This guide is a navigation aid, not proof that every configuration works on the current machine; re-read relevant source before editing.

- Start with `git status --short` and inspect existing diffs. Do not overwrite, reset, format, or commit unrelated work.
- At the initial analysis, `.config/scripts/db.py` had substantial uncommitted changes and `.config/scripts/todo.md` was untracked. Re-check rather than assuming this remains true.
- Edit repository sources, not separate copies under `$HOME`. Stow symlinks can make edits immediately affect the live workstation.
- Do not read or reproduce secrets from `~/.env`, project `.env` files, shell history, database connection strings, or clipboard contents unless specifically needed and authorized. Use placeholders in documentation and tests.
- Do not run network/service controls, database mutations, Git push helpers, clipboard writers, or desktop automation just to validate syntax.
- Use `git ls-files` for the maintained inventory. `.config/tmux/plugins/` contains ignored third-party installations, not first-party code; do not recursively modify them. Respect nested instructions when working in a dependency.
- `.config/yazi/flavors/catppuccin-mocha.yazi/` is vendored and explicitly marked `DO_NOT_MODIFY_ANYTHING_IN_THIS_DIRECTORY`.

## Deployment and environment

`README.md` documents cloning into `~/dotfiles`, then running GNU Stow from the repository:

```sh
stow .       # link into the parent directory (normally $HOME)
stow -D .    # unlink; changes the live setup
```

Do not run these automatically. Preview with `stow -n -v .` first. For another checkout location, select the intended target explicitly with `-t "$HOME"`. Never use `--adopt` casually: it can move existing home files into the repository.

There is no repository `.stow-local-ignore`. Adding a root `AGENTS.md` may cause Stow to link it into `$HOME`, unintentionally applying repository instructions more broadly. To keep this guide local, include `--ignore='^AGENTS\.md$'` in both preview and deployment commands, or agree on a persistent ignore rule before deployment.

The README uses `pacman`, but the scripts include GNOME/Wayland, X11/XWayland, and Hyprland integrations. Do not infer the current distribution or compositor from the README alone. Several paths still use `/home/sinsenti`; many aliases assume `~/dotfiles` and personal `~/git/...` directories. Kitty is referenced extensively but its configuration is not tracked here; neither is a Hyprland configuration.

## Repository map

| Path | Purpose / where to make changes |
| --- | --- |
| `.zshrc` | Shell initialization, environment, completion/history, plugin loading, module sourcing, final widgets |
| `.p10k.zsh` | Large generated-style Powerlevel10k configuration; avoid broad rewrites |
| `.config/zsh/functions/*.zsh` | Automatically sourced shell aliases and functions, grouped by topic |
| `.config/nvim/init.lua` | Neovim entry point; loads `config.lazy` |
| `.config/nvim/lua/config/` | Lazy bootstrap, options, keymaps, shared functions, autocmds |
| `.config/nvim/lua/plugins/` | lazy.nvim plugin specifications and plugin-specific mappings |
| `.config/nvim/lazyvim.json` | Enabled LazyVim extras |
| `.config/nvim/lazy-lock.json` | Plugin revisions; change only for intentional dependency updates |
| `.config/nvim/ftplugin/markdown.lua` | Markdown buffer-specific behavior |
| `.config/scripts/` | Standalone Bash/Python utilities; no shared package/build system |
| `.config/tmux/tmux.conf` | Terminal multiplexer bindings, appearance, TPM plugins |
| `.config/workmux/config.yaml` | Worktree/agent defaults and pane layout |
| `.config/gh-dash/config.yml` | GitHub dashboard, PR-review and diff shortcuts |
| `.config/yazi/{yazi,keymap,theme,package}.toml` | File-manager behavior, keys, theme and dependency metadata |
| `.taskrc` | Taskwarrior settings, personal data path, urgency weights |
| `.config/procps/toprc` | Saved `top` preferences; not application code |

## Zsh architecture and workflows

Startup order matters:

1. Powerlevel10k instant prompt stays at the top.
2. Bootstrap/source Zinit and load the prompt theme.
3. Initialize cached completion, then deferred plugins/snippets (fzf-tab, suggestions, highlighting, vi-mode, tmux, Carapace).
4. Load/generate the Zoxide cache, export environment and paths, and source optional `~/.env`.
5. Define lazy NVM loading and history hooks; source optional FZF cache.
6. Source every `~/.config/zsh/functions/*.zsh` module.
7. Load `.p10k.zsh`, apply final keybindings, and initialize Worktrunk (`wt`) if available.

Modules:

- `aliases.zsh`: command shortcuts, including `p` → `pi`, `wm` → `workmux`, `db` → the Python database browser, and script launchers.
- `nav.zsh`: `v` opens Neovim with optional session restoration (`-s`, `-g`, directory/file modes); `fn` selects files, `tl` selects tmux windows, `e` launches Yazi and adopts its directory. `f` and `fcurl` execute commands selected from history.
- `git.zsh`: `T` opens Neogit, `gco` checks out branches, `w` wraps Worktrunk with an interactive menu or argument passthrough.
- `docker.zsh`: worktree-aware Compose startup, container exec/log/stop actions. `dwt` can copy a project `.env` and build/start services.
- `python.zsh`: `py` searches the current directory and ancestors for uv/virtualenv runners, with an interactive script picker; `va` activates a nearby virtualenv.
- `atuin.zsh`: Atuin history setup and Ctrl+R bindings. Alt+R remains the FZF history fallback in `.zshrc`.
- `utils.zsh`, `pdf.zsh`, `wifi.zsh`: clipboard/process/recording, PDF, and network helpers.

These are Zsh modules, not POSIX shell scripts. Preserve Zsh arrays, globbing, widgets, and `unalias` guards. Check both `.zshrc` and modules for duplicate definitions and deferred plugin overrides.

## Neovim architecture

Uses LazyVim on lazy.nvim. `lua/config/lazy.lua` bootstraps lazy.nvim, imports LazyVim, the Python extra, and `plugins`. Also inspect `lazyvim.json`: extras there enable additional language, editing, debugging, test, and GitHub integrations.

- General options belong in `options.lua`; global mappings in `keymaps.lua`; reusable custom actions in `functions.lua` (a large module returning `M`). Plugin-specific options/mappings belong in the relevant plugin spec.
- Leader is Space, local leader is backslash. Lua formatting is configured by `stylua.toml`: two spaces, 120 columns. Preserve `stylua: ignore` regions.
- `keymaps.lua` requires `config.functions`. Custom actions span Git/Diffview, Markdown cleanup and translation, notes, browser lookup, clipboard handling, and tmux management.
- Search is deliberately split across `fff.lua`, `fzf-lua.lua`, and `snacks.lua`; do not assume one picker owns every binding. Examples: `ff`/leader-Space use fff; Snacks handles buffers and other pickers.
- Git uses Neogit, Diffview, Fugitive, and Gitsigns. Session restoration is invoked by shell launchers through `persistence`.
- Notes/Markdown configuration is spread across `obsidian.lua`, `markdown.lua`, image/paste plugins, the Markdown ftplugin, and shared functions. Vaults reference personal directories outside this repo.
- `db.lua` configures Neovim database plugins; it is separate from `.config/scripts/db.py`.
- `example.lua` immediately returns `{}`; its example specs are inactive. `config/unused.lua` has no reference found in the tracked configuration. Do not treat examples/commented blocks as active features, or assume `trash.lua` is inactive because of its name.
- Before changing a mapping, search both `keymaps.lua` and plugin specs; duplicated keys and lazy-loading order can affect the result.

## tmux, worktrees, and GitHub

- tmux prefixes are Ctrl+Space and backtick; windows start at 1, status is at the top, and mouse/clipboard/passthrough/extended keys are enabled.
- TPM loads navigation, clipboard, resurrection/continuum, fuzzy/session pickers, floating panes, and Catppuccin plugins. The final `run` invokes the installed TPM under `~/.config/tmux/plugins/`.
- tmux and Neovim share Ctrl+h/j/k/l navigation via vim-tmux-navigator. Consider both configurations when changing navigation.
- Workmux defaults to agent `pi`, a focused `pi` pane, worktrees under `.claude/worktrees`, and `main_branch: dev`. That is a tool default, not evidence of this repository's current branch.
- gh-dash PR key `C` starts a Workmux review with pi; `D` opens a tmux window using Worktrunk and Neovim Diffview. Dependencies include authenticated `gh`, workmux, wt, tmux, and Neovim; `g` launches lazygit and diffs use diffnav.

## Script hotspots and dependencies

- `db.py`: substantial interactive database browser/editor. Supports local SQLite discovery, Docker PostgreSQL/MySQL/MariaDB discovery, and direct connection URLs. Includes paging, filtering, schema/foreign-key inspection, raw SQL, editing, deletion, insertion, and export. Uses standard-library SQLite, external database CLIs/Docker, Neovim editing, clipboard helpers, and optional `prompt_toolkit`. Test mutations only against disposable fixtures; preserve terminal cleanup and cancellation behavior.
- `code_paste.py`: extracts file paths/code from Markdown or clipboard/input and writes files. Treat it as a file writer, not a harmless preview.
- `copy_all.sh` and related copy helpers: collect source into clipboard-oriented output. Review selection/exclusions before use to avoid copying secrets.
- `focus-*.sh` and `focus_kittty_browsers.sh`: GNOME window automation through `org.gnome.Shell.Extensions.Windows` D-Bus methods. Some shell files embed Python; `bash -n` does not validate that embedded Python.
- `vim_grid.py`: PyQt6 pointer-control overlay, forces XWayland (`QT_QPA_PLATFORM=xcb`), invokes ydotool, and interacts with GNOME pointer settings.
- OCR/translation/PDF helpers use combinations of gnome-screenshot, Tesseract, Python OCR/PDF libraries, rofi, translate-shell, curl, jq, mpv, and clipboard tools. Translation/dictionary operations can send text to external services.
- `fast-nvim.sh` focuses/creates a Kitty notes window via xdotool; `rerun_last_cmd.sh` consumes the shell's last-command cache. Neither should be run as a syntax check.

Common external tools include Zsh, Git, Stow, Kitty, Neovim, tmux/TPM, fzf, rg, fd, bat, exa, zoxide, Atuin, Carapace, and wl-clipboard. Other dependencies are per-feature, not a guaranteed installed package set. No central dependency manifest exists.

## Known inconsistencies to verify, not silently fix

- `zn` calls `n` and `zy` calls `y`, but the corresponding launchers defined in `nav.zsh` are `v` and `e`. tmux's `e` binding also sends `y`. External commands may exist; check before renaming anything.
- Alias `nt` points to `.config/tmux/.tmux.conf`, whereas the tracked file is `tmux.conf`; `smartcopy` references an untracked/missing `backup_code.py`.
- `.zshrc` and `utils.zsh` both define `preexec`; module sourcing determines the final definition. It writes command text to `~/.cache/last_cmd`, which may contain sensitive arguments.
- `.zshrc` sets `NVIM_FAST_MODE` around command-line editing, but no tracked Neovim code was found consuming that variable. Do not assume it enables a minimal startup.
- Personal absolute paths, mixed display-server APIs, repeated settings, and commented experiments need contextual review rather than repository-wide cleanup.

## Validation

No repository-wide test runner or CI configuration was found. Use non-executing checks on changed files first, from the repository root:

```sh
git diff --check
zsh -f -n .zshrc
zsh -f -n .config/zsh/functions/nav.zsh    # substitute the changed module
bash -n .config/scripts/fast-nvim.sh      # substitute the changed Bash script
python3 -c 'import ast, pathlib; p=pathlib.Path(".config/scripts/db.py"); ast.parse(p.read_text(), filename=str(p))'
# If installed; run from .config/nvim so its formatter config is discovered:
(cd .config/nvim && stylua --check lua/config/keymaps.lua)
```

Parse all Neovim Lua without loading plugins or executing configuration:

```sh
nvim --headless -u NONE -i NONE --noplugin \
  '+lua for _, f in ipairs(vim.fn.glob(".config/nvim/**/*.lua", false, true)) do local chunk, err = loadfile(f); if not chunk then print(err); vim.cmd("cquit") end end' \
  +qa
```

Use Python `json` / `tomllib` for JSON/TOML syntax; TOML support requires Python 3.11+. YAML needs a separate parser/schema-aware tool. Syntax checks do not verify plugin APIs, application schemas, keybinding precedence, external dependencies, or desktop behavior.

Initial analysis checks passed for 11 Zsh files (including `.zshrc`/`.p10k.zsh`), 24 Bash scripts, four Python scripts, 30 Lua files, three JSON files, and six TOML files. YAML and live application behavior were not validated; StyLua and ShellCheck were not available on PATH. This is a snapshot, not a substitute for checking subsequent edits.

Sourcing `.zshrc` may download plugins and execute local environment code. Normal Neovim startup may bootstrap/download plugins; tmux reload can execute TPM and affect existing sessions. Only perform live integration tests when appropriate to the task, with isolation or user agreement. Report exactly which checks ran and which remain unverified.
