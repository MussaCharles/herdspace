"""Unit tests for lib/hopen/look.py and the theme and color actions of the palette."""
import contextlib
import io
import os
import pathlib
import re
import tempfile
import unittest
from unittest import mock

import helpers  # noqa: F401  (puts lib/ on sys.path)

from hopen import look, palette, panes

REPO = pathlib.Path(__file__).resolve().parents[2]


def write_config(home, text):
    path = pathlib.Path(home, ".config", "herdr", "config.toml")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def shell_list(name):
    """The lines of a list variable of lib/herdspace/theme.sh."""
    text = (REPO / "lib" / "herdspace" / "theme.sh").read_text()
    return re.search(rf'^{name}="([^"]*)"', text, re.M).group(1)


@mock.patch.dict(os.environ, {"HERDR_CONFIG_PATH": ""})
class LookTest(unittest.TestCase):
    def test_the_lists_match_the_herdspace_command(self):
        self.assertEqual(shell_list("THEMES").split(), [name for name, _, _ in look.THEMES])
        pairs = [tuple(line.split()) for line in shell_list("COLORS").split("\n")]
        self.assertEqual(pairs, look.COLORS)
        self.assertIn(f'THEME_DEFAULT="{look.THEME_DEFAULT}"', (REPO / "lib" / "herdspace" / "theme.sh").read_text())

    def test_the_repository_configuration(self):
        with tempfile.TemporaryDirectory() as home:
            write_config(home, (REPO / "config" / "herdr" / "config.toml").read_text())
            self.assertEqual(look.theme(home), "dracula")
            self.assertEqual(look.accent(home), "")
            self.assertEqual(look.color_name(look.accent(home)), "theme color")

    def test_a_chosen_theme_and_color(self):
        with tempfile.TemporaryDirectory() as home:
            write_config(home, '[theme]\nname = "nord"\n[theme.custom]\naccent = "#ec4899"\n')
            self.assertEqual(look.theme(home), "nord")
            self.assertEqual(look.color_name(look.accent(home)), "pink")
            write_config(home, '[theme.custom]\naccent = "#123456"\n')
            self.assertEqual(look.theme(home), "catppuccin")
            self.assertEqual(look.color_name(look.accent(home)), "#123456")

    def test_the_rows_start_with_random_and_mark_the_current_value(self):
        rows = look.theme_rows("nord", False).split("\n")
        self.assertEqual(rows[0].split("\t")[0], "random")
        self.assertEqual(len(rows), len(look.THEMES) + 1)
        self.assertTrue(next(r for r in rows if r.startswith("nord\t")).endswith("(now)"))
        colors = look.color_rows("", False).split("\n")
        self.assertEqual([r.split("\t")[0] for r in colors[:2]], ["random", "default"])
        self.assertTrue(colors[1].endswith("(now)"))
        self.assertIn("pink       #ec4899", look.color_rows("#ec4899", False))

    def test_samples_have_color_only_in_a_color_menu(self):
        self.assertNotIn("\033", look.theme_rows("nord", False))
        self.assertIn("\033[48;2;46;52;64m", look.theme_rows("nord", True))
        self.assertIn("\033[38;2;236;72;153m", look.color_rows("", True))


@mock.patch.dict(os.environ, {"HERDR_CONFIG_PATH": ""})
class PaletteLookTest(unittest.TestCase):
    def context(self, home):
        return palette.Context("/w", "/bin/hopen", home, panes.Place("p1", "ws1", "t1"))

    def run_action(self, function, answer, home):
        group = palette.group_module("herdspace")
        with mock.patch.object(group, "choose_look", return_value=answer), \
                mock.patch.object(group, "then_wait", return_value=0) as wait, \
                contextlib.redirect_stdout(io.StringIO()):
            try:
                function(self.context(home), "x")
            except SystemExit:
                pass
        return wait

    def test_the_rows_show_the_current_values(self):
        with tempfile.TemporaryDirectory() as home:
            write_config(home, '[theme]\nname = "nord"\n[theme.custom]\naccent = "#ec4899"\n')
            pathlib.Path(home, ".local", "share", "herdspace").mkdir(parents=True)
            pathlib.Path(home, ".local", "share", "herdspace", "last-setup").write_text("role=server\n")
            ctx = self.context(home)
            with mock.patch("shutil.which", return_value="/bin/herdspace"):
                palette.group_module("herdspace").items(ctx)
            lines = {item[0]: item[2] for item in ctx.items}
            self.assertTrue(lines["hs-theme"].endswith("now nord"))
            self.assertTrue(lines["hs-color"].endswith("now pink"))

    def test_a_theme_runs_herdspace_theme(self):
        group = palette.group_module("herdspace")
        with tempfile.TemporaryDirectory() as home:
            write_config(home, '[theme]\nname = "dracula"\n')
            self.run_action(group.change_theme, "nord", home).assert_called_once_with("herdspace", "theme", "nord")
            self.run_action(group.change_theme, "random", home).assert_called_once_with("herdspace", "theme", "random")
            self.run_action(group.change_theme, "dracula", home).assert_not_called()
            self.run_action(group.change_theme, "", home).assert_not_called()

    def test_a_color_runs_herdspace_color(self):
        group = palette.group_module("herdspace")
        with tempfile.TemporaryDirectory() as home:
            write_config(home, '[theme.custom]\naccent = "#ec4899"\n')
            self.run_action(group.change_color, "blue", home).assert_called_once_with("herdspace", "color", "blue")
            self.run_action(group.change_color, "default", home).assert_called_once_with("herdspace", "color", "default")
            self.run_action(group.change_color, "pink", home).assert_not_called()
            write_config(home, '[theme]\nname = "dracula"\n')
            self.run_action(group.change_color, "default", home).assert_not_called()


if __name__ == "__main__":
    unittest.main()
