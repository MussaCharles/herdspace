# shellcheck shell=bash
# The command palette, like Ctrl+Shift+P in VS Code.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# The command palette lists each action as "Group: Action", with its key or
# command at the right, as in VS Code. It shows only the actions that fit the
# place: in Herdr or not, in a project with tasks, in a git folder, on a client,
# and with the tools that are installed. PALETTE_RECENT keeps the ids of the
# last actions, with no paths and no text that the person typed.
PALETTE_RECENT="${XDG_CACHE_HOME:-$HOME/.cache}/herdspace/palette-recent"
PALETTE_ITEMS=""

# pal_add ID GROUP TEXT [HINT] adds one action, as "ID<TAB>GROUP<TAB>line<TAB>
# colored line". The colored line has the group in its color and the hint dim.
pal_add() {
  local line color pad=""
  line="$(printf '%s: %s' "$2" "$3")"
  color="$(sgr "$(group_color "$2")")$2"$'\033[0m'": $3"
  if [ -n "${4:-}" ]; then
    [ "${#line}" -ge 58 ] || pad="$(printf '%*s' $((58 - ${#line})) '')"
    line="$(printf '%-58s %s' "$line" "$4")"
    color="${color}${pad} $(sgr "$UI_DIM")$4"$'\033[0m'
  fi
  PALETTE_ITEMS="${PALETTE_ITEMS}$1"$'\t'"$2"$'\t'"${line}"$'\t'"${color}"$'\n'
}

# integrations prints "name<TAB>state" for each Herdr integration, for example
# "claude<TAB>current (v11)" or "kimi<TAB>not installed".
integrations() {
  herdr integration status 2>/dev/null | sed -E 's/^([a-z-]+)( \(experimental\))?: ([^(]*[^ (])( \(v[0-9]+\))?.*$/\1\t\3\4/'
}

# show_integrations prints the integrations in two columns.
show_integrations() {
  printf '  The Herdr integration of each agent program:\n\n'
  integrations | awk -F '\t' '{ printf "  %-18s %s\n", $1, $2 }'
  printf '\n  An agent needs its integration only for the state and the resume of\n  its conversation. See the agents page of the herdspace docs.\n'
}

# agents_sorted prints "pane<TAB>agent<TAB>state<TAB>cwd" for each agent, the
# blocked and done agents first.
agents_sorted() {
  herdr agent list 2>/dev/null | python3 -c '
import json, sys
order = {"blocked": 0, "done": 1, "working": 2, "idle": 3}
agents = json.load(sys.stdin).get("result", {}).get("agents", [])
for a in sorted(agents, key=lambda a: order.get(a.get("agent_status"), 4)):
    print("\t".join([a.get("pane_id", ""), a.get("agent") or "agent", a.get("agent_status", ""), a.get("cwd", "")]))'
}

# worktrees DIR prints "path<TAB>branch<TAB>workspace" for each linked worktree.
worktrees() {
  herdr worktree list --cwd "$1" 2>/dev/null | python3 -c '
import json, sys
for w in json.load(sys.stdin).get("result", {}).get("worktrees", []):
    if w.get("is_linked_worktree"):
        print("\t".join([w.get("path", ""), w.get("branch") or "-", w.get("workspace_id") or ""]))' 2>/dev/null
}

# keys_help prints the keys that a person uses most.
keys_help() {
  cat <<'KEYS'
  Herdr (Mac / Linux)
    New tab, close tab           Cmd+T, Cmd+W      / Ctrl+Shift+T, Ctrl+Shift+W
    Go to anything               Cmd+K             / Ctrl+Shift+K
    Command palette              Cmd+Shift+P       / Ctrl+Shift+P
    lazygit over the pane        Cmd+Shift+G       / Ctrl+Shift+G
    Previous or next tab         Ctrl+Left, Ctrl+Right
    Previous or next workspace   Ctrl+Up, Ctrl+Down
    Next or previous pane        Alt+Up, Alt+Down
    Split right, split down      Ctrl+B V, Ctrl+B -
    Zoom the pane                Ctrl+B Z
    Leave, keep everything       Ctrl+B Q
  Shell
    Find a file, search text     ff, fif TEXT
    Jump to a folder             z NAME, zi
  Ghostty (outside Herdr)
    New tab, clear the screen    Cmd+Option+T, Cmd+Option+K / Ctrl+Alt+Shift+T
KEYS
}

