#!/usr/bin/env bash
# The prerequisites step. Each run starts with it. It lists what the setup
# needs before it can start, installs the missing items after one question, and
# lets the person skip an optional item.
#
# A platform script adds each item with prereq_add, and then calls run_prereqs.
#
# The step never turns on remote access, never installs an SSH server, and never
# copies a key to a server. Remote access is a choice of the owner of the server.

PREREQ_LABELS=()
PREREQ_KINDS=()
PREREQ_READY=()
PREREQ_APPLY=()
PREREQ_PASSWORD=()
PREREQ_FIX=()

# prereq_add LABEL KIND READY_FN APPLY_FN PASSWORD FIX
#   KIND      necessary or optional. The setup cannot run without a necessary item.
#   READY_FN  exits 0 if the item is there.
#   APPLY_FN  installs the item, or "-" if the setup cannot install it.
#   PASSWORD  yes if the install can ask for a password, or no.
#   FIX       what a person can do, if the setup cannot install the item.
prereq_add() {
  PREREQ_LABELS+=("$1")
  PREREQ_KINDS+=("$2")
  PREREQ_READY+=("$3")
  PREREQ_APPLY+=("$4")
  PREREQ_PASSWORD+=("$5")
  PREREQ_FIX+=("$6")
}

# can_use_password exits 0 if a step that asks for a password can run now: a
# person is at the terminal, or sudo works with no password, or this is root.
can_use_password() {
  [ -t 0 ] && return 0
  [ "$(id -u)" -eq 0 ] && return 0
  have sudo && sudo -n true 2>/dev/null
}

# ask_yes QUESTION exits 0 for yes. The default is yes. With --yes, or with no
# terminal, the answer is yes.
ask_yes() {
  local answer
  [ "${ASSUME_YES:-0}" = "1" ] && return 0
  [ -t 0 ] || return 0
  printf '  %s [Y/n] (Enter = yes) ' "$1"
  IFS= read -r answer || answer=""
  case "$answer" in
    n | N | no | No) return 1 ;;
    *) return 0 ;;
  esac
}

# prereq_fix_line prints the fix of one item that the setup cannot install.
prereq_fix_line() {
  printf '         %s\n' "$1"
}

run_prereqs() {
  local i missing=() necessary_left=0
  step "Prerequisites"
  for i in "${!PREREQ_LABELS[@]}"; do
    if "${PREREQ_READY[$i]}"; then
      if [ "$UI_COLOR" -eq 1 ]; then ui_item $((i + 1)) "${PREREQ_LABELS[$i]}" ok; else ok "${PREREQ_LABELS[$i]}"; fi
    elif [ "$UI_COLOR" -eq 1 ] && [ "$MODE" != "check" ]; then
      missing+=("$i")
      ui_item $((i + 1)) "${PREREQ_LABELS[$i]}" "$([ "${PREREQ_KINDS[$i]}" = necessary ] && echo missing || echo optional)"
    else
      missing+=("$i")
      if [ "$MODE" = "check" ]; then
        if [ "${PREREQ_KINDS[$i]}" = "necessary" ]; then
          note_todo "${PREREQ_LABELS[$i]} is missing"
        else
          info "${PREREQ_LABELS[$i]} is missing (optional)"
        fi
        [ "${PREREQ_APPLY[$i]}" != "-" ] || prereq_fix_line "${PREREQ_FIX[$i]}"
      else
        printf '  [miss] %s (%s)\n' "${PREREQ_LABELS[$i]}" "${PREREQ_KINDS[$i]}"
      fi
    fi
  done
  if [ "${#missing[@]}" -eq 0 ] || [ "$MODE" = "check" ]; then
    # A test can stop here, after the prerequisites.
    [ -z "${HS_PREREQS_ONLY:-}" ] || exit "$([ "$TODO" -eq 0 ] && echo 0 || echo 1)"
    return 0
  fi

  # One question for the necessary items. Then one question for each optional item.
  local install_necessary=1
  ask_yes "Install the missing necessary items?" || install_necessary=0
  for i in "${missing[@]}"; do
    local label="${PREREQ_LABELS[$i]}" kind="${PREREQ_KINDS[$i]}"
    if [ "$kind" = "optional" ]; then
      ask_yes "Install ${label}? It is optional." || { info "Skipped ${label}."; continue; }
    elif [ "$install_necessary" -eq 0 ]; then
      warn "${label} is necessary."
      necessary_left=1
      continue
    fi
    if [ "${PREREQ_APPLY[$i]}" = "-" ]; then
      warn "The setup cannot install ${label}. ${PREREQ_FIX[$i]}"
      [ "$kind" != "necessary" ] || necessary_left=1
      continue
    fi
    if [ "${PREREQ_PASSWORD[$i]}" = "yes" ] && ! can_use_password; then
      warn "${label} needs a password, and no person is at the terminal. ${PREREQ_FIX[$i]}"
      [ "$kind" != "necessary" ] || necessary_left=1
      continue
    fi
    step "$label"
    if "${PREREQ_APPLY[$i]}" && "${PREREQ_READY[$i]}"; then
      ok "$label"
    else
      warn "Could not install ${label}. ${PREREQ_FIX[$i]}"
      [ "$kind" != "necessary" ] || necessary_left=1
    fi
  done
  [ "$necessary_left" -eq 0 ] || die "A necessary item is missing. Do the steps above, and run the setup again."
  # A test can stop here, after the prerequisites.
  [ -z "${HS_PREREQS_ONLY:-}" ] || { ok "Prerequisites done."; exit 0; }
}

