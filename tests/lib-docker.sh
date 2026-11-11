#!/usr/bin/env bash
# lib-docker.sh holds the Docker options that the Linux tests share. Scripts in
# tests/ source it.
#
# By default, the tests keep their images, and they share the apt downloads of
# one base image between runs, in two Docker volumes. Each test still starts
# from a new container and runs the full setup. Only the downloads are reused.
# NO_CACHE=1 builds each image from the start, removes it after the run, and
# downloads every package again.

# build_flags prints the extra options for docker build. APT_MIRROR_UBUNTU and
# APT_MIRROR_DEBIAN name a mirror that apt tries before the default one. If
# the mirror fails, apt uses the default mirror. tests/apt-mirror.sh does it.
build_flags() {
  [ "${NO_CACHE:-0}" = "1" ] && printf '%s\n' --no-cache
  [ -n "${APT_MIRROR_UBUNTU:-}" ] && printf '%s\n' --build-arg "APT_MIRROR_UBUNTU=${APT_MIRROR_UBUNTU}"
  [ -n "${APT_MIRROR_DEBIAN:-}" ] && printf '%s\n' --build-arg "APT_MIRROR_DEBIAN=${APT_MIRROR_DEBIAN}"
  return 0
}

# apt_cache_args BASE sets APT_CACHE to the docker run options that share the
# apt downloads of BASE, for example ubuntu:24.04.
apt_cache_args() {
  local name
  APT_CACHE=()
  [ "${NO_CACHE:-0}" = "1" ] && return 0
  name="herdspace-test-apt-$(printf '%s' "$1" | tr -c 'a-z0-9' '-')"
  # shellcheck disable=SC2034 # The scripts that source this file read APT_CACHE.
  APT_CACHE=(-v "${name}-archives:/var/cache/apt/archives" -v "${name}-lists:/var/lib/apt/lists")
}

# remove_images removes the test images, but only with NO_CACHE=1.
remove_images() {
  [ "${NO_CACHE:-0}" = "1" ] || return 0
  docker rmi -f "$@" >/dev/null 2>&1 || true
}