# session_command prints the command that attaches to the current session.
session_command() {
  case "${HERDR_SESSION:-default}" in
    default | "") printf 'herdr' ;;
    *) printf 'herdr --session %s' "$HERDR_SESSION" ;;
  esac
}

# palette_items DIR fills PALETTE_ITEMS with the actions for DIR and the place.
palette_items() {
  local dir="$1" match file label name text state cwd kind role=""
  PALETTE_ITEMS=""
  # Projects
  if [ -n "$PAL_PANE" ]; then
    pal_add here Projects "Open this folder as its own workspace" "herdr workspace create"
    pal_add window Projects "Open this session in a new window" "$(session_command)"
  else
    pal_add folder Projects "Open this folder in Herdr" "hopen ."
    while IFS=$'\t' read -r name file; do
      pal_add "open:${name}" Projects "Open the list ${name}" "hopen ${name}"
    done < <(find_lists 2>/dev/null)
  fi
  pal_add all Projects "Open every list in the background" "hopen --all"
  pal_add lists Projects "Show every list and its state" "hopen --list"
  pal_add convert Projects "Write a herdspace.toml from a VS Code list" "hopen --convert"
  # Tasks
  if match="$(project_for_dir "$dir")"; then
    file="${match%%$'\t'*}"
    label="${match#*$'\t'}"
    while IFS=$'\t' read -r name text; do
      [ -n "$name" ] && pal_add "task:${name}" Tasks "Run the task ${name}: ${text}" "hopen --task ${name}"
    done < <(read_list "$file" items 2>/dev/null | awk -F '\036' -v l="$label" '$1 == "K" && $2 == l { print $3 "\t" $4 }')
  fi
  # Files
  # In Herdr, quick open replaces this action.
  [ -n "$PAL_PANE" ] || ! command -v fzf >/dev/null 2>&1 || pal_add find Files "Find a file, and open it" "ff"
  [ -z "$PAL_PANE" ] || ! command -v fzf >/dev/null 2>&1 || pal_add quick Files "Quick open: a file in the editor of this tab" "Cmd+P, Ctrl+B F"
  command -v rg >/dev/null 2>&1 && pal_add grep Files "Search in the files, and open a result" "fif TEXT"
  command -v rg >/dev/null 2>&1 && pal_add ignored Files "Choose folders, and search them with the ignored files" "hopen --with-ignored"
  if command -v nvim >/dev/null 2>&1 || [ -n "${EDITOR:-}" ]; then
    pal_add edit Files "Open this folder in the editor" "nvim ."
    pal_add read-md Files "Read a Markdown file, rendered" "nvim -R FILE.md"
  fi
  # Git
  if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if command -v lazygit >/dev/null 2>&1; then
      pal_add git Git "Git status (lazygit)" "Cmd+Shift+G, Ctrl+B D"
      [ -z "$PAL_PANE" ] || pal_add git-tab Git "Open lazygit in a new tab" "lazygit"
    fi
    if [ -n "$PAL_PANE" ]; then
      pal_add wt-new Git "New worktree for an agent, on a new branch" "Ctrl+B Shift+G"
      pal_add wt-open Git "Open a worktree" "herdr worktree open"
      pal_add wt-list Git "Show the worktrees" "herdr worktree list"
      pal_add wt-remove Git "Remove a worktree" "herdr worktree remove"
    fi
  fi
  # Agents
  if [ -n "$PAL_PANE" ]; then
    while IFS=$'\t' read -r name kind state cwd; do
      [ -n "$name" ] && pal_add "agent:${name}" Agents "Go to ${kind} (${state}) in ${cwd/#"$HOME"/\~}" "Cmd+K"
    done < <(agents_sorted)
    [ -z "$(agents_sorted)" ] || pal_add explain Agents "Explain the state of an agent" "herdr agent explain"
    for kind in claude codex opencode gemini pi amp aider; do
      command -v "$kind" >/dev/null 2>&1 && pal_add "start:${kind}" Agents "Start ${kind} in a new pane" "$kind"
    done
  fi
  # The Herdr integrations of the agent programs.
  if command -v herdr >/dev/null 2>&1; then
    pal_add integ-status Agents "Show the Herdr integrations" "herdr integration status"
    pal_add integ-add Agents "Add the Herdr integration for an agent" "herdr integration install"
    pal_add integ-remove Agents "Remove the Herdr integration of an agent" "herdr integration uninstall"
  fi
  # Layout
  if [ -n "$PAL_PANE" ]; then
    while read -r name; do
      [ "$name" = plain ] || pal_add "apply:${name}" Layout "Split the current tab with the template ${name}" "hopen --apply ${name}"
    done < <(show_templates | tail -n +2 | cut -d ' ' -f1)
    pal_add split-right Layout "Split right" "Ctrl+B V"
    pal_add split-down Layout "Split down" "Ctrl+B -"
    pal_add zoom Layout "Zoom the pane, or return" "Ctrl+B Z"
  fi
  pal_add templates Layout "Show every template" "hopen --templates"
  # Workspace and tabs
  if [ -n "$PAL_PANE" ]; then
    pal_add new-tab "Workspace and tabs" "New tab" "Cmd+T, Ctrl+B C"
    pal_add new-ws "Workspace and tabs" "New workspace in this folder" "Ctrl+B Shift+N"
    pal_add rename-ws "Workspace and tabs" "Rename the workspace" "Ctrl+B Shift+W"
    pal_add rename-tab "Workspace and tabs" "Rename the tab" "Ctrl+B Shift+T"
    pal_add rename-pane "Workspace and tabs" "Rename the pane" "Ctrl+B Shift+P"
    pal_add close-tab "Workspace and tabs" "Close the tab" "Cmd+W, Ctrl+B Shift+X"
  fi
  # Sessions
  if command -v herdr >/dev/null 2>&1; then
    pal_add sessions Sessions "Show the sessions" "herdr session list"
    pal_add stop-session Sessions "Stop a session" "herdr session stop"
  fi
  # Network
  pal_add ports Network "Show the ports that your programs listen on" "hopen --ports"
  # herdspace
  if command -v herdspace >/dev/null 2>&1; then
    pal_add hs-version herdspace "Show the installed and the latest version" "herdspace --version"
    pal_add hs-update herdspace "Update herdspace" "herdspace update"
    role="$(sed -n 's/^role=//p' "${XDG_DATA_HOME:-$HOME/.local/share}/herdspace/last-setup" 2>/dev/null)"
    case "$role" in client | both) pal_add hs-keys herdspace "Show or change the Ghostty keys" "herdspace keys" ;; esac
    case "$role" in server | both) pal_add hs-editor herdspace "Show or change the editor mode: reader or normal" "herdspace editor" ;; esac
  fi
  if command -v herdr >/dev/null 2>&1; then
    [ ! -x "$HOME/.local/bin/herdr-update-check" ] || pal_add herdr-update Herdr "Check for a new Herdr version" "herdr-update-check --now"
    pal_add herdr-reload Herdr "Reload the Herdr configuration" "herdr server reload-config"
    pal_add herdr-status Herdr "Show the state of the Herdr server" "herdr status"
  fi
  # Help
  pal_add keys-help Help "Show the keys"
  pal_add docs Help "Show the links to the cheat sheet and the docs" "herdspace help"
}

