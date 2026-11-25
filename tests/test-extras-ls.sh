#!/usr/bin/env bash
# test-extras-ls.sh sources config/shell/extras.zsh in a terminal, with stub
# eza and ls commands that print their arguments. ls and ll must run eza only
# with flags that mean the same in eza, and the standard ls with any other
# flag. An alias of your own stays yours, and the herdspace shell replaces an
# alias such as the ls alias of Oh My Zsh.
# It needs zsh, Python 3, and no network.
# Usage: tests/test-extras-ls.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; failures=$((failures + 1)); }
contains() { case "$1" in *"$2"*) pass "$3" ;; *) fail "$3: wanted [$2] in [${1:0:600}]" ;; esac; }

command -v zsh >/dev/null || { echo "SKIP: no zsh"; exit 0; }
mkdir -p "$tmp/bin" "$tmp/home"
printf '#!/bin/sh\necho "EZA [$*]"\n' >"$tmp/bin/eza"
printf '#!/bin/sh\necho "LS [$*]"\n' >"$tmp/bin/ls"
chmod 755 "$tmp/bin/eza" "$tmp/bin/ls"

# run_zsh BEFORE COMMANDS: in a terminal, run BEFORE, source the extras, and
# run COMMANDS.
run_zsh() {
  python3 - "$tmp" "$ROOT/config/shell/extras.zsh" "$1" "$2" <<'PY'
import os, pty, sys
tmp, extras, before, commands = sys.argv[1:5]
script = before + "\nsource " + repr(extras) + "\n" + commands + "\n"
env = {"HOME": tmp + "/home", "PATH": tmp + "/bin:/usr/bin:/bin", "TERM": "xterm", "HERDSPACE_UPDATE_CHECK": "0"}
pid, fd = pty.fork()
if pid == 0:
    os.execve("/bin/sh", ["sh", "-c", 'exec zsh -f -c "$0"', script], env)
out = b""
while True:
    try:
        data = os.read(fd, 4096)
    except OSError:
        break
    if not data:
        break
    out += data
os.waitpid(pid, 0)
sys.stdout.write(out.decode(errors="replace").replace("\r", ""))
PY
}

out="$(run_zsh ':' 'ls; ls -la src; ls -lh; ls -h; ls -ltrF; ls -S; ls --color=auto; ls -- -name; ll; ll -t; ls -F src; ls -lF')"
lines() { printf '%s\n' "$out" | sed -n "$1p"; }
[ "$(lines 1)" = "EZA []" ] && pass "ls runs eza" || fail "ls runs eza: [$(lines 1)]"
[ "$(lines 2)" = "EZA [-la src]" ] && pass "ls -la runs eza" || fail "ls -la runs eza: [$(lines 2)]"
[ "$(lines 3)" = "EZA [-l]" ] && pass "ls -lh runs eza -l, which shows human sizes" || fail "ls -lh: [$(lines 3)]"
[ "$(lines 4)" = "EZA []" ] && pass "ls -h runs eza" || fail "ls -h: [$(lines 4)]"
[ "$(lines 5)" = "LS [-ltrF]" ] && pass "ls -ltrF runs the standard ls" || fail "ls -ltrF: [$(lines 5)]"
[ "$(lines 6)" = "LS [-S]" ] && pass "ls -S runs the standard ls" || fail "ls -S: [$(lines 6)]"
[ "$(lines 7)" = "LS [--color=auto]" ] && pass "a long option runs the standard ls" || fail "a long option: [$(lines 7)]"
[ "$(lines 8)" = "EZA [-- -name]" ] && pass "a name after -- goes to eza as a name" || fail "a name after --: [$(lines 8)]"
[ "$(lines 9)" = "EZA [-la]" ] && pass "ll runs eza -la" || fail "ll: [$(lines 9)]"
[ "$(lines 10)" = "LS [-la -t]" ] && pass "ll -t runs the standard ls -la -t" || fail "ll -t: [$(lines 10)]"
[ "$(lines 11)" = "EZA [--classify=always src]" ] && pass "ls -F runs eza --classify=always" || fail "ls -F: [$(lines 11)]"
[ "$(lines 12)" = "EZA [--classify=always -l]" ] && pass "ls -lF runs eza --classify=always -l" || fail "ls -lF: [$(lines 12)]"

# zsh reads the whole script before it runs it, so eval expands the alias.
out="$(run_zsh "alias ls='ls -G'" 'eval ls')"
contains "$out" "LS [-G]" "an own alias ls stays yours"
out="$(run_zsh "HERDSPACE_SHELL=1; alias ls='ls -G'" 'eval ls; eval ls -t')"
contains "$out" "EZA []" "the herdspace shell replaces an alias ls"
contains "$out" "LS [-t]" "in the herdspace shell, ls -t runs the standard ls"
out="$(run_zsh "ls() { echo OWN; }" 'ls')"
contains "$out" "OWN" "an own function ls stays yours"

echo "RESULT failures=${failures}"
[ "$failures" -eq 0 ]
