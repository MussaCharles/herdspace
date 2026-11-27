# shellcheck shell=bash
# herdspace uninstall, which removes what the setup wrote.
# bin/herdspace loads this file. It defines functions and variables, and runs nothing.

# herdspace uninstall removes what the setup wrote, and nothing else. The
# manifest, ~/.local/share/herdspace/manifest.tsv, holds the hash of each file
# that the setup wrote. A file with that hash has no change of yours, so it goes.
# A file with another hash is yours now, so it stays. The marked blocks go from
# the shell and Ghostty files, and your own lines stay.

# These lines are in a new ~/.zshrc and a new Ghostty file, outside the blocks.
# A file with only these lines and blanks holds nothing of yours.
TEMPLATE_LINES='# Your zsh configuration. herdspace changes only the marked block, and it
# never replaces this file.
# Put your own lines below. They load after herdspace, so they can change
# what it sets.
# Ghostty configuration. herdspace changes only its marked blocks, and it
# never replaces this file. Ghostty uses the last value of each setting, so
# a line of yours below the blocks wins.
# Put your own lines below.'
# The files with marked blocks, and the names of the blocks. The block "herdspace
# bash env" is not in the list: it holds your exports, so it always stays.
BLOCK_FILES=".zshrc .zprofile .config/ghostty/config.ghostty"
BLOCK_NAMES="herdspace|herdspace extras|herdspace keys|herdspace ssh|herdspace appearance"
# Folders that other programs share. The uninstall never removes them.
SHARED_DIRS=".config .local .local/bin .local/lib .local/share .cache Library Library/LaunchAgents Library/Application_Support .config/systemd .config/systemd/user"
UN_CHECK=1
UN_KEPT=""
UN_GONE=""
UN_DIRS=""
UN_SELF_KEEP=0
# UN_SELF_LIBS holds the modules of this command. They go last, with the command.
UN_SELF_LIBS=""
UN_UNIT="${HOME}/.config/systemd/user/herdr.service"
UN_PLIST="${HOME}/Library/LaunchAgents/local.herdr.server.plist"

# un_home PATH prints PATH with ~ for the home folder.
un_home() { case "$1" in "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;; *) printf '%s' "$1" ;; esac; }

# un_say VERB TEXT prints one line of the plan, or of the result. In a check,
# the verb is the plain form ("remove"), and in an uninstall it is the past ("removed").
un_say() {
  local verb="$1"
  [ "$UN_CHECK" -eq 1 ] || case "$verb" in
    remove) verb="removed" ;;
    edit) verb="edited" ;;
    restore) verb="restored" ;;
    disable) verb="disabled" ;;
  esac
  printf '  %-9s %s\n' "$verb" "$2"
}

# un_manifest_hash FILE prints the hash that the setup recorded for FILE.
un_manifest_hash() { awk -F '\t' -v d="$1" '$1 == d {print $2}' "${STATE}/manifest.tsv" 2>/dev/null | tail -n 1; }

# un_unchanged FILE succeeds if FILE is a plain file with the recorded hash.
un_unchanged() {
  local recorded
  [ -f "$1" ] && [ ! -L "$1" ] || return 1
  recorded="$(un_manifest_hash "$1")"
  [ -n "$recorded" ] && [ "$recorded" = "$(sha_of "$1")" ]
}

un_is_gone() { printf '%s' "$UN_GONE" | grep -Fxq -- "$1"; }

# un_drop FILE LABEL removes FILE, or in a check, says that it would.
un_drop() {
  UN_GONE="${UN_GONE}$1
"
  UN_DIRS="${UN_DIRS}$(dirname "$1")
"
  [ "$UN_CHECK" -eq 1 ] || rm -f "$1"
  un_say remove "$(un_home "$1")${2:+ ($2)}"
}

