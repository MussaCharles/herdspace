#!/usr/bin/env bash
# run-macos.sh tests the macOS scripts on a Mac. A container cannot run macOS,
# so the test uses a temporary home folder and stub commands. Stubs replace the
# commands that change the system, so the real account does not change.
#
# The test needs Homebrew with the tools installed.
# Usage: tests/run-macos.sh [server|client|prereqs|keys|both]...   Default: server client prereqs keys both
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ "$(uname -s)" = Darwin ] || { echo 'This test runs only on macOS.'; exit 1; }
[ "$#" -gt 0 ] || set -- server client prereqs keys both

TEST_TERMINFO="${HOME}/.terminfo"

# A Unix socket path has a short limit, so the home folder must have a short path.
TEST_HOME="$(mktemp -d /tmp/hbt.XXXXXX)"
STUBS="${TEST_HOME}/stubs"
CALLS="${TEST_HOME}/calls.log"
mkdir -p "$STUBS" "${TEST_HOME}/home/.claude" "${TEST_HOME}/home/.pi/agent/extensions"
# hopen needs Python 3.11 or later. The test uses the newest Homebrew Python.
for py in /opt/homebrew/bin/python3.1[1-9]; do
  [ -x "$py" ] && ln -sf "$py" "${STUBS}/python3"
done
[ -e "${STUBS}/python3" ] || { echo "FAIL this test needs Python 3.11 or later from Homebrew: brew install python"; exit 1; }
# The Homebrew folder of the stub, so that the prerequisites step finds it writable.
mkdir -p "${TEST_HOME}/brew/Cellar" "${TEST_HOME}/brew/bin"

for name in defaults chsh activate-stub; do
  cat >"${STUBS}/${name}" <<STUB
#!/bin/sh
echo "${name} \$*" >>"${CALLS}"
exit 0
STUB
done
cat >"${STUBS}/launchctl" <<STUB
#!/bin/sh
echo "launchctl \$*" >>"${CALLS}"
[ "\$1" = bootstrap ] && touch "${TEST_HOME}/loaded"
if [ "\$1" = print ]; then [ -f "${TEST_HOME}/loaded" ]; exit \$?; fi
exit 0
STUB
cat >"${STUBS}/ssh" <<STUB
#!/bin/sh
echo "ssh \$*" >>"${CALLS}"
case "\$*" in
  *" true") exit 0 ;;
  *infocmp*) [ -s "${TEST_HOME}/terminfo.sent" ]; exit \$? ;;
  *tic*) cat >"${TEST_HOME}/terminfo.sent"; exit 0 ;;
esac
exit 0
STUB
cat >"${STUBS}/brew" <<STUB
#!/bin/sh
echo "brew \$*" >>"${CALLS}"
case "\$1" in
  shellenv) exit 0 ;;
  --prefix) echo "${TEST_HOME}/brew"; exit 0 ;;
  list)
    if [ "\$2" = --formula ]; then cat "${TEST_HOME}/brew-installed" 2>/dev/null; fi
    if [ "\$2" = --cask ] && [ -n "\${STUB_NO_GHOSTTY:-}" ]; then exit 1; fi
    exit 0
    ;;
  install)
    shift
    for f in "\$@"; do echo "\$f" >>"${TEST_HOME}/brew-installed"; done
    ;;
