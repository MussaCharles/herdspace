#!/usr/bin/env bash
# test-palette-groups.sh lists the actions of the command palette with
# "hopen --palette --print", in a temporary home folder with stub commands, in
# Herdr and outside it. Each action must have exactly one group in
# lib/hopen/palette/ that runs it. It needs no Herdr and no network.
#
# Usage: tests/test-palette-groups.sh [OLD_HOPEN]
#   With OLD_HOPEN, it also compares the actions with those of an older hopen.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
ROOT="$(pwd)"
failures=0
pass() { printf 'PASS %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; failures=$((failures + 1)); }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
home="${tmp}/home"
stub="${tmp}/stub"
mkdir -p "$home/.local/share/herdspace" "$stub" "$home/proj"
printf 'role=both\n' >"$home/.local/share/herdspace/last-setup"
cat >"$home/proj/herdspace.toml" <<'TOML'
[[project]]
name = "proj"
path = "."

[tasks]
test = "make test"
TOML
git -C "$home/proj" init -q

# The stub herdr answers the commands that the palette reads.
cat >"${stub}/herdr" <<'SH'
#!/bin/sh
case "$1 $2" in
  "agent list") echo '{"result":{"agents":[{"pane_id":"p9","agent":"claude","agent_status":"idle","cwd":"/tmp"}]}}' ;;
  "worktree list") echo '{"result":{"worktrees":[]}}' ;;
  "integration status") echo 'claude: current (v11)' ;;
esac
exit 0
SH
for cmd in herdspace lazygit fzf rg nvim claude codex; do printf '#!/bin/sh\nexit 0\n' >"${stub}/${cmd}"; done
chmod +x "$stub"/*

print_actions() {
  local hopen="$1" pane="$2"
  (cd "$home/proj" && env -i HOME="$home" PATH="${stub}:$(dirname "$(command -v python3)"):/usr/bin:/bin" \
    TERM=dumb HERDR_PANE_ID="$pane" HERDR_SESSION=default "$hopen" --palette --print)
}

groups="$(python3 -I -c 'import ast, sys
tree = ast.parse(open(sys.argv[1]).read())
for node in tree.body:
    if isinstance(node, ast.Assign) and getattr(node.targets[0], "id", "") == "GROUPS":
        print(" ".join(ast.literal_eval(node.value)))' "${ROOT}/lib/hopen/palette/__init__.py")"
[ -n "$groups" ] && pass "the palette names the groups" || fail "the palette names the groups"
for g in $groups; do
  [ -f "${ROOT}/lib/hopen/palette/${g}.py" ] && grep -q '^ACTIONS = {' "${ROOT}/lib/hopen/palette/${g}.py" &&
    pass "the group ${g} has a file with its table of actions" || fail "the group ${g} has a file with its table of actions"
done

for pane in "" p1; do
  where="outside Herdr"
  [ -z "$pane" ] || where="in Herdr"
  ids="$(print_actions "${ROOT}/bin/hopen" "$pane" | cut -f1)"
  [ "$(grep -c . <<<"$ids")" -ge 15 ] && pass "the palette lists actions ${where}" || fail "the palette lists actions ${where}: ${ids}"
  # owners prints "id<TAB>group..." for each id: the groups whose table has it.
  bad="$(python3 -I -B "${ROOT}/lib/hopen/__main__.py" internal palette-owner $ids | awk -F '\t' 'split($2, g, " ") != 1 { printf " %s(%d)", $1, split($2, g, " ") }')"
  [ -z "$bad" ] && pass "each action ${where} has exactly one group that runs it" || fail "each action ${where} has exactly one group that runs it:${bad}"
  if [ -n "${1:-}" ]; then
    if diff <(print_actions "$1" "$pane") <(print_actions "${ROOT}/bin/hopen" "$pane") >"${tmp}/diff"; then
      pass "the actions ${where} are the same as those of the older hopen"
    else
      fail "the actions ${where} are the same as those of the older hopen: $(head -c 400 "${tmp}/diff")"
    fi
  fi
done

echo "RESULT palette-groups failures=${failures}"
exit $((failures > 0))