# un_without FILE NAME... prints FILE with each marked block removed. A blank
# line that follows a block at the top of the file goes with it.
un_without() {
  local file="$1" name tmp
  shift
  tmp="$(mktemp)"
  cat "$file" >"$tmp"
  for name in "$@"; do
    awk -v begin="# >>> ${name} >>>" -v end="# <<< ${name} <<<" '
      $0 == begin { skip = 1; top = (NR == 1); next }
      skip && $0 == end { skip = 0; drop = top; top = 0; next }
      skip { next }
      drop && $0 ~ /^[ \t]*$/ { drop = 0; next }
      { drop = 0; print }' "$tmp" >"${tmp}.next"
    cat "${tmp}.next" >"$tmp"
    rm -f "${tmp}.next"
  done
  cat "$tmp"
  rm -f "$tmp"
}

# un_only_template FILE succeeds if FILE has no line besides blanks and the
# lines of the templates.
un_only_template() {
  local left
  left="$(grep -v '^[[:space:]]*$' "$1" | grep -vxF -f <(printf '%s\n' "$TEMPLATE_LINES") || true)"
  [ -z "$left" ]
}

# un_service_off stops the login service from starting again. It never stops a
# running server, because a stop closes every pane.
un_service_off() {
  if un_unchanged "$UN_UNIT"; then
    if [ "$UN_CHECK" -eq 1 ]; then
      un_say disable "the Herdr login service (a running server keeps running)"
    else
      if command -v systemctl >/dev/null 2>&1; then systemctl --user disable herdr.service >/dev/null 2>&1 || true; fi
      un_say disable "the Herdr login service (a running server keeps running)"
    fi
  fi
  if un_unchanged "$UN_PLIST"; then
    printf '  %-9s %s\n' note "The LaunchAgent stops loading at your next login. A running server keeps running."
  fi
}

# un_files removes each file of the manifest that no person changed.
un_files() {
  local file self="${HOME}/.local/bin/herdspace"
  if [ ! -f "${STATE}/manifest.tsv" ]; then
    printf '  There is no manifest of installed files, so no file is removed.\n'
    return 0
  fi
  while IFS=$'\t' read -r file _; do
    case "$file" in "$HOME"/*) ;; *) continue ;; esac
    { [ -e "$file" ] || [ -L "$file" ]; } || continue
    if un_unchanged "$file"; then
      # This command and its modules go last, because the uninstall runs from them.
      case "$file" in
        "$self") ;;
        "${HOME}/.local/lib/herdspace/"*) UN_SELF_LIBS="${UN_SELF_LIBS}${file}
" ;;
        *) un_drop "$file" ;;
      esac
    else
      UN_KEPT="${UN_KEPT}${file}
"
      [ "$file" != "$self" ] || UN_SELF_KEEP=1
      printf '  %-9s %s (you changed it)\n' keep "$(un_home "$file")"
    fi
  done < <(awk -F '\t' 'NF >= 2 {last[$1] = $2} END {for (f in last) print f "\t" last[f]}' "${STATE}/manifest.tsv" | sort)
}

# un_blocks removes the marked blocks from the files of a person.
un_blocks() {
  local f file name had tmp ifs="$IFS"
  for f in $BLOCK_FILES; do
    file="${HOME}/${f}"
    { [ -f "$file" ] && [ ! -L "$file" ]; } || continue
    ! un_is_gone "$file" || continue
    had=""
    IFS='|'
    for name in $BLOCK_NAMES; do
      if grep -qxF -- "# >>> ${name} >>>" "$file"; then had="${had}${had:+|}${name}"; fi
    done
    [ -n "$had" ] || { IFS="$ifs"; continue; }
    # shellcheck disable=SC2086 # One word for each block name.
    set -- $had
    IFS="$ifs"
    tmp="$(mktemp)"
    un_without "$file" "$@" >"$tmp"
    if [ ! -s "$tmp" ] || un_only_template "$tmp"; then
      un_drop "$file" "it has only the blocks of herdspace"
    else
      [ "$UN_CHECK" -eq 1 ] || cat "$tmp" >"$file"
      un_say edit "$(un_home "$file"): the herdspace blocks go, your lines stay"
    fi
    rm -f "$tmp"
  done
  if [ -f "${HOME}/.zshenv" ] && grep -qxF '# >>> herdspace bash env >>>' "${HOME}/.zshenv"; then
    printf '  %-9s %s\n' keep "$(un_home "${HOME}/.zshenv"): the block with the exports that the setup moved from your bash files"
  fi
}

# un_mission_control gives the Ctrl arrow shortcuts back to Mission Control, if
# the setup turned them off. The file done/mission-control records that.
un_mission_control() {
  local mark="${STATE}/done/mission-control" pair
  local activate="${ACTIVATE_SETTINGS:-/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings}"
  [ -f "$mark" ] || return 0
  if [ "$UN_CHECK" -eq 0 ]; then
    for pair in "32 126" "33 125" "79 123" "81 124"; do
      # shellcheck disable=SC2086 # One word for the shortcut and one for the key.
      set -- $pair
      defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$1" \
        "<dict><key>enabled</key><true/><key>value</key><dict><key>type</key><string>standard</string><key>parameters</key><array><integer>65535</integer><integer>$2</integer><integer>8650752</integer></array></dict></dict>"
    done
    [ ! -x "$activate" ] || "$activate" -u >/dev/null 2>&1 || true
    rm -f "$mark"
  fi
  un_say restore "the Ctrl arrow shortcuts of Mission Control (log out and in if a key does not work)"
}

# un_generated removes what herdspace makes by itself: the plugins and the data
# of its Neovim, and two files that Neovim writes. The folder with the Neovim
# files stays if it holds a file of yours.
un_generated() {
  local nvim="${HOME}/.config/herdspace-nvim" d f other=0
  if [ -d "$nvim" ]; then
    while IFS= read -r f; do
      case "$f" in */lazy-lock.json | */lazyvim.json) continue ;; esac
      un_is_gone "$f" || other=1
    done < <(find "$nvim" -type f -o -type l 2>/dev/null)
    if [ "$other" -eq 0 ]; then
      for f in "$nvim/lazy-lock.json" "$nvim/lazyvim.json"; do
        [ ! -f "$f" ] || un_drop "$f"
      done
    fi
  fi
  for d in "${HOME}/.local/share/herdspace-nvim" "${HOME}/.local/state/herdspace-nvim" "${XDG_CACHE_HOME:-$HOME/.cache}/herdspace-nvim"; do
    [ -d "$d" ] || continue
    [ "$UN_CHECK" -eq 1 ] || rm -rf "$d"
    un_say remove "$(un_home "$d")/ (the data of the herdspace Neovim)"
  done
}

