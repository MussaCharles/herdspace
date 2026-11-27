# shellcheck shell=bash
# herdspace keys, the Ghostty keys of a client.
# bin/herdspace loads this file. It defines functions and variables, and runs nothing.

# cmd_keys [normal|herdr] shows or changes the Ghostty keys of a client. It
# runs the setup of the installed release again with the key option, so that
# the Ghostty file, the Linux keys, and Mission Control on a Mac all change.
cmd_keys() {
  local want="${1:-}" now role="" os="" line flag value args=() src
  [ -f "${STATE}/last-setup" ] || die "No setup is saved on this machine. Run the setup once, as the Quick start shows: https://github.com/${REPO}#quick-start"
  while IFS= read -r line; do
    case "$line" in
      role=*) role="${line#role=}" ;;
      os=*) os="${line#os=}" ;;
      arg=--keep-terminal-keys | arg=--use-herdspace-keys) ;;
      arg=*) args+=("${line#arg=}") ;;
    esac
  done <"${STATE}/last-setup"
  case "$role" in
    client | both) ;;
    *) die "herdspace keys changes the keys of Ghostty on a client machine. This machine has a ${role:-unknown} setup." ;;
  esac
  now="$(cat "${HOME}/.config/herdspace/keys" 2>/dev/null || echo herdspace)"
  case "$want" in
    "")
      if [ "$now" = "terminal" ]; then
        printf '  The keys: normal. Ghostty keeps its own keys, for example Cmd+T for a new tab.\n'
        printf '  To send these keys to Herdr, run: herdspace keys herdr\n'
      else
        printf '  The keys: herdr. Cmd+T, Cmd+W, and Cmd+K go to Herdr (Ctrl+Shift+T and others on Linux).\n'
        printf '  Outside Herdr, these keys do nothing. To give them back to Ghostty, run: herdspace keys normal\n'
      fi
      return 0
      ;;
    normal) flag="--keep-terminal-keys"; value="terminal" ;;
    herdr) flag="--use-herdspace-keys"; value="herdspace" ;;
    *) printf "herdspace: '%s' is not a key mode. Use 'normal' or 'herdr'.\n" "$want" >&2; exit 2 ;;
  esac
  if [ "$now" = "$value" ]; then
    printf '  The keys are %s already. Nothing to change.\n' "$want"
    return 0
  fi
  src="${XDG_DATA_HOME:-$HOME/.local/share}/herdspace/$(installed)/bootstrap.sh"
  [ -f "$src" ] || die "The files of herdspace $(installed) are missing. Run: herdspace update --force ${flag}"
  [ -z "$os" ] || args=(--os "$os" ${args[@]+"${args[@]}"})
  printf '  The setup runs again with %s.\n' "$flag"
  bash "$src" "$role" ${args[@]+"${args[@]}"} "$flag"
}
