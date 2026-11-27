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
lacks() { case "$1" in *"$2"*) fail "$3: found [$2]" ;; *) pass "$3" ;; esac; }
contains() { case "$1" in *"$2"*) pass "$3" ;; *) fail "$3: ${1:0:300}" ;; esac; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp" dist/9.9.9-test dist/9.9.9-test.notes.md dist/9.9.9-guard.notes.md' EXIT
tag=9.9.9-test
tools/release.sh "$tag" --repo example/hopen-test >/dev/null || { echo "FAIL release build"; exit 1; }
dist="$(pwd)/dist/${tag}"
for f in "hopen-${tag}.tar.gz" install.sh SHA256SUMS; do
  if [ -f "${dist}/${f}" ]; then pass "release has ${f}"; else fail "release has ${f}"; fi
done
contains "$(grep -c '@VERSION@\|@REPO@' "${dist}/install.sh")" '0' 'install.sh has the tag and the repository'
full_hopen="$(tar -xzOf "${dist}/herdspace-${tag}.tar.gz" "herdspace-${tag}/bin/hopen")"
contains "$full_hopen" "HOPEN_VERSION=\"${tag}\"" 'the full archive has hopen with the tag'
if [ "$full_hopen" = "$(tar -xzOf "${dist}/hopen-${tag}.tar.gz" "hopen-${tag}/hopen")" ]; then pass 'both archives have the same hopen'; else fail 'both archives have the same hopen'; fi
if [ "$(tar -xzOf "${dist}/herdspace-${tag}.tar.gz" "herdspace-${tag}/lib/hopen/palette.sh")" = "$(tar -xzOf "${dist}/hopen-${tag}.tar.gz" "hopen-${tag}/lib/hopen/palette.sh")" ]; then pass 'both archives have the modules of hopen'; else fail 'both archives have the modules of hopen'; fi
if [ "$(tar -xzOf "${dist}/herdspace-${tag}.tar.gz" "herdspace-${tag}/lib/hopen/palette/projects.sh")" = "$(tar -xzOf "${dist}/hopen-${tag}.tar.gz" "hopen-${tag}/lib/hopen/palette/projects.sh")" ]; then pass 'both archives have the palette groups of hopen'; else fail 'both archives have the palette groups of hopen'; fi

home="${tmp}/home"
mkdir -p "${home}/.local/bin" "${tmp}/old"
printf '#!/bin/sh\necho old\n' >"${tmp}/old/hopen"
ln -s "${tmp}/old/hopen" "${home}/.local/bin/hopen"
run_install() { HOME="$home" XDG_CONFIG_HOME="" HOPEN_BASE_URL="file://${dist}" PATH="${home}/.local/bin:${PATH}" bash "${dist}/install.sh" "$@" 2>&1; }

out="$(run_install)"
contains "$out" 'Replaced the link' 'install replaces an old link'
if [ -f "${home}/.local/bin/hopen" ] && [ ! -L "${home}/.local/bin/hopen" ] && [ -x "${home}/.local/bin/hopen" ]; then pass 'hopen is a real file'; else fail 'hopen is a real file'; fi
contains "$(HOME="$home" "${home}/.local/bin/hopen" --version)" "hopen ${tag}" 'hopen shows the release tag'
if [ -f "${home}/.local/lib/hopen/core.sh" ]; then pass 'the modules of hopen are next to the bin folder'; else fail 'the modules of hopen are next to the bin folder'; fi
if [ -f "${home}/.local/lib/hopen/palette/projects.sh" ]; then pass 'the palette groups of hopen are installed'; else fail 'the palette groups of hopen are installed'; fi
if [ -f "${home}/.local/lib/hopen/lists.py" ]; then pass 'the Python part of hopen is installed'; else fail 'the Python part of hopen is installed'; fi
contains "$(HOME="$home" XDG_CONFIG_HOME="" "${home}/.local/bin/hopen" --templates 2>&1)" 'code' 'the installed hopen loads its modules'
mkdir -p "${home}/demo" && printf '[[project]]\nname = "api"\npath = "."\n' >"${home}/demo/herdspace.toml"
contains "$(HOME="$home" XDG_CONFIG_HOME="" "${home}/.local/bin/hopen" --complete lists 2>&1)" 'demo' 'the installed hopen reads a list with its Python part'
for t in code agent grid review; do
  if [ -f "${home}/.config/hopen/templates/${t}.layout" ]; then pass "template ${t} installed"; else fail "template ${t} installed"; fi
