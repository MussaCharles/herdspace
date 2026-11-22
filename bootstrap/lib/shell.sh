#!/usr/bin/env bash
# Sets up zsh, Oh My Zsh, Powerlevel10k, and the prompt color.

OMZ_DIR="${HOME}/.oh-my-zsh"
OMZ_CUSTOM="${OMZ_DIR}/custom"

pin_ready() { [ -d "$1/.git" ] && [ "$(git -C "$1" rev-parse HEAD 2>/dev/null)" = "$2" ]; }

shell_pins_ready() {
  have git || return 1
  pin_ready "$OMZ_DIR" "$OHMYZSH_REF" &&
    pin_ready "${OMZ_CUSTOM}/themes/powerlevel10k" "$POWERLEVEL10K_REF" &&
    pin_ready "${OMZ_CUSTOM}/plugins/zsh-autosuggestions" "$ZSH_AUTOSUGGESTIONS_REF" &&
    pin_ready "${OMZ_CUSTOM}/plugins/zsh-syntax-highlighting" "$ZSH_SYNTAX_HIGHLIGHTING_REF"
}

install_shell_pins() {
  git_pin https://github.com/ohmyzsh/ohmyzsh.git "$OMZ_DIR" "$OHMYZSH_REF"
  git_pin https://github.com/romkatv/powerlevel10k.git "${OMZ_CUSTOM}/themes/powerlevel10k" "$POWERLEVEL10K_REF"
  git_pin https://github.com/zsh-users/zsh-autosuggestions.git "${OMZ_CUSTOM}/plugins/zsh-autosuggestions" "$ZSH_AUTOSUGGESTIONS_REF"
  git_pin https://github.com/zsh-users/zsh-syntax-highlighting.git "${OMZ_CUSTOM}/plugins/zsh-syntax-highlighting" "$ZSH_SYNTAX_HIGHLIGHTING_REF"
  # Oh My Zsh warns at each start if another account can write to its folders.
  chmod -R go-w "$OMZ_DIR"
}

# setup_shell ROLE. ROLE is "client" or "server". The folder segment of the
# prompt has a different color on each, so a shell shows where it runs.
# HS_ROLE=both (from bootstrap.sh both) replaces ROLE: one machine is both.
setup_shell() {
  local role="${HS_ROLE:-$1}" color tmp
  case "$role" in
    client | both) color="${PROMPT_COLOR_CLIENT:-166}" ;;
    *) color="${PROMPT_COLOR_SERVER:-30}" ;;
  esac
  run_part "Oh My Zsh and Powerlevel10k" shell_pins_ready install_shell_pins
  install_file "${REPO_ROOT}/config/shell/zshrc.zsh" "${HOME}/.config/herdspace/zshrc.zsh"
  install_file "${REPO_ROOT}/config/shell/p10k.zsh" "${HOME}/.p10k.zsh"
  install_file "${REPO_ROOT}/config/shell/extras.zsh" "${HOME}/.config/herdspace/extras.zsh"
  install_file "${REPO_ROOT}/bin/herdspace" "${HOME}/.local/bin/herdspace" 755
  tmp="$(mktemp)"
  printf 'export BOOTSTRAP_ROLE=%s\nexport BOOTSTRAP_PROMPT_COLOR=%s\n' "$role" "$color" >"$tmp"
  install_file "$tmp" "${HOME}/.config/herdspace/env.zsh"
  rm -f "$tmp"
  setup_zshrc
}

# The block that loads the herdspace shell from ~/.zshrc.
# shellcheck disable=SC2016 # The lines are text for zsh.
ZSHRC_BLOCK='if [[ -r "$HOME/.config/herdspace/zshrc.zsh" ]]; then
  source "$HOME/.config/herdspace/zshrc.zsh"
fi'

# zshrc_template prints a new ~/.zshrc: the block, then room for your own lines.
zshrc_template() {
  printf '# Your zsh configuration. herdspace changes only the marked block, and it\n'
  printf '# never replaces this file.\n'
  printf '# >>> herdspace >>>\n%s\n# <<< herdspace <<<\n\n' "$ZSHRC_BLOCK"
  printf '# Put your own lines below. They load after herdspace, so they can change\n'
  printf '# what it sets.\n'
}

