#!/usr/bin/env bash
# Starts the Herdr server at boot with a systemd user service.

install_linux_service() {
  step "Start Herdr at boot"
  if [ "${SKIP_LOGIN_SERVICE:-0}" = "1" ]; then
    info "Skipped the service."
    stop_setup_server
    return 0
  fi
  local unit="${HOME}/.config/systemd/user/herdr.service" tmp
  tmp="$(mktemp)"
  sed "s|@HOME@|${HOME}|g" "${REPO_ROOT}/service/herdr.service" >"$tmp"
  install_file "$tmp" "$unit"
  rm -f "$tmp"
  if ! systemctl --user daemon-reload 2>/dev/null; then
    warn "This computer has no systemd user session. Herdr starts when you run: herdr"
    stop_setup_server
    return 0
  fi
  systemctl --user enable herdr.service >/dev/null 2>&1
  # A linger keeps the user service running with no login.
  run_root loginctl enable-linger "$(id -un)" || warn "Could not turn on linger. Herdr starts at your first login."
  stop_setup_server
  if ! server_answers; then
    systemctl --user start herdr.service || warn "The service did not start."
  fi
  ok "herdr.service"
}
