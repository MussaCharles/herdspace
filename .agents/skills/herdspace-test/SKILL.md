---
name: herdspace-test
description: Run the herdspace tests on the sandboxes that this machine supports, and check a published release in a fresh sandbox. Use it for a pull request, a release, a new or changed test, or a trial of the features.
---

# Run the tests

The tests run in sandboxes. Linux tests use Docker containers. macOS tests use a Tart VM, or a temporary home folder with stub commands. A machine can support some of them and not others. Find out first, run the tests for each sandbox that exists, and report each one that you skipped. The [testing guide](../../../docs/testing.md) explains each test.

## 1. Find the sandboxes of this machine

Run each check. Do not install a missing tool without the agreement of the person.

| Sandbox | Signs that it is ready | The tests that need it |
|---------|----------------|------------------------|
| Linux containers | `docker info` answers | `tests/run-linux.sh`, `tests/run-systemd.sh`, `tests/run-prereqs.sh`, `tests/capture-media.sh` |
| Ghostty in a container | Docker answers, and the machine can build `tests/Dockerfile.client` | `tests/run-client-linux.sh` (real key presses) |
| macOS stubs | `uname -s` is `Darwin`, and Homebrew has the server tools (Herdr, Neovim, and the others) and Python 3.11 or later. The test uses the real tools, with a temporary home folder. Only commands that change the system are stubs. | `tests/run-macos.sh` |
| macOS VM | `uname -m` is `arm64` on a Mac, `tart` is installed, and `tart list --quiet` shows the base image (`tahoe-base`) | the macOS part of `tests/run-release-check.sh` |
| Any machine | bash, git, and Python 3.11 or later | `tests/test-hopen-list.sh`, `tests/test-skills.sh`, `tests/test-install.sh`, `tests/test-nvim-plugins.sh`, `tests/test-links.sh`, `tests/test-ui.sh`, `shellcheck` |

## 2. Run the tests that the change touches

| You changed | Run |
|-------------|-----|
| `bin/hopen` or a template | `tests/test-hopen-list.sh`, then `tests/run-linux.sh` and `tests/run-macos.sh server` |
| A setup script or a configuration file | `tests/test-install.sh`, `tests/run-macos.sh`, `tests/run-linux.sh` |
| A key, or the client setup | `tests/run-client-linux.sh` too |
| The login service | `tests/run-systemd.sh` too |
| The prerequisites step | `tests/run-prereqs.sh` |
| A skill or `AGENTS.md` | `tests/test-skills.sh` |
| A Markdown file | `tests/test-links.sh` |
| The output or a question of the setup | `tests/test-ui.sh` |
| A release, before you publish it | every test above |
| A release, after you publish it | `tests/run-release-check.sh` |

Run a test that takes more than two minutes in the background, with its output in a log file in `tests/.work`. Watch it with a quiet script. The script prints a line in two cases: the test ends, or the log stops growing for five minutes. Start such a script with `bash` by name, because your own shell can be zsh. If a test stops moving, find the cause. For example, a question can wait for an answer. Do not wait forever.

## CI

GitHub Actions runs the tests on fresh runners for each pull request, each release, and once a week. The [CI guide](../../../docs/ci.md) lists the jobs. CI does not replace a local run: run the tests of the change before you push. If a test passes on your machine and fails in CI, the test can depend on your machine. Make the test create what it needs, for example a stub program or a terminal description. The `herdspace-ci` skill lists the CI failures that happened before. The Tart check stays local, because no hosted runner can start a macOS VM.

## 3. Report

Copy the `FAIL` and `RESULT` lines into the pull request or the reply. Name each sandbox that this machine does not have, and the tests that did not run for that reason. If you skipped a sandbox, do not say that all tests pass.

## Check a release after the publish

`tests/run-release-check.sh` runs each option of the Quick start of the README: `server`, `client`, `both`, and `hopen`. It reads each command from `README.md`, and installs the published release in fresh containers and fresh clones of the Tart image. Then it checks the result, and runs `tests/tour-release.sh` where `hopen` is installed. The testing guide has a table of what it does for each option.

