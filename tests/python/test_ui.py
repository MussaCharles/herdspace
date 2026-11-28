"""Unit tests for lib/hopen/ui.py. The numbered menu runs with TERM=dumb, and
each answer comes from a function in place of the terminal."""
import contextlib
import io
import os
import unittest
from unittest import mock

import helpers  # noqa: F401  (puts lib/ on sys.path)

from hopen import ui

ITEMS = "a\tAlpha one\nb\tBeta two"


def answer(text):
    return lambda: text


@mock.patch.dict(os.environ, {"TERM": "dumb"})
class NumberedMenuTest(unittest.TestCase):
    def ask(self, func, *args):
        with contextlib.redirect_stderr(io.StringIO()) as err:
            result = func(*args)
        self.shown = err.getvalue()
        return result

    def test_a_number_or_a_key_chooses(self):
        self.assertEqual(self.ask(ui.choose, "Pick", ITEMS, answer("2")), "b")
        self.assertIn("   1) Alpha one\n   2) Beta two\n  Pick? Type a number or a name: ", self.shown)
        self.assertEqual(self.ask(ui.choose, "Pick", ITEMS, answer("a")), "a")

    def test_no_answer_cancels(self):
        self.assertEqual(self.ask(ui.choose, "Pick", ITEMS, answer("")), "")

    def test_an_unknown_answer_raises(self):
        for text in ("zz", "9", "0"):
            with self.assertRaises(ui.NoItem):
                self.ask(ui.choose, "Pick", ITEMS, answer(text))

    def test_pick_folders_takes_numbers(self):
        self.assertEqual(self.ask(ui.pick_folders, "src\ndocs\nlib", answer("1 3")), ["src", "lib"])
        with self.assertRaises(ui.NoItem) as stop:
            self.ask(ui.pick_folders, "src\ndocs\nlib", answer("2 x"))
        self.assertEqual(stop.exception.picked, ["docs"])

    def test_confirm_says_no_by_default(self):
        self.assertTrue(self.ask(ui.confirm, "Remove it?", answer("y")))
        self.assertFalse(self.ask(ui.confirm, "Remove it?", answer("")))
        self.assertFalse(self.ask(ui.confirm, "Remove it?", answer("no")))
        self.assertEqual(self.shown, "  Remove it? [y/N] ")

    def test_ask_text_returns_the_line(self):
        self.assertEqual(self.ask(ui.ask_text, "Name", answer("hello world")), "hello world")


class LookTest(unittest.TestCase):
    def test_sgr_and_group_colors(self):
        self.assertEqual(ui.sgr("#ff79c6"), "\033[38;2;255;121;198m")
        self.assertEqual(ui.group_color("Files"), "#ffb86c")
        self.assertEqual(ui.group_color("Help"), ui.UI_FG)

    @mock.patch.dict(os.environ, {"NO_COLOR": "1"})
    def test_no_color_turns_the_colors_off(self):
        self.assertFalse(ui.ui_color())
        self.assertIn("--no-color", ui.fzf_command("Menu"))
        self.assertEqual(ui.dim_folders(["a/b.txt"]), ["a/b.txt"])

    @mock.patch.dict(os.environ, {"NO_COLOR": ""})
    def test_the_folder_of_a_file_is_dim(self):
        self.assertEqual(ui.dim_folders(["src/app/main.py", "top.txt"]),
                         [ui.sgr(ui.UI_DIM) + "src/app/" + ui.RESET + "main.py", "top.txt"])
        command = ui.fzf_command("Menu", "--reverse")
        self.assertEqual(command[:5], ["fzf", "--border", "rounded", "--border-label", " Menu "])
        self.assertEqual(command[-1], "--reverse")


if __name__ == "__main__":
    unittest.main()
