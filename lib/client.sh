#!/usr/bin/env bash
# Steps that are the same on a macOS client and on a Linux client.

SSH_CHECK=(-o BatchMode=yes -o ConnectTimeout=5)

# terminfo_ready exits 0 if the server has the description. A server that does
# not answer also counts, so that it does not stop the run.
terminfo_ready() {
  local server="$1"
  if ! ssh "${SSH_CHECK[@]}" -- "$server" true 2>/dev/null; then
    warn "Could not connect to ${server}, so this script skips it."
    return 0
  fi
  ssh "${SSH_CHECK[@]}" -- "$server" infocmp -x xterm-ghostty >/dev/null 2>&1
}

# copy_terminfo sends the Ghostty terminal description to one server.
copy_terminfo() {
  local server="$1"
  infocmp -x xterm-ghostty | ssh -- "$server" tic -x - 2>/dev/null || warn "Could not copy the terminal description to ${server}."
}
