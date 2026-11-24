#!/usr/bin/env bash
# test-extras-keys.sh sources config/shell/extras.zsh in a terminal, with a stub
# fzf, and checks the fzf keys: a free key gets the fzf widget, a key that you
# bound before keeps your widget, the file prints no error, and the rest of the
# file still loads. zsh 5.8 and zsh 5.9 differ here, so CI also runs this test
# in an ubuntu:22.04 container.
# It needs zsh, Python 3, and no network.
# Usage: tests/test-extras-keys.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; failures=$((failures + 1)); }
contains() { case "$1" in *"$2"*) pass "$3" ;; *) fail "$3: wanted [$2] in [${1:0:600}]" ;; esac; }
lacks() { case "$1" in *"$2"*) fail "$3: found [$2]" ;; *) pass "$3" ;; esac; }

command -v zsh >/dev/null || { echo "SKIP: no zsh"; exit 0; }
echo "zsh: $(zsh --version)"

# A stub fzf: --zsh prints widgets and the three fzf keys.
mkdir -p "$tmp/bin" "$tmp/home"
cat >"$tmp/bin/fzf" <<'EOF'
#!/bin/sh
[ "$1" = --zsh ] || exit 0
cat <<'Z'
fzf-history-widget() { :; }; zle -N fzf-history-widget
fzf-file-widget() { :; }; zle -N fzf-file-widget
fzf-cd-widget() { :; }; zle -N fzf-cd-widget
bindkey '^R' fzf-history-widget
bindkey '^T' fzf-file-widget
bindkey '^[c' fzf-cd-widget
Z
EOF
chmod 755 "$tmp/bin/fzf"
# A stub hopen, so that the part after the fzf keys defines fif.
printf '#!/bin/sh\nexit 0\n' >"$tmp/bin/hopen"
chmod 755 "$tmp/bin/hopen"

# run_zsh BEFORE: run zsh in a terminal, run BEFORE, source the extras, and
# print the three keys, the skipped list, and whether fif exists.
run_zsh() {
  python3 - "$tmp" "$ROOT/config/shell/extras.zsh" "$1" <<'PY'
import os, pty, sys
tmp, extras, before = sys.argv[1:4]
script = before + "\n" + f"""
source {extras!r}
print -r -- "KEY_R=$(bindkey -- '^R')"
print -r -- "KEY_T=$(bindkey -- '^T')"
print -r -- "KEY_C=$(bindkey -- '^[c')"
print -r -- "SKIPPED=${{(j:,:)HERDSPACE_EXTRAS_SKIPPED}}"
print -r -- "FIF=${{+functions[fif]}}"
"""
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

out="$(run_zsh ':')"
lacks "$out" "invalid parameter name" "no error with the default keys"
lacks "$out" "extras.zsh" "the file prints nothing"
contains "$out" 'KEY_R="^R" fzf-history-widget' "Ctrl+R gets the fzf widget"
contains "$out" 'KEY_T="^T" fzf-file-widget' "Ctrl+T gets the fzf widget"
contains "$out" 'KEY_C="^[c" fzf-cd-widget' "Alt+C gets the fzf widget"
contains "$out" "FIF=1" "the rest of the file loads"

out="$(run_zsh 'my-widget() { :; }; zle -N my-widget; bindkey "^[c" my-widget; bindkey "^R" my-widget')"
lacks "$out" "invalid parameter name" "no error with own keys"
contains "$out" 'KEY_C="^[c" my-widget' "own Alt+C stays"
contains "$out" 'KEY_R="^R" my-widget' "own Ctrl+R stays"
contains "$out" 'KEY_T="^T" fzf-file-widget' "free Ctrl+T gets the fzf widget"
contains "$out" "fzf key ^[c" "the skipped list names Alt+C"
contains "$out" "FIF=1" "the rest of the file loads with own keys"

echo "RESULT failures=${failures}"
[ "$failures" -eq 0 ]
