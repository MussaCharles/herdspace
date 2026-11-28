"""hopen with a PATH that has no git, fd, rg, fzf, lsof, or herdr: a missing
program is a failed command, as in bash, and never a Python traceback."""
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
TOOLS = ["bash", "sh", "dirname", "readlink", "basename", "cat", "env", "find", "sed"]


class MissingProgramsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = pathlib.Path(self.tmp.name).resolve()
        self.home, self.bin = base / "home", base / "bin"
        (self.home / "w" / "api").mkdir(parents=True)
        (self.home / "w" / "herdspace.toml").write_text('[[project]]\nname = "api"\npath = "./api"\n'
                                                       '[project.tasks]\ntest = "echo ok"\n')
        self.bin.mkdir()
        for tool in TOOLS:
            found = shutil.which(tool)
            if found:
                (self.bin / tool).symlink_to(found)
        (self.bin / "python3").symlink_to(sys.executable)

    def tearDown(self):
        self.tmp.cleanup()

    def hopen(self, *args, cwd=None):
        env = {"HOME": str(self.home), "PATH": str(self.bin), "TERM": "dumb", "PWD": str(cwd or self.home)}
        return subprocess.run([str(ROOT / "bin" / "hopen"), *args], cwd=cwd or self.home, env=env,
                              capture_output=True, text=True, stdin=subprocess.DEVNULL, timeout=60)

    def assert_no_traceback(self, result):
        self.assertNotIn("Traceback", result.stderr + result.stdout)

    def test_the_palette_lists_its_actions(self):
        for folder in (self.home, self.home / "w" / "api"):
            result = self.hopen("--palette", "--print", cwd=folder)
            self.assert_no_traceback(result)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("ports\tNetwork:", result.stdout)

    def test_the_other_commands(self):
        for args in (["--list"], ["--templates"], ["--complete", "lists"], ["--ports"], ["--version"]):
            result = self.hopen(*args)
            self.assert_no_traceback(result)
            self.assertEqual(result.returncode, 0, f"{args}: {result.stderr}")
        result = self.hopen("--list")
        self.assertIn("stopped", result.stdout)

    def test_a_task_runs_with_no_herdr(self):
        result = self.hopen("--task", "test", "--trust", cwd=self.home / "w" / "api")
        self.assert_no_traceback(result)
        self.assertIn("ok", result.stdout)

    def test_find_with_no_fzf_says_what_is_missing(self):
        result = self.hopen("--find")
        self.assert_no_traceback(result)
        self.assertEqual(result.returncode, 1)
        self.assertIn("needs fzf", result.stderr)


if __name__ == "__main__":
    unittest.main()
