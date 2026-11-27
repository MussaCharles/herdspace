# shellcheck shell=bash
# The parts of a run, the summary table, and the next steps.
# bootstrap/lib/common.sh loads this file. It works with the bash 3.2 that macOS ships.

# run_part LABEL CHECK APPLY [ARG...] runs APPLY only if CHECK fails.
run_part() {
  local label="$1" check_fn="$2" apply_fn="$3" start
  shift 3
  if "$check_fn" "$@"; then
    ok "$label"
    SUMMARY="${SUMMARY}${label}|ready|0
"
    return 0
  fi
  if [ "$MODE" = "check" ]; then
    note_todo "$label"
    return 0
  fi
  step "$label"
  start="$SECONDS"
  "$apply_fn" "$@"
  CHANGED=$((CHANGED + 1))
  SUMMARY="${SUMMARY}${label}|done|$((SECONDS - start))
"
}

# summary_table prints the steps of the run in a table, at a terminal.
summary_table() {
  [ "$UI_COLOR" -eq 1 ] || return 0
  [ -n "$SUMMARY" ] || return 0
  local n=0 label result secs color mark
  printf '  %s%-4s %-34s %-10s %s%s\n' "$C_BOLD" "#" "Step" "Result" "Time" "$C_RESET"
  while IFS='|' read -r label result secs; do
    [ -n "$label" ] || continue
    n=$((n + 1))
    color="$C_GREEN" mark="$M_OK"
    case "$result" in missing) color="$C_RED" mark="$M_BAD" ;; esac
    printf '  %-4s %-34s %s%s %-8s%s %s\n' "$n" "${label:0:34}" "$color" "$mark" "$result" "$C_RESET" "$(ui_time "$secs")"
  done <<<"$SUMMARY"
  printf '\n'
}

# next_steps ROLE prints what to do after a run, with links to the docs of the release.
next_steps() {
  local server="${NEXT_SERVER:-<SSH name>}"
  # In a run of "both", the server part prints none. The client part follows.
  [ "$1" != "none" ] || return 0
  printf '\n  %sNext steps%s\n\n' "$C_BOLD" "$C_RESET"
  case "$1" in
    server)
      printf '    1. Set up your client machine, the machine that you type on:\n'
      printf '       %s/README.md#client-machine\n' "$HS_DOC_BASE"
      printf '       If this machine is also your client, run the setup with "both":\n'
      printf '       %s/README.md#one-machine-as-both\n' "$HS_DOC_BASE"
      printf '    2. From the client, connect with SSH, and open your projects:\n'
      printf '       hopen .          the current folder\n'
      printf '       hopen <list>     the projects of a list: %s/docs/hopen.md\n' "$HS_DOC_BASE"
      printf '    3. To check this machine later, run the setup with --check.\n'
      ;;
    client)
      ghostty_step
      printf '    2. Connect to your server:\n'
      printf '       ssh %s\n' "$server"
      printf '       If the server has no herdspace yet: %s/README.md#server-machine\n' "$HS_DOC_BASE"
      printf '    3. On the server, open your projects:\n'
      printf '       hopen .          the current folder\n'
      printf '       hopen <list>     the projects of a list\n'
      printf '    4. Learn the keys: %s/docs/keyboard-shortcuts.md\n' "$HS_DOC_BASE"
      printf '    If a Ctrl arrow key does not work on macOS, log out and log in again.\n'
      ;;
    both)
      ghostty_step
      printf '    2. Open your projects:\n'
      printf '       hopen .          the current folder\n'
      printf '       hopen <list>     the projects of a list: %s/docs/hopen.md\n' "$HS_DOC_BASE"
      printf '    3. Learn the keys: %s/docs/keyboard-shortcuts.md\n' "$HS_DOC_BASE"
      ;;
  esac
}

# ghostty_step prints the first next step of a client. A change of the opacity
# or the title bar style loads only after a full restart of Ghostty.
ghostty_step() {
  if [ "${GHOSTTY_CHANGED:-0}" -eq 1 ]; then
    printf '    1. Quit Ghostty and start it again, so that the new keys and look load.\n'
    printf '       A new window does not load the opacity or the title bar style.\n'
  else
    printf '    1. Open a new Ghostty window, so that the new keys load.\n'
  fi
}

# finish_run ROLE prints the result: the summary, the kept files, the backups,
# and the next steps for ROLE (server, client, or both).
finish_run() {
  local role="$1" f
  step "Result"
  if [ "$MODE" = "check" ]; then
    if [ "$TODO" -gt 0 ]; then
      info "$(ui_count item "$TODO") need work. Run the script with no --check to do them."
      exit 1
    fi
    if [ "$EDITED" -gt 0 ]; then
      ok "Nothing is missing. $(ui_count file "$EDITED") differ from this repository."
    else
      ok "Everything is already set up."
    fi
    exit 0
  fi
  summary_table
  if [ -n "$KEPT_LIST" ]; then
    info "Kept $(ui_count file "$EDITED") that differ from this repository:"
    printf '%s' "$KEPT_LIST" | while IFS= read -r f; do printf '    %s\n' "$(short_home "$f")"; done
    info "To decide again for a kept file, run the setup again. It asks about each file."
  fi
  if [ "$ZSHRC_KEPT_NO_EXTRAS" -eq 1 ]; then
    info "Your ~/.zshrc does not load the herdspace shell: the prompt, ff, fif, the completion of hopen, and the fzf keys."
    info "To add a block that loads it, run the setup again and answer f or e for ~/.zshrc."
  fi
  if [ -n "$BACKUP_LIST" ]; then
    info "Saved $(ui_count backup "$(printf '%s' "$BACKUP_LIST" | grep -c .)"). To put a file back, run its command:"
    printf '%s' "$BACKUP_LIST" | while IFS= read -r f; do printf '    mv %s.bak-%s %s\n' "$(short_home "$f")" "$STAMP" "$(short_home "$f")"; done
  fi
  if [ "$CHANGED" -eq 0 ]; then
    ok "Everything is already set up."
  else
    ok "Done."
  fi
  next_steps "$role"
}