```bash
tests/run-release-check.sh --version 0.5.0
```

- Name options to run only them, for example `client hopen`. `--only linux` or `--only macos` runs one kind of sandbox. A sandbox that the machine cannot run prints a `SKIP` line.
- If you change a command in the Quick start, the check runs the new command. If you add an option to the Quick start, add it to the check.
- If you add a feature that a person can see, add a step for it to `tests/tour-release.sh`. If the feature needs a tool of the setup, skip the step in `--only-hopen` mode.
- The sandboxes have no Ghostty window, so the check does not press the keys. `tests/run-client-linux.sh` does that before the release.

## Pitfalls that broke tests before

- A fixed port can be in use by another program, or by a server that an earlier test left. Use a random port, and stop each server that a test starts.
- `pgrep -f "hopen --palette"` finds its own command line. Write the pattern as `"hopen [-]-palette"`.
- If the keys hold a filter and Enter, fzf can take Enter first. Send only Enter, and choose the first item.
- fzf draws nothing with no `TERM`. A test of the numbered menu sets `TERM=dumb`.
- The zsh setup loads `ff`, `fif`, and the completion only in a terminal. `zsh -ic ... </dev/null` has no terminal. Use `tests/pty_run.py`.
- On macOS, `/var` is a link to `/private/var`, so compare folders by their real paths.
- `curl ... | bash -s -- ARGS </dev/null` gives bash an empty script, because the redirect replaces the pipe. zsh joins both inputs (`MULTIOS`), so the same line works in zsh and fails in bash.
- A script that changes its folder must find its own files first, with `HERE="$(cd "$(dirname "$0")" && pwd)"`. A relative path from `$0` breaks after a `cd`. The release check of a macOS runner found this in `tests/tour-release.sh`.
- A test that makes a temporary git repository must keep its own output files outside that repository. Else the next commit of the test takes them as a change. Set `core.hooksPath` to `/dev/null` there too, so that the hooks of your machine do not run.
- Do not edit a script while it runs. bash reads a script while it runs it, so an edit can break the rest of the run, for example with "unexpected EOF".
- `docker exec` starts with no file mask, so the files that it makes are world-writable. `sudo` then refuses `/etc/sudoers.d`, and `ssh` refuses `~/.ssh/config`. Start such a command with `umask 022`, or `umask 077` for `~/.ssh`.
- At its first start, Herdr shows an onboarding flow that takes the keys. A Herdr config with `onboarding = false` skips it. The full setup installs one. A test of "Only hopen" writes one first.
- A small Linux image has no `ss`, `lsof`, `curl`, or `procps`. Do not let a test depend on a tool that the setup does not install.
- In a Tart VM, host names can fail because the DNS proxy of the host refuses the VM. Set a public DNS server in the VM. Do not start the base image. Clone it.
- Apple allows two macOS VMs at a time on one Mac.
- Herdr stops in a terminal with no size. `tests/pty_run.py` gives its terminal a size. A test window must have a size before Herdr starts in it.
- If the Ghostty window of a client test does not open, the test must stop with the Ghostty log. A test that waits for a window can wait forever. A window can also close after the test found it, so `open_ghostty` checks it again after its wait.
- Each command that `tests/lib-pair.sh` runs in a container has a time limit, `STEP_LIMIT` (15 minutes by default). Keep a time limit on each new helper, so that one stuck command fails the test.
- A slow or broken package mirror looks like a stuck test. Set `APT_MIRROR_UBUNTU` or `APT_MIRROR_DEBIAN`. See the testing guide.
- Find the real cause of a failed test before you add code. Code that answers the terminal queries of fzf did not fix a fzf test, because the cause was a race. The code was removed again.

## Rules

- Do not run a test against the Herdr server of the person, and do not close their panes. The tests make their own sessions in a sandbox.
- Do not run `tests/tour-release.sh` on your own machine. It starts a Herdr server and writes lists in the home folder.
- A failed check can be a mistake in the test. Before you change the code, find out where the mistake is, and tell the person.
