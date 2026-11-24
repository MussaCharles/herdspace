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

echo "RESULT failures=${failures}"
exit $((failures > 0))
