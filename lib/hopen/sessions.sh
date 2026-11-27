# shellcheck shell=bash
# The Herdr sessions of hopen: start one, open the projects of a list, restart programs, and attach.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

session_answers() {
  local output
  output="$(HERDR_SESSION="$SESSION" herdr workspace list 2>/dev/null)" || return 1
  [[ "$output" == *workspace_list* ]]
}

start_session() {
  HERDR_SESSION="$SESSION" nohup herdr server >/dev/null 2>&1 &
  disown
  STARTED=1
  for _ in $(seq 1 40); do
    session_answers && return 0
    sleep 0.25
  done
  die "The session ${SESSION} did not start."
}

# workspaces prints one "label<TAB>workspace id" line for each workspace.
workspaces() {
  HERDR_SESSION="$SESSION" herdr workspace list | python3 -I -c '
import json, sys
for w in json.load(sys.stdin)["result"]["workspaces"]:
    print(w["label"], w["workspace_id"], sep="\t")
'
}

# panes_of WORKSPACE prints one "label<TAB>pane id" line for each pane.
panes_of() {
  HERDR_SESSION="$SESSION" herdr pane list | python3 -I -c '
import json, sys
for p in json.load(sys.stdin)["result"]["panes"]:
    if p["workspace_id"] == sys.argv[1]:
        print(p.get("label") or "", p["pane_id"], sep="\t")
' "$1"
}

# pane_is_idle exits 0 if the pane shows its shell prompt, with no program.
pane_is_idle() {
  local info
  for _ in $(seq 1 20); do
    info="$(HERDR_SESSION="$SESSION" herdr pane process-info --pane "$1" 2>/dev/null)" || info=""
    case "$info" in
      *shell_pid*)
        python3 -I -c '
import json, sys
p = json.load(sys.stdin)["result"]["process_info"]
sys.exit(0 if p.get("shell_pid") and p.get("foreground_process_group_id") == p.get("shell_pid") else 1)
' <<<"$info"
        return
        ;;
    esac
    sleep 0.25
  done
  return 1
}

state_file() { printf '%s/%s.tsv' "$STATE_DIR" "$SESSION"; }

# remember_template LABEL TEMPLATE PANES writes one state line for a workspace.
# PANES is "id=name id=name". Herdr keeps the pane IDs after a restart, so
# hopen finds each template pane by its ID, even if a plugin renamed it.
remember_template() {
  local file
  file="$(state_file)"
  mkdir -p "$STATE_DIR"
  touch "$file"
  awk -F '\t' -v l="$1" '$1 != l' "$file" >"${file}.tmp"
  printf '%s\t%s\t%s\n' "$1" "$2" "${3:-}" >>"${file}.tmp"
  mv "${file}.tmp" "$file"
}

