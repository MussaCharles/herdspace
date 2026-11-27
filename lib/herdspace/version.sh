# shellcheck shell=bash
# herdspace version, and the notice of a new release.
# bin/herdspace loads this file. It defines functions and variables, and runs nothing.

cmd_version() {
  local have latest
  have="$(installed)"
  printf 'herdspace %s\n' "$have"
  latest="$(latest_now)"
  if [ -z "$latest" ]; then
    printf 'The latest release: unknown. GitHub did not answer.\n'
  elif newer "$latest" "$have"; then
    printf 'The latest release: %s. Run: herdspace update\n' "$latest"
  else
    printf 'The latest release: %s. This is the latest version.\n' "$latest"
  fi
}

cmd_refresh() {
  local latest
  mkdir -p "$CACHE"
  latest="$(latest_now)"
  [ -n "$latest" ] && printf '%s\n' "$latest" >"${CACHE}/latest"
  touch "${CACHE}/latest-checked"
}

cmd_notice() {
  local latest have
  [ "${HERDSPACE_UPDATE_CHECK:-1}" != 0 ] || return 0
  mkdir -p "$CACHE" 2>/dev/null || return 0
  if ! fresh "${CACHE}/latest-checked" 1440; then
    touch "${CACHE}/latest-checked"
    nohup "$0" refresh >/dev/null 2>&1 </dev/null &
  fi
  latest="$(cat "${CACHE}/latest" 2>/dev/null)"
  have="$(installed)"
  [ -n "$latest" ] && newer "$latest" "$have" || return 0
  fresh "${CACHE}/notice-shown" 1440 && return 0
  touch "${CACHE}/notice-shown"
  printf '  herdspace %s is available (you have %s). Run: herdspace update\n' "$latest" "$have"
  printf '  What changed: https://github.com/%s/releases/tag/%s\n' "$REPO" "$latest"
}
