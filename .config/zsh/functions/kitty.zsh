# Toggle Kitty between the configured transparent opacity and fully opaque.
# `--toggle 1.0` resets to background_opacity (0.8) when currently opaque.
TT() {
  if ! command -v kitty >/dev/null 2>&1; then
    print -u2 'TT: kitty is not installed or not on PATH'
    return 127
  fi

  local socket_path
  if [[ ${KITTY_LISTEN_ON:-} == unix:* ]]; then
    socket_path=${KITTY_LISTEN_ON#unix:}
    if [[ -S $socket_path ]]; then
      kitty @ --to "$KITTY_LISTEN_ON" set-background-opacity --toggle 1.0
      return $?
    fi
  fi

  # Kitty can inherit a stale socket address after its process is restarted.
  local -a sockets
  sockets=("${XDG_RUNTIME_DIR:-/run/user/$UID}"/kitty-focus-app-search-*.sock(N))
  if (( ${#sockets[@]} == 1 )); then
    kitty @ --to "unix:${sockets[1]}" set-background-opacity --toggle 1.0
    return $?
  fi

  print -u2 'TT: could not find exactly one live Kitty control socket; open a fresh Kitty shell or check listen_on in kitty.conf'
  return 1
}
