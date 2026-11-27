# shellcheck shell=bash
# herdspace update, which runs the setup of a release again.
# bin/herdspace loads this file. It defines functions and variables, and runs nothing.

# keep_known_args BOOTSTRAP ARG... prints the saved options that the
# bootstrap.sh of an older release lists in its help. An older release stops on
# an option of a newer release, so the setup leaves that option out, and this
# function names it on stderr.
keep_known_args() {
  local file="$1" a skip=0 take=0
  shift
  for a in "$@"; do
    if [ "$skip" -eq 1 ]; then skip=0; continue; fi
    if [ "$take" -eq 1 ]; then take=0; printf '%s\n' "$a"; continue; fi
    case "$a" in
      --*)
        if grep -qF -- "$a" "$file"; then
          printf '%s\n' "$a"
          case "$a" in --server | --os) take=1 ;; esac
        else
          printf '  This release does not know the option %s, so the setup leaves it out.\n' "$a" >&2
          case "$a" in --server | --os) skip=1 ;; esac
        fi
        ;;
      *) printf '%s\n' "$a" ;;
    esac
  done
}

cmd_update() {
  local latest have role="" os="" line work args=() want force=0 a extra=() tag="" kept=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --force) force=1 ;;
      --version)
        [ "$#" -ge 2 ] || die "--version needs a release tag, for example: herdspace update --version 0.9.0"
        tag="$2"
        shift
        ;;
      --version=*) tag="${1#--version=}" ;;
      *) extra+=("$1") ;;
    esac
    shift
  done
  case "$tag" in
    "") ;;
    v[0-9]*) die "A release tag has no v in front. Use: herdspace update --version ${tag#v}" ;;
    *[!0-9A-Za-z.-]* | *..* | -* | .*) die "'${tag}' is not a release tag. A tag is a version, for example 0.9.0." ;;
    [0-9]*.[0-9]*.[0-9]*) ;;
    *) die "'${tag}' is not a release tag. A tag is a version, for example 0.9.0." ;;
  esac
  set -- ${extra[@]+"${extra[@]}"}
  [ -f "${STATE}/last-setup" ] || die "No setup is saved on this machine. Run the setup once, as the Quick start shows: https://github.com/${REPO}#quick-start"
  while IFS= read -r line; do
    case "$line" in
      role=*) role="${line#role=}" ;;
      os=*) os="${line#os=}" ;;
      arg=*) args+=("${line#arg=}") ;;
    esac
  done <"${STATE}/last-setup"
  case "$role" in server | client | both) ;; *) die "The saved setup has no role. Run the setup once again." ;; esac
  [ -z "$os" ] || args=(--os "$os" ${args[@]+"${args[@]}"})
  have="$(installed)"
  if [ -n "$tag" ]; then
    latest="$tag"
    if [ "$tag" = "$have" ] && [ "$force" -eq 0 ]; then
      printf '  herdspace %s is installed already. Nothing to change.\n' "$have"
      printf '  To run the setup again anyway, run: herdspace update --version %s --force\n' "$have"
      return 0
    elif [ "$tag" = "$have" ]; then
      printf '  herdspace %s is installed already. The setup runs again, because of --force.\n' "$have"
    elif newer "$have" "$tag"; then
      printf '  Going back from herdspace %s to the older release %s.\n' "$have" "$tag"
    else
      printf '  Changing herdspace from %s to %s.\n' "$have" "$tag"
    fi
  else
    latest="$(latest_now)"
    [ -n "$latest" ] || die "GitHub did not answer, so the latest release is unknown. Try again later."
    if [ "$latest" = "$have" ] && [ "$force" -eq 0 ]; then
      printf '  herdspace %s is the latest release. Nothing to update.\n' "$have"
      printf '  To run the setup again anyway, run: herdspace update --force\n'
      return 0
    elif [ "$latest" = "$have" ]; then
      printf '  herdspace %s is the latest release. The setup runs again, because of --force.\n' "$have"
    else
      printf '  Updating herdspace from %s to %s.\n' "$have" "$latest"
      printf '  What changed: https://github.com/%s/releases/tag/%s\n' "$REPO" "$latest"
    fi
  fi
  work="$(mktemp -d)"
  # The EXIT trap runs after this function returns, when the local work is
  # gone, so it uses a global name.
  HS_UPDATE_WORK="$work"
  trap 'rm -rf "${HS_UPDATE_WORK:-}"' EXIT
  for f in bootstrap.sh SHA256SUMS; do
    curl -fsSL "https://github.com/${REPO}/releases/download/${latest}/${f}" -o "${work}/${f}" ||
      die "Could not download ${f} of ${latest}.${tag:+ Does this release exist? The list: https://github.com/${REPO}/releases}"
  done
  want="$(awk '$2 == "bootstrap.sh" || $2 == "*bootstrap.sh" {print $1}' "${work}/SHA256SUMS")"
  [ -n "$want" ] && [ "$(sha_of "${work}/bootstrap.sh")" = "$want" ] || die "The checksum of bootstrap.sh is wrong. Nothing was changed."
  if [ -n "$tag" ] && [ "${#args[@]}" -gt 0 ]; then
    while IFS= read -r a; do kept+=("$a"); done < <(keep_known_args "${work}/bootstrap.sh" "${args[@]}")
    args=(${kept[@]+"${kept[@]}"})
  fi
  printf '  The setup runs: bootstrap.sh %s %s\n' "$role" "${args[*]:-}${*:+ $*}"
  HS_VERSION="$latest" bash "${work}/bootstrap.sh" "$role" ${args[@]+"${args[@]}"} "$@"
  local rc=$?
  rm -rf "$work"
  rm -f "${CACHE}/latest" "${CACHE}/notice-shown"
  [ "$rc" -ne 0 ] || [ ! -x "${HOME}/.local/bin/herdr-update-check" ] || "${HOME}/.local/bin/herdr-update-check" --now
  return "$rc"
}
