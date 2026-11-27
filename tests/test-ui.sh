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

# The own lines of a file.
mkdir -p "$tmp/files"
printf 'export ZSH="$HOME/.oh-my-zsh"\nsource $ZSH/oh-my-zsh.sh\nalias ls=eza\n' >"$tmp/files/new"
printf '# my comment\nexport ZSH="$HOME/.oh-my-zsh"\nalias ll="ls -la"\nexport PATH="$HOME/tools:$PATH"\n\nsource $ZSH/oh-my-zsh.sh\n' >"$tmp/files/old"
out="$(run "own_lines $tmp/files/new $tmp/files/old")"
contains "$out" 'alias ll="ls -la"' 'an own alias is an own line'
contains "$out" 'export PATH="$HOME/tools:$PATH"' 'an own PATH line is an own line'
lacks "$out" 'my comment' 'a comment is not an own line'
lacks "$out" 'oh-my-zsh.sh' 'a line that herdspace takes care of is not an own line'

# The extras block for a kept ~/.zshrc, and a second run adds no second block.
out="$(run "printf 'alias x=y\n' >\$HOME/.zshrc; extras_block \$HOME/.zshrc; extras_block \$HOME/.zshrc; cat \$HOME/.zshrc")"
contains "$out" '>>> herdspace extras >>>' 'the extras block has its markers'
contains "$out" 'alias x=y' 'the extras block keeps the lines of the person'
[ "$(printf '%s\n' "$out" | grep -c '>>> herdspace extras >>>')" = 1 ] && pass 'a second run adds no second block' || fail 'a second run adds no second block'

# A block keeps its place: the lines after it stay after it.
out="$(run "printf 'a\n# >>> b >>>\nold\n# <<< b <<<\nz\n' >\$HOME/f; ensure_block \$HOME/f b new; cat \$HOME/f")"
[ "$out" = "$(printf 'a\n# >>> b >>>\nnew\n# <<< b <<<\nz')" ] && pass 'a changed block keeps its place in the file' || fail "a changed block keeps its place in the file: [$out]"
out="$(run "printf 'mine\n' >\$HOME/f; ensure_block \$HOME/f b new top; cat \$HOME/f")"
[ "$(printf '%s\n' "$out" | head -n 1)" = '# >>> b >>>' ] && pass 'a new block can go at the top' || fail "a new block can go at the top: [$out]"

# ~/.zshrc: herdspace never replaces a file of the person.
zrun() { run "rm -f \$HOME/.zshrc \$HOME/.zshrc.bak-*; source $ROOT/bootstrap/lib/shell.sh; MODE=\${ZMODE:-ask}; $1"; }
out="$(zrun 'setup_zshrc; cat $HOME/.zshrc')"
contains "$out" '>>> herdspace >>>' 'a new ~/.zshrc has the herdspace block'
contains "$out" 'Put your own lines below' 'a new ~/.zshrc says where your own lines go'
out="$(zrun 'setup_zshrc; printf "alias mine=1\n" >>$HOME/.zshrc; setup_zshrc; cat $HOME/.zshrc')"
[ "$(printf '%s\n' "$out" | tail -n 1)" = 'alias mine=1' ] && pass 'a second run keeps your lines below the block' || fail "a second run keeps your lines below the block: [$out]"
out="$(zrun 'printf "# Managed by herdspace. A new run replaces this file.\nexport ZSH=\"\$HOME/.oh-my-zsh\"\nalias mine=1\n" >$HOME/.zshrc; setup_zshrc; cat $HOME/.zshrc; ls $HOME')"
contains "$out" 'was the file of an older herdspace' 'the file of an older herdspace gets the new layout'
contains "$out" '# alias mine=1' 'your own lines of the old file stay, each behind #'
contains "$out" '.zshrc.bak-' 'the old file gets a backup'
out="$(zrun 'printf "alias mine=1\n" >$HOME/.zshrc; setup_zshrc </dev/null; cat $HOME/.zshrc')"
lacks "$out" 'herdspace' 'with no terminal, your own ~/.zshrc stays as it is'
out="$(ZMODE=replace zrun 'printf "alias mine=1\n" >$HOME/.zshrc; setup_zshrc; cat $HOME/.zshrc')"
contains "$out" '>>> herdspace extras >>>' '--replace-all only adds the extras block to your own ~/.zshrc'
contains "$out" 'alias mine=1' '--replace-all keeps your own ~/.zshrc'

