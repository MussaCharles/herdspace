# shellcheck shell=bash
# The Agents group of the command palette.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

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

# pal_items_agents DIR adds the Agents actions for DIR and the place.
pal_items_agents() {
  local name kind state cwd
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
}

# pal_run_agents ID DIR runs the action ID of the Agents group. For an ID of
# another group, it sets PAL_MISS=1.
pal_run_agents() {
  local choice="$1" dir="$2" pick
  case "$choice" in
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
    *) PAL_MISS=1 ;;
  esac
}
