#!/usr/bin/env bash
# Installs tools from their release pages. Each file must match its checksum in
# tools/versions.tsv. tools/update-versions.sh writes that file.

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

install_release_tools() {
  step "Tools from release pages"
  local name
  for name in herdr neovim lazygit git-delta eza zoxide fzf; do
    install_release_tool "$name"
  done
}
