#!/usr/bin/env bash
# repo-settings.sh applies the GitHub settings of this repository, or compares
# them with the settings on GitHub. docs/repository-settings.md explains each
# setting and the reason for it.
#
# Usage: tools/repo-settings.sh --check|--apply [--repo owner/name]
#   --check   Show each setting that differs. Change nothing. Exit 1 if one differs.
#   --apply   Make the settings on GitHub match this file.
# It needs gh, and an account with admin access to the repository.
set -euo pipefail

MODE=""
REPO=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --check) MODE=check; shift ;;
    --apply) MODE=apply; shift ;;
    --repo) REPO="$2"; shift 2 ;;
    *) echo "Usage: tools/repo-settings.sh --check|--apply [--repo owner/name]" >&2; exit 2 ;;
  esac
done
[ -n "$MODE" ] || { echo "Usage: tools/repo-settings.sh --check|--apply [--repo owner/name]" >&2; exit 2; }
[ -n "$REPO" ] || REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"

# The names of the CI jobs that must pass before a merge. They must match the
# job names in .github/workflows/ci.yml.
CHECKS='["Fast checks", "Linux server (ubuntu-24.04)", "Linux server (ubuntu-24.04-arm)", "Linux login service and client keys", "macOS server"]'
# The repository admin role. Today, only the owner has it.
ADMIN='{"actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always"}'

ruleset_main_ci() {
  python3 -I -c '
import json, sys
checks = [{"context": c} for c in json.loads(sys.argv[1])]
print(json.dumps({
  "name": "main: pull requests and CI", "target": "branch", "enforcement": "active",
  "bypass_actors": [],
  "conditions": {"ref_name": {"include": ["~DEFAULT_BRANCH"], "exclude": []}},
  "rules": [
    {"type": "deletion"},
    {"type": "non_fast_forward"},
    {"type": "pull_request", "parameters": {
      "required_approving_review_count": 0, "dismiss_stale_reviews_on_push": False,
      "require_code_owner_review": False, "require_last_push_approval": False,
      "required_review_thread_resolution": False, "allowed_merge_methods": ["merge"]}},
    {"type": "required_status_checks", "parameters": {
      "strict_required_status_checks_policy": False, "required_status_checks": checks}},
  ]}))' "$CHECKS"
}

ruleset_main_merge() {
  python3 -I -c '
import json, sys
print(json.dumps({
  "name": "main: who can merge", "target": "branch", "enforcement": "active",
  "bypass_actors": [json.loads(sys.argv[1])],
  "conditions": {"ref_name": {"include": ["~DEFAULT_BRANCH"], "exclude": []}},
  "rules": [{"type": "update"}]}))' "$ADMIN"
}

ruleset_tags() {
  python3 -I -c '
import json, sys
print(json.dumps({
  "name": "release tags", "target": "tag", "enforcement": "active",
  "bypass_actors": [json.loads(sys.argv[1])],
  "conditions": {"ref_name": {"include": ["~ALL"], "exclude": []}},
  "rules": [{"type": "creation"}, {"type": "update"}, {"type": "deletion"}, {"type": "non_fast_forward"}]}))' "$ADMIN"
}

# Each setting: a name, the API path, the method to set it, and the wanted JSON.
# For --check, the wanted fields must be equal in the answer of a GET.
SETTINGS=(
  "general|repos/${REPO}|PATCH|{\"has_wiki\": false, \"has_projects\": false, \"delete_branch_on_merge\": true, \"allow_update_branch\": true, \"allow_merge_commit\": true, \"allow_squash_merge\": false, \"allow_rebase_merge\": false}"
  "secret scanning|repos/${REPO}|PATCH|{\"security_and_analysis\": {\"secret_scanning\": {\"status\": \"enabled\"}, \"secret_scanning_push_protection\": {\"status\": \"enabled\"}}}"
  "actions policy|repos/${REPO}/actions/permissions|PUT|{\"enabled\": true, \"allowed_actions\": \"selected\", \"sha_pinning_required\": true}"
  "allowed actions|repos/${REPO}/actions/permissions/selected-actions|PUT|{\"github_owned_allowed\": true, \"verified_allowed\": false, \"patterns_allowed\": []}"
  "workflow token|repos/${REPO}/actions/permissions/workflow|PUT|{\"default_workflow_permissions\": \"read\", \"can_approve_pull_request_reviews\": false}"
  "fork approval|repos/${REPO}/actions/permissions/fork-pr-contributor-approval|PUT|{\"approval_policy\": \"all_external_contributors\"}"
  "code scanning|repos/${REPO}/code-scanning/default-setup|PATCH|{\"state\": \"configured\", \"query_suite\": \"default\"}"
)

