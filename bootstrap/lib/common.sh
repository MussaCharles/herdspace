#!/usr/bin/env bash
# Shared helpers. This file works with the bash 3.2 that macOS ships.

STAMP="$(date +%Y%m%d-%H%M%S)"
export STATE_DIR="${HOME}/.local/share/herdspace"
# The person already agreed to the setup, so brew does not ask again before an
# install. Homebrew 7 asks by default. An older Homebrew ignores the variable.
export HOMEBREW_NO_ASK=1
# The script and its options, for the silent --check that lists the changed files.
HS_SELF="$0"
HS_ARGS=("$@")
# The docs of the release that runs. bootstrap.sh sets it.
HS_DOC_BASE="${HS_DOC_BASE:-https://github.com/MussaCharles/herdspace/blob/main}"

# The parts of the shared helpers, in files next to this one. Plain bash finds
# the folder, because a test can run with a PATH of stub commands only.
BOOTSTRAP_LIB="${BASH_SOURCE[0]%/*}"
[ "$BOOTSTRAP_LIB" != "${BASH_SOURCE[0]}" ] || BOOTSTRAP_LIB="."
# shellcheck source=bootstrap/lib/ui.sh
source "${BOOTSTRAP_LIB}/ui.sh"

# What the script does with a file that a person changed:
#   ask      ask about each file. With no terminal, keep the file.
#   check    change nothing, and report.
#   keep     keep each changed file, and add only what is missing.
#   replace  use the file from this repository, and keep a backup.
MODE="ask"
CHANGED=0
TODO=0
EDITED=0
KEPT_LIST=""
BACKUP_LIST=""
ASK_ALL=""
# The rows of the summary table: label, result, and seconds, one line each.
SUMMARY=""
# The changed files of this run, from a silent --check, for "File 1 of 6".
CHANGED_FILES=""
CHANGED_FILES_READY=0
# 1 when a run kept ~/.zshrc with no block that loads herdspace.
ZSHRC_KEPT_NO_EXTRAS=0
# shellcheck disable=SC2034 # prereqs.sh reads ASSUME_YES.
ASSUME_YES=0
MANIFEST="${STATE_DIR}/manifest.tsv"

# apply_mode_flag sets MODE. It returns 1 if the option is something else.
# shellcheck disable=SC2034 # prereqs.sh reads ASSUME_YES.
apply_mode_flag() {
  case "$1" in
    --check) MODE="check" ;;
    --keep-existing) MODE="keep" ;;
    --replace-all) MODE="replace" ;;
    --yes) ASSUME_YES=1 ;;
    *) return 1 ;;
  esac
}

# print_usage prints the comment at the top of a script.
print_usage() {
  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$1"
}

# shellcheck source=bootstrap/lib/files.sh
source "${BOOTSTRAP_LIB}/files.sh"
# shellcheck source=bootstrap/lib/ask.sh
source "${BOOTSTRAP_LIB}/ask.sh"
# shellcheck source=bootstrap/lib/run.sh
source "${BOOTSTRAP_LIB}/run.sh"
# shellcheck source=bootstrap/lib/tools.sh
source "${BOOTSTRAP_LIB}/tools.sh"
