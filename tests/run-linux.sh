#!/usr/bin/env bash
# run-linux.sh runs a full server bootstrap in throwaway containers.
# Usage: tests/run-linux.sh [image ...]   Default: ubuntu:24.04 debian:12
# Set FULL=1 to install the Neovim language tools too.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
# shellcheck source=tests/lib-docker.sh
source tests/lib-docker.sh
mkdir -p tests/.work
[ "$#" -gt 0 ] || set -- ubuntu:24.04 debian:12
flags="--skip-login-service"
[ "${FULL:-0}" = "1" ] || flags="${flags} --skip-nvim-tools"
status=0
for base in "$@"; do
  tag="hb-test-$(printf '%s' "$base" | tr -c 'a-z0-9' '-')"
  log="tests/.work/${tag}.log"
  # shellcheck disable=SC2046 # build_flags prints one option or nothing.
  docker build -q $(build_flags) --build-arg "BASE=${base}" -f tests/Dockerfile.linux -t "$tag" . >"$log" 2>&1 || { echo "FAIL build ${base}"; tail -n 20 "$log"; status=1; continue; }
  apt_cache_args "$base"
  docker run --rm --name "${tag}-$$" ${APT_CACHE[@]+"${APT_CACHE[@]}"} "$tag" bash -c "
    set -eo pipefail
    # A package source with no signature makes apt-get update fail, as a local
    # driver repository can on a real server. The setup must warn and go on.
    for arch in amd64 arm64; do sudo mkdir -p /var/unsigned-repo/dists/stable/main/binary-\$arch; sudo touch /var/unsigned-repo/dists/stable/main/binary-\$arch/Packages; done
    printf 'Suite: stable\\nCodename: stable\\nComponents: main\\nArchitectures: amd64 arm64\\n' | sudo tee /var/unsigned-repo/dists/stable/Release >/dev/null
    echo 'deb file:/var/unsigned-repo stable main' | sudo tee /etc/apt/sources.list.d/unsigned.list >/dev/null
    # An export in ~/.bashrc. With no terminal, the setup names it and changes nothing.
    echo 'export HS_TEST_TOKEN=test-value' >>\$HOME/.bashrc
    start=\$(date +%s)
    ./bootstrap.sh server ${flags} 2>&1 | tee /tmp/setup.log
    grep -q 'export variables that zsh does not have: HS_TEST_TOKEN' /tmp/setup.log
    grep -q '^export HS_TEST_TOKEN=test-value' \$HOME/.bashrc
    ! grep -q 'test-value' /tmp/setup.log
    echo RESULT bash-export-named
    # herdspace update reads the role and the options of the last setup.
    grep -qx 'role=server' \$HOME/.local/share/herdspace/last-setup || { cat \$HOME/.local/share/herdspace/last-setup; exit 1; }
    grep -qx 'arg=--skip-login-service' \$HOME/.local/share/herdspace/last-setup
    \$HOME/.local/bin/herdspace help | grep -q 'herdspace update'
    echo RESULT setup-saved
    grep -q 'apt-get update failed' /tmp/setup.log
    echo RESULT unsigned-source-warned
    echo \"RESULT bench setup=\$((\$(date +%s) - start))s\"
    tests/verify-server.sh linux
    tests/bench-hopen.sh
    tests/test-install.sh
    echo '== idempotent'
    tests/test-idempotent.sh bootstrap.sh \$HOME/.config/herdr/config.toml server ${flags}
    backups=\$(find \$HOME -name '*.bak-*' -not -path '*/.cache/*' -not -path '*/.oh-my-zsh/*' -not -path '*/.local/*' | wc -l)
    echo \"RESULT backups=\$backups\"
    [ \"\$backups\" -eq 0 ]
    getent passwd tester | grep -q zsh
    echo RESULT login-shell-zsh
    echo \"RESULT parsers=\$(ls \$HOME/.local/share/herdspace-nvim/site/parser 2>/dev/null | wc -l)\"
    if [ \"${FULL:-0}\" = 1 ]; then [ \"\$(ls \$HOME/.local/share/herdspace-nvim/site/parser | wc -l)\" -gt 0 ]; fi
    echo \"RESULT mason=\$(ls \$HOME/.local/share/herdspace-nvim/mason/packages 2>/dev/null | tr '\\n' ' ')\"
    if [ \"${FULL:-0}\" = 1 ]; then ls \$HOME/.local/share/herdspace-nvim/mason/packages | grep -q pyright; fi
    echo '== update with a live session'
    tests/test-live-update.sh ${flags}
    echo '== both on one machine'
    ./bootstrap.sh both --no-ghostty ${flags}
    grep -q 'BOOTSTRAP_ROLE=both' \$HOME/.config/herdspace/env.zsh
    ./bootstrap.sh both --check --no-ghostty ${flags} >/tmp/both-check.log 2>&1 || { cat /tmp/both-check.log; exit 1; }
    echo RESULT both-check-clean
    echo '== uninstall'
    \$HOME/.local/bin/herdspace uninstall --check >/tmp/un-check.log 2>&1 || { cat /tmp/un-check.log; exit 1; }
    test -x \$HOME/.local/bin/hopen
    test -d \$HOME/.local/share/herdspace
    \$HOME/.local/bin/herdspace uninstall --yes >/tmp/un.log 2>&1 || { cat /tmp/un.log; exit 1; }
    test ! -e \$HOME/.local/bin/hopen
    test ! -e \$HOME/.local/bin/herdspace
    test ! -e \$HOME/.local/share/herdspace
    test ! -e \$HOME/.config/herdspace/zshrc.zsh
    ! grep -qs '>>> herdspace' \$HOME/.zshrc \$HOME/.zprofile
    grep -q HS_TEST_TOKEN \$HOME/.bashrc
    test -x \$HOME/.local/bin/herdr
    echo RESULT uninstall-clean
  " >>"$log" 2>&1
  rc=$?
  grep -E '^(FAIL|RESULT)' "$log" | cut -c1-200
  echo "${base}: exit ${rc}"
  [ "$rc" -eq 0 ] || status=1
  remove_images "$tag"
done
exit "$status"
