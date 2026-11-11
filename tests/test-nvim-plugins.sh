#!/usr/bin/env bash
# test-nvim-plugins.sh checks the Neovim plugin step with a stub nvim: a failed
# download gives a warning and no done mark, and a good one gives the mark.
# Usage: tests/test-nvim-plugins.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; failures=$((failures + 1)); }

# run_step MODE runs the step in a fresh home. MODE "fail" is a stub nvim that
# exits 0 and downloads nothing, as Lazy does when GitHub does not answer.
# MODE "ok" is a stub that makes the LazyVim folder.
run_step() {
  local home="${tmp}/$1"
  mkdir -p "${home}/bin"
  if [ "$1" = ok ]; then
    printf '#!/bin/sh\nmkdir -p "$HOME/.local/share/nvim/lazy/LazyVim"\necho run >>"$HOME/runs"\n' >"${home}/bin/nvim"
  else
    printf '#!/bin/sh\necho run >>"$HOME/runs"\nexit 0\n' >"${home}/bin/nvim"
  fi
  chmod 755 "${home}/bin/nvim"
  HOME="$home" PATH="${home}/bin:/usr/bin:/bin" REPO_ROOT="$ROOT" bash -c '
    source "$REPO_ROOT/bootstrap/lib/common.sh"
    source "$REPO_ROOT/bootstrap/lib/server.sh"
    install_nvim_plugins
    if nvim_plugins_ready; then echo READY; else echo NOT_READY; fi
  ' 2>&1
}

out="$(run_step fail)"
case "$out" in *"could not download its plugins"*) pass "a failed download gives a warning" ;; *) fail "a failed download gives a warning: $out" ;; esac
case "$out" in *NOT_READY*) pass "a failed download writes no done mark" ;; *) fail "a failed download writes no done mark: $out" ;; esac
[ "$(wc -l <"${tmp}/fail/runs" | tr -d ' ')" = 2 ] && pass "a failed download is tried two times" || fail "a failed download is tried two times"
out="$(run_step ok)"
case "$out" in *NOT_READY*) fail "a good download writes the done mark: $out" ;; *READY*) pass "a good download writes the done mark" ;; *) fail "a good download writes the done mark: $out" ;; esac
case "$out" in *warn*) fail "a good download gives no warning: $out" ;; *) pass "a good download gives no warning" ;; esac
[ "$(wc -l <"${tmp}/ok/runs" | tr -d ' ')" = 1 ] && pass "a good download runs one time" || fail "a good download runs one time"
echo "RESULT failures=${failures}"
exit $((failures > 0))