# old_herdspace_zshrc FILE exits 0 if FILE is the ~/.zshrc of an older herdspace,
# which owned the whole file.
old_herdspace_zshrc() {
  head -n 1 "$1" 2>/dev/null | grep -Eqx '# Managed by herd(space|r-bootstrap)\. A new run replaces this file\.'
}

# move_to_template FILE OWN writes the new ~/.zshrc in place of the file of an
# older herdspace, after a backup. OWN, your own lines, go below the block,
# each one behind "# ", so that nothing runs before you look at it.
move_to_template() {
  local file="$1" own="$2" tmp
  tmp="$(mktemp)"
  zshrc_template >"$tmp"
  if [ -n "$own" ]; then
    {
      printf '\n# Your own lines from the old file, copied by the herdspace setup on %s.\n' "$(date +%Y-%m-%d)"
      printf '# The full old file is %s.bak-%s. Each line starts with "# ".\n' "$(short_home "$file")" "$STAMP"
      printf '# Remove it from each line that you want, and keep if/fi blocks complete.\n'
      printf '%s\n' "$own" | sed 's/^/# /'
    } >>"$tmp"
  fi
  write_file "$tmp" "$file" 644
  rm -f "$tmp"
}

# ask_zshrc FILE asks what to do with your own ~/.zshrc. It sets ZSHRC_ANSWER to
# full, extras, or keep. The default is full, unless the file loads Oh My Zsh.
ask_zshrc() {
  local file="$1" answer default=f
  ! grep -q 'oh-my-zsh\.sh' "$file" || default=e
  while true; do
    printf '\n  %s%s~/.zshrc is your own file. herdspace never replaces it.%s\n' "$C_BOLD" "$C_CYAN" "$C_RESET"
    printf '  It can add a marked block. Your own lines stay as they are.\n\n'
    ui_key f "Add a block at the top that loads the full herdspace shell" "$([ "$default" = f ] && echo '(Enter)')"
    ui_key e "Add a block at the end that loads only the shell extras" "$([ "$default" = e ] && echo '(Enter)')"
    ui_key k "Keep your file with no change"
    ui_key d "Show what each block does"
    printf '\n  Your choice: '
    IFS= read -r answer || answer="k"
    [ -n "$answer" ] || answer="$default"
    case "$answer" in
      f) ZSHRC_ANSWER="full"; return 0 ;;
      e) ZSHRC_ANSWER="extras"; return 0 ;;
      k) ZSHRC_ANSWER="keep"; return 0 ;;
      d)
        printf '\n  f: the block loads ~/.config/herdspace/zshrc.zsh: the prompt, Oh My Zsh, and the\n'
        printf '     extras. Your lines come after it, so they can change what it sets. Do not\n'
        printf '     choose f if your file loads Oh My Zsh or another prompt already.\n'
        printf '  e: the block loads ~/.config/herdspace/extras.zsh: the fzf keys, zoxide, ff, fif,\n'
        printf '     the completion of hopen, and eza and bat for ls and cat. The extras add and\n'
        printf '     never replace: an alias, a variable, or a key that you set stays yours.\n'
        ;;
    esac
  done
}