# palette_menu prints the chosen id, a tab, and the chosen place: right, down,
# tab, or nothing for the default place of the action. In fzf, Ctrl+V, Ctrl+S,
# and Ctrl+T choose the place. In the numbered menu, a word after the name or
# the number does: "edit right", "3 down", "git tab". The recent actions come
# first. With no fzf, the numbered menu has a heading for each group.
palette_menu() {
  local items recent="" id head text i=0 last="" answer name out key place="" header field
  if [ -f "$PALETTE_RECENT" ]; then
    while IFS= read -r id; do
      [ -n "$id" ] || continue
      recent="${recent}$(awk -F '\t' -v id="$id" '$1 == id { print $1 "\tRecently used\t" $3 "\t" $4; exit }' <<<"$PALETTE_ITEMS")"$'\n'
    done <"$PALETTE_RECENT"
  fi
  items="$(printf '%s%s' "$(grep -v '^$' <<<"$recent")${recent:+$'\n'}" "$PALETTE_ITEMS" | grep -v '^$')"
  if command -v fzf >/dev/null 2>&1 && [ -n "${TERM:-}" ] && [ "${TERM}" != dumb ]; then
    header='Type to filter. Enter runs. Esc closes. At the right: the key or the command of each action.'
    [ -z "$PAL_PANE" ] || header="${header}"$'\n''This palette: Cmd+Shift+P, or Ctrl+B, then A. On Linux, Cmd keys are Ctrl+Shift (Cmd+P is Ctrl+B, then F).'
    [ -z "$PAL_PANE" ] || header="${header}"$'\n''A program opens: Ctrl+V on the right, Ctrl+S below, Ctrl+T in a new tab.'
    field=3
    ! ui_color || field=4
    out="$(ui_fzf "Command palette" --ansi --delimiter '\t' --with-nth "$field" --prompt '> ' --header "$header" --expect ctrl-v,ctrl-s,ctrl-t --height 100% --reverse --no-multi --tiebreak=index <<<"$items")" || true
    key="$(sed -n 1p <<<"$out")"
    id="$(sed -n 2p <<<"$out" | cut -f1)"
    [ -n "$id" ] || return 0
    case "$key" in ctrl-v) place=right ;; ctrl-s) place=down ;; ctrl-t) place=tab ;; esac
    printf '%s\t%s\n' "$id" "$place"
    return 0
  fi
  while IFS=$'\t' read -r id head text _; do
    i=$((i + 1))
    if [ "$head" != "$last" ]; then
      printf '\n  %s\n' "$head" >&2
      last="$head"
    fi
    printf '  %3d) %s\n' "$i" "$text" >&2
  done <<<"$items"
  [ -z "$PAL_PANE" ] || printf '\n  A word after the action opens a program in another place: right, down, or tab.' >&2
  printf '\n  Action? Type a number or a name: ' >&2
  IFS= read -r answer </dev/tty || answer=""
  case "$answer" in
    *" right" | *" down" | *" tab")
      place="${answer##* }"
      answer="${answer% *}"
      ;;
  esac
  case "$answer" in
    "") return 0 ;;
    *[!0-9]*) name="$(awk -F '\t' -v n="$answer" '$1 == n {print $1; exit}' <<<"$items")" ;;
    *) name="$(awk -F '\t' -v n="$answer" 'NR == n {print $1; exit}' <<<"$items")" ;;
  esac
  [ -n "$name" ] || { printf '  [err]  No action %s.\n' "$answer" >&2; return 1; }
  printf '%s\t%s\n' "$name" "$place"
}

