#!/usr/bin/env bash
# test-ui.sh checks the output and the questions of the setup in a temporary
# home folder: plain text with no terminal, color and boxes at a terminal, the
# answers for a changed file, the own lines, the backups, and the next steps.
# It needs bash, Python 3, and no network.
# Usage: tests/test-ui.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; failures=$((failures + 1)); }
contains() { case "$1" in *"$2"*) pass "$3" ;; *) fail "$3: wanted [$2] in [${1:0:400}]" ;; esac; }
lacks() { case "$1" in *"$2"*) fail "$3: found [$2]" ;; *) pass "$3" ;; esac; }

# A script that loads common.sh in a fresh home folder and runs its arguments.
cat >"$tmp/run.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
export HOME="$tmp/home"
mkdir -p "\$HOME"
REPO_ROOT="$ROOT"
source "$ROOT/bootstrap/lib/common.sh"
eval "\$1"
EOF
chmod 755 "$tmp/run.sh"
run() { NO_COLOR="${NO_COLOR:-}" "$tmp/run.sh" "$1" 2>&1; }

# Plain text with no terminal.
out="$(run 'ok Homebrew; info note; step Prerequisites')"
contains "$out" '[ok]   Homebrew' 'with no terminal, ok keeps the word [ok]'
contains "$out" '== Prerequisites' 'with no terminal, a section keeps the plain header'
lacks "$out" $'\033[' 'with no terminal, the output has no color codes'
contains "$(run 'echo "$HOMEBREW_NO_ASK"')" '1' 'brew does not ask again before an install'

# Words follow the count.
contains "$(run 'ui_count file 1')" '1 file' 'one file'
contains "$(run 'ui_count file 3')" '3 files' 'three files'

# At a terminal: a box, a mark, and color. With NO_COLOR: plain text.
out="$(python3 "$ROOT/tests/pty_run.py" 5 '' env LANG=C.UTF-8 TERM=xterm-256color "$tmp/run.sh" 'step Prerequisites; ok Homebrew' 2>&1)"
contains "$out" 'Step 1: Prerequisites' 'at a terminal, a section has a numbered box'
contains "$out" '┌' 'at a terminal, the box has corners'
contains "$out" '✓' 'at a terminal, ok shows a check mark'
out="$(python3 "$ROOT/tests/pty_run.py" 5 '' env NO_COLOR=1 TERM=xterm-256color "$tmp/run.sh" 'ok Homebrew' 2>&1)"
contains "$out" '[ok]   Homebrew' 'with NO_COLOR at a terminal, the output stays plain'

# The own lines of a file, and their copy to ~/.zshrc.local.
mkdir -p "$tmp/files"
printf 'export ZSH="$HOME/.oh-my-zsh"\nsource $ZSH/oh-my-zsh.sh\nalias ls=eza\n' >"$tmp/files/new"
printf '# my comment\nexport ZSH="$HOME/.oh-my-zsh"\nalias ll="ls -la"\nexport PATH="$HOME/tools:$PATH"\n\nsource $ZSH/oh-my-zsh.sh\n' >"$tmp/files/old"
out="$(run "own_lines $tmp/files/new $tmp/files/old")"
contains "$out" 'alias ll="ls -la"' 'an own alias is an own line'
contains "$out" 'export PATH="$HOME/tools:$PATH"' 'an own PATH line is an own line'
lacks "$out" 'my comment' 'a comment is not an own line'
lacks "$out" 'oh-my-zsh.sh' 'a line that herdspace takes care of is not an own line'
out="$(run "move_own_lines $tmp/files/new $tmp/files/old; cat \$HOME/.zshrc.local")"
contains "$out" '# alias ll="ls -la"' 'the copied lines start with # in ~/.zshrc.local'
contains "$out" 'Copied 2 lines' 'the setup says how many lines it copied'

# The extras block for a kept ~/.zshrc, and a second run adds no second block.
out="$(run "printf 'alias x=y\n' >\$HOME/.zshrc; extras_block \$HOME/.zshrc; extras_block \$HOME/.zshrc; cat \$HOME/.zshrc")"
contains "$out" '>>> herdspace extras >>>' 'the extras block has its markers'
contains "$out" 'alias x=y' 'the extras block keeps the lines of the person'
[ "$(printf '%s\n' "$out" | grep -c 'extras.zsh')" = 1 ] && pass 'a second run adds no second block' || fail 'a second run adds no second block'

