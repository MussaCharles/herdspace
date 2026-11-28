# shellcheck shell=bash
# The Herdr panes: wait for one, split, open a tab, find the editor of a tab, and open a file in it.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.
# lib/hopen/panes.py does the work. Each command gets PAL_PANE, PAL_WS,
# PAL_TAB, and PAL_PLACE of the palette as its first four arguments.

# in_popup exits 0 in a Herdr popup, which closes when its command ends.
in_popup() { [ -z "${HERDR_PANE_ID:-}" ] && [ -n "${HERDR_ACTIVE_PANE_ID:-}" ]; }

# new_tab_run LABEL DIR COMMAND opens a new tab in the current workspace and
# runs COMMAND in it.
new_tab_run() { hopen_py internal new-tab-run "${PAL_PANE:-}" "${PAL_WS:-}" "${PAL_TAB:-}" "${PAL_PLACE:-}" "$@" || exit $?; }

# split_run DIRECTION DIR [COMMAND] splits the current pane, and runs COMMAND
# in the new pane.
split_run() { hopen_py internal split-run "${PAL_PANE:-}" "${PAL_WS:-}" "${PAL_TAB:-}" "${PAL_PLACE:-}" "$@" || exit $?; }

# run_at DEFAULT LABEL DIR [COMMAND] runs COMMAND in the place that the person
# chose in the palette (PAL_PLACE), or in DEFAULT: here, right, down, or tab.
# "here" replaces the palette with COMMAND. Outside Herdr, only "here" works.
run_at() { hopen_py internal run-at "${PAL_PANE:-}" "${PAL_WS:-}" "${PAL_TAB:-}" "${PAL_PLACE:-}" "$@" || exit $?; }
