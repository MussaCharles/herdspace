"""Unit tests for lib/hopen/palette/, the command palette."""
import contextlib
import io
import os
import pathlib
import tempfile
import unittest
from unittest import mock

import helpers  # noqa: F401  (puts lib/ on sys.path)

from hopen import palette, panes, ui


def context(pane=""):
    return palette.Context("/w", "/bin/hopen", "/h", panes.Place(pane, "ws1", "t1"))


class PaletteTest(unittest.TestCase):
    def test_each_action_of_each_table_has_one_group(self):
        for name in palette.GROUPS:
            for key in palette.group_module(name).ACTIONS:
                sample = key + "x" if key.endswith(":") else key
                self.assertEqual(palette.owner(sample), [name], key)

    @mock.patch.dict(os.environ, {"NO_COLOR": ""})
    def test_a_line_has_the_hint_at_the_right(self):
        ctx = context()
        ctx.add("ports", "Network", "Show the ports", "hopen --ports")
        action, group, line, color = ctx.items[0]
        self.assertEqual(line, "Network: Show the ports" + " " * 35 + " hopen --ports")
        self.assertEqual(len(line.split(" hopen")[0]), 58)
        self.assertTrue(color.startswith(ui.sgr("#a4ffff") + "Network" + ui.RESET + ": Show the ports"))
        self.assertTrue(color.endswith(ui.sgr(ui.UI_DIM) + "hopen --ports" + ui.RESET))

    def test_the_recent_list_keeps_five_ids_and_no_agent(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "herdspace", "palette-recent")
            for action in ("a", "b", "c", "d", "e", "f", "c", "agent:p1"):
                palette.remember(action, path)
            self.assertEqual(pathlib.Path(path).read_text(), "c\nf\ne\nd\nb\n")

    @mock.patch.dict(os.environ, {"TERM": "dumb"})
    def test_the_numbered_menu_takes_a_place_after_the_answer(self):
        ctx = context("p1")
        ctx.add("edit", "Files", "Open this folder in the editor", "nvim .")
        ctx.add("git", "Git", "Git status (lazygit)")
        with tempfile.TemporaryDirectory() as tmp, contextlib.redirect_stderr(io.StringIO()) as err:
            recent = os.path.join(tmp, "recent")
            self.assertEqual(palette.menu(ctx, recent, lambda: "edit right"), ("edit", "right"))
            self.assertEqual(palette.menu(ctx, recent, lambda: "2 tab"), ("git", "tab"))
            self.assertIsNone(palette.menu(ctx, recent, lambda: ""))
            with self.assertRaises(ui.NoItem):
                palette.menu(ctx, recent, lambda: "nope")
        self.assertIn("\n  Files\n    1) Files: Open this folder in the editor", err.getvalue())

    def test_an_action_runs_from_its_table(self):
        ctx = context()
        with mock.patch.object(palette.group_module("help"), "ACTIONS", {"docs": lambda c, a: 7}):
            self.assertEqual(palette.run(ctx, "docs"), 7)
        self.assertEqual(palette.run(ctx, "no-such-action"), 0)

    def test_the_session_command(self):
        projects = palette.group_module("projects")
        with mock.patch.dict(os.environ, {"HERDR_SESSION": "work"}):
            self.assertEqual(projects.session_command(), "herdr --session work")
        with mock.patch.dict(os.environ, {"HERDR_SESSION": "default"}):
            self.assertEqual(projects.session_command(), "herdr")

    def test_the_integration_lines(self):
        agents = palette.group_module("agents")
        out = "claude: current (v11)\nkimi (experimental): not installed\nodd line"
        with mock.patch.object(panes, "herdr", lambda *a: out):
            self.assertEqual(agents.integrations(), [("claude", "current (v11)"), ("kimi", "not installed"), ("odd line", "")])


if __name__ == "__main__":
    unittest.main()
