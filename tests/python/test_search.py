"""Unit tests for lib/hopen/search.py, the file lists and the text search."""
import os
import pathlib
import tempfile
import unittest
from unittest import mock

import helpers  # noqa: F401  (puts lib/ on sys.path)

from hopen import search


def which(*present):
    return lambda name: f"/usr/bin/{name}" if name in present else None


class SearchTest(unittest.TestCase):
    def test_a_name_that_starts_with_a_dash_is_never_an_option(self):
        self.assertEqual(search.search_dir("-x/"), "./-x")
        self.assertEqual(search.search_dir("build/"), "build")

    @mock.patch("shutil.which", which("fdfind"))
    def test_fdfind_on_debian(self):
        self.assertEqual(search.files_command([]), ["fdfind", "--type", "f", "--hidden", "--exclude", ".git"])

    @mock.patch("shutil.which", which("fd"))
    def test_the_ignored_files_of_the_chosen_folders(self):
        command = search.files_command(["build"])
        self.assertEqual(command[:4], ["fd", "--type", "f", "--hidden"])
        self.assertIn("--no-ignore-vcs", command)
        self.assertIn("node_modules", command)
        self.assertEqual(command[-2:], [".", "build"])

    @mock.patch("shutil.which", which())
    def test_find_with_no_fd(self):
        self.assertEqual(search.files_command([]), ["find", ".", "-type", "f", "!", "-path", "*/.git/*"])
        self.assertEqual(search.files_command(["a"]), ["find", "a", "-type", "f", "!", "-path", "*/.git/*"])

    def test_the_text_is_never_an_option(self):
        command = search.text_command("-rf", ["./-x"])
        self.assertEqual(command[command.index("--") + 1:], ["-rf", "./-x"])
        self.assertIn("--glob", command)
        self.assertNotIn("--hidden", search.text_command("x", []))

    @mock.patch("shutil.which", which())
    def test_the_folders_with_find(self):
        with tempfile.TemporaryDirectory() as tmp:
            for name in ("src/app", ".git/objects", "build"):
                (pathlib.Path(tmp) / name).mkdir(parents=True)
            old = os.getcwd()
            os.chdir(tmp)
            try:
                folders = sorted(search.list_folders())
            finally:
                os.chdir(old)
        self.assertEqual(folders, ["build", "src", "src/app"])


if __name__ == "__main__":
    unittest.main()
