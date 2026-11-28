# shellcheck shell=bash
# The choices of a person in the Herdr configuration: the prefix key, the
# theme, and the accent color. "herdspace prefix", "herdspace theme", and
# "herdspace color" change them. Each choice has a file in ~/.config/herdspace/,
# and the setup writes the saved choices into the Herdr configuration, so that
# an update keeps them.
# bin/herdspace and bootstrap/lib/server.sh load this file. It defines
# functions and variables, and runs nothing.

HC_DIR="${HOME}/.config/herdspace"
# Herdr reads HERDR_CONFIG_PATH in place of the usual file, if it is set.
HC_CONFIG="${HERDR_CONFIG_PATH:-${HOME}/.config/herdr/config.toml}"
# Each choice: the name of its file in HC_DIR, its table, and its key.
HC_CHOICES="prefix keys prefix
theme theme name
accent theme.custom accent"

# hc_get FILE TABLE KEY prints the string value of KEY in TABLE, or nothing.
hc_get() {
  awk -v table="[$2]" -v key="$3" '
    /^\[/ { inside = ($0 == table); next }
    inside && $0 ~ "^" key "[ \t]*=" {
      sub("^" key "[ \t]*=[ \t]*\"", ""); sub(/".*$/, ""); print; exit
    }
  ' "$1" 2>/dev/null
}

# hc_set SRC TABLE KEY VALUE OUT writes SRC to OUT, with VALUE for KEY in
# TABLE. A missing line goes first in the table, and a missing table at the end.
# An empty VALUE removes the line.
hc_set() {
  awk -v table="[$2]" -v key="$3" -v value="$4" '
    function put() { if (value != "") print key " = \"" value "\""; done = 1 }
    /^\[/ {
      if (inside && !done) put()
      inside = ($0 == table); print
      if (inside && !seen) { seen = 1 }
      next
    }
    inside && !done && $0 ~ "^" key "[ \t]*=" { put(); next }
    { print }
    END {
      if (inside && !done) put()
      if (!seen && value != "") { print ""; print table; put() }
    }
  ' "$1" >"$5"
}

# hc_text_ok VALUE succeeds if VALUE can stand in a TOML string with no
# escape: no quote, no backslash, and no space.
hc_text_ok() {
  case "$1" in
    "" | *'"'* | *\\* | *[[:space:]]*) return 1 ;;
  esac
}

# hc_saved NAME prints the saved choice NAME, or nothing.
hc_saved() {
  local value
  value="$(head -n 1 "${HC_DIR}/$1" 2>/dev/null | tr -d '[:space:]')"
  hc_text_ok "$value" && printf '%s\n' "$value"
}

# hc_render SRC OUT writes SRC to OUT with each saved choice. It fails if no
# choice is saved, or if each saved choice matches SRC already.
hc_render() {
  local src="$1" out="$2" name table key value changed=1 tmp
  cp "$src" "$out" || return 1
  while read -r name table key; do
    value="$(hc_saved "$name")" || continue
    [ "$value" != "$(hc_get "$out" "$table" "$key")" ] || continue
    tmp="$(mktemp)" || return 1
    hc_set "$out" "$table" "$key" "$value" "$tmp"
    cat "$tmp" >"$out"
    rm -f "$tmp"
    changed=0
  done <<EOF
$HC_CHOICES
EOF
  return "$changed"
}

# hc_saved_list prints the saved choices, as "prefix Ctrl+A, theme nord".
hc_saved_list() {
  local name table key value out=""
  while read -r name table key; do
    value="$(hc_saved "$name")" || continue
    [ "$name" != prefix ] || value="$(prefix_label "$value")"
    out="${out:+${out}, }${name} ${value}"
  done <<EOF
$HC_CHOICES
EOF
  printf '%s\n' "$out"
}

# hc_check FILE prints the problems that Herdr finds in FILE, and fails if
# there is one. With no herdr, it succeeds.
hc_check() {
  command -v herdr >/dev/null 2>&1 || return 0
  local out
  out="$(HERDR_CONFIG_PATH="$1" herdr config check 2>&1)" || true
  case "$out" in
    'config: ok'*) return 0 ;;
  esac
  printf '%s\n' "$out" | sed -n '2,$p'
  return 1
}

# hc_manifest_update FILE OLD_SHA NEW_SHA records NEW_SHA for FILE in the
# manifest of the setup, if the manifest has OLD_SHA for it. Then the next
# update sees a file that no person changed, and replaces it with no question.
hc_manifest_update() {
  local manifest="${HOME}/.local/share/herdspace/manifest.tsv" tmp
  [ -f "$manifest" ] || return 0
  awk -F '\t' -v d="$1" -v s="$2" '$1 == d && $2 == s {found = 1} END {exit !found}' "$manifest" || return 0
  tmp="$(mktemp)" || return 0
  awk -F '\t' -v d="$1" '$1 != d' "$manifest" >"$tmp"
  printf '%s\t%s\n' "$1" "$3" >>"$tmp"
  cat "$tmp" >"$manifest"
  rm -f "$tmp"
}

# hc_reload applies the configuration to each running Herdr server. The
# panes stay.
hc_reload() {
  command -v herdr >/dev/null 2>&1 || return 0
  local name any=0
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    any=1
    if herdr --session "$name" server reload-config >/dev/null 2>&1; then
      printf '  Session %s uses it now.\n' "$name"
    else
      printf '  Session %s did not reload. Run: herdr --session %s server reload-config\n' "$name" "$name"
    fi
  done < <(herdr session list --json 2>/dev/null | python3 -I -c '
import json, sys
try:
    data = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
for session in data.get("sessions", []):
    if session.get("running"):
        print(session["name"])
' 2>/dev/null)
  [ "$any" -eq 1 ] || printf '  Herdr uses it the next time it starts.\n'
}

# hc_change NAME VALUE DEFAULT LABEL saves the choice NAME and writes it into
# the Herdr configuration. A VALUE equal to DEFAULT removes the saved file, so
# that a later release can change the default. LABEL is the value for people.
hc_change() {
  local name="$1" value="$2" default="$3" label="$4" table key tmp old new noun="$1"
  [ "$name" != accent ] || noun="accent color"
  read -r table key <<EOF
$(printf '%s\n' "$HC_CHOICES" | awk -v n="$name" '$1 == n {print $2, $3}')
EOF
  if [ -f "$HC_CONFIG" ]; then
    tmp="$(mktemp)" || die "Could not make a temporary file."
    hc_set "$HC_CONFIG" "$table" "$key" "$value" "$tmp"
    if ! hc_check "$tmp" >"${tmp}.err"; then
      printf "herdspace: Herdr does not accept '%s' as the %s:\n" "$value" "$noun" >&2
      sed 's/^/  /' "${tmp}.err" >&2
      rm -f "$tmp" "${tmp}.err"
      exit 2
    fi
    old="$(sha_of "$HC_CONFIG")"
    cat "$tmp" >"$HC_CONFIG" || { rm -f "$tmp" "${tmp}.err"; die "Could not write ${HC_CONFIG}."; }
    rm -f "$tmp" "${tmp}.err"
    new="$(sha_of "$HC_CONFIG")"
    hc_manifest_update "$HC_CONFIG" "$old" "$new"
  fi
  if [ "$value" = "$default" ]; then
    rm -f "${HC_DIR}/${name}"
  elif ! { mkdir -p "$HC_DIR" && printf '%s\n' "$value" >"${HC_DIR}/${name}"; }; then
    die "Could not write ${HC_DIR}/${name}."
  fi
  if [ -f "$HC_CONFIG" ]; then
    printf '  The %s: %s. An update keeps it.\n' "$noun" "$label"
    hc_reload
  else
    printf '  The %s: %s. This machine has no Herdr configuration yet. The setup of a server uses it.\n' "$noun" "$label"
  fi
}