# The question about your own ~/.zshrc, at a terminal.
zask() {
  python3 "$ROOT/tests/pty_run.py" 6 "$1" env TERM=xterm-256color "$tmp/run.sh" "
    source $ROOT/bootstrap/lib/shell.sh; MODE=ask
    printf '$2' >\$HOME/.zshrc
    setup_zshrc; echo ANSWER=\$ZSHRC_ANSWER; head -n 1 \$HOME/.zshrc; tail -n 1 \$HOME/.zshrc" 2>&1
}
out="$(zask '\r' 'alias mine=1\n')"
contains "$out" 'herdspace never replaces it' 'the question says that herdspace never replaces your ~/.zshrc'
contains "$out" 'ANSWER=full' 'Enter adds the full herdspace shell to a file with no Oh My Zsh'
contains "$out" '# >>> herdspace >>>' 'the full block goes at the top'
out="$(zask '\r' 'source $ZSH/oh-my-zsh.sh\n')"
contains "$out" 'ANSWER=extras' 'Enter adds only the extras to a file that loads Oh My Zsh'
contains "$out" '# <<< herdspace extras <<<' 'the extras block goes at the end'
out="$(zask 'k\r' 'alias mine=1\n')"
contains "$out" 'ANSWER=keep' 'k keeps your ~/.zshrc with no change'

# The questions about changed files, at a terminal.
question() {
  # question KEYS [FILES]: a changed ~/.p10k.zsh, answered with KEYS.
  python3 "$ROOT/tests/pty_run.py" 6 "$1" env TERM=xterm-256color "$tmp/run.sh" "
    printf 'mine\n' >\$HOME/.p10k.zsh
    MODE=ask CHANGED_FILES_READY=1 CHANGED_FILES=\"\$HOME/.p10k.zsh${2-
\$HOME/.config/a}\"
    install_file $tmp/files/new \$HOME/.p10k.zsh
    echo DECISION=\$DECISION ASK_ALL=\$ASK_ALL" 2>&1
}
out="$(question '\r\r')"
contains "$out" '2 files differ from the herdspace version' 'the first question lists all the changed files'
contains "$out" 'Review one file at a time' 'the first question offers a review of each file'
contains "$out" 'Keep all 2 files' 'the first question offers to keep all files'
contains "$out" 'Replace all 2 files' 'the first question offers to replace all files'
contains "$out" 'File 1 of 2: ~/.p10k.zsh' 'the review names the file and its place'
contains "$out" 'Show the difference of this file' 'd says that it shows only this file'
contains "$out" 'DECISION=keep' 'Enter in the review keeps the file'
out="$(question 'K\r')"
contains "$out" 'DECISION=keep ASK_ALL=keep' 'K keeps all files'
lacks "$out" 'File 1 of 2' 'K asks about no single file'
out="$(question 'R\r')"
contains "$out" 'DECISION=replace ASK_ALL=replace' 'R replaces all files'
out="$(question 'v\rr\r')"
contains "$out" 'DECISION=replace ASK_ALL=review' 'r in the review replaces the file'
out="$(question '\r' '')"
lacks "$out" 'Review one file at a time' 'one changed file gets no question about all files'
contains "$out" 'differs from the herdspace version' 'one changed file gets its own question'

# A changed file of a folder, for example the Neovim files, gets its question too.
out="$(python3 "$ROOT/tests/pty_run.py" 6 'r\r' env TERM=xterm-256color "$tmp/run.sh" "
  mkdir -p $tmp/tree \$HOME/tree; printf 'new\n' >$tmp/tree/a.lua; printf 'mine\n' >\$HOME/tree/a.lua
  MODE=ask CHANGED_FILES_READY=1 CHANGED_FILES=\"\$HOME/tree/a.lua\"
  install_tree $tmp/tree \$HOME/tree; cat \$HOME/tree/a.lua" 2>&1)"
contains "$out" 'a.lua differs from the herdspace version' 'a file of a folder gets a question'
contains "$out" 'Saved a backup' 'the answer of a file of a folder counts'

# The prerequisites question names the default.
contains "$(python3 "$ROOT/tests/pty_run.py" 4 '\r' env TERM=xterm-256color "$tmp/run.sh" "source $ROOT/bootstrap/lib/prereqs.sh; ask_yes 'Install it?' && echo YES" 2>&1)" '[Y/n] (Enter = yes)' 'the yes question names its default'

# The end of a run: the kept files, the backups, and the next steps.
out="$(run "printf 'a\n' >\$HOME/.p10k.zsh; write_file $tmp/files/new \$HOME/.p10k.zsh 644; KEPT_LIST=\"\$HOME/.zshrc
\"; EDITED=1; ZSHRC_KEPT_NO_EXTRAS=1; HS_DOC_BASE=https://example.test/blob/1.0; NEXT_SERVER=box; finish_run client")"
contains "$out" 'Kept 1 file that differ' 'the kept line uses one file'
lacks "$out" 'replace-all' 'the end of a run does not advise --replace-all'
contains "$out" 'answer f or e for ~/.zshrc' 'the end of a run names the missing block'
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