done
if [ -f "${tmp}/old/hopen" ]; then pass 'the old file stays'; else fail 'the old file stays'; fi

out="$(run_install)"
contains "$out" 'is up to date' 'a second run changes nothing'
lacks "$out" 'modules of hopen' 'a second run copies no module'
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
if [ ! -e "${home}/.local/lib/hopen" ]; then pass 'uninstall removes the modules of hopen'; else fail 'uninstall removes the modules of hopen'; fi

# The release notes come from the changelog section of the tag.
cl="${tmp}/CHANGELOG.md"
printf '# Changelog\n\n## [Unreleased]\n\n## [%s] - 2026-01-01\n\n### Fixed\n\n- A test item.\n\n## [0.0.1] - 2025-01-01\n\n- An old item.\n\n[%s]: https://example.com\n' "$tag" "$tag" >"$cl"
HS_CHANGELOG="$cl" tools/release.sh "$tag" --repo example/hopen-test >/dev/null 2>&1
notes="$(cat "dist/${tag}.notes.md" 2>/dev/null)"
contains "$notes" '- A test item.' 'the notes have the changelog section'
contains "$notes" "blob/${tag}/README.md#quick-start" 'the notes link to the install steps'
case "$notes" in *'An old item'*|*'example.com'*) fail 'the notes stop at the next section' ;; *) pass 'the notes stop at the next section' ;; esac
contains "$(HS_CHANGELOG=/nonexistent tools/release.sh "$tag" --repo example/hopen-test 2>&1)" 'has no section' 'a missing section is reported'

touch release-guard-test.txt
contains "$(tools/release.sh v9.9.9 --repo example/hopen-test 2>&1)" 'no v in front' 'release.sh refuses a tag with v'
out="$(tools/release.sh 9.9.9-guard --repo example/hopen-test --publish 2>&1)"; rc=$?
rm -f release-guard-test.txt
contains "$out" 'release-guard-test.txt' 'publish lists an untracked file'
if [ "$rc" -ne 0 ]; then pass 'publish refuses a folder with changes'; else fail 'publish refuses a folder with changes'; fi

# bootstrap.sh from curl downloads the full release, and runs the right script.
for f in bootstrap.sh "herdspace-${tag}.tar.gz"; do
  if [ -f "${dist}/${f}" ]; then pass "release has ${f}"; else fail "release has ${f}"; fi