# setup_zshrc makes ~/.zshrc load the herdspace shell from a marked block.
# herdspace never replaces a ~/.zshrc of yours. It replaces only the file of
# an older herdspace, after a backup, and it keeps your own lines in it.
setup_zshrc() {
  local file="${HOME}/.zshrc" own tmp
  if [ ! -e "$file" ]; then
    if [ "$MODE" = "check" ]; then
      note_todo "${file} is missing"
    else
      tmp="$(mktemp)"
      zshrc_template >"$tmp"
      write_file "$tmp" "$file" 644
      rm -f "$tmp"
    fi
    return 0
  fi
  if grep -qxF '# >>> herdspace >>>' "$file"; then
    ensure_block "$file" "herdspace" "$ZSHRC_BLOCK"
    return 0
  fi
  if old_herdspace_zshrc "$file"; then
    own="$(own_lines "${REPO_ROOT}/config/shell/zshrc.zsh" "$file")"
    if [ "$MODE" = "check" ]; then
      note_todo "${file} is the file of an older herdspace. A run gives it the new layout."
      return 0
    fi
    move_to_template "$file" "$own"
    info "Your ~/.zshrc was the file of an older herdspace. It is now your file, with a marked block that loads the herdspace shell."
    [ -z "$own" ] || info "Your own lines from the old file are at its end, each behind \"# \". Review them there."
    return 0
  fi
  if grep -qxF '# >>> herdspace extras >>>' "$file"; then
    extras_block "$file"
    return 0
  fi
  ZSHRC_ANSWER="keep"
  case "$MODE" in
    check) info "${file} is your own file, with no block that loads herdspace."; return 0 ;;
    replace) ZSHRC_ANSWER="extras" ;;
    ask) [ ! -t 0 ] || ask_zshrc "$file" ;;
  esac
  # shellcheck disable=SC2034 # common.sh reads ZSHRC_KEPT_NO_EXTRAS at the end of the run.
  case "$ZSHRC_ANSWER" in
    full) ensure_block "$file" "herdspace" "$ZSHRC_BLOCK" top; ok "Added a block that loads the herdspace shell at the top of your ~/.zshrc." ;;
    extras) extras_block "$file"; ok "Added a block that loads the herdspace shell extras at the end of your ~/.zshrc." ;;
    *) ZSHRC_KEPT_NO_EXTRAS=1 ;;
  esac
}

# setup_zprofile writes the login block. A server also checks for a new Herdr.
setup_zprofile() {
  local role="${HS_ROLE:-$1}" text
  # shellcheck disable=SC2016 # These lines are text for zsh.
  text='[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac'
  if [ "$role" != "client" ]; then
    # shellcheck disable=SC2016
    text="${text}"'
if [[ -n "$SSH_CONNECTION" && -t 1 && -x "$HOME/.local/bin/herdr-update-check" ]]; then
  "$HOME/.local/bin/herdr-update-check"
fi'
  fi
  ensure_block "${HOME}/.zprofile" "herdspace" "$text"
}

# ---------- exports from the bash files
# After the login shell changes to zsh, an export that only ~/.bashrc or
# ~/.bash_profile has is missing in zsh, in each Herdr pane, and in each shell
# of an agent. move_bash_exports offers to move the plain one-line exports to a
# marked block in ~/.zshenv, which zsh reads for every shell. It never prints a
# value. It backs up each file first, tests the result, and puts the backups
# back if a test fails. Steps: docs/setup.md#exports-from-your-bash-files
BASH_ENV_BLOCK="herdspace bash env"
BASH_ENV_FILES=".bashrc .bash_profile"

# bash_export_scan FILE prints one line for each export of FILE:
# "move<TAB>LINE<TAB>NAME" for a line that can move, and "keep<TAB>-<TAB>NAME"
# for an export that the person must move by hand.
bash_export_scan() {
  python3 -I - "$1" <<'PY'
import re, sys

lines = open(sys.argv[1], encoding="utf-8", errors="surrogateescape").read().split("\n")
export = re.compile(r"^export ([A-Za-z_][A-Za-z0-9_]*)=(.*)$")
any_export = re.compile(r"^\s*(?:export|declare -x)\s+([A-Za-z_][A-Za-z0-9_]*)=")
opens = re.compile(r"^\s*(if|case|for|while|until|select)\b")
closes = re.compile(r"^\s*(fi|esac|done)\b")
function = re.compile(r"^\s*(function\s+\S+|[A-Za-z_][A-Za-z0-9_:-]*\s*\(\s*\))\s*\{?\s*$")
allowed = {"HOME", "PATH", "USER"}

def strip_quotes(text):
    """Returns the text with each quoted part removed, or None if a quote stays open."""
    out, i, quote = [], 0, None
    while i < len(text):
        c = text[i]
        if quote == "'":
            if c == "'":
                quote = None
        elif quote == '"':
            if c == "\\":
                i += 1
            elif c == '"':
                quote = None
        elif c == "\\":
            out.append(text[i:i + 2])
            i += 1
        elif c in "'\"":
            quote = c
        else:
            out.append(c)
        i += 1
    return None if quote else "".join(out)

depth, open_quote, moved = 0, False, set()
for number, line in enumerate(lines, 1):
    continued = number > 1 and lines[number - 2].endswith("\\")
    if open_quote or continued:
        # The line belongs to the line before it.
        rest = strip_quotes(("'" if open_quote else "") + line)
        open_quote = rest is None
        match = None
    else:
        match = export.match(line)
        rest = strip_quotes(line)
        open_quote = rest is None
    name = None
    if match:
        name, value = match.group(1), match.group(2)
        bare = strip_quotes(value)
        refs = set(re.findall(r"\$\{?([A-Za-z_][A-Za-z0-9_]*)", value))
        good = (
            depth == 0
            and bare is not None
            and not line.endswith("\\")
            and re.fullmatch(r"[^\s;&|<>`()]*(\s+#.*)?", bare) is not None
            and "$(" not in value and "`" not in value and "${!" not in value
            and refs <= (allowed | moved)
        )
        print(("move" if good else "keep") + f"\t{number if good else '-'}\t{name}")
        if good:
            moved.add(name)
    elif any_export.match(line):
        print(f"keep\t-\t{any_export.match(line).group(1)}")
    code = (rest or "").split("#", 1)[0]
    if opens.match(code) or function.match(code) or code.rstrip().endswith("{"):
        depth += 1
    if closes.match(code) or code.strip().startswith("}"):
        depth = max(0, depth - 1)
PY
}

