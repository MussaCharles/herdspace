#!/usr/bin/env bash
# test-bash-env.sh checks the move of exports from the bash files to ~/.zshenv,
# in a temporary home folder: which lines move, the question, the backups, the
# tests after the move, and that no value appears in the output.
# It needs bash, zsh, and Python 3, and no network.
# Usage: tests/test-bash-env.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; failures=$((failures + 1)); }
contains() { case "$1" in *"$2"*) pass "$3" ;; *) fail "$3: wanted [$2] in [${1:0:600}]" ;; esac; }
lacks() { case "$1" in *"$2"*) fail "$3: found [$2]" ;; *) pass "$3" ;; esac; }

# getent says that the login shell is zsh.
mkdir -p "$tmp/bin"
printf '#!/bin/sh\necho "tester:x:1:1::/home/tester:/usr/bin/zsh"\n' >"$tmp/bin/getent"
chmod 755 "$tmp/bin/getent"

cat >"$tmp/run.sh" <<EOF
#!/usr/bin/env bash
set -uo pipefail
export HOME="$tmp/home" PATH="$tmp/bin:\$PATH"
mkdir -p "\$HOME"
REPO_ROOT="$ROOT"
source "$ROOT/bootstrap/lib/common.sh"
source "$ROOT/bootstrap/lib/shell.sh"
eval "\$1"
EOF
chmod 755 "$tmp/run.sh"

# A ~/.bashrc with exports that move, and exports that must stay.
bashrc() {
  rm -rf "${tmp:?}/home"
  mkdir -p "$tmp/home"
  cat >"$tmp/home/.bashrc" <<'RC'
# ~/.bashrc
shopt -s histappend
export API_TOKEN=secret-value-123
export NAME_WITH_SPACE="two words"
export TOOL_HOME=$HOME/tool
export TOOL_BIN="${TOOL_HOME}/bin"
setup() {
export IN_FUNCTION=1
}
if [ -n "$PS1" ]; then
export IN_IF=1
fi
export CONTINUED=a\
b
export MULTI="one
two"
export FROM_COMMAND=$(date)
export FROM_OTHER=$OTHER_VAR
export TWO=1 THREE=2
  export INDENTED=1
alias ll='ls -l'
RC
}

run_move() { "$tmp/run.sh" "MODE=ask; move_bash_exports; echo BACKUPS=\$BACKUP_LIST" </dev/null 2>&1; }

# The scan.
bashrc
scan="$("$tmp/run.sh" 'bash_export_scan "$HOME/.bashrc"')"
for name in API_TOKEN NAME_WITH_SPACE TOOL_HOME TOOL_BIN; do
  contains "$scan" "move	" "the scan finds lines that move" >/dev/null
  printf '%s\n' "$scan" | grep -q "^move	[0-9]*	${name}$" && pass "${name} moves" || fail "${name} moves: ${scan}"
done
for name in IN_FUNCTION IN_IF CONTINUED MULTI FROM_COMMAND FROM_OTHER TWO INDENTED; do
  printf '%s\n' "$scan" | grep -q "^keep	-	${name}$" && pass "${name} stays" || fail "${name} stays: ${scan}"
done

# With no terminal, nothing changes, and the output names the variables only.
bashrc
before="$(cat "$tmp/home/.bashrc")"
out="$(run_move)"
[ "$(cat "$tmp/home/.bashrc")" = "$before" ] && pass "with no terminal, ~/.bashrc does not change" || fail "with no terminal, ~/.bashrc does not change"
[ ! -e "$tmp/home/.zshenv" ] && pass "with no terminal, no ~/.zshenv" || fail "with no terminal, no ~/.zshenv"
contains "$out" 'API_TOKEN' 'the note names the variables'
contains "$out" 'exports-from-your-bash-files' 'the note links the setup guide'
lacks "$out" 'secret-value-123' 'the note shows no value'

