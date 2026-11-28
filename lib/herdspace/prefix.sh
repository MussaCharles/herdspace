# shellcheck shell=bash
# herdspace prefix, the prefix key of Herdr.
# bin/herdspace and bootstrap/lib/server.sh load this file after herdrconf.sh.
# It defines functions and variables, and runs nothing.

# PREFIX_DEFAULT is the prefix of config/herdr/config.toml. Herdr itself uses
# ctrl+b when the configuration has no prefix.
PREFIX_DEFAULT="ctrl+space"

# prefix_of FILE prints the prefix of a Herdr configuration, or ctrl+b when
# the [keys] table has no prefix.
prefix_of() {
  local key
  key="$(hc_get "$1" keys prefix)"
  printf '%s\n' "${key:-ctrl+b}"
}

# prefix_label KEY prints KEY as the docs write it: ctrl+space is Ctrl+Space.
prefix_label() {
  printf '%s\n' "$1" | awk -F '+' '{
    out = ""
    for (i = 1; i <= NF; i++) {
      part = $i
      if (part == "cmd" || part == "super") part = "Cmd"
      else if (length(part) == 1) part = toupper(part)
      else part = toupper(substr(part, 1, 1)) substr(part, 2)
      out = out (i > 1 ? "+" : "") part
    }
    print out
  }'
}

# cmd_prefix [KEY|default] shows or changes the prefix key of Herdr.
cmd_prefix() {
  local want="${1:-}" now label
  if [ -f "$HC_CONFIG" ]; then now="$(prefix_of "$HC_CONFIG")"; else now="$(hc_saved prefix || echo "$PREFIX_DEFAULT")"; fi
  label="$(prefix_label "$now")"
  if [ -z "$want" ]; then
    printf '  The prefix: %s. Press %s, release it, then press one more key.\n' "$label" "$label"
    printf '  To change it, run: herdspace prefix KEY, for example: herdspace prefix ctrl+a\n'
    printf '  To go back to %s, run: herdspace prefix default\n' "$(prefix_label "$PREFIX_DEFAULT")"
    return 0
  fi
  want="$(printf '%s' "$want" | tr '[:upper:]' '[:lower:]')"
  [ "$want" != default ] || want="$PREFIX_DEFAULT"
  hc_text_ok "$want" || { printf "herdspace: '%s' is not a key. Use a key such as ctrl+space or ctrl+a.\n" "$1" >&2; exit 2; }
  if [ "$want" = "$now" ]; then
    printf '  The prefix is %s already. Nothing to change.\n' "$label"
    return 0
  fi
  hc_change prefix "$want" "$PREFIX_DEFAULT" "$(prefix_label "$want")"
}
