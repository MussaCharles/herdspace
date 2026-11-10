#!/usr/bin/env bash
# test-idempotent.sh proves how a script behaves on a computer that it already
# set up: a complete run, a partial run, and each way to handle a changed file.
#
# Usage: tests/test-idempotent.sh SCRIPT SAMPLE_FILE [script options...]
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="${ROOT}/$1"
SAMPLE="$2"
shift 2
export PATH="${HOME}/.local/bin:${PATH}"
failures=0
pass() { printf 'PASS %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; failures=$((failures + 1)); }
contains() { case "$1" in *"$2"*) pass "$3" ;; *) fail "$3: wanted [$2] in [${1: -300}]" ;; esac; }
lacks() { case "$1" in *"$2"*) fail "$3: found [$2]" ;; *) pass "$3" ;; esac; }
run_script() { "$SCRIPT" "$@" 2>&1 </dev/null; }
backups() { find "$(dirname "$SAMPLE")" -maxdepth 1 -name '*.bak-*' | wc -l | tr -d ' '; }
clear_backups() { find "$(dirname "$SAMPLE")" -maxdepth 1 -name '*.bak-*' -delete; }

# A complete computer.
start="$(date +%s)"
out="$(run_script "$@")"
took=$(($(date +%s) - start))
contains "$out" 'Everything is already set up' 'complete: says that it is done'
lacks "$out" '[todo]' 'complete: nothing to do'
if [ "$took" -le 20 ]; then pass "complete: fast (${took}s)"; else fail "complete: fast (${took}s)"; fi
out="$(run_script --check "$@")"; rc=$?
contains "$out" 'Everything is already set up' 'check: says that it is done'
if [ "$rc" -eq 0 ]; then pass 'check: exit 0'; else fail "check: exit ${rc}"; fi

# A computer with one part missing.
cp "${HOME}/.p10k.zsh" "${HOME}/.p10k.saved"
rm -f "${HOME}/.p10k.zsh"
before="$(ls -l "$SAMPLE")"
out="$(run_script --check "$@")"; rc=$?
contains "$out" '.p10k.zsh is missing' 'partial check: names the missing file'
if [ "$rc" -eq 1 ]; then pass 'partial check: exit 1'; else fail "partial check: exit ${rc}"; fi
if [ ! -e "${HOME}/.p10k.zsh" ]; then pass 'partial check: changes nothing'; else fail 'partial check: changes nothing'; fi
out="$(run_script "$@")"
if cmp -s "${HOME}/.p10k.zsh" "${HOME}/.p10k.saved"; then pass 'partial: restores the file'; else fail 'partial: restores the file'; fi
lacks "$out" 'Everything is already set up' 'partial: reports work'
lacks "$out" '== System packages' 'partial: skips finished parts'
if [ "$before" = "$(ls -l "$SAMPLE")" ]; then pass 'partial: leaves other files'; else fail 'partial: leaves other files'; fi
rm -f "${HOME}/.p10k.saved"

# A changed file, with no terminal.
cp "$SAMPLE" "${SAMPLE}.saved"
echo '# a line that a person added' >>"$SAMPLE"
out="$(run_script --check "$@")"; rc=$?
contains "$out" 'differs from this repository' 'edited check: reports the file'
if [ "$rc" -eq 0 ]; then pass 'edited check: exit 0'; else fail "edited check: exit ${rc}"; fi
out="$(run_script "$@")"
contains "$out" 'Kept 1 files' 'edited: keeps with no terminal'
contains "$(tail -n 1 "$SAMPLE")" 'a person added' 'edited: the file is unchanged'
out="$(run_script --keep-existing "$@")"
contains "$(tail -n 1 "$SAMPLE")" 'a person added' 'keep-existing: the file is unchanged'
[ "$(backups)" = 0 ] && pass 'keep-existing: no backup' || fail 'keep-existing: no backup'

# A person answers the question.
out="$(python3 "${ROOT}/tests/pty_run.py" 16 'k\n' "$SCRIPT" "$@" 2>&1)"
contains "$out" 'differs from this repository' 'ask: asks about the file'
contains "$(tail -n 1 "$SAMPLE")" 'a person added' 'ask: keep leaves the file'
out="$(python3 "${ROOT}/tests/pty_run.py" 16 'r\n' "$SCRIPT" "$@" 2>&1)"
if cmp -s "$SAMPLE" "${SAMPLE}.saved"; then pass 'ask: replace uses the repository file'; else fail 'ask: replace uses the repository file'; fi
[ "$(backups)" = 1 ] && pass 'ask: replace keeps a backup' || fail "ask: replace keeps a backup: $(backups)"
clear_backups

# Replace everything.
echo '# a line that a person added' >>"$SAMPLE"
out="$(run_script --replace-all "$@")"
if cmp -s "$SAMPLE" "${SAMPLE}.saved"; then pass 'replace-all: uses the repository file'; else fail 'replace-all: uses the repository file'; fi
[ "$(backups)" = 1 ] && pass 'replace-all: keeps a backup' || fail 'replace-all: keeps a backup'
clear_backups

# A file from an older version that no person changed.
echo '# an older version' >"$SAMPLE"
# shellcheck source=bootstrap/lib/common.sh
( source "${ROOT}/bootstrap/lib/common.sh"; manifest_set "$SAMPLE" "$(file_sha "$SAMPLE")" )
out="$(run_script "$@")"
if cmp -s "$SAMPLE" "${SAMPLE}.saved"; then pass 'outdated: updates with no question'; else fail 'outdated: updates with no question'; fi
lacks "$out" 'Kept' 'outdated: is not kept'
clear_backups
rm -f "${SAMPLE}.saved"

out="$(run_script "$@")"
contains "$out" 'Everything is already set up' 'after all cases: done again'
printf 'RESULT idempotent failures=%s\n' "$failures"
[ "$failures" -eq 0 ]
