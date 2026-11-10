#!/usr/bin/env bash
# install.sh installs hopen and its templates from a GitHub release.
#
# Usage: curl -fsSL <release-url>/install.sh | bash
#        bash install.sh [--version TAG] [--uninstall]
#
# The script downloads one archive, compares its checksum with SHA256SUMS, and
# copies hopen to ~/.local/bin and the templates to ~/.config/hopen/templates.
# It is safe to run again. It keeps a template that you changed, and it writes
# the new template next to it with the extension .new.
#
# Environment values:
#   HOPEN_VERSION    The release tag. The default is the release of this file.
#   HOPEN_BIN_DIR    Where hopen goes. The default is ~/.local/bin.
#   HOPEN_TEMPLATES  Where the templates go. The default is ~/.config/hopen/templates.
#   HOPEN_REPO       The GitHub repository, as owner/name. The release sets it.
#   HOPEN_BASE_URL   Where the release files are. Tests use a file:// address.
set -euo pipefail

REPO="${HOPEN_REPO:-@REPO@}"
RELEASE="@VERSION@"
VERSION="${HOPEN_VERSION:-$RELEASE}"
BIN_DIR="${HOPEN_BIN_DIR:-$HOME/.local/bin}"
TEMPLATE_DIR="${HOPEN_TEMPLATES:-${XDG_CONFIG_HOME:-$HOME/.config}/hopen/templates}"
ACTION="install"

info() { printf '  [info] %s\n' "$*"; }
warn() { printf '  [warn] %s\n' "$*" >&2; }
die() { printf '  [err]  %s\n' "$*" >&2; exit 1; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version) [ "$#" -ge 2 ] || die "--version needs a release tag."; VERSION="$2"; shift 2 ;;
    --uninstall) ACTION="uninstall"; shift ;;
    -h | --help) sed -n '2,18p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

if [ "$ACTION" = uninstall ]; then
  if [ -e "${BIN_DIR}/hopen" ] || [ -L "${BIN_DIR}/hopen" ]; then
    rm -f "${BIN_DIR}/hopen"
    info "Removed ${BIN_DIR}/hopen."
  else
    info "hopen is not in ${BIN_DIR}."
  fi
  info "The templates stay in ${TEMPLATE_DIR}. Delete that folder if you do not want them."
  exit 0
fi

case "$VERSION" in
  "" | @*@) die "No release is set. Run: bash install.sh --version <tag>" ;;
esac
case "$REPO" in
  "" | @*@) [ -n "${HOPEN_BASE_URL:-}" ] || die "No repository is set. Set HOPEN_REPO to owner/name." ;;
esac
BASE_URL="${HOPEN_BASE_URL:-https://github.com/${REPO}/releases/download/${VERSION}}"
ARCHIVE="hopen-${VERSION}.tar.gz"

for tool in curl tar python3; do
  command -v "$tool" >/dev/null 2>&1 || die "This script needs ${tool}."
done
command -v herdr >/dev/null 2>&1 || warn "Herdr is not installed. hopen needs it. See https://herdr.dev"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# fetch NAME downloads one release file. If curl cannot get it, for example
# from a private repository, the GitHub CLI tries with your login.
fetch() {
  if curl -fsSL "${BASE_URL}/$1" -o "${work}/$1" 2>/dev/null; then
    return 0
  fi
  if [ -z "${HOPEN_BASE_URL:-}" ] && command -v gh >/dev/null 2>&1; then
    gh release download "$VERSION" --repo "$REPO" --pattern "$1" --dir "$work" --clobber >/dev/null 2>&1 && return 0
  fi
  die "Could not download $1 from ${BASE_URL}."
}

sha_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d ' ' -f 1
  else
    shasum -a 256 "$1" | cut -d ' ' -f 1
  fi
}

info "Installing hopen ${VERSION}."
fetch "$ARCHIVE"
fetch SHA256SUMS
want="$(awk -v f="$ARCHIVE" '$2 == f || $2 == "*" f {print $1}' "${work}/SHA256SUMS")"
[ -n "$want" ] || die "SHA256SUMS has no line for ${ARCHIVE}."
[ "$(sha_of "${work}/${ARCHIVE}")" = "$want" ] || die "The checksum of ${ARCHIVE} is wrong. Nothing was installed."
tar -xzf "${work}/${ARCHIVE}" -C "$work"
src="${work}/hopen-${VERSION}"
[ -f "${src}/hopen" ] || die "The archive has no hopen file."

mkdir -p "$BIN_DIR"
target="${BIN_DIR}/hopen"
if [ -L "$target" ]; then
  info "Replaced the link ${target}, which pointed to $(readlink "$target")."
  rm -f "$target"
fi
if [ -f "$target" ] && cmp -s "${src}/hopen" "$target"; then
  info "${target} is up to date."
else
  cp "${src}/hopen" "${target}.tmp"
  chmod 755 "${target}.tmp"
  mv "${target}.tmp" "$target"
  info "Installed ${target}."
fi

mkdir -p "$TEMPLATE_DIR"
for file in "${src}"/templates/*.layout; do
  name="$(basename "$file")"
  dest="${TEMPLATE_DIR}/${name}"
  if [ ! -f "$dest" ]; then
    cp "$file" "$dest"
    info "Added the template ${name}."
  elif cmp -s "$file" "$dest"; then
    rm -f "${dest}.new"
  else
    cp "$file" "${dest}.new"
    warn "You changed ${dest}. It stays. The new version is ${dest}.new."
  fi
done

case ":${PATH}:" in
  *":${BIN_DIR}:"*) ;;
  *) warn "${BIN_DIR} is not in your PATH. Add it to your shell startup file." ;;
esac
info "Done. Run: hopen --help"
