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

set_login_shell_zsh() {
  local zsh_path
  zsh_path="$(command -v zsh)"
  if [ "$(getent passwd "$(id -un)" | cut -d: -f7)" != "$zsh_path" ]; then
    step "Login shell"
    run_root chsh -s "$zsh_path" "$(id -un)" || warn "Could not change the login shell. Run: chsh -s ${zsh_path}"
  fi
}

linux_arch() {
  case "$(uname -m)" in
    x86_64 | amd64) echo x86_64 ;;
    aarch64 | arm64) echo aarch64 ;;
    *) die "This processor type has no release files: $(uname -m)" ;;
  esac
}

# install_release_tool NAME installs one tool for this processor type.
install_release_tool() {
  local name="$1" arch line version url sha marker tmp file
  arch="$(linux_arch)"
  line="$(awk -F '\t' -v n="$name" -v a="$arch" '$1 == n && $3 == a' "${REPO_ROOT}/tools/versions.tsv")"
  [ -n "$line" ] || die "tools/versions.tsv has no entry for ${name} on ${arch}."
  version="$(printf '%s' "$line" | cut -f2)"
  url="$(printf '%s' "$line" | cut -f4)"
  sha="$(printf '%s' "$line" | cut -f5)"
  marker="${STATE_DIR}/installed/${name}"
  if [ -f "$marker" ] && [ "$(cat "$marker")" = "$sha" ]; then
    ok "${name} ${version}"
    return 0
  fi
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

# install_release_tools NAME... installs each tool in the list.
install_release_tools() {
  step "Tools from release pages"
  local name
  for name in "$@"; do
    install_release_tool "$name"
  done
}

# install_ghostty uses the package of the system if it has one. Otherwise it
# uses a community package with a pinned checksum. It returns 1 with no package.
install_ghostty() {
  if have ghostty; then
    ok "Ghostty is already installed"
    return 0
  fi
  local candidate codename
  candidate="$(apt-cache policy ghostty 2>/dev/null | awk '/Candidate:/ {print $2}')"
  if [ -n "$candidate" ] && [ "$candidate" != "(none)" ]; then
    apt_install ghostty
    ok "Ghostty from the system packages"
    return 0
  fi
  codename="$(. /etc/os-release && printf '%s' "${VERSION_CODENAME:-}")"
  if awk -F '\t' -v n="ghostty-${codename}" '$1 == n {found = 1} END {exit !found}' "${REPO_ROOT}/tools/versions.tsv"; then
    install_release_tool "ghostty-${codename}"
    return 0
  fi
  return 1
}
