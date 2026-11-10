#!/usr/bin/env bash
# Installs tools from their release pages. Each file must match its checksum in
# tools/versions.tsv. tools/update-versions.sh writes that file.

# run_root runs a command as root, with sudo when this account is not root.
run_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

apt_install() {
  run_root env DEBIAN_FRONTEND=noninteractive apt-get update -qq
  run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends "$@" >/dev/null
}

# link_debian_tools adds the usual names of two tools. Debian names them batcat and fdfind.
link_debian_tools() {
  mkdir -p "${HOME}/.local/bin"
  have batcat && ln -sfn "$(command -v batcat)" "${HOME}/.local/bin/bat"
  have fdfind && ln -sfn "$(command -v fdfind)" "${HOME}/.local/bin/fd"
  export PATH="${HOME}/.local/bin:${PATH}"
}

login_shell_ready() {
  have zsh && [ "$(getent passwd "$(id -un)" | cut -d: -f7)" = "$(command -v zsh)" ]
}

set_login_shell_zsh() {
  local zsh_path
  zsh_path="$(command -v zsh)"
  run_root chsh -s "$zsh_path" "$(id -un)" || warn "Could not change the login shell. Run: chsh -s ${zsh_path}"
}

# apt_ready NAME... exits 0 if each package is installed.
apt_ready() {
  local name
  for name in "$@"; do
    dpkg-query -W -f '${Status}' "$name" 2>/dev/null | grep -q 'install ok installed' || return 1
  done
}

linux_arch() {
  case "$(uname -m)" in
    x86_64 | amd64) echo x86_64 ;;
    aarch64 | arm64) echo aarch64 ;;
    *) die "This processor type has no release files: $(uname -m)" ;;
  esac
}

release_tool_line() {
  awk -F '\t' -v n="$1" -v a="$(linux_arch)" '$1 == n && $3 == a' "${REPO_ROOT}/tools/versions.tsv"
}

release_tool_binary() {
  case "$1" in
    git-delta) echo delta ;;
    neovim) echo nvim ;;
    ghostty-*) echo ghostty ;;
    *) echo "$1" ;;
  esac
}

release_tool_ready() {
  local name="$1" sha marker
  sha="$(release_tool_line "$name" | cut -f5)"
  marker="${STATE_DIR}/installed/${name}"
  [ -n "$sha" ] && [ -f "$marker" ] && [ "$(cat "$marker")" = "$sha" ] && have "$(release_tool_binary "$name")"
}

# install_release_tool NAME installs one tool for this processor type.
install_release_tool() {
  local name="$1" line version url sha marker tmp file
  line="$(release_tool_line "$name")"
  [ -n "$line" ] || die "tools/versions.tsv has no entry for ${name} on $(linux_arch)."
  version="$(printf '%s' "$line" | cut -f2)"
  url="$(printf '%s' "$line" | cut -f4)"
  sha="$(printf '%s' "$line" | cut -f5)"
  marker="${STATE_DIR}/installed/${name}"
  tmp="$(mktemp -d)"
  file="${tmp}/$(basename "$url")"
  curl -fsSL --retry 2 --connect-timeout 15 -o "$file" "$url"
  printf '%s  %s\n' "$sha" "$file" | sha256sum -c --status - || die "The checksum of ${name} does not match."
  mkdir -p "${HOME}/.local/bin"
  case "$name" in
    herdr)
      install -m 755 "$file" "${HOME}/.local/bin/herdr"
      ;;
    ghostty-*)
      chmod 644 "$file"
      run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends "$file" >/dev/null
      ;;
    neovim)
      rm -rf "${HOME}/.local/opt/neovim"
      mkdir -p "${HOME}/.local/opt/neovim"
      tar -xzf "$file" -C "${HOME}/.local/opt/neovim" --strip-components=1
      ln -sfn "${HOME}/.local/opt/neovim/bin/nvim" "${HOME}/.local/bin/nvim"
      ;;
    *)
      local binary="$name"
      [ "$name" = "git-delta" ] && binary="delta"
      tar -xzf "$file" -C "$tmp"
      install -m 755 "$(find "$tmp" -type f -name "$binary" | head -n 1)" "${HOME}/.local/bin/${binary}"
      ;;
  esac
  mkdir -p "$(dirname "$marker")"
  printf '%s' "$sha" >"$marker"
  rm -rf "$tmp"
  ok "${name} ${version}"
}

# setup_release_tools NAME... installs each tool that is missing or out of date.
setup_release_tools() {
  local name
  for name in "$@"; do
    run_part "$name" release_tool_ready install_release_tool "$name"
  done
}

ghostty_codename() { (. /etc/os-release && printf '%s' "${VERSION_CODENAME:-}"); }

ghostty_candidate() { apt-cache policy ghostty 2>/dev/null | awk '/Candidate:/ {print $2}'; }

ghostty_has_community_package() {
  awk -F '\t' -v n="ghostty-$(ghostty_codename)" '$1 == n {found = 1} END {exit !found}' "${REPO_ROOT}/tools/versions.tsv"
}

# ghostty_available exits 0 if this system has a Ghostty package.
ghostty_available() {
  have ghostty && return 0
  local candidate
  candidate="$(ghostty_candidate)"
  { [ -n "$candidate" ] && [ "$candidate" != "(none)" ]; } || ghostty_has_community_package
}

# install_ghostty uses the package of the system if it has one. Otherwise it
# uses a community package with a pinned checksum.
install_ghostty() {
  local candidate
  candidate="$(ghostty_candidate)"
  if [ -n "$candidate" ] && [ "$candidate" != "(none)" ]; then
    apt_install ghostty
  else
    install_release_tool "ghostty-$(ghostty_codename)"
  fi
}
