"""Shared helpers of the unit tests: the path of the package, and a runner."""
import pathlib
import subprocess
import sys

LIB = pathlib.Path(__file__).resolve().parents[2] / "lib"
MAIN = LIB / "hopen" / "__main__.py"
if str(LIB) not in sys.path:
    sys.path.append(str(LIB))


def run(*args, env=None):
    """Run the package as bin/hopen does, and return the finished process."""
    return subprocess.run([sys.executable, "-I", "-B", str(MAIN), *args],
                          capture_output=True, text=True, env=env)
