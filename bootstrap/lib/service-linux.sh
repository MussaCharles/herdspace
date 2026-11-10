#!/usr/bin/env bash
# Starts the Herdr server at boot with a systemd user service.

HERDR_UNIT="${HOME}/.config/systemd/user/herdr.service"

render_unit() { sed "s|@HOME@|${HOME}|g" "${REPO_ROOT}/bootstrap/service/herdr.service" >"$1"; }

linux_service_ready() {
  [ "${SKIP_LOGIN_SERVICE:-0}" = "1" ] && return 0
  # A machine with no systemd user session has nothing to set up.
  systemctl --user list-units >/dev/null 2>&1 || return 0
  local tmp status=0
  tmp="$(mktemp)"
  render_unit "$tmp"
  cmp -s "$tmp" "$HERDR_UNIT" || status=1
  rm -f "$tmp"
  [ "$status" -eq 0 ] && systemctl --user is-enabled herdr.service >/dev/null 2>&1
}

install_linux_service() {
  local tmp
  tmp="$(mktemp)"
  render_unit "$tmp"
  install_file "$tmp" "$HERDR_UNIT"
  rm -f "$tmp"
  systemctl --user daemon-reload
  systemctl --user enable herdr.service >/dev/null 2>&1
  # A linger keeps the user service running with no login.
  run_root loginctl enable-linger "$(id -un)" || warn "Could not turn on linger. Herdr starts at your first login."
  if ! server_answers; then
    systemctl --user start herdr.service || warn "The service did not start."
  fi
}
