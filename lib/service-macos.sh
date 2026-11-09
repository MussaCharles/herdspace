#!/usr/bin/env bash
# Starts the Herdr server at login with a LaunchAgent. The script never stops a
# server that was already running, because a stop closes every pane.

HERDR_LABEL="local.herdr.server"

install_macos_service() {
  step "Start Herdr at login"
  if [ "${SKIP_LOGIN_SERVICE:-0}" = "1" ]; then
    info "Skipped the LaunchAgent."
    stop_setup_server
    return 0
  fi
  local plist="${HOME}/Library/LaunchAgents/${HERDR_LABEL}.plist" tmp domain
  domain="gui/$(id -u)"
  tmp="$(mktemp)"
  sed -e "s|@HOME@|${HOME}|g" -e "s|@HERDR@|$(command -v herdr)|g" -e "s|@LABEL@|${HERDR_LABEL}|g" \
    "${REPO_ROOT}/service/herdr.plist" >"$tmp"
  install_file "$tmp" "$plist"
  rm -f "$tmp"
  stop_setup_server
  if launchctl print "${domain}/${HERDR_LABEL}" >/dev/null 2>&1; then
    ok "The LaunchAgent is already loaded"
  elif server_answers; then
    info "A Herdr server is running, so the LaunchAgent starts at the next login."
  else
    launchctl bootstrap "$domain" "$plist" || warn "The LaunchAgent starts at the next login."
    ok "$HERDR_LABEL"
  fi
}