# remember ID puts ID first in the recent list. Agent ids change, so they stay out.
remember() {
  case "$1" in agent:*) return 0 ;; esac
  mkdir -p "$(dirname "$PALETTE_RECENT")" 2>/dev/null || return 0
  {
    printf '%s\n' "$1"
    [ ! -f "$PALETTE_RECENT" ] || grep -vxF -- "$1" "$PALETTE_RECENT" | head -n 4 || true
  } >"${PALETTE_RECENT}.new" 2>/dev/null && mv "${PALETTE_RECENT}.new" "$PALETTE_RECENT"
}

# palette shows the actions that fit the current folder and place, and runs
# the one that the person chooses. With --print, it prints the actions only.
palette() {
  local dir="${HERDR_ACTIVE_PANE_CWD:-$PWD}" self="$0" choice text name pick
  PAL_PANE="${HERDR_ACTIVE_PANE_ID:-${HERDR_PANE_ID:-}}"
  PAL_WS="${HERDR_ACTIVE_WORKSPACE_ID:-${HERDR_WORKSPACE_ID:-}}"
  PAL_TAB="${HERDR_ACTIVE_TAB_ID:-${HERDR_TAB_ID:-}}"
  palette_items "$dir"
  if [ "${PALETTE_PRINT:-0}" -eq 1 ]; then
    awk -F '\t' '{ print $1 "\t" $3 }' <<<"$PALETTE_ITEMS" | grep -v '^$'
    return 0
  fi
  [ -t 0 ] && [ -t 1 ] || die "hopen --palette needs a terminal."
  choice="$(palette_menu)" || exit 1
  [ -n "$choice" ] || exit 0
  PAL_PLACE="${choice#*$'\t'}"
  choice="${choice%%$'\t'*}"
  [ -n "$choice" ] || exit 0
  remember "$choice"
  cd "$dir" || die "No folder ${dir}."
  case "$choice" in
    here) herdr workspace create --cwd "$dir" --label "$(basename "$dir")" --focus >/dev/null ;;
    window)
      then_wait printf '  Open a new terminal window, connect to this machine, and run:\n\n    %s\n\n  Each window keeps its own workspace and tab. Keep the two windows on\n  different tabs while an agent runs: https://github.com/herdrdev/herdr/issues/5749\n' "$(session_command)"
      ;;
    folder) exec "$self" . ;;
    open:*) exec "$self" "${choice#open:}" ;;
    all) then_wait "$self" --all --no-attach ;;
    lists) then_wait "$self" --list ;;
    convert)
      name="$(ask_text 'The name of the VS Code list')"
      [ -z "$name" ] || then_wait "$self" --convert "$name"
      ;;
    task:*) run_at here task "$dir" "$(printf '%q --task %q' "$self" "${choice#task:}")" ;;
    find) run_at here find "$dir" "$(printf '%q --find' "$self")" ;;
    quick) DIR="$dir"; quick_open ;;
    ignored)
      # Only the chosen folders are read, so the search stays fast.
      dir="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$dir")"
      text="$(cd "$dir" && list_folders | sort)" || true
      [ -n "$text" ] || { then_wait printf '  No folder in %s.\n' "$dir"; exit 0; }
      pick="$(pick_folders <<<"$text")" || exit 1
      [ -n "$pick" ] || exit 0
      while IFS= read -r name; do [ -z "$name" ] || add_search_dir "$name"; done <<<"$pick"
      choice="$(printf 'open\tOpen a file of these folders\ntext\tSearch the text in these folders\n' | choose "Search")" || exit 1
      DIR="$dir"
      case "$choice" in
        open) quick_open ;;
        text)
          GREP_TEXT="$(ask_text 'Search for')"
          [ -n "$GREP_TEXT" ] || exit 0
          grep_files
          ;;
      esac
      ;;
    grep)
      text="$(ask_text 'Search for')"
      [ -n "$text" ] || exit 0
      run_at here search "$dir" "$(printf '%q --grep %q' "$self" "$text")"
      ;;
    edit) run_at tab edit "$dir" "$(editor_command) ." ;;
    read-md)
      text="$(list_files 2>/dev/null | sed 's|^\./\([^-]\)|\1|' | grep -iE '\.(md|markdown)$' | sort)" || true
      [ -n "$text" ] || { then_wait printf '  No Markdown file in %s.\n' "$dir"; exit 0; }
      pick="$(awk '{ print $0 "\t" $0 }' <<<"$text" | choose "Markdown file")" || exit 1
      [ -n "$pick" ] || exit 0
      run_at tab "$(basename "$pick")" "$dir" "$(editor_command) -R $(printf '%q' "$pick")"
      ;;
    git) run_at here git "$dir" lazygit ;;
    git-tab) run_at tab git "$dir" lazygit ;;
    wt-new)
      name="$(ask_text 'The name of the new branch')"
      [ -n "$name" ] || exit 0
      then_wait herdr worktree create --cwd "$dir" --branch "$name" --focus
      ;;
    wt-open | wt-remove)
      pick="$(worktrees "$dir" | awk -F '\t' '{ print $1 "\t" $2 "  " $1 }' | choose "Worktree")" || exit 1
      [ -n "$pick" ] || exit 0
      if [ "$choice" = wt-open ] && [ -n "${PAL_PLACE:-}" ]; then
        run_at here "$(basename "$pick")" "$pick"
      elif [ "$choice" = wt-open ]; then
        herdr worktree open --cwd "$dir" --path "$pick" --focus >/dev/null
      else
        name="$(worktrees "$dir" | awk -F '\t' -v p="$pick" '$1 == p { print $3 }')"
        [ -n "$name" ] || { then_wait printf '  The worktree %s has no workspace. Open it first, then remove it.\n' "$pick"; exit 0; }
        confirm "Remove the worktree ${pick}? Changes that you did not commit are lost." || exit 0
        then_wait herdr worktree remove --workspace "$name"
      fi
      ;;
    wt-list) then_wait sh -c 'herdr worktree list --cwd "$1" | python3 -c "import json,sys; [print(\"  \"+(w.get(\"branch\") or \"-\")+\"  \"+w.get(\"path\",\"\")) for w in json.load(sys.stdin).get(\"result\",{}).get(\"worktrees\",[])]"' _ "$dir" ;;
    agent:*) herdr agent focus "${choice#agent:}" >/dev/null ;;
    integ-status) then_wait show_integrations ;;
    integ-add)
      pick="$(integrations | awk -F '\t' '$2 !~ /^current/ { print $1 "\t" $1 "  (" $2 ")" }' | choose "Integration to add")" || exit 1
      [ -n "$pick" ] || exit 0
      then_wait herdr integration install "$pick"
      ;;
    integ-remove)
      pick="$(integrations | awk -F '\t' '$2 !~ /^not installed/ { print $1 "\t" $1 "  (" $2 ")" }' | choose "Integration to remove")" || exit 1
      [ -n "$pick" ] || exit 0
      confirm "Remove the Herdr integration of ${pick}? Herdr then shows its state from the screen only." || exit 0
      then_wait herdr integration uninstall "$pick"
      ;;
    explain)
      pick="$(agents_sorted | awk -F '\t' '{ print $1 "\t" $2 " (" $3 ")  " $4 }' | choose "Agent")" || exit 1
      [ -z "$pick" ] || then_wait herdr agent explain "$pick"
      ;;
    start:*) run_at right "${choice#start:}" "$dir" "${choice#start:}" ;;
    apply:*) then_wait "$self" --apply "${choice#apply:}" ;;
    split-right) split_run right "$dir" ;;
    split-down) split_run down "$dir" ;;
    zoom) herdr pane zoom --pane "$PAL_PANE" --toggle >/dev/null ;;
    templates) then_wait "$self" --templates ;;
    new-tab) herdr tab create --workspace "$PAL_WS" --cwd "$dir" --focus >/dev/null ;;
    new-ws) herdr workspace create --cwd "$dir" --focus >/dev/null ;;
    rename-ws | rename-tab | rename-pane)
      name="$(ask_text 'The new name')"
      [ -n "$name" ] || exit 0
      case "$choice" in
        rename-ws) herdr workspace rename "$PAL_WS" "$name" >/dev/null ;;
        rename-tab) herdr tab rename "$PAL_TAB" "$name" >/dev/null ;;
        rename-pane) herdr pane rename "$PAL_PANE" "$name" >/dev/null ;;
      esac
      ;;
    close-tab) confirm "Close this tab and end the programs in it?" && herdr tab close "$PAL_TAB" >/dev/null ;;
    sessions) then_wait herdr session list ;;
    stop-session)
      pick="$(herdr session list 2>/dev/null | awk 'NR > 1 && $2 == "running" { print $1 "\t" $1 }' | choose "Session")" || exit 1
      [ -n "$pick" ] || exit 0
      text="Stop the session ${pick}, and end every program in it?"
      [ "$pick" != "${HERDR_SESSION:-default}" ] || text="Stop the session ${pick}, the one that you use now, and end every program in it?"
      confirm "$text" || exit 0
      if [ "$pick" = default ]; then then_wait herdr server stop; else then_wait herdr session stop "$pick"; fi
      ;;
    ports) then_wait "$self" --ports ;;
    hs-version) then_wait herdspace --version ;;
    hs-update) if [ -n "$PAL_PANE" ]; then new_tab_run update "$HOME" "herdspace update"; else exec herdspace update; fi ;;
    hs-keys)
      herdspace keys
      pick="$(printf 'normal\tnormal: Cmd+T, Cmd+W, and Cmd+K stay with Ghostty\nherdr\therdr: Cmd+T, Cmd+W, and Cmd+K go to Herdr\n' | choose "Keys")" || exit 1
      [ -n "$pick" ] || exit 0
      if [ -n "$PAL_PANE" ]; then new_tab_run keys "$HOME" "herdspace keys ${pick}"; else exec herdspace keys "$pick"; fi
      ;;
    hs-editor)
      herdspace editor
      pick="$(printf 'reader\treader: no warnings and no spell marks\nnormal\tnormal: the defaults of LazyVim\n' | choose "Editor")" || exit 1
      [ -n "$pick" ] || exit 0
      then_wait herdspace editor "$pick"
      ;;
    herdr-update) then_wait "$HOME/.local/bin/herdr-update-check" --now ;;
    herdr-reload) then_wait herdr server reload-config ;;
    herdr-status) then_wait herdr status ;;
    keys-help) then_wait keys_help ;;
    docs) then_wait printf '  The cheat sheet:  https://github.com/MussaCharles/herdspace/blob/main/docs/cheat-sheet.md\n  The docs:         https://github.com/MussaCharles/herdspace/blob/main/docs/README.md\n' ;;
  esac
}
