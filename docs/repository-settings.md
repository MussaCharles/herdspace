# Repository settings

Scope: the GitHub settings of this repository, the reason for each one, and how to apply them or compare them.

The settings are in `tools/repo-settings.sh`. The script is the record of the settings, so a change to a setting goes in the script first, through a pull request.

## Apply or compare the settings

You need `gh` and an account with admin access to the repository. To show each setting that differs, with no change:

```bash
tools/repo-settings.sh --check
```

To make the settings on GitHub match the script:

```bash
tools/repo-settings.sh --apply
```

## The branch `main`

Two rulesets protect `main`. A ruleset is a named list of rules for branches or tags. All rulesets for a branch apply together.

| Ruleset | Rules | Who can skip it |
|---------|-------|-----------------|
| main: pull requests and CI | A pull request is necessary for each change. Each CI job must pass. The jobs are "Fast checks", four "Linux server" jobs, "Linux login service and client keys", and "macOS server". Only merge commits are allowed. No force push, and no deletion. | Nobody, the owner too. |
| main: who can merge | Only a person in the bypass list can push to `main` or merge into it. | The repository admin role. Today, only the owner has it. |

To merge a pull request after every CI job passes, a person in the bypass list must say that they use the bypass. On the web page, tick the box that bypasses the rules. With the GitHub CLI:

```bash
gh pr merge <number> --merge --admin --delete-branch
```

`--admin` skips only the rules that you can bypass. It skips "main: who can merge", but not "main: pull requests and CI", because that ruleset has no bypass. A pull request with a failed or a missing check still cannot merge.

A pull request needs no approval. A person cannot approve their own pull request, so a required approval stops a project with one maintainer. The CI jobs do the check.

If you rename a job in `.github/workflows/ci.yml`, change its name in `tools/repo-settings.sh` in the same pull request. Merge the other open pull requests first. Then run `--apply` from the branch of the pull request, before its merge. A required check with an old name never passes, so a pull request that waits for it cannot merge.

## Release tags

The ruleset "release tags" covers all tags. Only the repository admin role can create, move, or delete a tag. A published tag must never move. `tools/release.sh --publish` runs with the account of the owner, so it can create the tag.

## GitHub Actions

| Setting | Value | Reason |
|---------|-------|--------|
| Allowed actions | Only the actions that GitHub made | The workflows use only `actions/checkout`. An action from another source can run any code. |
| Pinned actions | Each action must use a full commit SHA | A tag can move to other code. A SHA cannot. |
| Workflows from forks | Approval for all external contributors | A pull request from a fork runs only after the owner reads it. |
| `GITHUB_TOKEN` | Read-only, and it cannot approve pull requests | A workflow gets more rights only from its own file. |

Dependabot updates the SHA of each action once a week, from `.github/dependabot.yml`. Its pull requests run CI as any other pull request.

## Security features

| Feature | State |
|---------|-------|
| Dependabot alerts and security updates | On |
| Secret scanning and push protection | On. A push with a known secret, for example a token, stops before it reaches GitHub. |
| Code scanning | CodeQL default setup, for the workflows and the Python files. CodeQL has no support for shell scripts, so `shellcheck` in CI checks them. |
| Private vulnerability reporting | On. The security policy is `.github/SECURITY.md`. |

## General

| Setting | Value |
|---------|-------|
| Merge methods | Merge commits only |
| Delete the branch after a merge | On |
| Suggest an update of the branch of a pull request | On |
| Wiki and projects | Off. The docs are in the repository, and the plans are in issues. |

## Not used

- Required signed commits. Each contributor and each coding agent needs a signing key first.
- CODEOWNERS. With one maintainer, it adds nothing.
- Interaction limits. They are for a wave of spam, not a setting to keep on. See [Limiting interactions](https://docs.github.com/en/communities/moderating-comments-and-conversations/limiting-interactions-in-your-repository).

## References

- [About rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)
- [Available rules for rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)
- [Managing GitHub Actions settings for a repository](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository)
- [Quickstart for securing your repository](https://docs.github.com/en/code-security/getting-started/securing-your-repository)
- [About code scanning with CodeQL](https://docs.github.com/en/code-security/code-scanning/introduction-to-code-scanning/about-code-scanning-with-codeql)
- [REST API: repository rules](https://docs.github.com/en/rest/repos/rules), [REST API: Actions permissions](https://docs.github.com/en/rest/actions/permissions)
