# shellcheck shell=bash
# sandbox-guard.sh stops a test that runs the setup in the home folder, when the
# test runs on the real home folder of the user and outside a container. The
# run-*.sh scripts start such a test in a container or with a temporary home.
# Source this file at the top of the test.
if [ ! -f /.dockerenv ]; then
  # ~USER reads the home folder from the user database, not from $HOME.
  guard_home="$(eval "echo ~$(id -un)")"
  if [ -z "$guard_home" ] || [ "$(cd "$HOME" 2>/dev/null && pwd -P)" = "$(cd "$guard_home" 2>/dev/null && pwd -P)" ]; then
    echo "$(basename "$0") changes the home folder. Run it through a tests/run-*.sh script, which uses a container or a temporary home folder." >&2
    exit 2
  fi
fi
