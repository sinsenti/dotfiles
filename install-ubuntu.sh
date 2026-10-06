#!/usr/bin/env bash
# Provision the applications and runtime packages referenced by these dotfiles.
# This installs software only; it does not stow configs, change the login shell,
# explicitly enable/start services, create privileged groups, download speech models,
# or source configs.
set -Eeuo pipefail

SCRIPT_NAME=${0##*/}
PROFILE=full
DRY_RUN=0
ASSUME_YES=0
WITH_DOCKER=0
WITH_VOXTYPE=0
WITH_WIFI=0
SKIPPED_PACKAGES=()

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [options]

Ubuntu workstation dependency installer. The default profile is "full".

Options:
  --minimal          Install the shell/editor/CLI foundation; skip optional
                     desktop/OCR/media and Java/Go APT packages.
  --with-docker      Add Docker's official Ubuntu repository and install Docker
                     Engine + Compose. Package installation may start the daemon.
  --with-voxtype     Install Voxtype's official .deb on Ubuntu 24.04+ amd64.
                     Does not download the configured speech model or alter groups.
  --with-wifi        Install NetworkManager for the optional nmcli helpers.
  --dry-run          Print planned package installs and upstream installers only.
  --yes              Pass -y to apt; does not suppress errors or enable services.
  -h, --help         Show this help.

The installer never deploys this repository. Review its source before running:
  bash $SCRIPT_NAME --dry-run
  bash $SCRIPT_NAME
EOF
}

while (($#)); do
  case "$1" in
  --minimal) PROFILE=minimal ;;
  --with-docker) WITH_DOCKER=1 ;;
  --with-voxtype) WITH_VOXTYPE=1 ;;
  --with-wifi) WITH_WIFI=1 ;;
  --dry-run) DRY_RUN=1 ;;
  --yes) ASSUME_YES=1 ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    printf 'Unknown option: %s\n\n' "$1" >&2
    usage >&2
    exit 2
    ;;
  esac
  shift
done

log() { printf '\n==> %s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }

if [[ ! -r /etc/os-release ]]; then
  printf 'Cannot identify this operating system (missing /etc/os-release).\n' >&2
  exit 1
fi
# shellcheck disable=SC1091
. /etc/os-release
if [[ ${ID:-} != ubuntu ]]; then
  printf 'This script targets Ubuntu; detected ID=%s. No changes made.\n' "${ID:-unknown}" >&2
  exit 1
fi
if ((EUID == 0 && !DRY_RUN)); then
  printf 'Run this as your normal user; the script uses sudo only for APT operations.\n' >&2
  exit 1
fi

ARCH=$(dpkg --print-architecture)
case "$ARCH" in
amd64)
  RELEASE_ARCH=x86_64
  BUN_ARCH=x64
  VOXTYPE_ARCH=amd64
  ;;
arm64)
  RELEASE_ARCH=arm64
  BUN_ARCH=aarch64
  VOXTYPE_ARCH=arm64
  ;;
*)
  printf 'Unsupported architecture: %s (supported: amd64, arm64).\n' "$ARCH" >&2
  exit 1
  ;;
esac

export PATH="$HOME/.pi/agent/bin:$HOME/.atuin/bin:$HOME/.bun/bin:$HOME/.local/bin:$HOME/.cargo/bin:$HOME/go/bin:$PATH"