# The question, at a terminal.
ask() {
  bashrc
  [ -z "${2:-}" ] || printf '%s\n' "$2" >"$tmp/home/.zshenv"
  python3 "$ROOT/tests/pty_run.py" 6 "$1" env TERM=xterm-256color "$tmp/run.sh" "MODE=ask; move_bash_exports; echo BACKUPS=\$BACKUP_LIST" 2>&1
}
out="$(ask '\r')"
contains "$out" 'Exports in your bash files' 'the question has a title'
contains "$out" 'API_TOKEN' 'the question names the variables'
lacks "$out" 'secret-value-123' 'the question shows no value'
grep -q '^export API_TOKEN' "$tmp/home/.bashrc" && pass "Enter changes nothing" || fail "Enter changes nothing"
out="$(ask 'n\r')"
grep -q '^export API_TOKEN' "$tmp/home/.bashrc" && pass "n changes nothing" || fail "n changes nothing"

out="$(ask 'y\r' 'export MINE=1')"
lacks "$out" 'secret-value-123' 'the move shows no value'
contains "$out" 'Moved the exports of' 'the move says what moved'
contains "$out" '.bashrc.bak-' 'the move names the backup'
contains "$out" 'Put new variables in ~/.zshenv' 'the move says where new variables go'
zshenv="$(cat "$tmp/home/.zshenv")"
contains "$zshenv" 'export MINE=1' 'your own lines of ~/.zshenv stay'
contains "$zshenv" '# >>> herdspace bash env >>>' 'the lines go in a marked block'
contains "$zshenv" 'export API_TOKEN=secret-value-123' 'the token is in ~/.zshenv'
rc="$(cat "$tmp/home/.bashrc")"
lacks "$rc" 'secret-value-123' 'the token is no longer in ~/.bashrc'
contains "$rc" '# herdspace moved the export of API_TOKEN to ~/.zshenv.' 'a note in ~/.bashrc says where the line went'
contains "$rc" 'export IN_FUNCTION=1' 'an export in a function stays'
contains "$rc" "alias ll='ls -l'" 'the other lines stay'
mode() { if stat -c %a "$1" >/dev/null 2>&1; then stat -c %a "$1"; else stat -f %Lp "$1"; fi; }
[ "$(mode "$tmp/home/.zshenv")" = 600 ] && pass "only you can read ~/.zshenv" || fail "only you can read ~/.zshenv: $(mode "$tmp/home/.zshenv")"
backup="$(ls "$tmp/home"/.bashrc.bak-* 2>/dev/null | head -n 1)"
[ -n "$backup" ] && [ "$(mode "$backup")" = 600 ] && pass "only you can read the backup" || fail "only you can read the backup"
grep -q 'secret-value-123' "$backup" && pass "the backup has the old file" || fail "the backup has the old file"
got="$(env -i HOME="$tmp/home" PATH=/usr/bin:/bin zsh -c 'echo "$API_TOKEN|$NAME_WITH_SPACE|$TOOL_BIN"')"
[ "$got" = "secret-value-123|two words|${tmp}/home/tool/bin" ] && pass "zsh has the values" || fail "zsh has the values"
bash -n "$tmp/home/.bashrc" && pass "the .bashrc has no syntax error" || fail "the .bashrc has no syntax error"

# A second run finds nothing to move.
out="$(run_move)"
lacks "$out" 'API_TOKEN' 'a second run finds nothing to move'

# If the test after the move fails, the files come back.
out="$(ask 'y\r' 'if true; then')"
contains "$out" 'put your files back' 'a failed test puts the files back'
grep -q '^export API_TOKEN=secret-value-123' "$tmp/home/.bashrc" && pass "the .bashrc is back" || fail "the .bashrc is back"
[ "$(cat "$tmp/home/.zshenv")" = 'if true; then' ] && pass "the .zshenv is back" || fail "the .zshenv is back"
lacks "$out" 'secret-value-123' 'a failed test shows no value'
ls "$tmp/home"/.*.bak-* >/dev/null 2>&1 && fail "after a failed test, no backup with a value stays" || pass "after a failed test, no backup with a value stays"

# With a bash login shell, nothing happens.
printf '#!/bin/sh\necho "tester:x:1:1::/home/tester:/bin/bash"\n' >"$tmp/bin/getent"
bashrc
out="$(run_move)"
lacks "$out" 'API_TOKEN' 'with bash as the login shell, nothing happens'

echo "RESULT failures=${failures}"
exit $((failures > 0))
