# shellcheck shell=bash
# herdspace theme and herdspace color, the look of Herdr.
# bin/herdspace loads this file after herdrconf.sh. It defines functions and
# variables, and runs nothing.

# THEME_DEFAULT is the theme of config/herdr/config.toml.
THEME_DEFAULT="dracula"
# THEMES is the list of the built-in themes of Herdr 0.9.5. theme_list asks
# the installed Herdr first.
THEMES="catppuccin catppuccin-latte terminal tokyo-night tokyo-night-day dracula nord gruvbox gruvbox-light one-dark one-light solarized solarized-light kanagawa kanagawa-lotus rose-pine rose-pine-dawn vesper"
# COLORS is the list of accent colors, a name and a value on each line. The
# palette of hopen has the same list in lib/hopen/look.py.
COLORS="red #ef4444
orange #f97316
yellow #eab308
green #22c55e
teal #14b8a6
cyan #06b6d4
blue #3b82f6
purple #a855f7
pink #ec4899"

# theme_list prints the names of the built-in themes, one on each line. The
# installed Herdr names them in its error for an unknown theme.
theme_list() {
  local tmp out
  if command -v herdr >/dev/null 2>&1 && tmp="$(mktemp)"; then
    printf '[theme]\nname = "herdspace-no-theme"\n' >"$tmp"
    out="$(HERDR_CONFIG_PATH="$tmp" herdr config check 2>&1 | sed -n 's/.*valid themes: //p' | tr -d ',')"
    rm -f "$tmp"
    # shellcheck disable=SC2086 # One theme on each line.
    if [ -n "$out" ]; then printf '%s\n' $out; return 0; fi
  fi
  # shellcheck disable=SC2086 # One theme on each line.
  printf '%s\n' $THEMES
}

# pick_random NOW prints a random line of stdin that is not NOW.
pick_random() {
  awk -v now="$1" -v seed="$RANDOM" 'BEGIN {srand(seed)} $1 != now {line[n++] = $0} END {if (n) print line[int(rand() * n)]}'
}

# cmd_theme [NAME|random|default] shows or changes the theme of Herdr.
cmd_theme() {
  local want="${1:-}" now
  if [ -f "$HC_CONFIG" ]; then now="$(hc_get "$HC_CONFIG" theme name)"; else now="$(hc_saved theme || echo "$THEME_DEFAULT")"; fi
  now="${now:-catppuccin}"
  if [ -z "$want" ]; then
    printf '  The theme of Herdr: %s.\n' "$now"
    printf '  The themes: %s\n' "$(theme_list | tr '\n' ' ')"
    printf '  To change it, run: herdspace theme NAME, or: herdspace theme random\n'
    printf '  To go back to %s, run: herdspace theme default\n' "$THEME_DEFAULT"
    return 0
  fi
  want="$(printf '%s' "$want" | tr '[:upper:]' '[:lower:]')"
  case "$want" in
    default) want="$THEME_DEFAULT" ;;
    random) want="$(theme_list | pick_random "$now")" ;;
  esac
  if ! theme_list | grep -qx -- "$want"; then
    printf "herdspace: '%s' is not a theme of Herdr. Run 'herdspace theme' for the list.\n" "$1" >&2
    exit 2
  fi
  if [ "$want" = "$now" ]; then
    printf '  The theme is %s already. Nothing to change.\n' "$now"
    return 0
  fi
  hc_change theme "$want" "$THEME_DEFAULT" "$want"
}

# color_label VALUE prints the name of a color of the list, with its value,
# or the value alone. An empty value is the color of the theme.
color_label() {
  [ -n "$1" ] || { printf 'the color of the theme\n'; return 0; }
  printf '%s\n' "$COLORS" | awk -v v="$1" '$2 == v {print $1 " (" v ")"; found = 1} END {if (!found) print v}'
}

# cmd_color [NAME|#rrggbb|random|default] shows or changes the accent color
# of Herdr: the color of the headers and the highlights.
cmd_color() {
  local want="${1:-}" now value
  if [ -f "$HC_CONFIG" ]; then now="$(hc_get "$HC_CONFIG" theme.custom accent)"; else now="$(hc_saved accent || true)"; fi
  if [ -z "$want" ]; then
    printf '  The accent color of Herdr: %s.\n' "$(color_label "$now")"
    printf '  The colors: %s\n' "$(printf '%s\n' "$COLORS" | awk '{print $1}' | tr '\n' ' ')"
    printf '  To change it, run: herdspace color NAME, herdspace color "#rrggbb", or: herdspace color random\n'
    printf '  To use the color of the theme again, run: herdspace color default\n'
    return 0
  fi
  value="$(printf '%s' "$want" | tr '[:upper:]' '[:lower:]')"
  case "$value" in
    default) value="" ;;
    random) value="$(printf '%s\n' "$COLORS" | awk '{print $2, $1}' | pick_random "$now" | awk '{print $1}')" ;;
    \#[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
    *)
      value="$(printf '%s\n' "$COLORS" | awk -v n="$value" '$1 == n {print $2}')"
      if [ -z "$value" ]; then
        printf "herdspace: '%s' is not a color. Use a name of 'herdspace color', or a value such as #ec4899.\n" "$want" >&2
        exit 2
      fi
      ;;
  esac
  if [ "$value" = "$now" ]; then
    printf '  The accent color is %s already. Nothing to change.\n' "$(color_label "$now")"
    return 0
  fi
  hc_change accent "$value" "" "$(color_label "$value")"
}
