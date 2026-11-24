#!/usr/bin/env bash
# test-sign-tag.sh checks tools/sign-tag.sh in a temporary repository, with a
# temporary SSH key: a new tag gets a signature, the check of a release key,
# a key that is not in the list, and a tag with no signature.
# It needs git and ssh-keygen, and no network.
# Usage: tests/test-sign-tag.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; failures=$((failures + 1)); }
contains() { case "$1" in *"$2"*) pass "$3" ;; *) fail "$3: wanted [$2] in [$1]" ;; esac; }

ssh-keygen -q -t ed25519 -N '' -C test -f "$tmp/key"
ssh-keygen -q -t ed25519 -N '' -C test -f "$tmp/other"
printf 'herdspace-release namespaces="git" %s\n' "$(awk '{print $1" "$2}' "$tmp/key.pub")" >"$tmp/signers"
git init -q "$tmp/repo"
cd "$tmp/repo" || exit 1
git -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m one
export GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid HS_SIGNERS_FILE="$tmp/signers"
sign() { "$ROOT/tools/sign-tag.sh" "$@" 2>&1; }

out="$(HS_SIGNING_KEY="$tmp/key" sign --check)"
contains "$out" 'is in' 'a release key passes the check'
out="$(HS_SIGNING_KEY="$tmp/other" sign --check)"
contains "$out" 'is not in' 'another key fails the check'
out="$(HS_SIGNING_KEY="" GIT_CONFIG_GLOBAL=/dev/null sign --check)"
contains "$out" 'No signing key' 'no key fails the check'

out="$(HS_SIGNING_KEY="$tmp/other" sign 1.0.0 HEAD)"
contains "$out" 'is not in' 'another key makes no tag'
git rev-parse -q --verify refs/tags/1.0.0 >/dev/null && fail 'no tag stays after a failed signature' || pass 'no tag stays after a failed signature'

out="$(HS_SIGNING_KEY="$tmp/key" sign 1.0.0 HEAD)"
contains "$out" 'Made the signed tag 1.0.0' 'a release key makes a signed tag'
out="$(git -c gpg.ssh.allowedSignersFile="$tmp/signers" tag -v 1.0.0 2>&1)"
contains "$out" 'Good "git" signature' 'git tag -v accepts the tag'
out="$(sign 1.0.0 HEAD)"
contains "$out" 'has a valid signature' 'a signed tag that exists passes'

git tag 1.0.1
out="$(sign 1.0.1 HEAD)"
contains "$out" 'no valid signature' 'a tag with no signature fails'

echo "RESULT failures=${failures}"
[ "$failures" -eq 0 ]
