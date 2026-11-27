"""Unit tests for lib/hopen/lists.py, the reader of the project lists.

Each test writes a list in a temporary folder, runs lists.py with python3 -I
as read_list in lib/hopen/lists.sh does, and checks the lines that it prints.
They need only the standard library, and no Herdr. Run them with:

    python3 -m unittest discover -s tests/python
"""
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest

READER = pathlib.Path(__file__).resolve().parents[2] / "lib" / "hopen" / "lists.py"
RS = "\x1e"
US = "\x1f"


def read(path, what="items", template=""):
    """Run the reader, and return its lines split into fields."""
    out = subprocess.run(
        [sys.executable, "-I", str(READER), str(path), what, template],
        capture_output=True, text=True, check=True,
    ).stdout
    # Split at new lines only: splitlines() also splits at the byte 0x1e.
    return [line.split(RS) for line in out.split("\n") if line]


class ListReaderTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name).resolve() / "work"
        (self.root / "api").mkdir(parents=True)

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, name, text):
        path = self.root / name
        path.write_text(text)
        return path

    def toml(self):
        return self.write("herdspace.toml", "\n".join([
            'session = "work"',
            'template = "code"',
            'on_open = "echo hi"',
            "[env]",
            'A = "1"',
            "[[project]]",
            'name = "api"',
            'path = "./api"',
            "[[project.tabs]]",
            'name = "logs"',
            'run = "tail -f log"',
            "[project.tasks]",
            'test = "make test"',
            "",
        ]))

    def test_toml_session(self):
        self.assertEqual(read(self.toml(), "session"), [["work"]])

    def test_toml_items(self):
        lines = read(self.toml())
        self.assertEqual(lines[0], ["R", "work", str(self.root), "code", "echo hi", "A=1"])
        self.assertIn(["P", "api", str(self.root / "api"), "code", "-", "-"], lines)
        self.assertIn(["K", "api", "test", "make test"], lines)
        self.assertIn(["T", "api", "logs", "plain", "tail -f log"], lines)

    def test_env_values_use_the_unit_separator(self):
        path = self.write("herdspace.toml", '[env]\nA = "1"\nB = "2"\n[[project]]\nname = "api"\npath = "./api"\n')
        env = read(path)[0][5]
        self.assertEqual(sorted(env.split(US)), ["A=1", "B=2"])

    def test_a_template_name_with_a_path_is_refused(self):
        path = self.write("herdspace.toml", 'template = "code"\n[[project]]\nname = "api"\npath = "./api"\ntemplate = "../../x"\n')
        lines = read(path)
        self.assertTrue(any(f[0] == "W" and "../../x" in f[1] for f in lines))
        self.assertIn(["P", "api", str(self.root / "api"), "code", "-", "-"], lines)

    def test_the_template_option_wins(self):
        lines = read(self.toml(), template="grid")
        self.assertEqual({f[3] for f in lines if f[0] in ("R", "P")}, {"grid"})

    def test_vscode_file_with_comments_and_trailing_commas(self):
        path = self.write("w.code-workspace", "\n".join([
            "{",
            "  // a comment",
            '  "folders": [ { "name": "web", "path": "./api" }, ],',
            '  "settings": { "hopen.session": "vs" },',
            "}",
        ]))
        self.assertEqual(read(path, "session"), [["vs"]])
        self.assertIn(["P", "web", str(self.root / "api"), "plain", "-", "-"], read(path))

    def test_a_control_character_is_shown_as_a_question_mark(self):
        path = self.write("w.code-workspace", '{"folders": [{"name": "web\\u001b[31m", "path": "./api"}]}')
        names = [f[1] for f in read(path) if f[0] == "P"]
        self.assertEqual(names, ["web?[31m"])
        for fields in read(path):
            for value in fields:
                self.assertNotIn("\x1b", value)

    def test_an_empty_field_is_a_dash(self):
        path = self.write("herdspace.toml", '[[project]]\nname = "api"\npath = "./api"\n')
        parent = read(path)[0]
        self.assertEqual(parent[0], "R")
        self.assertEqual(parent[4:], ["-", "-"])


if __name__ == "__main__":
    unittest.main()