# A file with no manifest entry, from an install before the manifest existed.
# If it matches an older herdspace version, the setup updates it with no
# question. If a person changed it, the setup asks.
mkdir -p "$tmp/repo/bootstrap" "$tmp/repo/config"
echo 'new = true' >"$tmp/repo/config/app.toml"
old_sha="$(printf 'old = true\n' | { sha256sum 2>/dev/null || shasum -a 256; } | awk '{print $1}')"
printf '# list\nconfig/app.toml\t%s\n' "$old_sha" >"$tmp/repo/bootstrap/known-hashes.tsv"
known() { run "REPO_ROOT=$tmp/repo; rm -f \$STATE_DIR/manifest.tsv; printf '$1' >\$HOME/app.toml; file_status $tmp/repo/config/app.toml \$HOME/app.toml"; }
contains "$(known 'old = true\n')" 'outdated' 'a file from an older herdspace, with no manifest entry, is outdated'
contains "$(known 'old = true\nmine = 1\n')" 'edited' 'a changed file with no manifest entry is edited'
contains "$(run "REPO_ROOT=$tmp/repo; manifest_set \$HOME/app.toml 0000; printf 'old = true\n' >\$HOME/app.toml; file_status $tmp/repo/config/app.toml \$HOME/app.toml")" 'edited' 'a file whose manifest entry differs stays edited, even if it matches an older version'
out="$(run "REPO_ROOT=$tmp/repo; MODE=apply; rm -f \$STATE_DIR/manifest.tsv; printf 'old = true\n' >\$HOME/app.toml; install_file $tmp/repo/config/app.toml \$HOME/app.toml </dev/null; cat \$HOME/app.toml")"
contains "$out" 'new = true' 'the setup updates a file from an older herdspace'
lacks "$out" 'differs' 'the setup asks nothing about a file from an older herdspace'

# The Neovim files of an older herdspace move out of ~/.config/nvim. A folder
# with a file of the person stays.
nv() { run "source $ROOT/bootstrap/lib/server.sh; MODE=apply; rm -rf \$HOME/.config/nvim* \$STATE_DIR/manifest.tsv; mkdir -p \$HOME/.config/nvim/lua/config; cp $ROOT/config/nvim/init.lua \$HOME/.config/nvim/; cp $ROOT/config/nvim/lua/config/keymaps.lua \$HOME/.config/nvim/lua/config/; echo '{}' >\$HOME/.config/nvim/lazy-lock.json; $1; move_old_nvim; ls -d \$HOME/.config/nvim* 2>/dev/null | sed 's|.*/||'"; }
out="$(nv true)"
contains "$out" 'nvim.bak-' 'the Neovim files of an older herdspace move to a backup folder'
lacks "$(printf '%s\n' "$out" | grep -x nvim)" 'nvim' 'no ~/.config/nvim is left after the move'
contains "$out" 'herdspace-nvim' 'the move says where the herdspace Neovim files are'
out="$(nv 'echo "-- mine" >>$HOME/.config/nvim/init.lua')"
contains "$(printf '%s\n' "$out" | grep -x nvim)" 'nvim' 'a changed Neovim file keeps ~/.config/nvim where it is'
lacks "$out" 'nvim.bak-' 'a changed Neovim file makes no backup folder'
out="$(nv 'echo x >$HOME/.config/nvim/lua/plugins.lua')"
contains "$(printf '%s\n' "$out" | grep -x nvim)" 'nvim' 'a Neovim file of the person keeps ~/.config/nvim where it is'
contains "$out" 'Your own ~/.config/nvim stays, and nvim starts it' 'the setup says that your own Neovim starts'
contains "$out" 'NVIM_APPNAME=herdspace-nvim nvim' 'the setup says how to start the herdspace editor'
out="$(nv 'echo x >$HOME/.config/nvim/lua/plugins.lua; export NVIM_APPNAME=herdspace-nvim')"
lacks "$out" 'Your own' 'with NVIM_APPNAME=herdspace-nvim, the setup says nothing about your own Neovim'
out="$(nv true)"
lacks "$out" 'Your own' 'the folder of an older herdspace moves with no note about your own Neovim'
out="$(nv 'rm -rf $HOME/.config/nvim')"
lacks "$out" 'nvim' 'with no ~/.config/nvim, nothing moves'

echo "RESULT failures=${failures}"
exit $((failures > 0))
