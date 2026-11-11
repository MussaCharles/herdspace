---
name: herdspace-ci
description: Change the GitHub Actions workflows or the GitHub settings of the herdspace repository, or find the cause of a failed CI job. Use when you edit .github/workflows/, .github/dependabot.yml, or tools/repo-settings.sh, rename a CI job, or read the log of a failed run.
---

# Change CI and the repository settings

The [CI guide](../../../docs/ci.md) lists the workflows and the jobs. The [repository settings guide](../../../docs/repository-settings.md) lists each GitHub setting and its reason. This skill is the view of a person who changes them.

## Change a workflow

1. Follow the security rules in the CI guide: `permissions: contents: read`, `persist-credentials: false`, values from an event through `env`, no `pull_request_target`, and no secrets.
2. Pin each action to a full commit SHA, with the version in a comment. The repository refuses an action that is not pinned, or that GitHub did not make. To find the SHA of a tag:

   ```bash
   gh api repos/actions/checkout/git/ref/tags/v7.0.1 -q .object.sha
   ```

   If the answer has the type `tag`, not `commit`, read that tag object for its commit.
3. If you rename a job of `ci.yml`, change the name in `CHECKS` in `tools/repo-settings.sh` in the same pull request. After the merge, run `tools/repo-settings.sh --apply`. A required check with an old name never passes, and then no pull request can merge.
4. A workflow file must be on `main` before `gh workflow run` can start it. After that, `--ref <branch>` runs the version of a branch.

## Read a failed job

`gh run view --log-failed` answers only after the whole run ends. To read one job while the others still run:

```bash
gh api repos/MussaCharles/herdspace/actions/jobs/<job-id>/logs --allow-escape-sequences
```

The job IDs are in `gh run view <run-id> --json jobs`. Remove the color codes with `sed 's/\x1b\[[0-9;]*m//g'` before you search the log.

A new push to the branch of a pull request cancels the run that still goes. If you want the result of the slow jobs, commit the next fix, but push it after the run ends.

## Causes of CI failures before

Each of these made a job fail one time:

- A test that passes on your machine and fails on a runner can depend on your machine. A test once needed `rg`, and another needed a Ghostty terminal description in `~/.terminfo`. Make the test create what it needs: a stub program, or a description made from `xterm-256color`.
- systemd in a Docker container did not start on an Ubuntu runner with the cgroups of the host. Use `--cgroupns=private`, with no mount of `/sys/fs/cgroup`. Wait for `systemctl is-system-running` to answer `running` or `degraded`, and try `loginctl enable-linger` again until the login manager answers.
- The pitfalls of the tests themselves are in the `herdspace-test` skill. Read them too.
- A macOS runner has Homebrew and many tools already. It is not a clean Mac, and it has no screen. The real key test runs only in the Linux client test.

## Change a repository setting

1. Change `tools/repo-settings.sh` and `docs/repository-settings.md` in one pull request.
2. After the merge, apply the settings with an account that has admin access:

   ```bash
   tools/repo-settings.sh --apply
   ```

3. Make sure that `tools/repo-settings.sh --check` answers "The settings match."

Do not change a setting only in the web page of GitHub. The next `--apply` puts the value of the script back.

## Merge a pull request

Only the repository admin role can merge, through the bypass of "main: who can merge". Wait until every CI job passes, then merge with `--admin`:

```bash
gh pr merge <number> --repo MussaCharles/herdspace --merge --admin --delete-branch
```

Without `--admin`, `gh` answers "the base branch policy prohibits the merge", also after CI passes. `--admin` does not skip the CI checks, because nobody can bypass that ruleset. An agent with no admin access opens the pull request, and the owner merges it.

## Rules

- Do not turn off a required check or a ruleset to merge a pull request. Fix the cause.
- Do not add a self-hosted runner. A pull request from a fork can run code on it.
- Do not give a workflow write access to the repository, unless a job needs it and the pull request says why.