# ---------- items that more than one script uses

is_root() { [ "$(id -u)" -eq 0 ]; }

# sudo_ready exits 0 if this account can run commands as root.
sudo_ready() { is_root || have sudo; }
install_sudo() { is_root && apt_install sudo; }

# locale_ready exits 0 if the locale that this session asks for exists. An SSH
# client can send a locale, for example en_US.UTF-8, that a minimal server lacks.
wanted_locale() { printf '%s' "${LC_ALL:-${LANG:-}}"; }
locale_ready() {
  local want norm
  want="$(wanted_locale)"
  case "$want" in "" | C | C.* | POSIX) return 0 ;; esac
  norm="$(printf '%s' "$want" | tr 'A-Z' 'a-z' | sed 's/utf-8/utf8/')"
  locale -a 2>/dev/null | tr 'A-Z' 'a-z' | grep -qx "$norm"
}
install_locale() {
  local want
  want="$(wanted_locale)"
  apt_install locales || return 1
  run_root sed -i "s/^# *\(${want//./\\.}[[:space:]]\)/\1/" /etc/locale.gen
  grep -q "^${want//./\\.}[[:space:]]" /etc/locale.gen || printf '%s UTF-8\n' "$want" | run_root tee -a /etc/locale.gen >/dev/null
  run_root locale-gen >/dev/null
}

# servers_ready exits 0 if the client connects to each server in SERVERS with
# no password. The setup never changes the server to make this work.
servers_ready() {
  local server
  for server in "${SERVERS[@]}"; do
    ssh -o BatchMode=yes -o ConnectTimeout=5 -- "$server" true 2>/dev/null || return 1
  done
}
ssh_fix() { printf 'The server must accept SSH, and %s needs an SSH name and key. See docs/ssh.md.' "$1"; }

# ---------- macOS items

is_admin() { id -Gn | tr ' ' '\n' | grep -qx admin; }

# brew_writable exits 0 if this account can write to the Homebrew folder. On a
# Mac with two accounts, Homebrew can belong to the other account.
brew_writable() { have brew && [ -w "$(brew --prefix)" ] && [ -w "$(brew --prefix)/Cellar" ]; }

# python_ready exits 0 if python3 is Python 3.11 or later. hopen needs it to
# read a herdspace.toml list. Without the Command Line Tools, /usr/bin/python3
# only opens an install window, so the check does not run it then.
python_ready() {
  local py
  py="$(command -v python3)" || return 1
  if [ "$py" = /usr/bin/python3 ] && ! xcode-select -p >/dev/null 2>&1; then
    return 1
  fi
  "$py" -c 'import sys; sys.exit(sys.version_info < (3, 11))' 2>/dev/null
}
install_python() { brew install python; }

ghostty_ready() { [ -d /Applications/Ghostty.app ] || { have brew && brew list --cask ghostty >/dev/null 2>&1; }; }
# install_ghostty_app installs the Ghostty app. Homebrew can write to
# /Applications only from an admin account.
install_ghostty_app() { is_admin && brew install --cask ghostty; }