# bash_values SHELL FILE NAMES... prints NAME=<hash of the value> for each
# name, after SHELL loads FILE in a clean environment. No value is printed.
bash_values() {
  local shell="$1" file="$2"
  shift 2
  local script='. "$1"; shift; for n in "$@"; do printf "%s=" "$n"; eval "printf %s \"\${$n}\"" | { sha256sum 2>/dev/null || shasum -a 256; } | cut -c1-64; done'
  case "$shell" in
    bash) env -i HOME="$HOME" USER="${USER:-}" PATH=/usr/bin:/bin:/usr/sbin bash --norc --noprofile -c "$script" _ "$file" "$@" ;;
    zsh) env -i HOME="$HOME" USER="${USER:-}" PATH=/usr/bin:/bin:/usr/sbin zsh -f -c "$script" _ "$file" "$@" ;;
  esac 2>/dev/null
}

# ask_bash_exports NAMES asks whether to move the exports. It sets BASH_ENV_ANSWER.
ask_bash_exports() {
  local answer
  printf '\n  %s%sExports in your bash files%s\n\n' "$C_BOLD" "$C_CYAN" "$C_RESET"
  printf '  zsh is your login shell, and it does not read your bash files. These\n'
  printf '  variables are only in a bash file, so zsh, the Herdr panes, and the agents\n'
  printf '  do not have them:\n\n'
  printf '    %s\n' "$@"
  printf '\n  The setup can move these lines to ~/.zshenv, which zsh reads for every shell.\n'
  printf '  It backs up each file first, and shows no value.\n\n'
  while true; do
    ui_key y "Move the lines to ~/.zshenv"
    ui_key n "Change nothing" "(Enter)"
    printf '\n  Your choice: '
    IFS= read -r answer || answer=""
    case "$answer" in
      y | Y) BASH_ENV_ANSWER="move"; return 0 ;;
      n | N | "") BASH_ENV_ANSWER="keep"; return 0 ;;
    esac
  done
}