esac
exit 0
STUB
printf '#!/bin/sh\nexit 0\n' >"${STUBS}/claude"
cp "${STUBS}/claude" "${STUBS}/pi"
chmod 755 "${STUBS}"/*

run() {
  env -i HOME="${TEST_HOME}/home" USER="$(id -un)" LANG=en_US.UTF-8 TERM=xterm-256color \
    PATH="${STUBS}:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    ACTIVATE_SETTINGS="${STUBS}/activate-stub" GHOSTTY_TERMINFO="${TEST_TERMINFO:-}" "$@"
}

# shellcheck disable=SC2329 # The trap below calls this function.
cleanup() {
  case "$(run herdr status 2>/dev/null)" in
    *"socket: ${TEST_HOME}/home"*) run herdr server stop >/dev/null 2>&1 ;;
  esac
  rm -rf "$TEST_HOME"
}
trap cleanup EXIT

before="$(stat -f %m "$HOME/.config/herdr/config.toml" 2>/dev/null) $(find "$HOME/Library/LaunchAgents" -type f | wc -l)"
status=0

for target in "$@"; do
  case "$target" in
    server)
      run "$ROOT/bootstrap.sh" server --skip-nvim-tools || status=1
      run "$ROOT/tests/verify-server.sh" macos || status=1
      "$ROOT/tests/test-install.sh" || status=1
      grep -q 'brew install herdr' "$CALLS" && echo 'PASS brew installs herdr' || { echo 'FAIL brew installs herdr'; status=1; }
      grep -q 'launchctl bootstrap' "$CALLS" && echo 'PASS launch agent loads' || { echo 'FAIL launch agent loads'; status=1; }
      plutil -lint "${TEST_HOME}/home/Library/LaunchAgents/local.herdr.server.plist" >/dev/null && echo 'PASS plist is valid' || { echo 'FAIL plist is valid'; status=1; }
      run "$ROOT/tests/test-idempotent.sh" bootstrap.sh "${TEST_HOME}/home/.config/herdr/config.toml" server --skip-nvim-tools || status=1
      backups="$(find "${TEST_HOME}/home" -name '*.bak-*' -not -path '*/.cache/*' -not -path '*/.oh-my-zsh/*' -not -path '*/.local/*' | wc -l | tr -d ' ')"
      echo "RESULT server backups=${backups}"
      [ "$backups" = 0 ] || status=1
      ;;
    client)
      rm -f "${TEST_HOME}/home/.zshrc"
      run "$ROOT/bootstrap.sh" client --server example-server || status=1
      cmp -s "$ROOT/config/ghostty/config.ghostty" "${TEST_HOME}/home/.config/ghostty/config.ghostty" && echo 'PASS ghostty configuration' || { echo 'FAIL ghostty configuration'; status=1; }
      grep -q 'BOOTSTRAP_PROMPT_COLOR=166' "${TEST_HOME}/home/.config/herdspace/env.zsh" && echo 'PASS client prompt color' || { echo 'FAIL client prompt color'; status=1; }
      grep -q 'ssh -- example-server tic -x -' "$CALLS" && echo 'PASS terminal description sent' || { echo 'FAIL terminal description sent'; status=1; }
      [ "$(grep -c 'defaults write com.apple.symbolichotkeys' "$CALLS")" = 4 ] && echo 'PASS four shortcuts released' || { echo 'FAIL four shortcuts released'; status=1; }
      grep -q 'activate-stub -u' "$CALLS" && echo 'PASS shortcuts applied' || { echo 'FAIL shortcuts applied'; status=1; }
      run "$ROOT/tests/test-idempotent.sh" bootstrap.sh "${TEST_HOME}/home/.config/ghostty/config.ghostty" client --server example-server || status=1
      out="$(run zsh -i -c 'print -r -- CLIENT_OK' </dev/null 2>&1)"
      case "$out" in *CLIENT_OK*) echo 'PASS client shell starts' ;; *) echo "FAIL client shell starts: ${out:0:200}"; status=1 ;; esac
      ;;
    prereqs)
      # On an account that is not an admin, the setup cannot install Ghostty.
      # It must name the command for an admin account, and stop.
      if id -Gn | tr ' ' '\n' | grep -qx admin; then
        echo 'PASS prereqs: skipped, because this account is an admin'
      else
        out="$(run env STUB_NO_GHOSTTY=1 HS_PREREQS_ONLY=1 "$ROOT/bootstrap.sh" client --yes </dev/null 2>&1)"; rc=$?
        case "$out" in *"brew install --cask ghostty"*) echo 'PASS prereqs: names the Ghostty command for an admin' ;; *) echo "FAIL prereqs: names the Ghostty command for an admin: ${out:0:300}"; status=1 ;; esac
        [ "$rc" -ne 0 ] && echo 'PASS prereqs: stops without Ghostty' || { echo 'FAIL prereqs: stops without Ghostty'; status=1; }
      fi
      ;;
    keys)
      # --keep-terminal-keys keeps the keys of Ghostty and macOS. A later run
      # with no key option keeps the choice. --use-herdspace-keys goes back.
      cfg="${TEST_HOME}/home/.config/ghostty/config.ghostty"
      : >"$CALLS"
      run "$ROOT/bootstrap.sh" client --keep-terminal-keys --server example-server >/dev/null || status=1
      if grep -q 'unbind\|macos-option-as-alt' "$cfg"; then echo 'FAIL keys: terminal keys in Ghostty'; status=1; else echo 'PASS keys: terminal keys in Ghostty'; fi
      grep -q '^terminal$' "${TEST_HOME}/home/.config/herdspace/keys" && echo 'PASS keys: the choice is saved' || { echo 'FAIL keys: the choice is saved'; status=1; }
      [ "$(grep -c 'symbolichotkeys.*<true/>' "$CALLS")" = 4 ] && echo 'PASS keys: Mission Control gets its keys back' || { echo 'FAIL keys: Mission Control gets its keys back'; status=1; }
      if run "$ROOT/bootstrap.sh" client --check --server example-server >/dev/null && ! grep -q unbind "$cfg"; then echo 'PASS keys: a later run keeps the choice'; else echo 'FAIL keys: a later run keeps the choice'; status=1; fi
      run "$ROOT/bootstrap.sh" client --use-herdspace-keys --server example-server >/dev/null || status=1
      cmp -s "$ROOT/config/ghostty/config.ghostty" "$cfg" && echo 'PASS keys: herdspace keys again' || { echo 'FAIL keys: herdspace keys again'; status=1; }
      [ "$(grep -c 'symbolichotkeys.*<false/>' "$CALLS")" = 4 ] && echo 'PASS keys: Mission Control releases the keys again' || { echo 'FAIL keys: Mission Control releases the keys again'; status=1; }
      ;;
    both)
      # One machine that is a server and a client. A check after the run must
      # find nothing to do, so the two parts do not undo each other.
      run "$ROOT/bootstrap.sh" both --skip-nvim-tools || status=1
      grep -q 'BOOTSTRAP_ROLE=both' "${TEST_HOME}/home/.config/herdspace/env.zsh" && echo 'PASS both: one role' || { echo 'FAIL both: one role'; status=1; }
      grep -q 'herdr-update-check' "${TEST_HOME}/home/.zprofile" && echo 'PASS both: server login block' || { echo 'FAIL both: server login block'; status=1; }
      cmp -s "$ROOT/config/ghostty/config.ghostty" "${TEST_HOME}/home/.config/ghostty/config.ghostty" && echo 'PASS both: ghostty configuration' || { echo 'FAIL both: ghostty configuration'; status=1; }
      if out="$(run "$ROOT/bootstrap.sh" both --check --skip-nvim-tools 2>&1)"; then echo 'PASS both: a check finds nothing to do'; else echo 'FAIL both: a check finds nothing to do'; printf '%s\n' "$out" | grep -E '\[(todo|diff)\]'; status=1; fi
      ;;
    *) echo "Unknown target: ${target}"; status=1 ;;
  esac
done

after="$(stat -f %m "$HOME/.config/herdr/config.toml" 2>/dev/null) $(find "$HOME/Library/LaunchAgents" -type f | wc -l)"
if [ "$before" = "$after" ]; then echo 'PASS the real account did not change'; else echo 'FAIL the real account changed'; status=1; fi
echo "RESULT exit=${status}"
exit "$status"
