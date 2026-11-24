#!/usr/bin/env bash
# test-ghostty.sh checks how the client setup writes the Ghostty file in a
# temporary home folder: the marked blocks, the own lines of the person, the
# file of an older herdspace, the key and look choices, and the key question.
# It needs bash, Python 3, and no network.
# Usage: tests/test-ghostty.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; failures=$((failures + 1)); }
contains() { case "$1" in *"$2"*) pass "$3" ;; *) fail "$3: wanted [$2] in [${1:0:600}]" ;; esac; }
lacks() { case "$1" in *"$2"*) fail "$3: found [$2]" ;; *) pass "$3" ;; esac; }

cat >"$tmp/run.sh" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
export HOME="$tmp/home"
mkdir -p "\$HOME/.config/ghostty"
REPO_ROOT="$ROOT"
source "$ROOT/bootstrap/lib/common.sh"
source "$ROOT/bootstrap/lib/client.sh"
MODE="\${HS_MODE:-ask}"
eval "\$1"
SCRIPT
chmod 755 "$tmp/run.sh"
run() { rm -rf "${tmp:?}/home"; NO_COLOR=1 "$tmp/run.sh" "$1" </dev/null 2>&1; }
MAC="$ROOT/config/ghostty/config.ghostty"
LINUX="$ROOT/config/ghostty/config-linux.ghostty"
F='$HOME/.config/ghostty/config.ghostty'

# A new file: both blocks at the top, then room for your own lines.
out="$(run "KEYS=herdspace LOOK=herdspace install_ghostty_config $MAC; cat $F")"
contains "$out" '# >>> herdspace appearance >>>' 'a new file has the appearance block'
contains "$out" '# >>> herdspace keys >>>' 'a new file has the keys block'
contains "$out" 'keybind = super+alt+t=new_tab' 'the keys block has a replacement key for a new tab'
lacks "$out" 'super+e=unbind' 'Cmd+E keeps its Ghostty action'
contains "$out" 'Put your own lines below' 'a new file says where your own lines go'
contains "$out" 'shell-integration-features = ssh-env' 'a new file has the ssh block'
out="$(run "KEYS=herdspace; LOOK=herdspace; install_ghostty_config $MAC; echo 'window-position-x = 426' >>$F; CHANGED=0; install_ghostty_config $MAC; echo CHANGED=\$CHANGED; tail -n 1 $F")"
contains "$out" 'CHANGED=0' 'a second run changes nothing'
contains "$out" 'window-position-x = 426' 'a second run keeps your line at the end'

# The file of an older herdspace: a backup, and the own lines stay.
old="$(printf '# Ghostty configuration from herdspace.\nbackground = #1b1313\nkeybind = super+e=unbind\nwindow-position-x = 426\n')"
out="$(run "printf '%s\n' '$old' >$F; KEYS=herdspace LOOK=herdspace install_ghostty_config $MAC; cat $F; ls \$HOME/.config/ghostty")"
contains "$out" 'now keeps its own lines' 'the file of an older herdspace gets the new layout'
contains "$out" 'window-position-x = 426' 'your own line of the old file stays'
lacks "$out" 'super+e=unbind' 'an old unbind line of herdspace goes'
contains "$out" 'config.ghostty.bak-' 'the old file gets a backup'
out="$(run "printf '%s\n' '$old' >$F; manifest_set $F \$(file_sha $F); KEYS=herdspace LOOK=herdspace install_ghostty_config $MAC; cat $F")"
lacks "$out" 'window-position-x' 'an old file that herdspace wrote has no own lines'

# Your own file: the blocks go at the top, and your lines stay below them.
out="$(run "printf 'background = #000000\n' >$F; KEYS=herdspace LOOK=herdspace install_ghostty_config $MAC; cat $F")"
[ "$(printf '%s\n' "$out" | head -n 1)" = '# >>> herdspace appearance >>>' ] && pass 'the blocks go at the top of your own file' || fail "the blocks go at the top of your own file: [$out]"
[ "$(printf '%s\n' "$out" | tail -n 1)" = 'background = #000000' ] && pass 'your own value comes last, so it wins' || fail "your own value comes last, so it wins: [$out]"

# The choices remove a block.
out="$(run "KEYS=herdspace LOOK=herdspace install_ghostty_config $MAC; KEYS=terminal LOOK=terminal install_ghostty_config $MAC; cat $F")"
lacks "$out" 'unbind' 'the terminal keys remove the keys block'
lacks "$out" 'background-opacity' 'the terminal look removes the appearance block'
contains "$out" 'Put your own lines below' 'the rest of the file stays'
contains "$out" '# >>> herdspace ssh >>>' 'the terminal keys and look keep the ssh block'

# A file from 0.8.0, with no ssh block, gets it, and your lines stay last.
out="$(run "KEYS=herdspace; LOOK=herdspace; install_ghostty_config $MAC; awk '/# >>> herdspace ssh >>>/{s=1} !s; /# <<< herdspace ssh <<</{s=0}' $F >$F.old; cat $F.old >$F; echo 'font-size = 15' >>$F; install_ghostty_config $MAC; cat $F")"
contains "$out" 'shell-integration-features = ssh-env' 'an update adds the ssh block'
[ "$(printf '%s\n' "$out" | tail -n 1)" = 'font-size = 15' ] && pass 'after the ssh block, your own line still comes last' || fail "after the ssh block, your own line still comes last: [$out]"

# Linux gets no macOS lines.
out="$(run "KEYS=herdspace LOOK=herdspace install_ghostty_config $LINUX; cat $F")"
lacks "$out" 'macos-' 'Linux gets no macOS lines'
contains "$out" 'ctrl+alt+shift+t=new_tab' 'Linux gets a replacement key for a new tab'
contains "$out" 'shell-integration-features = ssh-env' 'Linux gets the ssh block'

# The key question: it explains the keys before it changes any key.
out="$(run 'load_keys; echo KEYS=$KEYS LOOK=$LOOK; cat $HOME/.config/herdspace/keys')"
contains "$out" 'Outside Herdr, these keys do nothing' 'with no terminal, the setup explains the keys'
contains "$out" 'KEYS=herdspace LOOK=herdspace' 'with no terminal, the default is the herdspace keys and look'
out="$(rm -rf "${tmp:?}/home"; python3 "$ROOT/tests/pty_run.py" 6 'n\r' env TERM=xterm-256color "$tmp/run.sh" 'load_keys; echo KEYS=$KEYS' 2>&1)"
contains "$out" 'The keys of Ghostty' 'at a terminal, the setup asks about the keys'
contains "$out" 'KEYS=terminal' 'n keeps the keys of the terminal'
out="$(rm -rf "${tmp:?}/home"; mkdir -p "$tmp/home/.config/herdspace"; echo herdspace >"$tmp/home/.config/herdspace/keys"; NO_COLOR=1 "$tmp/run.sh" 'load_keys' </dev/null 2>&1)"
lacks "$out" 'The keys of Ghostty' 'a saved choice gets no question'
out="$(rm -rf "${tmp:?}/home"; NO_COLOR=1 "$tmp/run.sh" 'keys_flag --keep-terminal-look; load_keys; echo LOOK=$LOOK' </dev/null 2>&1)"
contains "$out" 'LOOK=terminal' '--keep-terminal-look keeps the look of the terminal'

echo "RESULT ghostty failures=${failures}"
exit $((failures > 0))