move_bash_exports() {
  local f file names="" keep="" lines tmp new_lines="" old_block="" zshenv="${HOME}/.zshenv" had_zshenv=0
  local declined="${STATE_DIR}/bash-exports-declined" key backups="" failed=""
  have python3 && have zsh && have bash || return 0
  case "$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7)" in */zsh) ;; *) return 0 ;; esac
  for f in $BASH_ENV_FILES; do
    file="${HOME}/${f}"
    [ -f "$file" ] && [ ! -L "$file" ] || continue
    while IFS="$(printf '\t')" read -r kind _ name; do
      if [ "$kind" = "move" ]; then names="${names} ${name}"; else keep="${keep} ${name}"; fi
    done < <(bash_export_scan "$file")
  done
  # shellcheck disable=SC2086 # One word for each name.
  [ -n "$names" ] || { [ -z "$keep" ] || warn "Move these exports from your bash files to ~/.zshenv by hand:${keep}."; return 0; }
  key="$(printf '%s' "$names" | { sha256sum 2>/dev/null || shasum -a 256; } | cut -c1-64)"
  BASH_ENV_ANSWER="keep"
  if [ "$MODE" = "ask" ] && [ -t 0 ] && [ "$(cat "$declined" 2>/dev/null)" != "$key" ]; then
    # shellcheck disable=SC2086 # One word for each name.
    ask_bash_exports $names
  fi
  if [ "$BASH_ENV_ANSWER" != "move" ]; then
    [ "$MODE" = "ask" ] && [ -t 0 ] && { mkdir -p "$STATE_DIR"; printf '%s' "$key" >"$declined"; }
    info "Your bash files export variables that zsh does not have:${names}. See ${HS_DOC_BASE}/docs/setup.md#exports-from-your-bash-files"
    return 0
  fi

  # Back up each file. The backups hold the values, so only you can read them.
  [ -f "$zshenv" ] && had_zshenv=1
  for f in $BASH_ENV_FILES .zshenv; do
    file="${HOME}/${f}"
    [ -f "$file" ] || continue
    cp -p "$file" "${file}.bak-${STAMP}"
    chmod 600 "${file}.bak-${STAMP}"
    backups="${backups} ${file}"
  done

  # The lines that move, in the order of the files.
  tmp="$(mktemp)"
  chmod 600 "$tmp"
  for f in $BASH_ENV_FILES; do
    file="${HOME}/${f}"
    [ -f "$file" ] && [ ! -L "$file" ] || continue
    lines="$(bash_export_scan "$file" | awk -F '\t' '$1 == "move" {print $2}' | tr '\n' ' ')"
    [ -n "$lines" ] || continue
    awk -v want=" ${lines}" 'index(want, " " NR " ") {print}' "$file" >>"$tmp"
    awk -v want=" ${lines}" -v z="~/.zshenv" '
      index(want, " " NR " ") { split($0, p, /[ =]/); print "# herdspace moved the export of " p[2] " to " z "."; next }
      { print }' "$file" >"${file}.hs-new"
    cat "${file}.hs-new" >"$file"
    rm -f "${file}.hs-new"
  done
  old_block="$(awk -v b="# >>> ${BASH_ENV_BLOCK} >>>" -v e="# <<< ${BASH_ENV_BLOCK} <<<" '$0 == e {on = 0} on {print} $0 == b {on = 1}' "$zshenv" 2>/dev/null)"
  new_lines="$(cat "$tmp")"
  [ "$had_zshenv" -eq 1 ] || : >"$zshenv"
  chmod 600 "$zshenv"
  ensure_block "$zshenv" "$BASH_ENV_BLOCK" "${old_block:+${old_block}
}${new_lines}"

  # The tests. Each moved variable must have the same value in zsh as in bash.
  # shellcheck disable=SC2086 # One word for each name.
  if [ "$(bash_values bash "$tmp" $names)" != "$(bash_values zsh "$zshenv" $names)" ]; then failed="a value differs in zsh"; fi
  for f in $BASH_ENV_FILES; do
    [ ! -f "${HOME}/${f}" ] || bash -n "${HOME}/${f}" 2>/dev/null || failed="${failed:+${failed}, }~/${f} has a syntax error"
  done
  zsh -n "$zshenv" 2>/dev/null || failed="${failed:+${failed}, }~/.zshenv has a syntax error"
  rm -f "$tmp"
  if [ -n "$failed" ]; then
    # The backups hold the values, so no copy stays after the files are back.
    for file in $backups; do cat "${file}.bak-${STAMP}" >"$file" && rm -f "${file}.bak-${STAMP}"; done
    [ "$had_zshenv" -eq 1 ] || rm -f "$zshenv"
    warn "The test after the move failed (${failed}), so the setup put your files back. Nothing changed."
    return 0
  fi
  for file in $backups; do
    BACKUP_LIST="${BACKUP_LIST}${file}
"
  done
  ok "Moved the exports of${names} to ~/.zshenv. Backups:$(for file in $backups; do printf ' %s' "$(short_home "${file}.bak-${STAMP}")"; done)."
  [ -z "$keep" ] || warn "Move these exports by hand:${keep}."
  info "zsh is your login shell now. Put new variables in ~/.zshenv."
  CHANGED=$((CHANGED + 1))
}
