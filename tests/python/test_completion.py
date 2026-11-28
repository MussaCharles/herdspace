"""Unit tests for lib/hopen/completion.py."""
import io
import unittest
from contextlib import redirect_stderr

import helpers  # noqa: F401  (puts lib/ on sys.path)

from hopen import completion


class CompletionTest(unittest.TestCase):
    def test_zsh_asks_hopen_for_the_names(self):
        text = completion.completion_script("zsh")
        self.assertTrue(text.startswith("#compdef hopen\n"))
        self.assertIn("hopen --complete lists", text)
        self.assertIn("--palette", text)

    def test_bash_works_with_bash_3_2(self):
        text = completion.completion_script("bash")
        self.assertIn("complete -o filenames -F _hopen hopen", text)
        code = "\n".join(line for line in text.split("\n") if not line.lstrip().startswith("#"))
        self.assertNotIn("mapfile", code)
        self.assertNotIn("compopt", code)

    def test_another_shell_stops(self):
        with redirect_stderr(io.StringIO()) as err, self.assertRaises(SystemExit) as stop:
            completion.completion_script("fish")
        self.assertEqual(stop.exception.code, 1)
        self.assertIn("needs zsh or bash", err.getvalue())


if __name__ == "__main__":
    unittest.main()
