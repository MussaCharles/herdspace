---
name: herdspace-test
description: Run the herdspace tests on the sandboxes that this machine supports, and check a published release in a fresh sandbox. Use it for a pull request, a release, a new or changed test, or a trial of the features.
---

# Run the tests

The tests run in sandboxes. Linux tests use Docker containers. macOS tests use a Tart VM, or a temporary home folder with stub commands. A machine can support some of them and not others. Find out first, run the tests for each sandbox that exists, and report each one that you skipped. The [testing guide](../../../docs/testing.md) explains each test.

## Only in a sandbox

A test must never change the real home folder of the person or talk to their Herdr server. Two mistakes did that before. A loop over each `tests/test-*.sh` file ran the setup in the real home folder, and reloaded the configuration of the running Herdr sessions. A part of `tests/verify-server.sh`, cut out and run by hand, made a workspace in a session of the person, and wrote a file in their cache.

- Start a test that runs the setup, Herdr, or `hopen` only through its `tests/run-*.sh` script. That script gives it a container, or a temporary home folder and its own Herdr server.
- `tests/test-upgrade.sh`, `tests/test-rollback.sh`, `tests/test-live-update.sh`, and `tests/test-idempotent.sh` run in a container only. Do not run every `tests/test-*.sh` file in a loop.
- `tests/verify-server.sh` runs only inside the sandbox of `tests/run-linux.sh` or `tests/run-macos.sh`. Do not run a part of it by hand.
- A new test that runs the setup in the home folder must source `tests/sandbox-guard.sh`. It stops the test on the real home folder, outside a container.
- To try a change by hand, use a container, or set `HOME` to a temporary folder and start a Herdr server with its own session. Do not use the Herdr server of the person.

## 1. Find the sandboxes of this machine

Run each check. Do not install a missing tool without the agreement of the person.

| Sandbox | Signs that it is ready | The tests that need it |
|---------|----------------|------------------------|
| Linux containers | `docker info` answers | `tests/run-linux.sh`, `tests/run-systemd.sh`, `tests/run-prereqs.sh`, `tests/capture-media.sh` |
| Ghostty in a container | Docker answers, and the machine can build `tests/Dockerfile.client` | `tests/run-client-linux.sh` (real key presses) |
| macOS stubs | `uname -s` is `Darwin`, and Homebrew has the server tools (Herdr, Neovim, and the others) and Python 3.11 or later. The test uses the real tools, with a temporary home folder. Only commands that change the system are stubs. | `tests/run-macos.sh` |
| macOS VM | `uname -m` is `arm64` on a Mac, `tart` is installed, and `tart list --quiet` shows the base image (`tahoe-base`) | the macOS part of `tests/run-release-check.sh` |
| Any machine | bash, git, and Python 3.11 or later | The fast tests: `tests/test-*.sh`, and `shellcheck`. `docs/testing.md` lists each one. `tests/test-extras-keys.sh` and `tests/test-extras-ls.sh` also need zsh. CI runs them with zsh 5.8 in an `ubuntu:22.04` container too. |

## 2. Run the tests that the change touches

| You changed | Run |
|-------------|-----|
| `bin/hopen`, `lib/hopen/`, or a template | `tests/test-hopen-list.sh` and `tests/test-palette-groups.sh`, then `tests/run-linux.sh` and `tests/run-macos.sh server` |
| A setup script or a configuration file | `tests/test-install.sh`, `tests/run-macos.sh`, `tests/run-linux.sh` |
| `bin/herdspace` or `lib/herdspace/` | `tests/test-herdspace-cmd.sh` and `tests/test-uninstall.sh`, then `tests/run-linux.sh` and `tests/run-rollback.sh`, which runs `herdspace update --version` |
| A file in `bootstrap/lib/` | `tests/test-ui.sh` and the other fast tests, then every `tests/run-*.sh` script |
| A key, or the client setup | `tests/run-client-linux.sh` too |
| The login service | `tests/run-systemd.sh` too |
| The prerequisites step | `tests/run-prereqs.sh` |
| A skill or `AGENTS.md` | `tests/test-skills.sh` |
| A Markdown file | `tests/test-links.sh` |
| `config/shell/extras.zsh` | `tests/test-extras-keys.sh` and `tests/test-extras-ls.sh`, also in an `ubuntu:22.04` container (zsh 5.8) |
| The package list of the Linux setup | `tests/test-linux-packages.sh` |
| The agents of the server setup | `tests/test-agents.sh` |
| `tools/known-hashes.sh` | `tests/test-known-hashes.sh` |
| `tools/wait-release-files.sh` | `tests/test-wait-release-files.sh` |
| The palette, quick open, or a pane helper of `hopen` | `tests/run-linux.sh`, also once with less than one CPU (see "A slow machine") |
| The output or a question of the setup | `tests/test-ui.sh` |
| A release, before you publish it | every test above |
| A release, after you publish it | `tests/run-release-check.sh` |

Run a test that takes more than two minutes in the background, with its output in a log file in `tests/.work`. Watch it with a quiet script. The script prints a line in two cases: the test ends, or the log stops growing for five minutes. Start such a script with `bash` by name, because your own shell can be zsh. If a test stops moving, find the cause. For example, a question can wait for an answer. Do not wait forever.

## A slow machine

A CI runner, and an arm64 runner most of all, is slower than your machine. A race that never shows on your machine can fail there. A change can touch the palette, quick open, or another step that waits for Herdr or Neovim. Before you push it, run the Linux test once with less than one CPU. Make a copy of `tests/run-linux.sh` that adds `--cpus 0.7` to `docker run`, and run the copy. Do not commit the copy.

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
- `curl ... | bash -s -- ARGS </dev/null` gives bash an empty script, because the redirect replaces the pipe. zsh joins both inputs (`MULTIOS`), so the same line works in zsh and fails in bash. The release check fails a setup run whose log has no first line `herdspace setup (bootstrap.sh`, because such a run exits 0 with no output.
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
- Text that `herdr pane run` sends to a new pane before its shell starts gets lost. `hopen` waits for the prompt with `pane_ready`. A test must also wait until a pane runs the expected program before it sends the next key.
- At its first start, the herdspace Neovim installs parsers and language tools in the background, and prints many messages. A quit then can wait for a key. A test that quits Neovim must wait long enough. On a failure, it must dump the screen.
- LazyVim loads `lua/config/keymaps.lua` after startup. A key that must work at once belongs in the `keys` of a plugin spec that loads at startup.
- `tests/pty_run.py` sends all its keys at once, at half of its time limit, and stops the program at the limit. Give a slow step enough time.
- Leave no busy program behind for the next check. For example, close an editor that a check opened, because its first start takes the CPU.
- When a check fails only on CI, add a dump to the failure: the screen of the pane (`herdr pane read`), and `herdr pane process-info`. Read the dump before you change the code.
- In a container, a test from a git worktree fails "release build". The `.git` file of a worktree points to a path outside the container. Run the test from a normal clone.
- Find the real cause of a failed test before you add code. Code that answers the terminal queries of fzf did not fix a fzf test, because the cause was a race. The code was removed again.

## Rules

- Do not run a test against the Herdr server of the person, and do not close their panes. The tests make their own sessions in a sandbox.
- Do not run `tests/tour-release.sh` on your own machine. It starts a Herdr server and writes lists in the home folder.
- A failed check can be a mistake in the test. Before you change the code, find out where the mistake is, and tell the person.