done
piped() { HOME="$home" XDG_DATA_HOME="" HS_BASE_URL="file://$1" HS_NO_TTY=1 HS_DRY_RUN=1 bash -s -- "${@:2}" <"$1/bootstrap.sh" 2>&1; }
out="$(piped "$dist" client --os wsl --server example)"
contains "$out" 'bootstrap/platforms/client-linux.sh --server example --no-ghostty' 'piped bootstrap.sh picks the WSL client'
if [ -x "${home}/.local/share/herdspace/${tag}/bootstrap/platforms/server-linux.sh" ]; then pass 'piped bootstrap.sh keeps the release files'; else fail 'piped bootstrap.sh keeps the release files'; fi
if [ ! -d "${home}/.local/share/herdspace/${tag}/tests" ]; then pass 'the release has no tests folder'; else fail 'the release has no tests folder'; fi
out="$(piped "$dist" --check server --os linux)"
contains "$out" 'bootstrap/platforms/server-linux.sh --check' 'piped bootstrap.sh passes the options'
# A setup that passes saves its release and options, for herdspace update. A
# stub platform script stands in for the setup.
rel="${home}/.local/share/herdspace/${tag}"
printf '#!/bin/sh\nexit 0\n' >"${rel}/bootstrap/platforms/server-linux.sh"
HOME="$home" bash "${rel}/bootstrap.sh" server --os linux --skip-login-service --replace-all >/dev/null 2>&1
contains "$(cat "${home}/.local/share/herdspace/version" 2>/dev/null)" "$tag" 'a setup saves its release'
saved="$(cat "${home}/.local/share/herdspace/last-setup" 2>/dev/null)"
contains "$saved" 'role=server' 'a setup saves its role'
contains "$saved" 'os=linux' 'a setup saves the system that was given'
contains "$saved" 'arg=--skip-login-service' 'a setup saves its options'
lacks "$saved" 'replace-all' 'a setup does not save an option for one run'
HOME="$home" bash "${rel}/bootstrap.sh" client --os linux --server x --check >/dev/null 2>&1
contains "$(cat "${home}/.local/share/herdspace/last-setup" 2>/dev/null)" 'role=server' 'a --check saves nothing'
printf 'x' >>"${bad}/herdspace-${tag}.tar.gz"
out="$(piped "$bad" server)"
contains "$out" 'checksum' 'piped bootstrap.sh stops on a wrong checksum'
contains "$(HS_DRY_RUN=1 ./bootstrap.sh client --os mac 2>&1)" '--os must be' 'bootstrap.sh refuses an unknown system'
out="$(HS_DRY_RUN=1 ./bootstrap.sh both --os macos --check --skip-nvim-tools --skip-mission-control 2>&1)"
contains "$out" 'bootstrap/platforms/server-macos.sh --check --skip-nvim-tools' 'both gives the server script its options'
contains "$out" 'bootstrap/platforms/client-macos.sh --check --skip-mission-control' 'both gives the client script its options'
out="$(HS_DRY_RUN=1 ./bootstrap.sh both --os wsl 2>&1)"
contains "$out" 'bootstrap/platforms/client-linux.sh --no-ghostty' 'both on WSL uses no Ghostty'

# A download that stops in the middle runs nothing. Each part of the release
# scripts goes to bash on stdin, as with curl. Each command that the scripts
# can call is a stub that writes to a log, and the home folder stays empty.
cut="${tmp}/cut"
mkdir -p "${cut}/bin" "${cut}/home"
for c in curl gh tar git sudo apt-get brew mkdir mktemp cp mv rm ln chmod python3 uname sed awk; do
  printf '#!/bin/sh\necho "%s" >>"%s/log"\n' "$c" "$cut" >"${cut}/bin/${c}"
  chmod 755 "${cut}/bin/${c}"
done
for script in bootstrap.sh install.sh; do
  args=()
  [ "$script" = install.sh ] || args=(server)
  # The cuts end before the last line, main "$@", because that line runs all.
  size="$(($(wc -c <"${dist}/${script}") - $(tail -n 1 "${dist}/${script}" | wc -c)))"
  ran=""
  for n in $(seq 1 37 "$size") "$size"; do
    head -c "$n" "${dist}/${script}" | env -i HOME="${cut}/home" PATH="${cut}/bin" /bin/bash -s ${args[@]+"${args[@]}"} >/dev/null 2>&1
    if [ -s "${cut}/log" ] || [ -n "$(ls -A "${cut}/home")" ]; then ran="${ran} ${n}"; rm -f "${cut}/log"; rm -rf "${cut:?}/home" && mkdir "${cut}/home"; fi
  done
  if [ -z "$ran" ]; then pass "a cut ${script} runs nothing"; else fail "a cut ${script} runs commands at bytes:${ran}"; fi
done
# The whole script still runs.
out="$(env -i HOME="${cut}/home" PATH=/usr/bin:/bin /bin/bash -s -- --help <"${dist}/bootstrap.sh" 2>&1)"
contains "$out" 'Usage' 'the whole bootstrap.sh runs from stdin'

printf 'RESULT failures=%s\n' "$failures"
[ "$failures" -eq 0 ]
