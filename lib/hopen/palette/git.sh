# shellcheck shell=bash
# The Git group of the command palette.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# worktrees DIR prints "path<TAB>branch<TAB>workspace" for each linked worktree.
worktrees() {
  herdr worktree list --cwd "$1" 2>/dev/null | python3 -c '
import json, sys
for w in json.load(sys.stdin).get("result", {}).get("worktrees", []):
    if w.get("is_linked_worktree"):
        print("\t".join([w.get("path", ""), w.get("branch") or "-", w.get("workspace_id") or ""]))' 2>/dev/null
}

# pal_items_git DIR adds the Git actions for DIR and the place.
pal_items_git() {
  local dir="$1"
  if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if command -v lazygit >/dev/null 2>&1; then
      pal_add git Git "Git status (lazygit)" "Cmd+Shift+G, Ctrl+B D"
      [ -z "$PAL_PANE" ] || pal_add git-tab Git "Open lazygit in a new tab" "lazygit"
    fi
    if [ -n "$PAL_PANE" ]; then
      pal_add wt-new Git "New worktree for an agent, on a new branch" "Ctrl+B Shift+G"
      pal_add wt-open Git "Open a worktree" "herdr worktree open"
      pal_add wt-list Git "Show the worktrees" "herdr worktree list"
      pal_add wt-remove Git "Remove a worktree" "herdr worktree remove"
    fi
  fi
}

# pal_run_git ID DIR runs the action ID of the Git group. For an ID of another
# group, it sets PAL_MISS=1.
pal_run_git() {
  local choice="$1" dir="$2" name pick
  case "$choice" in
    git) run_at here git "$dir" lazygit ;;
    git-tab) run_at tab git "$dir" lazygit ;;
    wt-new)
      name="$(ask_text 'The name of the new branch')"
      [ -n "$name" ] || exit 0
      then_wait herdr worktree create --cwd "$dir" --branch "$name" --focus
      ;;
    wt-open | wt-remove)
      pick="$(worktrees "$dir" | awk -F '\t' '{ print $1 "\t" $2 "  " $1 }' | choose "Worktree")" || exit 1
      [ -n "$pick" ] || exit 0
      if [ "$choice" = wt-open ] && [ -n "${PAL_PLACE:-}" ]; then
        run_at here "$(basename "$pick")" "$pick"
      elif [ "$choice" = wt-open ]; then
        herdr worktree open --cwd "$dir" --path "$pick" --focus >/dev/null
      else
        name="$(worktrees "$dir" | awk -F '\t' -v p="$pick" '$1 == p { print $3 }')"
        [ -n "$name" ] || { then_wait printf '  The worktree %s has no workspace. Open it first, then remove it.\n' "$pick"; exit 0; }
        confirm "Remove the worktree ${pick}? Changes that you did not commit are lost." || exit 0
        then_wait herdr worktree remove --workspace "$name"
      fi
      ;;
    wt-list) then_wait sh -c 'herdr worktree list --cwd "$1" | python3 -c "import json,sys; [print(\"  \"+(w.get(\"branch\") or \"-\")+\"  \"+w.get(\"path\",\"\")) for w in json.load(sys.stdin).get(\"result\",{}).get(\"worktrees\",[])]"' _ "$dir" ;;
    *) PAL_MISS=1 ;;
  esac
}
