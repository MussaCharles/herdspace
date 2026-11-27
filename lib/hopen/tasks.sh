# shellcheck shell=bash
# The tasks of a list: hopen --task, with the environment of the project.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# project_for_dir DIR prints "list file<TAB>label" for the project that holds
# DIR. The deepest project folder wins, so a project wins over the parent
# workspace of its list.
project_for_dir() {
  local dir="$1" name file
  find_lists 2>/dev/null | while IFS=$'\t' read -r name file; do
    read_list "$file" items 2>/dev/null | awk -F '\036' -v f="$file" '($1 == "R" || $1 == "P") { print $3 "\t" f "\t" $2 }'
  done | awk -F '\t' -v d="$dir" '
    (d == $1 || index(d, $1 "/") == 1) && length($1) > best { best = length($1); found = $2 "\t" $3 }
    END { if (found == "") exit 1; print found }'
}

# env_for ITEMS LABEL sets ENV_ARGS to the environment values of one project:
# its env values, and the values of its env file that env does not set.
env_for() {
  local items="$1" label="$2" envs file_env item key
  envs="$(awk -F '\036' -v l="$label" '($1 == "R" || $1 == "P") && $2 == l && $6 != "-" { print $6; exit }' <<<"$items")"
  file_env="$(awk -F '\036' -v l="$label" '$1 == "F" && $2 == l { print $5; exit }' <<<"$items")"
  ENV_ARGS=()
  if [ -n "$envs" ]; then
    while IFS= read -r -d $'\x1f' item; do
      [ -z "$item" ] || ENV_ARGS+=(--env "$item")
    done <<<"${envs}"$'\x1f'
  fi
  if [ -n "$file_env" ]; then
    while IFS= read -r -d $'\x1f' item; do
      key="${item%%=*}"
      [ -n "$item" ] || continue
      case $'\x1f'"${envs}"$'\x1f' in *$'\x1f'"${key}="*) continue ;; esac
      ENV_ARGS+=(--env "$item")
    done <<<"${file_env}"$'\x1f'
  fi
}

# run_task runs a task of the project of the current folder. In Herdr, it runs
# in a new pane below the current pane. A popup of Herdr has no pane of its
# keep_pane_name PANE NAME sets the name again if a plugin changed it. The Auto
# Title plugin can name a new pane when it first sees it, also a pane that has a
# name already. It keeps a name that changes after that first sighting.
keep_pane_name() {
  local pane="$1" name="$2" _try label
  for _try in 1 2; do
    sleep 1
    label="$(herdr pane list 2>/dev/null | python3 -I -c 'import json,sys
for p in json.load(sys.stdin)["result"]["panes"]:
    if p["pane_id"] == sys.argv[1]: print(p.get("label") or "")' "$pane" 2>/dev/null)" || return 0
    [ "$label" = "$name" ] || herdr pane rename "$pane" "$name" >/dev/null 2>&1 || return 0
  done
}

# own, so there it splits the active pane. Outside Herdr, it runs here.
run_task() {
  local dir="${HERDR_ACTIVE_PANE_CWD:-$PWD}" match file label items tasks command actions output pane item
  match="$(project_for_dir "$dir")" || die "No project of a list holds the folder $(short_path "$dir")."
  file="${match%%$'\t'*}"
  label="${match#*$'\t'}"
  items="$(read_list "$file" items)" || die "Could not read ${file}."
  tasks="$(awk -F '\036' -v l="$label" '$1 == "K" && $2 == l { print $3 "\t" $4 }' <<<"$items")"
  [ -n "$tasks" ] || die "The project ${label} has no tasks. Add tasks to $(short_path "$file"). See https://github.com/MussaCharles/herdspace/blob/main/docs/hopen.md#tasks"
  if [ -z "$TASK_NAME" ]; then
    if [ -t 0 ] && [ -t 1 ]; then
      TASK_NAME="$(while IFS=$'\t' read -r item command; do printf '%s\t%-14s %s\n' "$item" "$item" "$command"; done <<<"$tasks" | choose "Run which task")" || exit 1
      [ -n "$TASK_NAME" ] || exit 0
    else
      printf '%s\n' "$tasks"
      return 0
    fi
  fi
  command="$(awk -F '\t' -v n="$TASK_NAME" '$1 == n { print $2; exit }' <<<"$tasks")"
  [ -n "$command" ] || die "The project ${label} has no task ${TASK_NAME}. Its tasks: $(cut -f1 <<<"$tasks" | tr '\n' ' ')"
  actions="$(list_actions "$items")"
  list_trusted "$file" "$actions" "$(grep $'^F\x1e' <<<"$items" || true)" ||
    die "hopen runs a task only from an approved list. Run hopen --task in a terminal to approve $(short_path "$file"), or add --trust."
  env_for "$items" "$label"
  pane="${HERDR_PANE_ID:-${HERDR_ACTIVE_PANE_ID:-}}"
  if [ -n "$pane" ]; then
    output="$(herdr pane split "$pane" --direction down --ratio 0.65 --focus ${ENV_ARGS[@]+"${ENV_ARGS[@]}"})" || die "Could not split the pane."
    pane="$(json_get "d['result']['pane']['pane_id']" <<<"$output")"
    herdr pane rename "$pane" "$TASK_NAME" >/dev/null
    herdr pane run "$pane" "cd $(printf '%q' "$dir") && ${command}" >/dev/null
    printf '  [info] Task %s runs in a new pane: %s\n' "$TASK_NAME" "$command"
    keep_pane_name "$pane" "$TASK_NAME"
  else
    printf '  [info] Task %s: %s\n' "$TASK_NAME" "$command"
    for item in ${ENV_ARGS[@]+"${ENV_ARGS[@]}"}; do
      [ "$item" = --env ] || export "${item?}"
    done
    cd "$dir" && exec "${SHELL:-/bin/sh}" -c "$command"
  fi
}
