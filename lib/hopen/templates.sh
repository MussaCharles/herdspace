# shellcheck shell=bash
# The layout templates: find, list, and apply one, and the names of the guards.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

template_file() { printf '%s/%s.layout' "$TEMPLATE_DIR" "$1"; }

# template_exists exits 0 for a template file, and for "plain", which means no
# panes. A name is letters, numbers, "-", and "_", so it cannot leave the folder.
template_exists() {
  [ "$1" = plain ] && return 0
  [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || return 1
  [ -f "$(template_file "$1")" ]
}

# lib/hopen/templates.py reads the template files and lists them.
template_lines() { hopen_py internal template-lines "$TEMPLATE_DIR" "$1"; }

show_templates() { hopen_py internal templates "$TEMPLATE_DIR"; }

# apply_template NAME ROOT_PANE splits from ROOT_PANE and starts each program.
apply_template() {
  local name="$1" root="$2" made pane from direction size command id source
  made="$(printf '%s\t%s' "" "")"
  while read -r pane from direction size command; do
    if [ "$from" = "-" ]; then
      id="$root"
    else
      source="$(awk -F '\t' -v n="$from" '$1 == n {print $2}' <<<"$made")"
      if [ -z "$source" ]; then
        warn "Template ${name}: the pane ${from} comes later or does not exist."
        continue
      fi
      id="$(herdr pane split "$source" --direction "$direction" --ratio "$size" --no-focus ${ENV_ARGS[@]+"${ENV_ARGS[@]}"} | json_get "d['result']['pane']['pane_id']")"
    fi
    herdr pane rename "$id" "$pane" >/dev/null
    GUARD_PAIRS="${GUARD_PAIRS}${id}"$'\t'"${pane}"$'\n'
    made="${made}
$(printf '%s\t%s' "$pane" "$id")"
    if [ -n "$command" ] && [ "$command" != "-" ]; then
      herdr pane run "$id" "$command" >/dev/null
    fi
  done < <(template_lines "$name")
}

# guard_names keeps the template pane names and the tab names of a list for a
# short time. A plugin such as Auto Title names panes and tabs too. It keeps a name that you chose, but after a
# restart it can forget that choice, because every session writes its choices
# to one shared file, with pane IDs that repeat across sessions. So for
# HOPEN_GUARD_SECONDS (default 30), a background job puts back each template
# name that changed. The plugin then counts the name as one that you chose
# again. HOPEN_GUARD_SECONDS=0 turns the guard off.
guard_names() {
  local seconds="${HOPEN_GUARD_SECONDS:-30}"
  [ -n "$GUARD_PAIRS$GUARD_TABS" ] && [ "$seconds" != 0 ] || return 0
  # The guard is a Python loop in lib/hopen/templates.py. nohup needs a
  # program, so it starts the Python of hopen_py by its path.
  printf '%s\036%s' "$GUARD_PAIRS" "$GUARD_TABS" | nohup "$(hopen_python)" -I -B "${HOPEN_LIB}/__main__.py" internal guard "$seconds" >/dev/null 2>&1 &
  disown
  GUARD_PAIRS=""
  GUARD_TABS=""
}
