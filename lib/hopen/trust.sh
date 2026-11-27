# shellcheck shell=bash
# The trust of the commands of a list: hopen runs a command of a list only after the person trusts it.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# list_actions ITEMS prints each command and environment value of a list.
list_actions() {
  awk -F '\036' '
    ($1 == "R" || $1 == "P") && $5 != "-" { print "    " $2 ": run " $5 }
    ($1 == "R" || $1 == "P") && $6 != "-" { gsub("\037", ", ", $6); print "    " $2 ": set " $6 }
    $1 == "T" && $5 != "-" { print "    " $2 ", tab " $3 ": run " $5 }
    $1 == "F" { print "    " $2 ": load " $3 " (" $4 ")" }
    $1 == "K" { print "    " $2 ", task " $3 ": run " $4 }
  ' <<<"$1"
}

# file_hash FILE [EXTRA] prints the checksum of FILE. EXTRA is the values that
# the list loads from env files, so that a change to them asks again. EXTRA
# goes on stdin, because another user can read the arguments of a process.
file_hash() {
  printf '%s' "${2:-}" | python3 -I -c '
import hashlib, sys
digest = hashlib.sha256(open(sys.argv[1], "rb").read())
extra = sys.stdin.buffer.read()
if extra:
    digest.update(b"\0" + extra)
print(digest.hexdigest())
' "$1"
}
trust_file() { printf '%s/trusted.tsv' "$STATE_DIR"; }

# list_trusted FILE ACTIONS [EXTRA] exits 0 if hopen can use the commands and values of
# FILE: the person approved this version of the file before, approves it now,
# or gave --trust. A changed file needs a new approval.
list_trusted() {
  local file="$1" actions="$2" hash answer
  hash="$(file_hash "$file" "${3:-}")" || return 1
  [[ "$hash" =~ ^[0-9a-f]{64}$ ]] || return 1
  awk -F '\t' -v f="$file" -v h="$hash" '$1 == f && $2 == h { found = 1 } END { exit !found }' "$(trust_file)" 2>/dev/null && return 0
  if [ "$TRUST_FLAG" -ne 1 ]; then
    [ -t 0 ] || return 1
    printf '  [info] %s runs these commands and sets these values:\n%s\n' "$(short_path "$file")" "$actions"
    printf '  Use them? Answer yes only for a list that you trust. [y/N] '
    IFS= read -r answer || answer=""
    case "$answer" in y | Y | yes | Yes) ;; *) return 1 ;; esac
  fi
  mkdir -p "$STATE_DIR"
  { awk -F '\t' -v f="$file" '$1 != f' "$(trust_file)" 2>/dev/null || true; printf '%s\t%s\n' "$file" "$hash"; } >"$(trust_file).new"
  mv "$(trust_file).new" "$(trust_file)"
}