# restart_programs starts each template program again in a pane that shows only
# its shell. Herdr restores the panes after a stop, but not their programs.
restart_programs() {
  local file label template id panes pane from direction size command pane_id restarted=0
  file="$(state_file)"
  [ -f "$file" ] || return 0
  local all
  all="$(workspaces)"
  while IFS=$'\t' read -r label template saved; do
    template_exists "$template" && [ "$template" != plain ] || continue
    # A tab of a workspace has the state label "workspace/tab".
    id="$(awk -F '\t' -v l="${label%%/*}" '$1 == l {print $2}' <<<"$all")"
    [ -n "$id" ] || continue
    panes="$(panes_of "$id")"
    while read -r pane from direction size command; do
      # The saved ID comes first. The name is for state from older versions.
      pane_id="$(tr ' ' '\n' <<<"${saved:-}" | awk -F '=' -v n="$pane" '$2 == n {print $1; exit}')"
      if [ -z "$pane_id" ] || ! cut -f2 <<<"$panes" | grep -Fxq -- "$pane_id"; then
        pane_id="$(awk -F '\t' -v l="$pane" '$1 == l {print $2; exit}' <<<"$panes")"
      fi
      [ -n "$pane_id" ] || continue
      GUARD_PAIRS="${GUARD_PAIRS}${pane_id}"$'\t'"${pane}"$'\n'
      [ -n "$command" ] && [ "$command" != "-" ] || continue
      if pane_is_idle "$pane_id"; then
        HERDR_SESSION="$SESSION" herdr pane run "$pane_id" "$command" >/dev/null
        restarted=$((restarted + 1))
      fi
    done < <(template_lines "$template")
  done <"$file"
  [ "$restarted" -eq 0 ] || printf '  [info] Session %s: %s programs started again.\n' "$SESSION" "$restarted"
}

# open_template TEMPLATE PANE STATE_LABEL splits PANE with TEMPLATE, starts its
# programs, and remembers the panes under STATE_LABEL.
open_template() {
  local template="$1" root="$2" state_label="$3" before
  [ "$template" != plain ] || return 0
  before="$GUARD_PAIRS"
  HERDR_SESSION="$SESSION" apply_template "$template" "$root"
  remember_template "$state_label" "$template" "$(printf '%s' "${GUARD_PAIRS#"$before"}" | tr '\t' '=' | tr '\n' ' ' | sed 's/ $//')"
}

# prepare_session starts SESSION and adds each folder that has no workspace.
# A new workspace gets its template, its on-open command, and its extra tabs.
prepare_session() {
  local items existing added=0 kind label folder template extra envs output root workspace_id item
  local current="" current_folder="" current_id="" file_env="" key
  STARTED=0
  session_answers || start_session
  [ "$STARTED" -eq 0 ] || restart_programs
  if [ -n "$FOLDER" ]; then
    # A folder with no list: one workspace, with no commands or values.
    items="$(printf 'R\036%s\036%s\036%s\036-\036-' "$SESSION" "$FOLDER" "${TEMPLATE_FLAG:-plain}")"
  else
    items="$(read_list "$LIST_FILE" items)" || die "Could not read ${LIST_FILE}."
  fi
  local actions trusted=1
  actions="$(list_actions "$items")"
  if [ -n "$actions" ] && ! list_trusted "$LIST_FILE" "$actions" "$(grep $'^F\x1e' <<<"$items" || true)"; then
    trusted=0
    warn "hopen did not use the commands and values of $(short_path "$LIST_FILE"). Run hopen in a terminal to approve them, or add --trust."
  fi
  existing="$(workspaces | cut -f1)"
  while IFS=$'\x1e' read -r kind label folder template extra envs; do
    [ "$extra" != "-" ] && [ "$trusted" -eq 1 ] || extra=""
    [ "$envs" != "-" ] && [ "$trusted" -eq 1 ] || envs=""
    case "$kind" in
      W) warn "$label"; continue ;;
      F)
        # The values of an env file, for the R or P line that comes next.
        # "extra" holds them here, and it is empty with no approval.
        file_env="$extra"
        continue
        ;;
      T)
        # A tab line: label, tab name (in "folder"), template, command.
        [ "$label" = "$current" ] && [ -n "$current_id" ] || continue
        if ! template_exists "$template"; then
          warn "${label}/${folder}: no template named ${template}. The tab opens with one pane."
          template="plain"
        fi
        output="$(HERDR_SESSION="$SESSION" herdr tab create --workspace "$current_id" --cwd "$current_folder" --label "$folder" --no-focus ${ENV_ARGS[@]+"${ENV_ARGS[@]}"})"
        root="$(json_get "d['result']['root_pane']['pane_id']" <<<"$output")"
        GUARD_TABS="${GUARD_TABS}${root}"$'\t'"${folder}"$'\n'
        open_template "$template" "$root" "${label}/${folder}"
        [ -z "$extra" ] || HERDR_SESSION="$SESSION" herdr pane run "$root" "$extra" >/dev/null
        continue
        ;;
      R) label="$SESSION" ;;
      P) ;;
      *) continue ;;
    esac
    current="$label"
    current_folder="$folder"
    current_id=""
    ENV_ARGS=()
    if [ -n "$envs" ]; then
      while IFS= read -r -d $'\x1f' item; do
        [ -z "$item" ] || ENV_ARGS+=(--env "$item")
      done <<<"${envs}"$'\x1f'
    fi
    # A value from the env file is used only if env does not set the name.
    if [ -n "$file_env" ]; then
      while IFS= read -r -d $'\x1f' item; do
        key="${item%%=*}"
        [ -n "$item" ] || continue
        case $'\x1f'"${envs}"$'\x1f' in *$'\x1f'"${key}="*) continue ;; esac
        ENV_ARGS+=(--env "$item")
      done <<<"${file_env}"$'\x1f'
    fi
    file_env=""
    if grep -Fxq -- "$label" <<<"$existing"; then
      continue
    fi
    if [ ! -d "$folder" ]; then
      warn "Skipped ${label}: the folder ${folder} does not exist."
      continue
    fi
    if ! template_exists "$template"; then
      warn "${label}: no template named ${template}. It opens with one pane."
      template="plain"
    fi
    output="$(HERDR_SESSION="$SESSION" herdr workspace create --cwd "$folder" --label "$label" --no-focus ${ENV_ARGS[@]+"${ENV_ARGS[@]}"})"
    root="$(json_get "d['result']['root_pane']['pane_id']" <<<"$output")"
    workspace_id="$(json_get "d['result']['workspace']['workspace_id']" <<<"$output")"
    current_id="$workspace_id"
    # The on-open command runs first. The shell then starts the template program.
    [ -z "$extra" ] || HERDR_SESSION="$SESSION" herdr pane run "$root" "$extra" >/dev/null
    open_template "$template" "$root" "$label"
    added=$((added + 1))
  done <<<"$items"
  printf '  [info] Session %s: %s workspaces added.\n' "$SESSION" "$added"
  template_note "$items" "$added"
  HERDR_SESSION="$SESSION" guard_names
}

# template_note ITEMS ADDED explains --template when it did not split each
# project: the template applies only to the workspaces that the run creates.
template_note() {
  [ -n "$TEMPLATE_FLAG" ] || return 0
  local total existing
  total="$(printf '%s\n' "$1" | awk -F '\036' '$1 == "R" || $1 == "P"' | wc -l | tr -d ' ')"
  existing=$((total - $2))
  [ "$existing" -gt 0 ] || return 0
  if [ "$2" -eq 0 ]; then
    printf '  [info] --template %s splits only new projects, and each project of %s has a workspace already.\n' "$TEMPLATE_FLAG" "$SESSION"
  else
    printf '  [info] --template %s split the %s new projects. %s projects existed already.\n' "$TEMPLATE_FLAG" "$2" "$existing"
  fi
  printf '         To split a project that exists, go to its tab in Herdr, and run: hopen --apply %s\n' "$TEMPLATE_FLAG"
}

attach_session() {
  if [ "${HERDR_ENV:-}" = "1" ]; then
    die "You are in a Herdr pane. Press ctrl+b, then q, and run this command again."
  fi
  exec herdr session attach "$SESSION"
}

open_all() {
  local lists wanted="$SESSION" name
  lists="$(find_lists)"
  [ -n "$lists" ] || die "No project lists. Create ~/my-projects.code-workspace or ~/my-projects/herdspace.toml."
  if [ -n "$wanted" ] && ! grep -q "^${wanted}"$'\t' <<<"$lists"; then
    die "No project list for ${wanted}."
  fi
  while IFS=$'\t' read -r name LIST_FILE; do
    SESSION="$name"
    prepare_session
  done <<<"$lists"
  if [ -n "$wanted" ]; then
    SESSION="$wanted"
    attach_session
  fi
  printf '  [info] Run hopen with a session name to attach, for example: hopen %s\n' "$(printf '%s' "$lists" | head -n 1 | cut -f1)"
}

# apply_here splits the current tab of a Herdr pane with a template.
apply_here() {
  # A popup of Herdr has no pane of its own, so it applies to the active pane.
  local target="${HERDR_PANE_ID:-${HERDR_ACTIVE_PANE_ID:-}}"
  [ -n "$target" ] || die "Run --apply inside a Herdr pane."
  template_exists "$APPLY_NAME" || die "No template named ${APPLY_NAME}. Run hopen --templates."
  [ "$APPLY_NAME" != plain ] || return 0
  local tab count
  tab="$(herdr pane list | python3 -I -c '
import json, sys
print([p["tab_id"] for p in json.load(sys.stdin)["result"]["panes"] if p["pane_id"] == sys.argv[1]][0])
' "$target")"
  count="$(herdr pane list | python3 -I -c '
import json, sys
print(len([p for p in json.load(sys.stdin)["result"]["panes"] if p["tab_id"] == sys.argv[1]]))
' "$tab")"
  [ "$count" = 1 ] || die "The current tab has ${count} panes. Open a new tab, and run --apply there."
  apply_template "$APPLY_NAME" "$target"
  guard_names
}
