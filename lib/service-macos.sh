#!/usr/bin/env bash
# Starts the Herdr server at login with a LaunchAgent. The script never stops a
# server that was already running, because a stop closes every pane.

HERDR_LABEL="local.herdr.server"
HERDR_PLIST="${HOME}/Library/LaunchAgents/${HERDR_LABEL}.plist"

render_plist() {
  sed -e "s|@HOME@|${HOME}|g" -e "s|@HERDR@|$(command -v herdr)|g" -e "s|@LABEL@|${HERDR_LABEL}|g" \
    "${REPO_ROOT}/service/herdr.plist" >"$1"
}

macos_service_ready() {
  [ "${SKIP_LOGIN_SERVICE:-0}" = "1" ] && return 0
  have herdr || return 1
  local tmp status=0
  tmp="$(mktemp)"
  render_plist "$tmp"
  cmp -s "$tmp" "$HERDR_PLIST" || status=1
  rm -f "$tmp"
  [ "$status" -eq 0 ] || return 1
  launchctl print "gui/$(id -u)/${HERDR_LABEL}" >/dev/null 2>&1 || server_answers
}

install_macos_service() {
  local tmp domain
  domain="gui/$(id -u)"
  tmp="$(mktemp)"
  render_plist "$tmp"
  install_file "$tmp" "$HERDR_PLIST"
  rm -f "$tmp"
  if launchctl print "${domain}/${HERDR_LABEL}" >/dev/null 2>&1; then
    ok "The LaunchAgent is already loaded"
  elif server_answers; then
    info "A Herdr server is running, so the LaunchAgent starts at the next login."
  else
    launchctl bootstrap "$domain" "$HERDR_PLIST" || warn "The LaunchAgent starts at the next login."
  fi
}
