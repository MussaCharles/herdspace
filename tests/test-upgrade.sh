#!/usr/bin/env bash
# test-upgrade.sh installs an older release, and then updates to this folder,
# as a person does. An update must not ask about a file that the person did not
# change, also for an install from before the manifest existed. A file that the
# person changed must stay, with a question.
# Usage: tests/test-upgrade.sh TAG [setup options]   It runs in a test container.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
failures=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; failures=$((failures + 1)); }
TAG="$1"
shift
REPO="${HS_REPO:-MussaCharles/herdspace}"
MANIFEST="${HOME}/.local/share/herdspace/manifest.tsv"
EDIT="${HOME}/.config/nvim/lua/config/options.lua"
export PATH="${HOME}/.local/bin:${PATH}"

# differs prints the files that a --check of this folder counts as changed.
differs() {
  ./bootstrap.sh server --check "$@" 2>&1 | sed -n 's/^ *\[diff\] \(.*\) differs from this repository$/\1/p'
}

echo "== install ${TAG}"
# A fresh test image has no curl. A person downloads the setup with it.
command -v curl >/dev/null || { sudo apt-get update -qq && sudo apt-get install -y -qq curl >/dev/null; } >/tmp/upgrade-curl.log 2>&1
if ! curl -fsSL "https://github.com/${REPO}/releases/download/${TAG}/bootstrap.sh" | bash -s -- server "$@" >/tmp/upgrade-old.log 2>&1; then
  tail -n 20 /tmp/upgrade-old.log
  fail "${TAG} installs"
  echo "RESULT upgrade-${TAG} failures=${failures}"
  exit 1
fi
pass "${TAG} installs"

out="$(differs "$@")"
[ -z "$out" ] && pass "${TAG}: an update asks about no file" || fail "${TAG}: an update asks about no file: ${out}"

# An install from before the manifest: the setup knows the files from the list
# of older versions.
[ -f "$MANIFEST" ] && mv "$MANIFEST" "${MANIFEST}.saved"
out="$(differs "$@")"
[ -z "$out" ] && pass "${TAG} with no manifest: an update asks about no file" || fail "${TAG} with no manifest: an update asks about no file: ${out}"

printf -- '-- A line of the person.\n' >>"$EDIT"
out="$(differs "$@")"
[ "$out" = "$EDIT" ] && pass "${TAG} with no manifest: an update asks about the changed file only" || fail "${TAG} with no manifest: an update asks about the changed file only: ${out}"

echo "== update to this folder, with no terminal"
./bootstrap.sh server "$@" </dev/null >/tmp/upgrade-new.log 2>&1 || { tail -n 20 /tmp/upgrade-new.log; fail "the update runs"; }
grep -q 'A line of the person' "$EDIT" && pass "the update keeps the changed file" || fail "the update keeps the changed file"
backups="$(find "$HOME" -name '*.bak-*' -not -path '*/.cache/*' -not -path '*/.oh-my-zsh/*' | grep -c 'nvim')"
[ "$backups" -eq 0 ] && pass "the update makes no backup of a Neovim file" || fail "the update makes no backup of a Neovim file: ${backups}"

out="$(differs "$@")"
[ "$out" = "$EDIT" ] && pass "after the update, only the changed file differs" || fail "after the update, only the changed file differs: ${out}"
before="$(find "$HOME" -name '*.bak-*' -not -path '*/.cache/*' | wc -l)"
./bootstrap.sh server "$@" </dev/null >/tmp/upgrade-again.log 2>&1 || fail "a second update runs"
after="$(find "$HOME" -name '*.bak-*' -not -path '*/.cache/*' | wc -l)"
[ "$before" -eq "$after" ] && pass "a second update changes no file" || fail "a second update changes no file: ${before} ${after} backups"

echo "RESULT upgrade-${TAG} failures=${failures}"
exit $((failures > 0))
