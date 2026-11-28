"""The entry point of the hopen package.

It loads the package from the folder of this file by its path, with no change
to sys.path, so that no other folder and no other package named hopen can
take its place.
"""
import importlib.util
import os
import sys

HERE = os.path.dirname(os.path.realpath(__file__))
spec = importlib.util.spec_from_file_location(
    "hopen", os.path.join(HERE, "__init__.py"), submodule_search_locations=[HERE])
package = importlib.util.module_from_spec(spec)
sys.modules["hopen"] = package
spec.loader.exec_module(package)

from hopen import cli  # noqa: E402

sys.exit(cli.main(sys.argv[1:]))