differs=0

# same WANTED ACTUAL exits 0 if each field of WANTED has the same value in ACTUAL.
same() {
  python3 -I -c '
import json, sys
def sub(w, a):
    if isinstance(w, dict):
        return isinstance(a, dict) and all(k in a and sub(v, a[k]) for k, v in w.items())
    if isinstance(w, list) and w and isinstance(w[0], dict):
        return isinstance(a, list) and len(w) == len(a) and all(sub(x, y) for x, y in zip(w, a))
    if isinstance(w, list):
        return isinstance(a, list) and sorted(map(str, w)) == sorted(map(str, a))
    return w == a
sys.exit(0 if sub(json.loads(sys.argv[1]), json.loads(sys.argv[2])) else 1)' "$1" "$2"
}

report() {
  if [ "$2" = ok ]; then echo "  [ok]   $1"; else echo "  [diff] $1"; differs=1; fi
}

for entry in "${SETTINGS[@]}"; do
  IFS='|' read -r name path method wanted <<<"$entry"
  actual="$(gh api "$path" 2>/dev/null)" || actual='{}'
  if same "$wanted" "$actual"; then
    report "$name" ok
  elif [ "$MODE" = apply ]; then
    gh api -X "$method" "$path" --input - <<<"$wanted" >/dev/null
    echo "  [set]  $name"
  else
    report "$name" diff
  fi
done

# Dependabot alerts and security updates answer 204 when they are on.
for feature in vulnerability-alerts automated-security-fixes; do
  if gh api "repos/${REPO}/${feature}" >/dev/null 2>&1 && { [ "$feature" = vulnerability-alerts ] || gh api "repos/${REPO}/${feature}" -q .enabled | grep -qx true; }; then
    report "$feature" ok
  elif [ "$MODE" = apply ]; then
    gh api -X PUT "repos/${REPO}/${feature}" >/dev/null
    echo "  [set]  $feature"
  else
    report "$feature" diff
  fi
done

# The rulesets, found by name.
for make in ruleset_main_ci ruleset_main_merge ruleset_tags; do
  wanted="$($make)"
  name="$(python3 -I -c 'import json, sys; print(json.loads(sys.argv[1])["name"])' "$wanted")"
  id="$(gh api "repos/${REPO}/rulesets" -q ".[] | select(.name == \"${name}\") | .id" 2>/dev/null || true)"
  actual='{}'
  [ -z "$id" ] || actual="$(gh api "repos/${REPO}/rulesets/${id}")"
  if [ -n "$id" ] && same "$wanted" "$actual"; then
    report "ruleset: ${name}" ok
  elif [ "$MODE" = apply ]; then
    if [ -n "$id" ]; then
      gh api -X PUT "repos/${REPO}/rulesets/${id}" --input - <<<"$wanted" >/dev/null
    else
      gh api -X POST "repos/${REPO}/rulesets" --input - <<<"$wanted" >/dev/null
    fi
    echo "  [set]  ruleset: ${name}"
  else
    report "ruleset: ${name}" diff
  fi
done

if [ "$MODE" = check ]; then
  if [ "$differs" -eq 0 ]; then echo "The settings match."; else echo "Some settings differ. Run tools/repo-settings.sh --apply."; fi
  exit "$differs"
fi
