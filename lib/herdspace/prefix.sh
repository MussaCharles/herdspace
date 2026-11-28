# shellcheck shell=bash
# herdspace prefix, the prefix key of Herdr.
# bin/herdspace and bootstrap/lib/server.sh load this file. It defines
# functions and variables, and runs nothing.

# PREFIX_DEFAULT is the prefix of config/herdr/config.toml. Herdr itself uses
# ctrl+b when the configuration has no prefix.
PREFIX_DEFAULT="ctrl+space"
PREFIX_FILE="${HOME}/.config/herdspace/prefix"
# Herdr reads HERDR_CONFIG_PATH in place of the usual file, if it is set.
PREFIX_CONFIG="${HERDR_CONFIG_PATH:-${HOME}/.config/herdr/config.toml}"

# prefix_of FILE prints the prefix of the [keys] table of a Herdr
# configuration, or ctrl+b when the table has no prefix.
prefix_of() {
  awk '
    /^\[/ { keys = ($0 == "[keys]") ; next }
    keys && /^prefix[ \t]*=/ {
      sub(/^prefix[ \t]*=[ \t]*"/, ""); sub(/".*$/, ""); print; found = 1; exit
    }
    END { if (!found) print "ctrl+b" }
  ' "$1" 2>/dev/null
}

# prefix_saved prints the saved choice, or nothing.
prefix_saved() {
  local key
  key="$(head -n 1 "$PREFIX_FILE" 2>/dev/null | tr -d '[:space:]')"
  prefix_valid_text "$key" && printf '%s\n' "$key"
}

# prefix_valid_text KEY succeeds if KEY can stand in a TOML string with no
# escape: no quote, no backslash, and no space.
prefix_valid_text() {
  case "$1" in
    "" | *'"'* | *\\* | *[[:space:]]*) return 1 ;;
  esac
}

# prefix_write SRC KEY OUT writes SRC to OUT, with KEY as the prefix of the
# [keys] table. If the table has no prefix line, the line goes first in it.
prefix_write() {
  awk -v key="$2" '
    function put() { print "prefix = \"" key "\""; done = 1 }
    /^\[/ {
      if (keys && !done) put()
      keys = ($0 == "[keys]"); print; next
    }
    keys && !done && /^prefix[ \t]*=/ { put(); next }
    { print }
    END { if (keys && !done) put() }
  ' "$1" >"$3"
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

# prefix_check FILE prints the problems that Herdr finds in FILE, and fails
# if there is one. With no herdr, it succeeds.
prefix_check() {
  command -v herdr >/dev/null 2>&1 || return 0
  local out
  out="$(HERDR_CONFIG_PATH="$1" herdr config check 2>&1)" || true
  case "$out" in
    'config: ok'*) return 0 ;;
  esac
  printf '%s\n' "$out" | sed -n '2,$p'
  return 1
}

# prefix_manifest_update FILE OLD_SHA NEW_SHA records NEW_SHA for FILE in the
# manifest of the setup, if the manifest has OLD_SHA for it. Then the next
# update sees a file that no person changed, and replaces it with no question.
prefix_manifest_update() {
  local manifest="${HOME}/.local/share/herdspace/manifest.tsv" tmp
  [ -f "$manifest" ] || return 0
  awk -F '\t' -v d="$1" -v s="$2" '$1 == d && $2 == s {found = 1} END {exit !found}' "$manifest" || return 0
  tmp="$(mktemp)" || return 0
  awk -F '\t' -v d="$1" '$1 != d' "$manifest" >"$tmp"
  printf '%s\t%s\n' "$1" "$3" >>"$tmp"
  cat "$tmp" >"$manifest"
  rm -f "$tmp"
}

# prefix_reload applies the configuration to each running Herdr server. The
# panes stay.
prefix_reload() {
  command -v herdr >/dev/null 2>&1 || return 0
  local name any=0
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    any=1
    if herdr --session "$name" server reload-config >/dev/null 2>&1; then
      printf '  Session %s uses the new prefix now.\n' "$name"
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

# cmd_prefix [KEY|default] shows or changes the prefix key of Herdr. The
# choice goes to ~/.config/herdspace/prefix, so that an update keeps it, and
# to the Herdr configuration, which each running server reloads.
cmd_prefix() {
  local want="${1:-}" now label tmp old new
  if [ -f "$PREFIX_CONFIG" ]; then now="$(prefix_of "$PREFIX_CONFIG")"; else now="$(prefix_saved || echo "$PREFIX_DEFAULT")"; fi
  label="$(prefix_label "$now")"
  if [ -z "$want" ]; then
    printf '  The prefix: %s. Press %s, release it, then press one more key.\n' "$label" "$label"
    printf '  To change it, run: herdspace prefix KEY, for example: herdspace prefix ctrl+a\n'
    printf '  To go back to %s, run: herdspace prefix default\n' "$(prefix_label "$PREFIX_DEFAULT")"
    return 0
  fi
  want="$(printf '%s' "$want" | tr '[:upper:]' '[:lower:]')"
  [ "$want" != default ] || want="$PREFIX_DEFAULT"
  prefix_valid_text "$want" || { printf "herdspace: '%s' is not a key. Use a key such as ctrl+space or ctrl+a.\n" "$1" >&2; exit 2; }
  if [ "$want" = "$now" ]; then
    printf '  The prefix is %s already. Nothing to change.\n' "$label"
    return 0
  fi
  if [ -f "$PREFIX_CONFIG" ]; then
    tmp="$(mktemp)" || die "Could not make a temporary file."
    prefix_write "$PREFIX_CONFIG" "$want" "$tmp"
    if ! prefix_check "$tmp" >"${tmp}.err"; then
      printf "herdspace: Herdr does not accept '%s' as the prefix:\n" "$want" >&2
      sed 's/^/  /' "${tmp}.err" >&2
      rm -f "$tmp" "${tmp}.err"
      exit 2
    fi
    old="$(sha_of "$PREFIX_CONFIG")"
    cat "$tmp" >"$PREFIX_CONFIG" || { rm -f "$tmp" "${tmp}.err"; die "Could not write ${PREFIX_CONFIG}."; }
    rm -f "$tmp" "${tmp}.err"
    new="$(sha_of "$PREFIX_CONFIG")"
    prefix_manifest_update "$PREFIX_CONFIG" "$old" "$new"
  fi
  if [ "$want" = "$PREFIX_DEFAULT" ]; then
    rm -f "$PREFIX_FILE"
  elif ! { mkdir -p "$(dirname "$PREFIX_FILE")" && printf '%s\n' "$want" >"$PREFIX_FILE"; }; then
    die "Could not write ${PREFIX_FILE}."
  fi
  if [ -f "$PREFIX_CONFIG" ]; then
    printf '  The prefix: %s. An update keeps it.\n' "$(prefix_label "$want")"
    prefix_reload
  else
    printf '  The prefix: %s. This machine has no Herdr configuration yet. The setup of a server uses the prefix.\n' "$(prefix_label "$want")"
  fi
}
