#!/bin/sh
# apt-mirror.sh runs in a test image before the first apt-get. It puts another
# mirror in front of the default one: APT_MIRROR_UBUNTU for Ubuntu (on ARM, a
# mirror with ubuntu-ports), and APT_MIRROR_DEBIAN for Debian. apt uses the
# first mirror that works, and it uses the default mirror if the other fails.
# With no mirror set, it changes nothing.
set -eu
use_mirror() {
  mirror="$1" default="$2" list="$3"
  [ -n "$mirror" ] || return 0
  printf '%s\n%s\n' "$mirror" "$default" >"$list"
  for f in /etc/apt/sources.list.d/*.sources; do
    [ -f "$f" ] || continue
    sed -i "s#^URIs: ${default}/\{0,1\}\$#URIs: mirror+file:${list}#" "$f"
  done
}
use_mirror "${APT_MIRROR_UBUNTU:-}" http://ports.ubuntu.com/ubuntu-ports /etc/apt/mirrors-ubuntu-ports.txt
use_mirror "${APT_MIRROR_UBUNTU:-}" http://archive.ubuntu.com/ubuntu /etc/apt/mirrors-ubuntu.txt
use_mirror "${APT_MIRROR_DEBIAN:-}" http://deb.debian.org/debian /etc/apt/mirrors-debian.txt