# un_prune removes each empty folder that held a removed file, up to your home
# folder and the folders that other programs share.
un_prune() {
  local dir stop
  [ "$UN_CHECK" -eq 0 ] || return 0
  while IFS= read -r dir; do
    [ -n "$dir" ] || continue
    while [ "$dir" != "$HOME" ] && [ "$dir" != "/" ] && [ -d "$dir" ]; do
      for stop in $SHARED_DIRS; do
        [ "$dir" != "${HOME}/${stop//_/ }" ] || break 2
      done
      rmdir "$dir" 2>/dev/null || break
      dir="$(dirname "$dir")"
    done
  done <<<"$UN_DIRS"
}

# un_state removes the choices, the cache, the state, and then this command.
un_state() {
  local conf="${HOME}/.config/herdspace" self="${HOME}/.local/bin/herdspace" file
  if [ -d "$conf" ]; then
    if [ "$UN_CHECK" -eq 0 ]; then
      rm -f "$conf/keys" "$conf/look" "$conf/editor"
      if rmdir "$conf" 2>/dev/null; then
        un_say remove "$(un_home "$conf")/"
      else
        printf '  %-9s %s\n' keep "$(un_home "$conf")/ (it holds a backup or a file of yours)"
      fi
    else
      un_say remove "$(un_home "$conf")/ (your choice of keys, look, and editor, and the folder if it is empty)"
    fi
  fi
  if [ -d "$CACHE" ]; then
    [ "$UN_CHECK" -eq 1 ] || rm -rf "$CACHE"
    un_say remove "$(un_home "$CACHE")/"
  fi
  if [ -d "$STATE" ]; then
    [ "$UN_CHECK" -eq 1 ] || rm -rf "$STATE"
    un_say remove "$(un_home "$STATE")/ (the manifest, the saved setup, and the downloaded releases)"
  fi
  if [ "$UN_SELF_KEEP" -eq 0 ]; then
    printf '%s' "$UN_SELF_LIBS" | while IFS= read -r file; do [ -z "$file" ] || un_drop "$file"; done
    [ "$UN_CHECK" -eq 1 ] || rmdir "${HOME}/.local/lib/herdspace" 2>/dev/null || true
  fi
  if [ -e "$self" ] && [ "$UN_SELF_KEEP" -eq 0 ]; then
    [ "$UN_CHECK" -eq 1 ] || rm -f "$self"
    un_say remove "$(un_home "$self") (this command)"
  fi
}