run_or_print() {
  if ((DRY_RUN)); then
    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

apt_install_available() {
  local package candidate
  local -a available=()
  for package in "$@"; do
    if ((DRY_RUN)); then
      available+=("$package")
      continue
    fi
    candidate=$(apt-cache policy "$package" 2>/dev/null | awk '/Candidate:/ { print $2; exit }')
    if [[ -n $candidate && $candidate != '(none)' ]]; then
      available+=("$package")
    else
      SKIPPED_PACKAGES+=("$package")
    fi
  done

  if ((${#available[@]} == 0)); then
    return 0
  fi
  local -a args=(apt-get install --no-install-recommends)
  ((ASSUME_YES)) && args+=(-y)
  run_or_print sudo "${args[@]}" "${available[@]}"
}

apt_update() {
  run_or_print sudo apt-get update
}

install_core_apt_packages() {
  log 'Installing Ubuntu shell and CLI packages'
  apt_install_available \
    bash-completion build-essential bzip2 ca-certificates curl file findutils fzf \
    fd-find bat git gnupg jq less pkg-config pipx python3 python3-pip \
    python3-tk python3-venv ripgrep stow tmux unzip wget zsh
}

install_desktop_apt_packages() {
  log 'Installing desktop, document, OCR, and media dependencies'
  apt_install_available \
    btop chafa dbus-x11 eza ffmpeg fonts-powerline gnome-screenshot \
    libglib2.0-bin libimage-exiftool-perl libnotify-bin mediainfo mpv ncompress \
    ocrmypdf p7zip-full poppler-utils python3-fitz python3-pil python3-pyqt6 \
    python3-pytesseract qpdf rofi taskwarrior tesseract-ocr tesseract-ocr-eng \
    tesseract-ocr-rus thunar translate-shell unrar-free wmctrl x11-utils xclip \
    xdotool xsel wl-clipboard ydotool imagemagick xdg-utils zathura \
    zathura-pdf-poppler
}

install_development_apt_packages() {
  log 'Installing language and editor build prerequisites'
  apt_install_available default-jdk golang-go libssl-dev
}

add_yazi_repository() {
  local key=/usr/share/keyrings/yazi-keyring.gpg
  local source=/etc/apt/sources.list.d/yazi.list
  if [[ -e $source ]]; then
    log 'Yazi APT source already exists; leaving it untouched'
    return 0
  fi
  if ((DRY_RUN)); then
    printf '[dry-run] Add Yazi signed APT source: %s\n' 'https://yazi-rs.github.io/docs/installation/'
    return 0
  fi
  local temp_key
  temp_key=$(mktemp)
  trap 'rm -f -- "$temp_key"' RETURN
  curl --proto '=https' --tlsv1.2 -fsSL https://yazi-rs.github.io/builds/yazi-keyring.gpg -o "$temp_key"
  sudo install -D -m 0644 "$temp_key" "$key"
  printf '%s\n' 'deb [signed-by=/usr/share/keyrings/yazi-keyring.gpg] https://yazi-rs.github.io/builds/ stable main' |
    sudo tee "$source" >/dev/null
  rm -f -- "$temp_key"
  trap - RETURN
  apt_update
}

add_github_cli_repository() {
  local key=/etc/apt/keyrings/githubcli-archive-keyring.gpg
  local source=/etc/apt/sources.list.d/github-cli.list
  if [[ -e $source ]]; then
    log 'GitHub CLI APT source already exists; leaving it untouched'
    return 0
  fi
  if ((DRY_RUN)); then
    printf '[dry-run] Add GitHub CLI signed APT source: %s\n' 'https://github.com/cli/cli/blob/trunk/docs/install_linux.md'
    return 0
  fi
  local temp_key
  temp_key=$(mktemp)
  trap 'rm -f -- "$temp_key"' RETURN
  curl --proto '=https' --tlsv1.2 -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o "$temp_key"
  sudo install -D -m 0644 "$temp_key" "$key"
  printf 'deb [arch=%s signed-by=%s] https://cli.github.com/packages stable main\n' "$ARCH" "$key" |
    sudo tee "$source" >/dev/null
  rm -f -- "$temp_key"
  trap - RETURN
  apt_update
}

add_docker_repository() {
  local key=/etc/apt/keyrings/docker.asc
  local source=/etc/apt/sources.list.d/docker.sources
  if [[ -e $source ]]; then
    log 'Docker APT source already exists; leaving it untouched'
    return 0
  fi
  if ((DRY_RUN)); then
    printf '[dry-run] Add Docker signed APT source and install Docker Engine + Compose.\n'
    return 0
  fi
  local ubuntu_codename=${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}
  if [[ -z $ubuntu_codename ]]; then
    printf 'Could not determine the Ubuntu APT codename; not adding Docker source.\n' >&2
    return 1
  fi
  local temp_key
  temp_key=$(mktemp)
  trap 'rm -f -- "$temp_key"' RETURN
  curl --proto '=https' --tlsv1.2 -fsSL https://download.docker.com/linux/ubuntu/gpg -o "$temp_key"
  sudo install -D -m 0644 "$temp_key" "$key"
  sudo tee "$source" >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $ubuntu_codename
Components: stable
Architectures: $ARCH
Signed-By: $key
EOF
  rm -f -- "$temp_key"
  trap - RETURN
  apt_update
}

install_official_apt_apps() {
  add_yazi_repository
  add_github_cli_repository
  log 'Installing Kitty (Ubuntu package provides the /usr/bin/kitty path used by this setup) and Yazi/GitHub CLI'
  apt_install_available gh kitty yazi
}

latest_github_release_tag() {
  local repository=$1
  curl --proto '=https' --tlsv1.2 -fsSL \
    -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2022-11-28' \
    "https://api.github.com/repos/$repository/releases/latest" | jq -er '.tag_name'
}

install_nvim() {
  if command -v nvim >/dev/null 2>&1; then
    log "Neovim already available at $(command -v nvim); leaving it in place"
    return 0
  fi
  if [[ -e $HOME/.local/bin/nvim || -L $HOME/.local/bin/nvim ]]; then
    warn "$HOME/.local/bin/nvim already exists; not replacing it"
    return 0
  fi
  local tag version archive_dir archive url
  if ((DRY_RUN)); then
    printf '[dry-run] Download the latest official Neovim archive for %s into ~/.local/opt/nvim/<version>\n' "$ARCH"
    return 0
  fi
  tag=$(latest_github_release_tag neovim/neovim)
  version=${tag#v}
  archive_dir="$HOME/.local/opt/nvim/$version"
  archive="$archive_dir/nvim-linux-$RELEASE_ARCH.tar.gz"
  mkdir -p "$archive_dir" "$HOME/.local/bin"
  url="https://github.com/neovim/neovim/releases/download/$tag/nvim-linux-$RELEASE_ARCH.tar.gz"
  curl --proto '=https' --tlsv1.2 -fL "$url" -o "$archive"
  tar -xzf "$archive" --strip-components=1 -C "$archive_dir"
  rm -f -- "$archive"
  ln -s "$archive_dir/bin/nvim" "$HOME/.local/bin/nvim"
}

install_github_release_tool() {
  local repository=$1 asset=$2 executable=$3
  local destination="$HOME/.local/bin/$executable"
  if ((DRY_RUN)); then
    printf '[dry-run] Download official %s release asset %s to %s\n' "$repository" "$asset" "$destination"
    return 0
  fi
  if command -v "$executable" >/dev/null 2>&1; then
    log "$executable already available at $(command -v "$executable"); leaving it in place"
    return 0
  fi
  if [[ -e $destination || -L $destination ]]; then
    warn "$destination already exists; not replacing it"
    return 0
  fi
  local tag version temp_dir archive binary
  tag=$(latest_github_release_tag "$repository")
  version=${tag#v}
  temp_dir=$(mktemp -d)
  trap 'rm -rf -- "$temp_dir"' RETURN
  archive="$temp_dir/$asset"
  curl --proto '=https' --tlsv1.2 -fL \
    "https://github.com/$repository/releases/download/$tag/$asset" -o "$archive"
  tar -xzf "$archive" -C "$temp_dir"
  binary=$(find "$temp_dir" -type f -name "$executable" -print -quit)
  if [[ -z $binary ]]; then
    printf 'Could not find %s in release %s (%s).\n' "$executable" "$tag" "$repository" >&2
    return 1
  fi
  install -D -m 0755 "$binary" "$destination"
  rm -rf -- "$temp_dir"
  trap - RETURN
  log "Installed $executable $version to $destination"
}

install_lazygit() {
  local lazygit_arch
  case "$ARCH" in amd64) lazygit_arch=x86_64 ;; arm64) lazygit_arch=arm64 ;; esac
  local tag version asset temp_dir binary
  if command -v lazygit >/dev/null 2>&1; then
    log "lazygit already available at $(command -v lazygit); leaving it in place"
    return 0
  fi
  if [[ -e $HOME/.local/bin/lazygit || -L $HOME/.local/bin/lazygit ]]; then
    warn "$HOME/.local/bin/lazygit already exists; not replacing it"
    return 0
  fi
  if ((DRY_RUN)); then
    printf '[dry-run] Download the latest official lazygit Linux %s release to ~/.local/bin/lazygit\n' "$lazygit_arch"
    return 0
  fi
  tag=$(latest_github_release_tag jesseduffield/lazygit)
  version=${tag#v}
  asset="lazygit_${version}_Linux_${lazygit_arch}.tar.gz"
  temp_dir=$(mktemp -d)
  trap 'rm -rf -- "$temp_dir"' RETURN
  curl --proto '=https' --tlsv1.2 -fL \
    "https://github.com/jesseduffield/lazygit/releases/download/$tag/$asset" -o "$temp_dir/$asset"
  tar -xzf "$temp_dir/$asset" -C "$temp_dir" lazygit
  binary="$temp_dir/lazygit"
  install -D -m 0755 "$binary" "$HOME/.local/bin/lazygit"
  rm -rf -- "$temp_dir"
  trap - RETURN
}

install_carapace() {
  local tag version asset asset_arch
  case "$ARCH" in amd64) asset_arch=amd64 ;; arm64) asset_arch=arm64 ;; esac
  if command -v carapace >/dev/null 2>&1; then
    log "Carapace already available at $(command -v carapace); leaving it in place"
    return 0
  fi
  if [[ -e $HOME/.local/bin/carapace || -L $HOME/.local/bin/carapace ]]; then
    warn "$HOME/.local/bin/carapace already exists; not replacing it"
    return 0
  fi
  if ((DRY_RUN)); then
    printf '[dry-run] Download the latest official Carapace Linux %s release to ~/.local/bin/carapace\n' "$asset_arch"
    return 0
  fi
  tag=$(latest_github_release_tag carapace-sh/carapace-bin)
  version=${tag#v}
  asset="carapace-bin_${version}_linux_${asset_arch}.tar.gz"
  install_github_release_tool carapace-sh/carapace-bin "$asset" carapace
}

install_bun() {
  if command -v bun >/dev/null 2>&1; then
    log "Bun already available at $(command -v bun); leaving it in place"
    return 0
  fi
  local destination="$HOME/.bun/bin/bun"
  if [[ -e $destination || -L $destination ]]; then
    warn "$destination already exists; not replacing it"
    return 0
  fi
  local temp_dir archive binary
  archive="bun-linux-$BUN_ARCH.zip"
  if ((DRY_RUN)); then
    printf '[dry-run] Download official Bun Linux %s archive into ~/.bun/bin (without editing shell rc files)\n' "$BUN_ARCH"
    return 0
  fi
  temp_dir=$(mktemp -d)
  trap 'rm -rf -- "$temp_dir"' RETURN
  curl --proto '=https' --tlsv1.2 -fL \
    "https://github.com/oven-sh/bun/releases/latest/download/$archive" -o "$temp_dir/$archive"
  unzip -q "$temp_dir/$archive" -d "$temp_dir"
  binary=$(find "$temp_dir" -type f -name bun -print -quit)
  [[ -n $binary ]] || {
    printf 'Bun archive did not contain the bun executable.\n' >&2
    return 1
  }
  install -D -m 0755 "$binary" "$destination"
  rm -rf -- "$temp_dir"
  trap - RETURN
}

install_nvm_and_node() {
  if [[ ! -s $HOME/.nvm/nvm.sh ]]; then
    if ((DRY_RUN)); then
      printf '[dry-run] Install NVM v0.40.8 with PROFILE=/dev/null (do not edit shell rc files)\n'
    else
      mkdir -p "$HOME/.nvm"
      curl --proto '=https' --tlsv1.2 -fsSL \
        https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh |
        PROFILE=/dev/null NVM_DIR="$HOME/.nvm" bash
    fi
  fi
  if ((DRY_RUN)); then
    printf '[dry-run] Use NVM to install Node.js LTS and npm package sql-formatter\n'
    return 0
  fi
  # This repo's .zshrc deliberately lazy-loads NVM; load it only in this process.
  # shellcheck disable=SC1090
  . "$HOME/.nvm/nvm.sh"
  nvm install --lts
  nvm use --lts
  npm install --global sql-formatter
}

install_rust_and_worktrunk() {
  if command -v wt >/dev/null 2>&1; then
    log "Worktrunk already available at $(command -v wt); leaving it in place"
    return 0
  fi
  if ((DRY_RUN)); then
    if command -v cargo >/dev/null 2>&1; then
      printf '[dry-run] cargo install worktrunk (only if Git is 2.43 or newer)\n'
    else
      printf '[dry-run] Install Rust with rustup, then cargo install worktrunk (only if Git is 2.43 or newer)\n'
    fi
    return 0
  fi
  if ! command -v cargo >/dev/null 2>&1; then
    run_shell_installer 'Rustup' https://sh.rustup.rs sh -s -- -y --no-modify-path
    export PATH="$HOME/.cargo/bin:$PATH"
  fi
  if ! command -v cargo >/dev/null 2>&1; then
    warn 'Cargo is unavailable; cannot install Worktrunk. Install Rust with rustup and rerun.'
    return 0
  fi
  local git_version
  git_version=$(git --version | awk '{print $3}')
  if dpkg --compare-versions "$git_version" ge 2.43; then
    run_or_print cargo install worktrunk
  else
    warn "Worktrunk requires Git 2.43+ (found $git_version); it was not installed."
  fi
}

install_voxtype() {
  if [[ $ARCH != amd64 ]]; then
    printf 'The official Voxtype package is currently supported here only on amd64.\n' >&2
    return 1
  fi
  if ! dpkg --compare-versions "${VERSION_ID:-0}" ge 24.04; then
    printf 'Voxtype binary packages require Ubuntu 24.04+; detected %s.\n' "${VERSION_ID:-unknown}" >&2
    return 1
  fi
  local release asset url temp_deb
  if ((DRY_RUN)); then
    printf '[dry-run] Install latest official Voxtype .deb for %s; do not download its local speech model\n' "$VOXTYPE_ARCH"
    return 0
  fi
  release=$(curl --proto '=https' --tlsv1.2 -fsSL \
    -H 'Accept: application/vnd.github+json' \
    https://api.github.com/repos/peteonrails/voxtype/releases/latest)
  asset=$(jq -er --arg arch "_${VOXTYPE_ARCH}.deb" '.assets[] | select(.name | endswith($arch)) | .browser_download_url' <<<"$release" | head -n 1)
  url=$asset
  temp_deb=$(mktemp --suffix=.deb)
  trap 'rm -f -- "$temp_deb"' RETURN
  curl --proto '=https' --tlsv1.2 -fL "$url" -o "$temp_deb"
  local -a args=(apt-get install)
  ((ASSUME_YES)) && args+=(-y)
  run_or_print sudo "${args[@]}" "$temp_deb"
  rm -f -- "$temp_deb"
  trap - RETURN
}

create_ubuntu_command_compat_links() {
  ((DRY_RUN)) && {
    printf '[dry-run] Create non-overwriting fd/bat/exa compatibility links under ~/.local/bin\n'
    return 0
  }
  mkdir -p "$HOME/.local/bin"
  local source name
  for pair in 'fd:fdfind' 'bat:batcat' 'exa:eza'; do
    name=${pair%%:*}
    source=${pair#*:}
    if ! command -v "$name" >/dev/null 2>&1 &&
      command -v "$source" >/dev/null 2>&1 &&
      [[ ! -e $HOME/.local/bin/$name && ! -L $HOME/.local/bin/$name ]]; then
      ln -s "$(command -v "$source")" "$HOME/.local/bin/$name"
    fi
  done
}

install_user_apps() {
  log 'Installing official user-level tools'
  if ! command -v pi >/dev/null 2>&1; then
    run_shell_installer 'Pi coding agent' https://pi.dev/install.sh sh
  else
    log "Pi already available at $(command -v pi); leaving it in place"
  fi
  if ! command -v atuin >/dev/null 2>&1; then
    run_shell_installer 'Atuin' https://setup.atuin.sh sh -s -- --non-interactive
  else
    log "Atuin already available at $(command -v atuin); leaving it in place"
  fi
  if ! command -v zoxide >/dev/null 2>&1; then
    run_shell_installer 'Zoxide' https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh sh
  else
    log "Zoxide already available at $(command -v zoxide); leaving it in place"
  fi
  if ! command -v uv >/dev/null 2>&1; then
    run_shell_installer 'uv' https://astral.sh/uv/install.sh sh
  else
    log "uv already available at $(command -v uv); leaving it in place"
  fi
  install_bun
  install_nvim
  install_rust_and_worktrunk
  if ! command -v workmux >/dev/null 2>&1; then
    run_shell_installer 'Workmux' https://raw.githubusercontent.com/raine/workmux/main/scripts/install.sh bash
  else
    log "Workmux already available at $(command -v workmux); leaving it in place"
  fi
  install_carapace
  install_lazygit
  if command -v diffnav >/dev/null 2>&1; then
    log "diffnav already available at $(command -v diffnav); leaving it in place"
  elif command -v go >/dev/null 2>&1; then
    run_or_print go install github.com/dlvhdr/diffnav@latest
  elif ((DRY_RUN)) && [[ $PROFILE == full ]]; then
    printf '[dry-run] go install github.com/dlvhdr/diffnav@latest (after golang-go is installed)\n'
  else
    log 'Skipping diffnav (Go is unavailable)'
  fi
  if command -v gh >/dev/null 2>&1; then
    if ((DRY_RUN)); then
      printf '[dry-run] gh extension install dlvhdr/gh-dash\n'
    elif ! gh extension list 2>/dev/null | grep -q 'dlvhdr/gh-dash'; then
      gh extension install dlvhdr/gh-dash
    fi
  else
    warn 'GitHub CLI unavailable; gh-dash extension was not installed.'
  fi
  install_nvm_and_node
}

run_shell_installer() {
  local label=$1 url=$2 interpreter=$3
  shift 3
  if ((DRY_RUN)); then
    printf '[dry-run] %s: curl -fsSL %q | %q' "$label" "$url" "$interpreter"
    printf ' %q' "$@"
    printf '\n'
  else
    curl --proto '=https' --tlsv1.2 -fsSL "$url" | "$interpreter" "$@"
  fi
}

install_docker_engine() {
  log 'Adding Docker official Ubuntu APT repository (explicitly requested)'
  add_docker_repository
  apt_install_available docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  warn 'Docker may be started by package-manager post-install hooks. No user is added to the root-equivalent docker group.'
}

install_voxtype_dependencies() {
  apt_install_available libnotify-bin pipewire-alsa playerctl wl-clipboard wtype
  install_voxtype
}

main() {
  log "Ubuntu ${VERSION_ID:-unknown} / ${ARCH}; profile=$PROFILE"
  if ((DRY_RUN)); then
    printf 'Dry-run: no apt, network, filesystem, or shell-profile changes will be made.\n'
  else
    if ! command -v sudo >/dev/null 2>&1; then
      printf 'sudo is required to install Ubuntu packages.\n' >&2
      exit 1
    fi
    apt_update
  fi

  install_core_apt_packages
  if [[ $PROFILE == full ]]; then
    install_desktop_apt_packages
    install_development_apt_packages
  fi
  install_official_apt_apps
  if ((WITH_WIFI)); then
    warn 'Installing NetworkManager can affect host networking; use --with-wifi only on the intended workstation.'
    apt_install_available network-manager
  fi
  create_ubuntu_command_compat_links
  install_user_apps
  if ((WITH_DOCKER)); then
    install_docker_engine
  fi
  if ((WITH_VOXTYPE)); then
    install_voxtype_dependencies
  fi

  if ((${#SKIPPED_PACKAGES[@]})); then
    printf '\nPackages unavailable from the currently configured Ubuntu APT sources (not installed):\n'
    printf '  %s\n' "${SKIPPED_PACKAGES[@]}"
    printf 'Enable Ubuntu Universe or install the corresponding upstream package if you need these features.\n'
  fi

  cat <<'EOF'

Next steps (not performed automatically):
  1. Preview and review dotfile links: stow -n -v --ignore='^AGENTS\.md$' .
  2. Deploy only after reviewing:       stow --ignore='^AGENTS\.md$' .
  3. Start zsh, Neovim, and tmux when ready; their configs bootstrap plugins on first use.
  4. Run `gh auth login` before GitHub workflows. Review/configure desktop portal,
     GNOME Shell extension, Wayland/X11 input services, and Voxtype model separately.

This script does not install private/project-specific tools (for example a1aws),
unknown commands referenced by local configs (for example tuicr), or the custom
GNOME Window Calls extension. See README.md for the remaining manual requirements.
EOF
}

main "$@"
