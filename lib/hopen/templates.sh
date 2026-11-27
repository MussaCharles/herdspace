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

template_lines() { grep -vE '^[[:space:]]*(#|$)' "$(template_file "$1")"; }

show_templates() {
  local file name text
  printf '%-12s %s\n' TEMPLATE DESCRIPTION
  printf '%-12s %s\n' plain "One pane with a shell. This is the default."
  for file in "$TEMPLATE_DIR"/*.layout; do
    [ -f "$file" ] || continue
    name="$(basename "$file" .layout)"
    text="$(sed -n "1s/^# *${name}: *//p" "$file")"
    printf '%-12s %s\n' "$name" "${text:-}"
  done
}

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
  printf '%s\036%s' "$GUARD_PAIRS" "$GUARD_TABS" | nohup python3 -I -c '
import json, subprocess, sys, time
panes_text, _, tabs_text = sys.stdin.read().partition("\x1e")
pairs = [line.split("\t", 1) for line in panes_text.split("\n") if "\t" in line]
# A tab is found by its first pane, because a tab create answer has that pane.
tabs = [line.split("\t", 1) for line in tabs_text.split("\n") if "\t" in line]
end = time.time() + float(sys.argv[1])

def herdr(*args):
    out = subprocess.run(["herdr", *args], capture_output=True, text=True, timeout=5).stdout
    return json.loads(out)["result"]

while (pairs or tabs) and time.time() < end:
    time.sleep(0.5)
    try:
        panes = herdr("pane", "list")["panes"]
        labels = {p["pane_id"]: p.get("label") or "" for p in panes}
        tab_of = {p["pane_id"]: (p["workspace_id"], p["tab_id"]) for p in panes}
        tab_labels = {}
        for workspace in {tab_of[pane][0] for pane, _ in tabs if pane in tab_of}:
            for tab in herdr("tab", "list", "--workspace", workspace)["tabs"]:
                tab_labels[tab["tab_id"]] = tab.get("label") or ""
    except Exception:
        continue
    pairs = [(pane, name) for pane, name in pairs if pane in labels]
    for pane, name in pairs:
        if labels[pane] != name:
            subprocess.run(["herdr", "pane", "rename", pane, name], capture_output=True, timeout=5)
    tabs = [(pane, name) for pane, name in tabs if pane in tab_of and tab_of[pane][1] in tab_labels]
    for pane, name in tabs:
        tab = tab_of[pane][1]
        if tab_labels[tab] != name:
            subprocess.run(["herdr", "tab", "rename", tab, name], capture_output=True, timeout=5)
' "$seconds" >/dev/null 2>&1 &
  disown
  GUARD_PAIRS=""
  GUARD_TABS=""
}
