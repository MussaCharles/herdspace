#!/usr/bin/env bash
# test-herdspace-cmd.sh checks the herdspace command with a stub curl: the
# version, the notice once a day, the switch that turns it off, a missing
# network, and an update with the saved role and options.
# It needs bash and no network.
# Usage: tests/test-herdspace-cmd.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; failures=$((failures + 1)); }
contains() { case "$1" in *"$2"*) pass "$3" ;; *) fail "$3: wanted [$2] in [${1:0:500}]" ;; esac; }
lacks() { case "$1" in *"$2"*) fail "$3: found [$2]" ;; *) pass "$3" ;; esac; }

export HOME="$tmp/home" XDG_CACHE_HOME="$tmp/home/.cache"
mkdir -p "$HOME/.local/share/herdspace" "$tmp/bin" "$tmp/release"
# The stub curl logs each call. LATEST is the tag of the latest release, and an
# empty LATEST is a missing network.
cat >"$tmp/bin/curl" <<'STUB'
#!/usr/bin/env bash
echo "curl $*" >>"$HOME/curl.log"
url="" out=""
while [ "$#" -gt 0 ]; do
  case "$1" in -o) out="$2"; shift ;; http*) url="$1" ;; esac
  shift
done
[ -n "${LATEST:-}" ] || exit 7
case "$url" in
  */releases/latest) printf 'HTTP/2 302\r\nlocation: https://github.com/o/r/releases/tag/%s\r\n\r\n' "$LATEST" ;;
  */download/9.9.9/*) exit 22 ;;
  */download/*) cp "$RELEASE_DIR/$(basename "$url")" "$out" ;;
esac
STUB
chmod 755 "$tmp/bin/curl"
export PATH="$tmp/bin:$PATH" RELEASE_DIR="$tmp/release"
hs() { "$ROOT/bin/herdspace" "$@" 2>&1; }
echo 0.7.0 >"$HOME/.local/share/herdspace/version"

# version and --version.
out="$(LATEST=0.7.1 hs --version)"
contains "$out" 'herdspace 0.7.0' '--version shows the installed version'
contains "$out" 'The latest release: 0.7.1. Run: herdspace update' '--version shows a newer release'
[ "$out" = "$(LATEST=0.7.1 hs version)" ] && pass 'version and --version print the same text' || fail 'version and --version print the same text'
contains "$(LATEST=0.7.0 hs --version)" 'This is the latest version' '--version says when the version is the latest'
contains "$(LATEST='' hs --version)" 'GitHub did not answer' '--version says when GitHub does not answer'
contains "$(LATEST=0.10.0 hs --version)" 'Run: herdspace update' '0.10.0 is newer than 0.7.0'

# The help, and an unknown command.
out="$(hs help)"
contains "$out" 'Usage: herdspace update' 'help shows the usage'
lacks "$out" 'set -' 'help shows no line of the script'
contains "$out" 'herdspace uninstall --check' 'help lists uninstall --check'
contains "$out" 'herdspace uninstall [--yes]' 'help lists uninstall'
out="$(hs --update)"; rc=$?
contains "$out" "herdspace: '--update' is not a herdspace command." 'an unknown command says that it is unknown'
contains "$out" "Did you mean 'herdspace update'?" '--update suggests herdspace update'
contains "$out" "Run 'herdspace help' for the usage." 'an unknown command says where the help is'
lacks "$out" 'Usage: herdspace update' 'an unknown command does not print the whole help'
[ "$rc" -eq 2 ] && pass "an unknown command exits 2" || fail "an unknown command exits 2: ${rc}"
lacks "$(hs foo)" 'Did you mean' 'an unknown word gets no suggestion'
lacks "$(LATEST=0.6.9 hs --version)" 'Run: herdspace update' '0.6.9 is not newer than 0.7.0'

# The notice: the first shell starts the check in the background, a later
# shell prints the line, and only once a day.
rm -rf "$XDG_CACHE_HOME" "$HOME/curl.log"
out="$(LATEST=0.7.1 hs notice)"
lacks "$out" 'available' 'the first shell prints nothing, because the check runs in the background'
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$XDG_CACHE_HOME/herdspace/latest" ] && break; sleep 0.2; done
contains "$(cat "$XDG_CACHE_HOME/herdspace/latest" 2>/dev/null)" '0.7.1' 'the background check saves the latest tag'
out="$(LATEST=0.7.1 hs notice)"
contains "$out" 'herdspace 0.7.1 is available (you have 0.7.0). Run: herdspace update' 'the next shell prints the notice'
contains "$out" 'releases/tag/0.7.1' 'the notice links what changed'
lacks "$(LATEST=0.7.1 hs notice)" 'available' 'the notice shows only once a day'
calls="$(grep -c 'releases/latest' "$HOME/curl.log")"
[ "$calls" -eq 1 ] && pass 'the shell asks GitHub at most once a day' || fail "the shell asks GitHub at most once a day: ${calls} calls"

rm -rf "$XDG_CACHE_HOME" "$HOME/curl.log"
out="$(HERDSPACE_UPDATE_CHECK=0 LATEST=0.7.1 hs notice)"
[ -z "$out" ] && [ ! -e "$HOME/curl.log" ] && pass 'HERDSPACE_UPDATE_CHECK=0 sends no request' || fail 'HERDSPACE_UPDATE_CHECK=0 sends no request'

rm -rf "$XDG_CACHE_HOME"
start=$(date +%s)
out="$(LATEST='' hs notice)"
[ $(($(date +%s) - start)) -le 1 ] && [ -z "$out" ] && pass 'with no network, the notice prints nothing and does not wait' || fail 'with no network, the notice prints nothing and does not wait'

echo 0.7.1 >"$XDG_CACHE_HOME/herdspace/latest"
echo dev >"$HOME/.local/share/herdspace/version"
lacks "$(LATEST=0.7.1 hs notice)" 'available' 'a setup from the repository gets no notice'
echo 0.7.0 >"$HOME/.local/share/herdspace/version"

# update: the saved role and options, and the checksum.
contains "$(LATEST=0.7.1 hs update)" 'No setup is saved' 'update with no saved setup says what to do'
printf 'role=client\nos=linux\narg=--server\narg=box\narg=--no-ghostty\n' >"$HOME/.local/share/herdspace/last-setup"
printf '#!/usr/bin/env bash\necho "SETUP $* VERSION=$HS_VERSION" >"$HOME/setup.log"\n' >"$tmp/release/bootstrap.sh"
(cd "$tmp/release" && { sha256sum bootstrap.sh 2>/dev/null || shasum -a 256 bootstrap.sh; } >SHA256SUMS)
out="$(LATEST=0.7.1 hs update --skip-mission-control)"
contains "$out" 'Updating herdspace from 0.7.0 to 0.7.1' 'update names both versions'
lacks "$out" 'unbound variable' 'update ends with no unbound variable'
contains "$(cat "$HOME/setup.log" 2>/dev/null)" 'SETUP client --os linux --server box --no-ghostty --skip-mission-control VERSION=0.7.1' 'update runs the setup with the saved role and options, and the new ones'
rm -f "$HOME/setup.log"
out="$(LATEST=0.7.0 hs update)"
contains "$out" 'herdspace 0.7.0 is the latest release. Nothing to update.' 'update on the latest release says that nothing is new'
contains "$out" 'herdspace update --force' 'update on the latest release names --force'
[ ! -e "$HOME/setup.log" ] && pass 'update on the latest release runs no setup' || fail 'update on the latest release runs no setup'
out="$(LATEST=0.7.0 hs update --force --skip-mission-control)"
contains "$out" 'because of --force' 'update --force says why the setup runs'
contains "$(cat "$HOME/setup.log" 2>/dev/null)" 'SETUP client --os linux --server box --no-ghostty --skip-mission-control VERSION=0.7.0' 'update --force runs the setup, and does not pass --force to it'
rm -f "$HOME/setup.log"
echo 'echo changed' >>"$tmp/release/bootstrap.sh"
out="$(LATEST=0.7.1 hs update)"
contains "$out" 'The checksum of bootstrap.sh is wrong' 'update stops when the checksum does not match'
[ ! -e "$HOME/setup.log" ] && pass 'a wrong checksum runs no setup' || fail 'a wrong checksum runs no setup'
contains "$(LATEST='' hs update)" 'GitHub did not answer' 'update with no network changes nothing'

# update --version: the checks of the tag, a stop at the installed version, and
# an older release that does not know a saved option.
printf 'role=client\nos=linux\narg=--server\narg=box\narg=--no-ghostty\narg=--keep-terminal-look\n' >"$HOME/.local/share/herdspace/last-setup"
printf '#!/usr/bin/env bash\n# Options: --os, --server HOST, --no-ghostty\necho "SETUP $* VERSION=$HS_VERSION" >"$HOME/setup.log"\n' >"$tmp/release/bootstrap.sh"
(cd "$tmp/release" && { sha256sum bootstrap.sh 2>/dev/null || shasum -a 256 bootstrap.sh; } >SHA256SUMS)
rm -f "$HOME/setup.log" "$HOME/curl.log"
echo 0.8.0 >"$HOME/.local/share/herdspace/version"
out="$(LATEST=0.9.0 hs update --version 0.7.0)"
contains "$out" 'Going back from herdspace 0.8.0 to the older release 0.7.0.' 'update --version names a step back'
contains "$out" 'does not know the option --keep-terminal-look' 'update --version names a saved option that the older release does not know'
contains "$(cat "$HOME/setup.log" 2>/dev/null)" 'SETUP client --os linux --server box --no-ghostty VERSION=0.7.0' 'update --version runs the older setup with the options that it knows'
lacks "$(cat "$HOME/setup.log" 2>/dev/null)" '--keep-terminal-look' 'update --version leaves out the unknown option'
[ -z "$(grep 'releases/latest' "$HOME/curl.log")" ] && pass 'update --version does not ask for the latest release' || fail 'update --version does not ask for the latest release'
rm -f "$HOME/setup.log"
out="$(LATEST=0.9.0 hs update --version=0.9.0)"
contains "$out" 'Changing herdspace from 0.8.0 to 0.9.0.' 'update --version=TAG goes to a newer release too'
rm -f "$HOME/setup.log"
echo 0.7.0 >"$HOME/.local/share/herdspace/version"
out="$(LATEST=0.9.0 hs update --version 0.7.0)"
contains "$out" 'herdspace 0.7.0 is installed already. Nothing to change.' 'update --version of the installed version changes nothing'
contains "$out" 'herdspace update --version 0.7.0 --force' 'update --version of the installed version names --force'
[ ! -e "$HOME/setup.log" ] && pass 'update --version of the installed version runs no setup' || fail 'update --version of the installed version runs no setup'
out="$(LATEST=0.9.0 hs update --version 0.7.0 --force)"
contains "$out" 'because of --force' 'update --version with --force runs the setup again'
[ -e "$HOME/setup.log" ] && pass 'update --version with --force runs the setup' || fail 'update --version with --force runs the setup'
rm -f "$HOME/setup.log"
out="$(LATEST=0.9.0 hs update --version v0.7.0)"; rc=$?
contains "$out" 'has no v in front. Use: herdspace update --version 0.7.0' 'update --version with a v says what to use'
[ "$rc" -eq 1 ] && [ ! -e "$HOME/setup.log" ] && pass 'a tag with a v runs no setup' || fail "a tag with a v runs no setup: ${rc}"
contains "$(LATEST=0.9.0 hs update --version latest)" "'latest' is not a release tag" 'update --version with a word says that it is not a tag'
contains "$(LATEST=0.9.0 hs update --version '0.7.0;ls')" 'is not a release tag' 'update --version with odd characters is refused'
contains "$(LATEST=0.9.0 hs update --version)" '--version needs a release tag' 'update --version with no tag says what is missing'
out="$(LATEST=0.9.0 hs update --version 9.9.9)"; rc=$?
contains "$out" 'Could not download bootstrap.sh of 9.9.9. Does this release exist?' 'update --version of a missing release says so'
[ "$rc" -eq 1 ] && [ ! -e "$HOME/setup.log" ] && pass 'a missing release runs no setup' || fail "a missing release runs no setup: ${rc}"
contains "$(hs help)" 'herdspace update --version TAG' 'help shows update --version'
echo 0.7.0 >"$HOME/.local/share/herdspace/version"

# keys: show the mode, and change it with the setup of the installed release.
mkdir -p "$HOME/.local/share/herdspace/0.7.0"
printf '#!/usr/bin/env bash\necho "KEYS-SETUP $*" >"$HOME/keys.log"\n' >"$HOME/.local/share/herdspace/0.7.0/bootstrap.sh"
printf 'role=client\nos=linux\narg=--server\narg=box\narg=--use-herdspace-keys\n' >"$HOME/.local/share/herdspace/last-setup"
contains "$(hs keys)" 'The keys: herdr' 'keys shows the herdr mode by default'
out="$(hs keys normal)"
contains "$(cat "$HOME/keys.log" 2>/dev/null)" 'KEYS-SETUP client --os linux --server box --keep-terminal-keys' 'keys normal runs the setup with the saved options and --keep-terminal-keys only'
lacks "$(cat "$HOME/keys.log" 2>/dev/null)" '--use-herdspace-keys' 'keys normal drops the old key option'
rm -f "$HOME/keys.log"
mkdir -p "$HOME/.config/herdspace" && echo terminal >"$HOME/.config/herdspace/keys"
contains "$(hs keys)" 'The keys: normal' 'keys shows the normal mode'
contains "$(hs keys normal)" 'Nothing to change' 'keys normal in the normal mode changes nothing'
[ ! -e "$HOME/keys.log" ] && pass 'keys in the same mode runs no setup' || fail 'keys in the same mode runs no setup'
hs keys herdr >/dev/null
contains "$(cat "$HOME/keys.log" 2>/dev/null)" '--use-herdspace-keys' 'keys herdr runs the setup with --use-herdspace-keys'
out="$(hs keys fancy)"; rc=$?
contains "$out" "'fancy' is not a key mode" 'keys with a wrong word says so'
[ "$rc" -eq 2 ] && pass 'keys with a wrong word exits 2' || fail "keys with a wrong word exits 2: ${rc}"
printf 'role=server\n' >"$HOME/.local/share/herdspace/last-setup"
contains "$(hs keys normal)" 'on a client machine' 'keys on a server says that it is for a client'

# editor: show the mode, and change it in ~/.config/herdspace/editor.
rm -f "$HOME/.config/herdspace/editor"
contains "$(hs --help)" 'herdspace editor [reader|normal]' 'help lists editor'
contains "$(hs editor)" 'The editor: reader' 'editor shows the reader mode by default'
contains "$(hs editor reader)" 'Nothing to change' 'editor reader in the reader mode changes nothing'
contains "$(hs editor normal)" 'The editor: normal' 'editor normal changes the mode'
[ "$(cat "$HOME/.config/herdspace/editor" 2>/dev/null)" = normal ] && pass 'editor normal saves the choice' || fail 'editor normal saves the choice'
contains "$(hs editor)" 'The editor: normal' 'editor shows the normal mode'
hs editor reader >/dev/null
[ "$(cat "$HOME/.config/herdspace/editor" 2>/dev/null)" = reader ] && pass 'editor reader saves the choice' || fail 'editor reader saves the choice'
out="$(hs editor fancy 2>&1)"; rc=$?
contains "$out" "'fancy' is not an editor mode" 'editor with a wrong word says so'
[ "$rc" -eq 2 ] && pass 'editor with a wrong word exits 2' || fail "editor with a wrong word exits 2: ${rc}"

echo "RESULT failures=${failures}"
exit $((failures > 0))
