#!/usr/bin/env bash
# run-prereqs.sh tests the prerequisites step of the Linux setup in throwaway
# containers. It stops each run after the step, with HS_PREREQS_ONLY=1.
#
# Usage: tests/run-prereqs.sh
cd "$(dirname "$0")/.." || exit 1
# shellcheck source=tests/lib-docker.sh
source tests/lib-docker.sh
status=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; status=1; }
contains() { case "$1" in *"$2"*) pass "$3" ;; *) fail "$3: ${1:0:300}" ;; esac; }

tag="hb-test-prereqs"
# shellcheck disable=SC2046 # build_flags prints one option or nothing.
docker build -q $(build_flags) --build-arg BASE=ubuntu:24.04 -f tests/Dockerfile.linux -t "$tag" . >/dev/null || { echo "FAIL build"; exit 1; }
apt_cache_args ubuntu:24.04
# box USER ENV... runs a command in a new container. The session asks for
# en_US.UTF-8, which the image does not have.
box() {
  local user="$1"
  shift
  docker run --rm --user "$user" -e LANG=en_US.UTF-8 -e HS_PREREQS_ONLY=1 ${APT_CACHE[@]+"${APT_CACHE[@]}"} "$tag" bash -c "$*" 2>&1
}

out="$(box tester './bootstrap.sh server --check; echo "rc=$?"')"
contains "$out" "Locale en_US.UTF-8 is missing (optional)" 'check reports the missing locale'
contains "$out" "[ok]   sudo" 'check finds sudo'
contains "$out" "rc=0" 'a missing optional item does not fail the check'

out="$(box tester './bootstrap.sh server --yes </dev/null; echo "rc=$?"; locale -a')"
contains "$out" "en_US.utf8" '--yes installs the locale with sudo'
contains "$out" "rc=0" 'the prerequisites step ends'

out="$(box root 'mv /usr/bin/sudo /usr/bin/sudo.off; su tester -c "cd ~/repo && ./bootstrap.sh server --yes </dev/null"; echo "rc=$?"')"
contains "$out" "Run the setup as root, or ask an admin to give this account sudo." 'no sudo: the setup names the fix'
contains "$out" "rc=1" 'no sudo: the setup stops'

out="$(box root 'mv /usr/bin/sudo /usr/bin/sudo.off; ./bootstrap.sh server --yes </dev/null; echo "rc=$?"')"
contains "$out" "[ok]   sudo" 'root needs no sudo'
contains "$out" "rc=0" 'root: the prerequisites step ends'

out="$(box tester './bootstrap.sh client --server nowhere.invalid --yes </dev/null; echo "rc=$?"')"
contains "$out" "SSH connection to each server (optional)" 'client reports a server with no SSH'
contains "$out" "See docs/ssh.md" 'client points to the SSH guide'
contains "$out" "rc=0" 'a server with no SSH does not stop the client'

remove_images "$tag"
echo "RESULT exit=${status}"
exit "$status"