# The questions about a changed file, at a terminal.
question() {
  # question KEYS: a changed ~/.zshrc, answered with KEYS. It prints the result.
  python3 "$ROOT/tests/pty_run.py" 6 "$1" env TERM=xterm-256color "$tmp/run.sh" "
    printf 'alias mine=1\n' >\$HOME/.zshrc
    MODE=ask CHANGED_FILES_READY=1 CHANGED_FILES=\"\$HOME/.zshrc
\$HOME/.p10k.zsh\"
    install_file $tmp/files/new \$HOME/.zshrc
    echo DECISION=\$DECISION EXTRAS=\$EXTRAS
    grep -c 'herdspace extras' \$HOME/.zshrc || true
    ls \$HOME/.zshrc.local 2>/dev/null || true" 2>&1
}
out="$(question '\r')"
contains "$out" 'File 1 of 2' 'the question says which file of how many'
contains "$out" 'Keep your file' 'the question names each answer'
contains "$out" '(Enter)' 'the question marks the default'
contains "$out" 'Keep this file and the 1 file after it' 'an answer for more files says how many'
contains "$out" 'DECISION=keep' 'Enter keeps the file'
out="$(question 'e\r')"
contains "$out" 'EXTRAS=1' 'e keeps the file and adds the extras'
contains "$out" 'Added the herdspace shell extras' 'the setup says that it added the extras'
out="$(question 'm\r')"
contains "$out" 'DECISION=replace' 'm replaces the file'
contains "$out" '.zshrc.local' 'm copies the own lines to ~/.zshrc.local'
out="$(question 'R\r')"
contains "$out" 'Replace these 1 file too?' 'R asks before it replaces the files after this one'

# The prerequisites question names the default.
contains "$(python3 "$ROOT/tests/pty_run.py" 4 '\r' env TERM=xterm-256color "$tmp/run.sh" "source $ROOT/bootstrap/lib/prereqs.sh; ask_yes 'Install it?' && echo YES" 2>&1)" '[Y/n] (Enter = yes)' 'the yes question names its default'

# The end of a run: the kept files, the backups, and the next steps.
out="$(run "printf 'a\n' >\$HOME/.p10k.zsh; write_file $tmp/files/new \$HOME/.p10k.zsh 644; KEPT_LIST=\"\$HOME/.zshrc
\"; EDITED=1; ZSHRC_KEPT_NO_EXTRAS=1; HS_DOC_BASE=https://example.test/blob/1.0; NEXT_SERVER=box; finish_run client")"
contains "$out" 'Kept 1 file that differ' 'the kept line uses one file'
lacks "$out" 'replace-all' 'the end of a run does not advise --replace-all'
contains "$out" 'answer e for ~/.zshrc' 'the end of a run names the missing extras'
contains "$out" 'mv ~/.p10k.zsh.bak-' 'the end of a run shows the command to put a backup back'
contains "$out" 'ssh box' 'the next steps of a client name the server'
contains "$out" 'https://example.test/blob/1.0/docs/keyboard-shortcuts.md' 'the next steps link to the docs of the release'
out="$(run "HS_DOC_BASE=https://example.test/blob/1.0; finish_run server")"
contains "$out" 'README.md#client-machine' 'the next steps of a server link to the client setup'
contains "$out" 'hopen .' 'the next steps of a server name hopen'
lacks "$(run 'finish_run none')" 'Next steps' 'the server part of a run of both prints no next steps'

# The progress bar of the language tools counts the servers of tools/nvim-wait.lua.
lua_list="$(sed -n 's/^local servers = { \(.*\) }$/\1/p' "$ROOT/tools/nvim-wait.lua" | tr -d '",' | tr -s ' ')"
sh_list="$(sed -n 's/^NVIM_SERVERS="\(.*\)"$/\1/p' "$ROOT/bootstrap/lib/server.sh")"
[ -n "$sh_list" ] && [ "$lua_list" = "$sh_list" ] && pass 'the progress bar counts the same servers that Neovim installs' || fail "the progress bar counts the same servers that Neovim installs: [$lua_list] [$sh_list]"

echo "RESULT failures=${failures}"
exit $((failures > 0))
