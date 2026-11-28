"""Unit tests for lib/hopen/prefix.py and the prefix action of the palette."""
import contextlib
import io
import os
import pathlib
import tempfile
import unittest
from unittest import mock

import helpers  # noqa: F401  (puts lib/ on sys.path)

from hopen import palette, panes, prefix

REPO = pathlib.Path(__file__).resolve().parents[2]


def write_config(home, text):
    path = pathlib.Path(home, ".config", "herdr", "config.toml")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    return path


@mock.patch.dict(os.environ, {"HERDR_CONFIG_PATH": ""})
class PrefixTest(unittest.TestCase):
    def test_the_repository_configuration_uses_ctrl_space(self):
        with tempfile.TemporaryDirectory() as home:
            write_config(home, (REPO / "config" / "herdr" / "config.toml").read_text())
            self.assertEqual(prefix.current(home), "alt+space")
            self.assertEqual(prefix.now(home), "Alt+Space")

    def test_no_prefix_line_or_no_file_is_the_herdr_default(self):
        with tempfile.TemporaryDirectory() as home:
            self.assertEqual(prefix.current(home), "ctrl+b")
            write_config(home, '[keys]\nnew_tab = "prefix+c"\n')
            self.assertEqual(prefix.current(home), "ctrl+b")

    def test_only_the_keys_table_counts(self):
        with tempfile.TemporaryDirectory() as home:
            write_config(home, '[other]\nprefix = "ctrl+q"\n[keys]\nprefix = "ctrl+a"\n')
            self.assertEqual(prefix.current(home), "ctrl+a")
            write_config(home, '[other]\nprefix = "ctrl+q"\n')
            self.assertEqual(prefix.current(home), "ctrl+b")

    def test_herdr_config_path_wins(self):
        with tempfile.TemporaryDirectory() as home:
            write_config(home, '[keys]\nprefix = "ctrl+a"\n')
            other = pathlib.Path(home, "other.toml")
            other.write_text('[keys]\nprefix = "ctrl+s"\n')
            with mock.patch.dict(os.environ, {"HERDR_CONFIG_PATH": str(other)}):
                self.assertEqual(prefix.current(home), "ctrl+s")

    def test_label(self):
        self.assertEqual(prefix.label("alt+space"), "Alt+Space")
        self.assertEqual(prefix.label("ctrl+a"), "Ctrl+A")
        self.assertEqual(prefix.label("cmd+shift+k"), "Cmd+Shift+K")
        self.assertEqual(prefix.label("super+b"), "Cmd+B")
        self.assertEqual(prefix.label("§"), "§")


@mock.patch.dict(os.environ, {"HERDR_CONFIG_PATH": ""})
class PalettePrefixTest(unittest.TestCase):
    def context(self, home):
        return palette.Context("/w", "/bin/hopen", home, panes.Place("p1", "ws1", "t1"))

    def test_the_hints_show_the_current_prefix(self):
        with tempfile.TemporaryDirectory() as home:
            write_config(home, '[keys]\nprefix = "ctrl+a"\n')
            ctx = self.context(home)
            palette.group_module("layout").items(ctx)
            palette.group_module("tabs").items(ctx)
            lines = "\n".join(item[2] for item in ctx.items)
            self.assertIn("Ctrl+A V", lines)
            self.assertIn("Cmd+T, Ctrl+A C", lines)
            self.assertNotIn("Ctrl+B", lines)

    def test_the_rows_mark_the_current_prefix(self):
        group = palette.group_module("herdspace")
        rows = group.prefix_rows("ctrl+a").split("\n")
        self.assertEqual([row.split("\t")[0] for row in rows], ["alt+space", "ctrl+a", "ctrl+s", "ctrl+b", "other"])
        self.assertTrue(rows[1].endswith("(now)"))
        self.assertNotIn("(now)", rows[0])

    def test_a_choice_runs_herdspace_prefix(self):
        group = palette.group_module("herdspace")
        with tempfile.TemporaryDirectory() as home:
            write_config(home, '[keys]\nprefix = "alt+space"\n')
            ctx = self.context(home)
            with mock.patch.object(group, "choose", return_value="ctrl+a"), \
                    mock.patch.object(group, "then_wait", return_value=0) as wait, \
                    contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(group.change_prefix(ctx, "hs-prefix"), 0)
            wait.assert_called_once_with("herdspace", "prefix", "ctrl+a")

    def test_another_key_is_typed(self):
        group = palette.group_module("herdspace")
        with tempfile.TemporaryDirectory() as home:
            ctx = self.context(home)
            with mock.patch.object(group, "choose", return_value="other"), \
                    mock.patch.object(group.ui, "ask_text", return_value=" ctrl+q "), \
                    mock.patch.object(group, "then_wait", return_value=0) as wait, \
                    contextlib.redirect_stdout(io.StringIO()):
                group.change_prefix(ctx, "hs-prefix")
            wait.assert_called_once_with("herdspace", "prefix", "ctrl+q")

    def test_esc_or_the_same_key_changes_nothing(self):
        group = palette.group_module("herdspace")
        with tempfile.TemporaryDirectory() as home:
            write_config(home, '[keys]\nprefix = "alt+space"\n')
            ctx = self.context(home)
            for answer in ("", "alt+space"):
                with mock.patch.object(group, "choose", return_value=answer), \
                        mock.patch.object(group, "then_wait") as wait, \
                        contextlib.redirect_stdout(io.StringIO()):
                    with self.assertRaises(SystemExit):
                        group.change_prefix(ctx, "hs-prefix")
                wait.assert_not_called()


if __name__ == "__main__":
    unittest.main()
