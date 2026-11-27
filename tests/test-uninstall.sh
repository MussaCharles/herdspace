#!/usr/bin/env bash
# test-uninstall.sh checks "herdspace uninstall" in temporary home folders. A
# helper writes a fake install with the functions of the setup, so that the
# manifest and the marked blocks are the real ones. The test runs --check, which
# changes nothing, and then the uninstall: a file with no change goes, a file
# that a person changed stays, the blocks go, and the lines of the person stay.
# It uses stub systemctl and defaults commands. It needs bash and no network.
# Usage: tests/test-uninstall.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; failures=$((failures + 1)); }
contains() { case "$1" in *"$2"*) pass "$3" ;; *) fail "$3: wanted [$2] in [${1:0:900}]" ;; esac; }
lacks() { case "$1" in *"$2"*) fail "$3: found [$2]" ;; *) pass "$3" ;; esac; }
gone() { [ ! -e "$1" ] && [ ! -L "$1" ] && pass "$2" || fail "$2: $1 exists"; }
here() { [ -e "$1" ] && pass "$2" || fail "$2: $1 is missing"; }

# The stubs log each call. A real systemctl or defaults would change this machine.
mkdir -p "$tmp/bin"
for stub in systemctl defaults; do
  printf '#!/usr/bin/env bash\necho "%s $*" >>"$STUB_LOG"\n' "$stub" >"$tmp/bin/$stub"
  chmod 755 "$tmp/bin/$stub"
done
export PATH="$tmp/bin:$PATH" STUB_LOG="$tmp/stub.log"

# A helper that runs a setup function in the home folder that it gets.
cat >"$tmp/seed.sh" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
export HOME="\$1"
REPO_ROOT="$ROOT"
source "$ROOT/bootstrap/lib/common.sh"
source "$ROOT/bootstrap/lib/shell.sh"
source "$ROOT/bootstrap/lib/client.sh"
MODE=ask
shift
eval "\$1"
SCRIPT
chmod 755 "$tmp/seed.sh"
seed() { "$tmp/seed.sh" "$1" "$2" </dev/null >/dev/null 2>&1; }
# snapshot HOME prints the path and the hash of each file, to compare two states.
snapshot() { (cd "$1" && find . -type f -o -type l | sort | while IFS= read -r f; do printf '%s %s\n' "$f" "$(cksum <"$f" 2>/dev/null)"; done); }

# ---------- scenario 1: a server and client with changes of the person
H="$tmp/one"
mkdir -p "$H"
seed "$H" '
  install_file "${REPO_ROOT}/config/herdr/config.toml" "${HOME}/.config/herdr/config.toml"
  install_file "${REPO_ROOT}/config/lazygit/config.yml" "${HOME}/.config/lazygit/config.yml"
  install_tree "${REPO_ROOT}/lib/hopen" "${HOME}/.local/lib/hopen"
  install_file "${REPO_ROOT}/bin/hopen" "${HOME}/.local/bin/hopen" 755
  install_tree "${REPO_ROOT}/lib/herdspace" "${HOME}/.local/lib/herdspace"
  install_file "${REPO_ROOT}/bin/herdspace" "${HOME}/.local/bin/herdspace" 755
  install_file "${REPO_ROOT}/config/shell/zshrc.zsh" "${HOME}/.config/herdspace/zshrc.zsh"
  install_file "${REPO_ROOT}/config/shell/extras.zsh" "${HOME}/.config/herdspace/extras.zsh"
  install_tree "${REPO_ROOT}/config/templates" "${HOME}/.config/hopen/templates"
  install_file "${REPO_ROOT}/config/nvim/init.lua" "${HOME}/.config/herdspace-nvim/init.lua"
  cp "${REPO_ROOT}/config/nvim/lazy-lock.json" "${HOME}/.config/herdspace-nvim/lazy-lock.json"
  mkdir -p "${HOME}/.local/share/herdspace-nvim/lazy" && echo plugin >"${HOME}/.local/share/herdspace-nvim/lazy/x"
  sed "s|@HOME@|${HOME}|g" "${REPO_ROOT}/bootstrap/service/herdr.service" >"${HOME}/unit.tmp"
  install_file "${HOME}/unit.tmp" "${HOME}/.config/systemd/user/herdr.service"; rm "${HOME}/unit.tmp"
  printf "export MINE=1\nalias gs=\"git status\"\n" >"${HOME}/.zshrc"
  ensure_block "${HOME}/.zshrc" herdspace "$ZSHRC_BLOCK" top
  extras_block "${HOME}/.zshrc"
  printf "export PATH_MINE=1\n" >"${HOME}/.zprofile"
  setup_zprofile server
  printf "export KEEP_ME=1\n" >"${HOME}/.zshenv"
  ensure_block "${HOME}/.zshenv" "herdspace bash env" "export FROM_BASH=1"
  KEYS=herdspace LOOK=herdspace install_ghostty_config "${REPO_ROOT}/config/ghostty/config.ghostty"
  echo "font-size = 99" >>"${HOME}/.config/ghostty/config.ghostty"
  echo "# my change" >>"${HOME}/.config/lazygit/config.yml"
  mkdir -p "${STATE_DIR}/done" "${HOME}/.cache/herdspace"
  echo 0.9.0 >"${STATE_DIR}/version"; echo role=both >"${STATE_DIR}/last-setup"
  touch "${STATE_DIR}/done/mission-control"
  echo herdspace >"${HOME}/.config/herdspace/keys"; echo herdspace >"${HOME}/.config/herdspace/look"
  echo latest >"${HOME}/.cache/herdspace/latest"
