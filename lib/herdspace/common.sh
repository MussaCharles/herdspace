# shellcheck shell=bash
# The helpers that more than one command of herdspace uses.
# bin/herdspace loads this file. It defines functions and variables, and runs nothing.

die() { printf '  [err]  %s\n' "$*" >&2; exit 1; }

installed() { cat "${STATE}/version" 2>/dev/null || echo unknown; }

# latest_now asks GitHub for the tag of the latest release. The latest release
# is never a pre-release. It sends no data about this machine.
latest_now() {
  curl -fsSI --connect-timeout 3 --max-time 6 "https://github.com/${REPO}/releases/latest" 2>/dev/null |
    tr -d '\r' | awk 'tolower($1) == "location:" {print $2}' | tail -n 1 | sed -n 's|.*/releases/tag/\([0-9][^/]*\)$|\1|p'
}

# newer A B succeeds if version A is newer than version B.
newer() {
  case "$1$2" in *[!0-9.]*) return 1 ;; esac
  [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -t . -k 1,1n -k 2,2n -k 3,3n | tail -n 1)" = "$1" ]
}

sha_of() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d ' ' -f 1; else shasum -a 256 "$1" | cut -d ' ' -f 1; fi; }

# fresh FILE MINUTES succeeds if FILE changed in the last MINUTES.
fresh() { [ -n "$(find "$1" -mmin "-$2" 2>/dev/null)" ]; }
