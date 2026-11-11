#!/usr/bin/env bash
# run-linux.sh runs a full server bootstrap in throwaway containers.
# Usage: tests/run-linux.sh [image ...]   Default: ubuntu:24.04 debian:12
# Set FULL=1 to install the Neovim language tools too.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
mkdir -p tests/.work
[ "$#" -gt 0 ] || set -- ubuntu:24.04 debian:12
flags="--skip-login-service"
[ "${FULL:-0}" = "1" ] || flags="${flags} --skip-nvim-tools"
status=0
for base in "$@"; do
  tag="hb-test-$(printf '%s' "$base" | tr -c 'a-z0-9' '-')"
  log="tests/.work/${tag}.log"
  docker build -q --build-arg "BASE=${base}" -f tests/Dockerfile.linux -t "$tag" . >"$log" 2>&1 || { echo "FAIL build ${base}"; tail -n 20 "$log"; status=1; continue; }
  docker run --rm --name "${tag}-$$" "$tag" bash -c "
    set -e
    ./bootstrap.sh server ${flags}
    tests/verify-server.sh linux
    tests/test-install.sh
    echo '== idempotent'
    tests/test-idempotent.sh bootstrap.sh \$HOME/.config/herdr/config.toml server ${flags}
    backups=\$(find \$HOME -name '*.bak-*' -not -path '*/.cache/*' -not -path '*/.oh-my-zsh/*' -not -path '*/.local/*' | wc -l)
    echo \"RESULT backups=\$backups\"
    [ \"\$backups\" -eq 0 ]
    getent passwd tester | grep -q zsh
    echo RESULT login-shell-zsh
    echo \"RESULT parsers=\$(ls \$HOME/.local/share/nvim/site/parser 2>/dev/null | wc -l)\"
    if [ \"${FULL:-0}\" = 1 ]; then [ \"\$(ls \$HOME/.local/share/nvim/site/parser | wc -l)\" -gt 0 ]; fi
    echo \"RESULT mason=\$(ls \$HOME/.local/share/nvim/mason/packages 2>/dev/null | tr '\\n' ' ')\"
    if [ \"${FULL:-0}\" = 1 ]; then ls \$HOME/.local/share/nvim/mason/packages | grep -q pyright; fi
    echo '== both on one machine'
    ./bootstrap.sh both --no-ghostty ${flags}
    grep -q 'BOOTSTRAP_ROLE=both' \$HOME/.config/herdspace/env.zsh
    ./bootstrap.sh both --check --no-ghostty ${flags} >/tmp/both-check.log 2>&1 || { cat /tmp/both-check.log; exit 1; }
    echo RESULT both-check-clean
  " >>"$log" 2>&1
  rc=$?
  grep -E '^(FAIL|RESULT)' "$log" | cut -c1-200
  echo "${base}: exit ${rc}"
  [ "$rc" -eq 0 ] || status=1
  docker rmi -f "$tag" >/dev/null 2>&1 || true
done
exit "$status"
