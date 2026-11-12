# CI

Scope: the GitHub Actions workflows of this repository. It names the events that start them, what each job tests, and what to do about a failed job.

CI (continuous integration) runs the tests on GitHub-hosted runners. A runner is a fresh virtual machine that GitHub deletes after the job. Standard runners are free with no minute limit for a public repository. The [testing guide](testing.md) explains each test.

## Why GitHub Actions

The CI service must be free for this project, with Linux and with macOS on Apple silicon. GitHub Actions is the only service that is free with no limit on both. CircleCI gives an open-source project free Linux minutes, but macOS minutes only from the small Free plan. GitLab.com gives 400 compute minutes each month, and a macOS minute counts 6 times or more. Cirrus CI shut down on 2026-06-01.

No free service can start a macOS VM in its runner. For that reason, the macOS jobs run the real setup on the runner itself. The Tart check of [After a release](testing.md#after-a-release) stays a local test.

## The workflows

| Workflow | File | When it runs |
|----------|------|--------------|
| CI | `.github/workflows/ci.yml` | For each pull request, once a week on Monday, and by hand. |
| Release check | `.github/workflows/release.yml` | When a release is published, and by hand. A pre-release does not start it. |

Each trigger finds a different kind of problem:

- A pull request finds a change that breaks a test, before the merge.
- A release finds a problem in the published files: the archives, the checksums, the `latest` links, and the install from `curl`. A pull request cannot test these files, because they do not exist yet.
- The weekly run finds a change outside the repository, with no change in the code. For example, Ubuntu, Debian, Homebrew, or the runner image can change. The weekly run also installs the Neovim language tools (`FULL=1`).

`tools/release.sh` publishes with the GitHub account of the person. For that reason, the release starts the release check. An event from the `GITHUB_TOKEN` of a workflow does not start a new workflow.

## The jobs of CI

| Job | Runner | Tests |
|-----|--------|-------|
| Fast checks | `ubuntu-24.04` | `shellcheck`, `tests/test-skills.sh`, `tests/test-hopen-list.sh`, `tests/test-install.sh`, `tests/test-nvim-plugins.sh`, `tests/test-links.sh` |
| Linux server | `ubuntu-24.04` and `ubuntu-24.04-arm` | `tests/run-linux.sh`, `tests/run-prereqs.sh` |
| Linux login service and client keys | `ubuntu-24.04` | `tests/run-systemd.sh`, `tests/run-client-linux.sh` |
| macOS server | `macos-26` | A real `bootstrap.sh server --yes` on the runner, then `bootstrap.sh server --check`, then `tests/run-macos.sh` |

The Linux tests start their own containers on the runner, as on a machine of a contributor. The jobs run at the same time. A pull request gets its result in about 8 minutes.

## The jobs of the release check

| Job | Runner | Tests |
|-----|--------|-------|
| Linux | `ubuntu-24.04` and `ubuntu-24.04-arm` | `tests/run-release-check.sh --only linux`: fresh Ubuntu and Debian containers |
| macOS | `macos-26` | The install from the `latest` links on the runner, then `tests/tour-release.sh` |

To check a release again, open the Actions tab, choose "Release check", and click "Run workflow". Type the tag, or leave it empty for the latest release. With the GitHub CLI:

```bash
gh workflow run release.yml -f tag=0.5.0
```

## When a job fails

1. Open the failed job. The step that failed shows its `FAIL` lines. For the tests that write logs, the step "Show the logs" prints the end of each log in `tests/.work`.
2. Run the same test on your own machine. Follow the `herdspace-test` skill, or the [testing guide](testing.md).
3. If the test passes on your machine and fails on the runner, the test can depend on your machine. For example, the test can use a tool that the runner does not have. Fix the test so that it makes what it needs.

To run a failed job again, open the run, and click "Re-run failed jobs". A new push to the branch of a pull request cancels the run that is still going for that pull request.

## Security rules

These rules follow [Secure use of GitHub Actions](https://docs.github.com/en/actions/reference/security/secure-use):

- Each workflow sets `permissions: contents: read`. If a job needs more, give it to that job only.
- Each action is pinned to a full commit SHA, with the version in a comment.
- The checkout keeps no credentials (`persist-credentials: false`).
- The workflows use `pull_request`, never `pull_request_target`. A pull request from a fork gets a read-only token and no secrets.
- A value from an event goes to a step through `env`, not inside the script text.
- The workflows use no secrets and no self-hosted runner.

## Required checks

Each CI job is a required check for a merge to `main`. The [repository settings](repository-settings.md) list the checks. If you rename a job, change the name in `tools/repo-settings.sh` in the same pull request.

## Limits

| Limit | Value |
|-------|-------|
| Jobs at a time | 20, and 5 of them on macOS |
| Time for one job | 6 hours. The jobs here stop after 60 minutes. |
| Weekly run | GitHub turns off a scheduled workflow after 60 days with no activity in a public repository. The time of a scheduled run is not exact. |
| Ghostty on macOS | A macOS runner has no screen. The real key test runs only in the Linux client test. |

## References

- [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions)
- [GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
- [Actions limits](https://docs.github.com/en/actions/reference/limits)
- [Events that trigger workflows](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows)
- [GITHUB_TOKEN](https://docs.github.com/en/actions/concepts/security/github_token)
- [CircleCI pricing](https://circleci.com/pricing/), [GitLab pricing](https://about.gitlab.com/pricing/), [Cirrus Labs](https://cirruslabs.org/)