# un_stays says what the uninstall leaves, and how to remove it by hand.
un_stays() {
  printf '\n  What stays:\n'
  printf '    Your projects, your Herdr sessions, and each file of yours. A running Herdr server keeps running.\n'
  printf '    Herdr, and the tools of the setup (zsh, Neovim, lazygit, eza, zoxide, fzf, bat, fd, delta).\n'
  if [ "$(uname -s)" = "Darwin" ]; then
    printf '      Remove a package by hand: brew uninstall <name>. For Ghostty: brew uninstall --cask ghostty\n'
  else
    printf '      Remove a package by hand: sudo apt-get remove <name>. For a tool in ~/.local/bin: rm ~/.local/bin/<name>\n'
    printf '      Remove the Neovim of the setup: rm -r ~/.local/opt/neovim. Turn off the linger of the login service: loginctl disable-linger\n'
  fi
  printf '    Your login shell. To go back to bash: chsh -s /bin/bash\n'
  printf '    Oh My Zsh and its plugins. Remove them by hand: rm -rf ~/.oh-my-zsh\n'
  printf '    The backups of the setup, named *.bak-<date>. Delete them when you do not need them.\n'
  printf '    The integrations and the plugin of Herdr. See: herdr integration --help and herdr plugin --help\n'
}

cmd_uninstall() {
  local a answer="" yes=0 file
  UN_CHECK=0
  for a in "$@"; do
    case "$a" in
      --check) UN_CHECK=1 ;;
      --yes | -y) yes=1 ;;
      *) printf "herdspace: 'uninstall' does not know '%s'. Use --check or --yes.\n" "$a" >&2; exit 2 ;;
    esac
  done
  [ -d "$STATE" ] || [ -e "${HOME}/.local/bin/herdspace" ] || die "herdspace is not set up here. ${STATE} does not exist."
  if [ "$UN_CHECK" -eq 1 ]; then
    printf '  This is a check. Nothing changes.\n\n'
  else
    printf '  This removes the files that the herdspace setup wrote, and each marked block.\n'
    printf '  A file that you changed stays. To see the list first, run: herdspace uninstall --check\n'
    if [ "$yes" -eq 0 ]; then
      [ -t 0 ] || die "There is no terminal to ask. Run: herdspace uninstall --yes"
      printf '\n  Uninstall herdspace? [y/N] '
      IFS= read -r answer || answer=""
      case "$answer" in y | Y | yes) ;; *) printf '  Nothing changed.\n'; return 0 ;; esac
    fi
    printf '\n'
  fi
  un_service_off
  un_files
  un_blocks
  un_mission_control
  un_generated
  un_prune
  [ "$UN_CHECK" -eq 1 ] || ! command -v systemctl >/dev/null 2>&1 || systemctl --user daemon-reload >/dev/null 2>&1 || true
  un_state
  un_stays
  if [ "$UN_CHECK" -eq 1 ]; then
    printf '\n  Nothing changed. To uninstall, run: herdspace uninstall\n'
  elif [ -n "$UN_KEPT" ]; then
    printf '\n  Done. These files stay, because you changed them:\n'
    printf '%s' "$UN_KEPT" | while IFS= read -r file; do [ -z "$file" ] || printf '    %s\n' "$(un_home "$file")"; done
  else
    printf '\n  Done. herdspace is removed.\n'
  fi
}