'
# What belongs to the person, and must stay.
mkdir -p "$H/projects/app" "$H/.config/nvim" "$H/.config/systemd/user"
echo '[session]' >"$H/projects/app/herdspace.toml"
echo 'vim.o.number = true' >"$H/.config/nvim/init.lua"
printf '#!/bin/sh\necho herdr\n' >"$H/.local/bin/herdr"
echo old >"$H/.zshrc.bak-20260101-000000"
echo mine >"$H/.config/herdspace/my-note"

before="$(snapshot "$H")"
out="$(HOME="$H" "$H/.local/bin/herdspace" uninstall --check 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && pass '--check exits 0' || fail "--check exits 0: ${rc}"
[ "$before" = "$(snapshot "$H")" ] && pass '--check changes no file' || fail '--check changes a file'
[ ! -s "$STUB_LOG" ] && pass '--check calls no systemctl and no defaults' || fail "--check calls a command: $(cat "$STUB_LOG")"
contains "$out" 'This is a check. Nothing changes.' '--check says that it changes nothing'
contains "$out" 'remove    ~/.config/herdr/config.toml' '--check lists a file that it would remove'
contains "$out" 'keep      ~/.config/lazygit/config.yml (you changed it)' '--check names a file that it keeps'
contains "$out" 'edit      ~/.zshrc' '--check lists the zshrc blocks'
contains "$out" 'restore   the Ctrl arrow shortcuts' '--check lists the Mission Control keys'
contains "$out" 'What stays:' '--check says what stays'

# No terminal and no --yes: nothing happens.
out="$(HOME="$H" "$H/.local/bin/herdspace" uninstall 2>&1 </dev/null)"; rc=$?
[ "$rc" -ne 0 ] && pass 'no terminal and no --yes fails' || fail 'no terminal and no --yes fails'
contains "$out" 'herdspace uninstall --yes' 'the failure names --yes'
[ "$before" = "$(snapshot "$H")" ] && pass 'no terminal and no --yes changes no file' || fail 'no terminal and no --yes changes a file'
out="$(HOME="$H" "$H/.local/bin/herdspace" uninstall --bogus 2>&1)"; rc=$?
[ "$rc" -eq 2 ] && pass 'an unknown option exits 2' || fail "an unknown option exits 2: ${rc}"

# The question at a terminal: the default is no.
out="$(HOME="$H" python3 "$ROOT/tests/pty_run.py" 5 '\r' "$H/.local/bin/herdspace" uninstall 2>&1)"
contains "$out" 'Uninstall herdspace? [y/N]' 'the question has the default no'
contains "$out" 'Nothing changed.' 'Enter answers no'
[ "$before" = "$(snapshot "$H")" ] && pass 'the answer no changes no file' || fail 'the answer no changes a file'

