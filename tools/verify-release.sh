#!/usr/bin/env bash
# verify-release.sh builds a release again from the checked-out commit, and
# compares it with the files of the published release. It finds a release file
# that differs from the code of its tag, for example after a change on the
# build machine or after an upload by somebody else.
#
# Usage: tools/verify-release.sh <tag> [--repo owner/name] [--files DIR]
#   With no --files, it downloads the release with gh. It also makes sure that
#   the tag points to the checked-out commit, and that main holds the commit.
#   --files DIR compares the files in DIR, and skips the download and the git
#   checks. The tests use it.
# The downloaded files stay in dist/<tag>-published, for the attestation step
# of .github/workflows/release.yml. It exits 1 when a file differs.
# Run it in a clone of the tag: it builds the commit of the current folder with
# the tools/release.sh of that commit. The script itself can come from another
# clone, for example from main.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

TAG=""
REPO=""
FILES=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --files) FILES="$2"; shift 2 ;;
    -*) echo "Unknown option: $1" >&2; exit 2 ;;
    *) TAG="$1"; shift ;;
  esac
done
[ -n "$TAG" ] || { echo "Usage: tools/verify-release.sh <tag> [--repo owner/name] [--files DIR]" >&2; exit 2; }
if [ -z "$REPO" ]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)" || true
fi
[ -n "$REPO" ] || { echo "Give the repository with --repo owner/name." >&2; exit 2; }

fail() { echo "FAIL $*" >&2; exit 1; }

if [ -z "$FILES" ]; then
  # The tag must point to the commit that this script builds, and main must
  # hold that commit.
  tag_commit="$(git rev-parse "refs/tags/${TAG}^{commit}" 2>/dev/null)" || fail "The tag ${TAG} is not in this clone. Fetch the tags."
  [ "$tag_commit" = "$(git rev-parse HEAD)" ] || fail "The tag ${TAG} points to ${tag_commit}, but the checked-out commit is $(git rev-parse HEAD)."
  git fetch -q origin main
  git merge-base --is-ancestor "$tag_commit" origin/main || fail "The commit ${tag_commit} of the tag ${TAG} is not on main."
  FILES="dist/${TAG}-published"
  rm -rf "$FILES"
  mkdir -p "$FILES"
  gh release download "$TAG" --repo "$REPO" --dir "$FILES"
fi

# Each file must match its line of SHA256SUMS.
(
  cd "$FILES"
  if command -v sha256sum >/dev/null 2>&1; then sha256sum --quiet -c SHA256SUMS; else shasum -a 256 --quiet -c SHA256SUMS; fi
) || fail "A file of the release does not match SHA256SUMS."

tools/release.sh "$TAG" --repo "$REPO" >/dev/null 2>&1 || fail "tools/release.sh could not build ${TAG}."

# The release must hold the same files as the new build. bootstrap.sh and
# install.sh must be the same byte for byte. An archive must hold the same
# entries, with the same content and the same execute permission. The gzip
# bytes can differ between two machines, so they are not compared.
python3 -I - "dist/${TAG}" "$FILES" <<'PY'
import hashlib, os, sys, tarfile

built, published = sys.argv[1], sys.argv[2]
problems = []

def names(folder):
    return sorted(n for n in os.listdir(folder) if os.path.isfile(os.path.join(folder, n)))

want, have = names(built), names(published)
for name in sorted(set(want) - set(have)):
    problems.append(f"missing in the release: {name}")
for name in sorted(set(have) - set(want)):
    problems.append(f"extra in the release: {name}")

def digest(data):
    return hashlib.sha256(data).hexdigest()

def entries(path):
    result = {}
    with tarfile.open(path, "r:gz") as tar:
        for member in tar.getmembers():
            name = member.name.removeprefix("./").rstrip("/")
            if member.isdir():
                result[name] = ("dir",)
            elif member.isfile():
                result[name] = ("file", bool(member.mode & 0o111), digest(tar.extractfile(member).read()))
            elif member.issym():
                result[name] = ("link", member.linkname)
            else:
                result[name] = ("other", member.type)
    return result

for name in sorted(set(want) & set(have)):
    a, b = os.path.join(built, name), os.path.join(published, name)
    if name.endswith(".tar.gz"):
        built_entries, published_entries = entries(a), entries(b)
        for entry in sorted(set(built_entries) | set(published_entries)):
            if built_entries.get(entry) != published_entries.get(entry):
                if entry not in published_entries:
                    problems.append(f"{name}: missing {entry}")
                elif entry not in built_entries:
                    problems.append(f"{name}: extra {entry}")
                else:
                    problems.append(f"{name}: {entry} differs")
    elif name != "SHA256SUMS":
        with open(a, "rb") as fa, open(b, "rb") as fb:
            if fa.read() != fb.read():
                problems.append(f"{name} differs")

for line in problems:
    print(f"FAIL {line}", file=sys.stderr)
if problems:
    sys.exit(1)
print(f"OK {len(have)} files of the release match the build of the tag.")
PY
