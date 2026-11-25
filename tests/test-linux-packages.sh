#!/usr/bin/env bash
# test-linux-packages.sh checks which packages the Linux server setup asks apt
# for, with stub commands. A tool that already works from another source than
# apt (NodeSource, nvm, a GitHub .deb, cargo) gets no package, an installed or
# held package stays in the list, and a missing tool gets its package.
# It needs bash, and no network and no apt.
# Usage: tests/test-linux-packages.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; failures=$((failures + 1)); }
contains() { case " $1 " in *" $2 "*) pass "$3" ;; *) fail "$3: wanted [$2] in [$1]" ;; esac; }
lacks() { case " $1 " in *" $2 "*) fail "$3: found [$2] in [$1]" ;; *) pass "$3" ;; esac; }

LIST="ca-certificates curl git zsh python3 ripgrep fd-find bat build-essential nodejs npm"

# packages INSTALLED HELD COMMANDS...: the list that apt gets. dpkg-query
# reports each package in INSTALLED as installed and in HELD as held. Only the
# stub COMMANDS are on PATH.
packages() {
  local dir="$tmp/case$RANDOM" installed="$1" held="$2" cmd
  shift 2
  mkdir -p "$dir"
  cat >"$dir/dpkg-query" <<STUB
#!/bin/sh
for name in $installed; do [ "\$name" = "\$4" ] && { printf 'install ok installed'; exit 0; }; done
for name in $held; do [ "\$name" = "\$4" ] && { printf 'hold ok installed'; exit 0; }; done
exit 1
STUB
  for cmd in "$@"; do printf '#!/bin/sh\nexit 0\n' >"$dir/$cmd"; done
  chmod 755 "$dir"/*
  ln -s "$(command -v grep)" "$dir/grep"
  PATH="$dir" "$BASH" -c '
    source "$1/bootstrap/lib/common.sh"
    source "$1/bootstrap/lib/linux-tools.sh"
    skip_other_sources $2 2>/dev/null | { out=""; while read -r p; do out="$out $p"; done; echo "${out# }"; }' _ "$ROOT" "$LIST" 2>/dev/null
}

out="$(packages '' '')"
[ "$out" = "$LIST" ] && pass "no tools: apt gets every package" || fail "no tools: apt gets every package: [$out]"

out="$(packages 'nodejs' '' node npm)"
contains "$out" nodejs "NodeSource: the installed nodejs package stays in the list"
lacks "$out" npm "NodeSource: apt gets no npm package, because npm works"

out="$(packages '' '' node npm)"
lacks "$out" nodejs "nvm: apt gets no nodejs package"
lacks "$out" npm "nvm: apt gets no npm package"

out="$(packages '' '' node)"
contains "$out" npm "node with no npm: apt gets the npm package"

out="$(packages '' '' bat rg fd)"
lacks "$out" bat "bat from a GitHub .deb: apt gets no bat package"
lacks "$out" ripgrep "rg from cargo: apt gets no ripgrep package"
lacks "$out" fd-find "fd from a GitHub .deb: apt gets no fd-find package"

out="$(packages '' '' fdfind batcat)"
lacks "$out" fd-find "fdfind works: apt gets no fd-find package"
lacks "$out" bat "batcat works: apt gets no bat package"

out="$(packages '' '' cc)"
contains "$out" build-essential "cc with no make: apt gets build-essential"
out="$(packages '' '' gcc make)"
lacks "$out" build-essential "gcc and make: apt gets no build-essential"

out="$(packages '' '' git curl zsh python3)"
for p in git curl zsh python3; do lacks "$out" "$p" "$p works: apt gets no $p package"; done
contains "$out" ca-certificates "ca-certificates has no command, so it stays in the list"

out="$(packages 'git' 'zsh' git zsh)"
contains "$out" git "an installed package stays in the list"
contains "$out" zsh "a held package stays in the list"

# apt_ready sees a held package as installed.
mkdir -p "$tmp/held"
printf '#!/bin/sh\nprintf "hold ok installed"\n' >"$tmp/held/dpkg-query"
chmod 755 "$tmp/held/dpkg-query"
ln -s "$(command -v grep)" "$tmp/held/grep"
held="$(PATH="$tmp/held" "$BASH" -c 'source "$1/bootstrap/lib/common.sh"; source "$1/bootstrap/lib/linux-tools.sh"; apt_ready zsh && echo yes || echo no' _ "$ROOT" 2>/dev/null)"
[ "$held" = yes ] && pass "apt_ready sees a held package as installed" || fail "apt_ready sees a held package as installed: [$held]"

echo "RESULT failures=${failures}"
[ "$failures" -eq 0 ]