# The uninstall.
out="$(HOME="$H" "$H/.local/bin/herdspace" uninstall --yes 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && pass 'uninstall exits 0' || fail "uninstall exits 0: ${rc}: ${out}"
[ -z "${SHOW:-}" ] || echo "$out"
gone "$H/.config/herdr/config.toml" 'a file with no change is gone'
gone "$H/.local/bin/hopen" 'hopen is gone'
gone "$H/.local/lib/hopen" 'the modules of hopen are gone'
gone "$H/.local/bin/herdspace" 'the herdspace command is gone'
gone "$H/.local/lib/herdspace" 'the modules of the herdspace command are gone'
gone "$H/.config/hopen" 'the folder of the templates is gone'
gone "$H/.config/herdspace-nvim" 'the Neovim folder with no change is gone'
gone "$H/.local/share/herdspace-nvim" 'the plugins of the herdspace Neovim are gone'
gone "$H/.config/herdspace/zshrc.zsh" 'the shell file is gone'
gone "$H/.local/share/herdspace" 'the state folder is gone'
gone "$H/.cache/herdspace" 'the cache folder is gone'
gone "$H/.config/herdspace/keys" 'the keys choice is gone'
gone "$H/.config/systemd/user/herdr.service" 'the login service file is gone'
here "$H/.config/lazygit/config.yml" 'a changed file stays'
contains "$(cat "$H/.config/lazygit/config.yml")" '# my change' 'the changed file keeps its change'
contains "$out" '.config/lazygit/config.yml' 'the output names the changed file'
contains "$out" 'These files stay, because you changed them' 'the output has the list of kept files'
z="$(cat "$H/.zshrc")"
lacks "$z" '>>> herdspace' 'the zshrc has no herdspace block'
contains "$z" 'export MINE=1' 'the zshrc keeps your export'
contains "$z" 'alias gs=' 'the zshrc keeps your alias'
case "$z" in '') fail 'the zshrc is not empty' ;; [[:space:]]*) fail 'the zshrc starts with a blank line' ;; *) pass 'the zshrc has no blank line at the top' ;; esac
contains "$(cat "$H/.zprofile")" 'export PATH_MINE=1' 'the zprofile keeps your line'
lacks "$(cat "$H/.zprofile")" 'herdspace' 'the zprofile has no herdspace block'
g="$(cat "$H/.config/ghostty/config.ghostty")"
lacks "$g" '>>> herdspace' 'the Ghostty file has no herdspace block'
contains "$g" 'font-size = 99' 'the Ghostty file keeps your line'
contains "$(cat "$H/.zshenv")" 'FROM_BASH=1' 'the block of moved exports stays in zshenv'
contains "$(cat "$H/.zshenv")" 'KEEP_ME=1' 'zshenv keeps your line'
contains "$out" 'moved from your bash files' 'the output says that the exports block stays'
here "$H/projects/app/herdspace.toml" 'a project stays'
here "$H/.local/bin/herdr" 'Herdr stays'
here "$H/.config/nvim/init.lua" 'your own Neovim folder stays'
here "$H/.zshrc.bak-20260101-000000" 'a backup stays'
here "$H/.config/herdspace/my-note" 'a file of yours in the herdspace config folder stays'
contains "$out" 'it holds a backup or a file of yours' 'the output says that the config folder stays'
log="$(cat "$STUB_LOG" 2>/dev/null)"
contains "$log" 'systemctl --user disable herdr.service' 'the login service is disabled'
lacks "$log" 'stop' 'the login service is not stopped'
lacks "$log" '--now' 'disable does not use --now, so the server keeps running'
contains "$log" 'defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 32' 'Mission Control gets its key back'
contains "$log" '<key>enabled</key><true/>' 'the shortcuts turn on'
contains "$out" 'Herdr, and the tools of the setup' 'the output says that Herdr stays'
contains "$out" 'chsh -s /bin/bash' 'the output says how to go back to bash'

# ---------- scenario 2: an install with no change, and no marker of Mission Control
H="$tmp/two"
mkdir -p "$H"
seed "$H" '
  install_tree "${REPO_ROOT}/lib/herdspace" "${HOME}/.local/lib/herdspace"
  install_file "${REPO_ROOT}/bin/herdspace" "${HOME}/.local/bin/herdspace" 755
  install_file "${REPO_ROOT}/config/herdr/config.toml" "${HOME}/.config/herdr/config.toml"
  setup_zshrc
  setup_zprofile client
  KEYS=herdspace LOOK=herdspace install_ghostty_config "${REPO_ROOT}/config/ghostty/config.ghostty"
  mkdir -p "${STATE_DIR}"; echo 0.9.0 >"${STATE_DIR}/version"
'
: >"$STUB_LOG"
out="$(HOME="$H" "$H/.local/bin/herdspace" uninstall --yes 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && pass 'a clean uninstall exits 0' || fail "a clean uninstall exits 0: ${rc}: ${out}"
gone "$H/.zshrc" 'a zshrc with only the herdspace block is gone'
gone "$H/.config/ghostty" 'a Ghostty file with only the blocks is gone, and its folder too'
gone "$H/.config/herdr" 'an empty folder is gone'
gone "$H/.local/bin/herdspace" 'the command is gone'
here "$H/.local" 'a shared folder stays'
contains "$out" 'herdspace is removed' 'a clean uninstall says so'
lacks "$(cat "$STUB_LOG" 2>/dev/null)" 'defaults' 'no marker, so Mission Control is not touched'
[ -z "$(find "$H" -type f | head -n 1)" ] && pass 'no file is left' || fail "files are left: $(find "$H" -type f)"

# ---------- scenario 3: you changed the command, and the manifest is missing
H="$tmp/three"
mkdir -p "$H"
seed "$H" '
  install_tree "${REPO_ROOT}/lib/herdspace" "${HOME}/.local/lib/herdspace"
  install_file "${REPO_ROOT}/bin/herdspace" "${HOME}/.local/bin/herdspace" 755
  mkdir -p "${STATE_DIR}"
'
echo '# local change' >>"$H/.local/bin/herdspace"
out="$(HOME="$H" "$H/.local/bin/herdspace" uninstall --yes 2>&1)"
here "$H/.local/bin/herdspace" 'a changed herdspace command stays'
here "$H/.local/lib/herdspace/uninstall.sh" 'the modules of a changed herdspace command stay'
contains "$out" 'you changed it' 'the output names the changed command'
rm -f "$H/.local/share/herdspace/manifest.tsv"
out="$(HOME="$H" "$H/.local/bin/herdspace" uninstall --check 2>&1)"
contains "$out" 'This is a check' 'a check with no manifest works'
out="$(HOME="$tmp/empty" "$ROOT/bin/herdspace" uninstall --check 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && contains "$out" 'is not set up here' 'a home with no herdspace says so' || fail 'a home with no herdspace fails'

echo "RESULT failures=${failures}"
exit $((failures > 0))
