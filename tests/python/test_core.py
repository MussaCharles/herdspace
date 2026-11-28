"""Unit tests for lib/hopen/core.py."""
import io
import unittest
from contextlib import redirect_stderr

import helpers  # noqa: F401  (puts lib/ on sys.path)

from hopen import core


class CoreTest(unittest.TestCase):
    def test_valid_name(self):
        for name in ("work", "my-projects", "a.b_c", "0"):
            self.assertTrue(core.valid_name(name), name)
        for name in ("", "a b", "a/b", "ä", "x\\n"):
            self.assertFalse(core.valid_name(name), name)

    def test_short_path(self):
        self.assertEqual(core.short_path("/home/me/code", "/home/me"), "~/code")
        self.assertEqual(core.short_path("/srv/code", "/home/me"), "/srv/code")

    def test_fail_prints_the_error_and_exits_with_1(self):
        err = io.StringIO()
        with redirect_stderr(err), self.assertRaises(SystemExit) as stop:
            raise core.Fail("No folder x.")
        self.assertEqual(stop.exception.code, 1)
        self.assertEqual(err.getvalue(), "  [err]  No folder x.\n")


if __name__ == "__main__":
    unittest.main()
