#!/usr/bin/env bash
# test-install.sh builds a release and installs it into a temporary home folder.
# It runs on Linux and on macOS, and it changes nothing outside a temporary folder.
#
# Usage: tests/test-install.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
failures=0
pass() { printf 'PASS %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; failures=$((failures + 1)); }
contains() { case "$1" in *"$2"*) pass "$3" ;; *) fail "$3: ${1:0:300}" ;; esac; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp" dist/v9.9.9-test' EXIT
tag=v9.9.9-test
tools/release.sh "$tag" --repo example/hopen-test >/dev/null || { echo "FAIL release build"; exit 1; }
dist="$(pwd)/dist/${tag}"
for f in "hopen-${tag}.tar.gz" install.sh SHA256SUMS; do
  if [ -f "${dist}/${f}" ]; then pass "release has ${f}"; else fail "release has ${f}"; fi
done
contains "$(grep -c '@VERSION@\|@REPO@' "${dist}/install.sh")" '0' 'install.sh has the tag and the repository'

home="${tmp}/home"
mkdir -p "${home}/.local/bin" "${tmp}/old"
printf '#!/bin/sh\necho old\n' >"${tmp}/old/hopen"
ln -s "${tmp}/old/hopen" "${home}/.local/bin/hopen"
run_install() { HOME="$home" XDG_CONFIG_HOME="" HOPEN_BASE_URL="file://${dist}" PATH="${home}/.local/bin:${PATH}" bash "${dist}/install.sh" "$@" 2>&1; }

out="$(run_install)"
contains "$out" 'Replaced the link' 'install replaces an old link'
if [ -f "${home}/.local/bin/hopen" ] && [ ! -L "${home}/.local/bin/hopen" ] && [ -x "${home}/.local/bin/hopen" ]; then pass 'hopen is a real file'; else fail 'hopen is a real file'; fi
contains "$(HOME="$home" "${home}/.local/bin/hopen" --version)" "hopen ${tag}" 'hopen shows the release tag'
for t in code agent grid review; do
  if [ -f "${home}/.config/hopen/templates/${t}.layout" ]; then pass "template ${t} installed"; else fail "template ${t} installed"; fi
done
if [ -f "${tmp}/old/hopen" ]; then pass 'the old file stays'; else fail 'the old file stays'; fi

out="$(run_install)"
contains "$out" 'is up to date' 'a second run changes nothing'
if find "$home" -name '*.new' | grep -q .; then fail 'a second run writes no .new file'; else pass 'a second run writes no .new file'; fi

printf '\n# my change\n' >>"${home}/.config/hopen/templates/code.layout"
out="$(run_install)"
contains "$out" 'code.layout.new' 'a changed template is reported'
contains "$(cat "${home}/.config/hopen/templates/code.layout")" '# my change' 'a changed template stays'
if [ -f "${home}/.config/hopen/templates/code.layout.new" ]; then pass 'the new template is beside it'; else fail 'the new template is beside it'; fi

bad="${tmp}/bad"
cp -R "$dist" "$bad"
printf 'x' >>"${bad}/hopen-${tag}.tar.gz"
rm -f "${home}/.local/bin/hopen"
out="$(HOME="$home" HOPEN_BASE_URL="file://${bad}" bash "${bad}/install.sh" 2>&1)"
contains "$out" 'checksum' 'a wrong checksum stops the install'
if [ ! -e "${home}/.local/bin/hopen" ]; then pass 'nothing is installed after a wrong checksum'; else fail 'nothing is installed after a wrong checksum'; fi

out="$(HOME="$home" bash install.sh 2>&1)"
contains "$out" 'No release is set' 'install.sh from git asks for a tag'

run_install >/dev/null
out="$(run_install --uninstall)"
contains "$out" 'Removed' 'uninstall removes hopen'
if [ ! -e "${home}/.local/bin/hopen" ] && [ -d "${home}/.config/hopen/templates" ]; then pass 'uninstall keeps the templates'; else fail 'uninstall keeps the templates'; fi

printf 'RESULT failures=%s\n' "$failures"
[ "$failures" -eq 0 ]
