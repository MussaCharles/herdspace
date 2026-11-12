# Testing

Scope: the tests of this repository, what each test proves, and how to run it.

GitHub Actions runs most of these tests for each pull request, each release, and once a week. See the [CI guide](ci.md).

The Linux tests use throwaway Docker containers. The macOS test runs on a Mac with a temporary home folder and stub commands. For a test of the real macOS setup, use a VM. See [Test in a sandbox](#test-in-a-sandbox). No test changes your own account.

## The tests

| Test | What it proves |
|------|----------------|
| `tests/run-linux.sh` | A full server setup works in Ubuntu and Debian containers, and a second run changes nothing. |
| `tests/run-systemd.sh` | The login service starts Herdr in a container with real systemd, and it starts Herdr again after a crash. |
| `tests/run-client-linux.sh` | A Linux client connects to a server in a second container. Real Ghostty key presses reach Herdr over SSH. |
| `tests/run-macos.sh` | The macOS scripts work with a temporary home folder and stub commands. It needs Python 3.11 or later from Homebrew. |
| `tests/test-install.sh` | A release builds, `install.sh` installs `hopen`, and `bootstrap.sh` from `curl` picks the right script. |
| `tests/run-prereqs.sh` | The prerequisites step finds and installs a missing locale, stops with a fix when `sudo` is missing, works as root, and reports a server with no SSH. |
| `tests/test-hopen-list.sh` | `hopen` reads each list setting, refuses crafted lists, and keeps session names safe. It needs no Herdr, and it runs in a second. |
| `tests/bench-hopen.sh` | Measures how long `hopen` takes with 20 projects. `tests/run-linux.sh` runs it after the server setup. See [Benchmark](#benchmark). |
| `tests/test-nvim-plugins.sh` | After a failed plugin download, the Neovim plugin step warns, and the next run tries again. It uses a stub `nvim`, and it runs in a second. |
| `tests/test-ci-changes.sh` | `tools/ci-changes.sh` finds a pull request that changes only docs, in a temporary git repository. |
| `tests/test-links.sh` | Each relative link of each Markdown file points at a file that exists, and each `#anchor` matches a heading. A link in a community file in `.github/` starts with `/`. It needs no network. |
| `tests/test-skills.sh` | Each skill follows the Agent Skills specification, and each Claude Code link points at its skill. |
| `tests/run-release-check.sh` | A published release installs from the `latest` links in a fresh container and a fresh macOS VM, and each `hopen` feature works there. See [After a release](#after-a-release). |

A container cannot run macOS. For that reason, `tests/run-macos.sh` does not change macOS shortcuts or install Homebrew packages.

## Run the tests

Run each command from the root folder of this repository:

```bash
tests/run-linux.sh
```

```bash
tests/run-systemd.sh
```

```bash
tests/run-client-linux.sh
```

```bash
tests/run-macos.sh
```

```bash
tests/test-install.sh
```

```bash
tests/run-prereqs.sh
```

```bash
tests/test-hopen-list.sh
```

```bash
tests/test-skills.sh
```

```bash
tests/test-links.sh
```

Each test prints one `PASS` or `FAIL` line for each check, and a `RESULT` line at the end. The logs go to `tests/.work`.

| Option | Effect |
|--------|--------|
| `tests/run-linux.sh ubuntu:26.04` | Test another image. The default images are `ubuntu:24.04` and `debian:12`. |
| `FULL=1` | Also install the Neovim language tools. A run takes longer. |
| `NO_CACHE=1` | Build each image from the start, remove it after the run, and download every package again. |
| `APT_MIRROR_UBUNTU=<address>` | Try this Ubuntu mirror before the default one. On an ARM machine, use a mirror with `ubuntu-ports`, for example `http://<mirror>/ubuntu-ports`. |
| `APT_MIRROR_DEBIAN=<address>` | Try this Debian mirror before the default one, for example `http://<mirror>/debian`. |
| `CLIENT_BASE=<image>` | `run-client-linux.sh`: test another client image. |
| `tests/run-macos.sh server` | Test only the server, or only the `client`. |

## Benchmark

`tests/run-linux.sh` prints the time of the server setup and of `hopen` with a list of 20 projects:

```text
RESULT bench setup=<seconds>s
RESULT bench plain first=<seconds>s second=<seconds>s projects=20
RESULT bench code first=<seconds>s second=<seconds>s projects=20
```

`first` is the run that creates 20 workspaces. `second` is a run that adds nothing. `plain` opens one pane in each workspace, and `code` splits each workspace into the panes of the `code` template. The benchmark fails only if a workspace is missing. To use another count, run `tests/bench-hopen.sh 50` on a server machine.

Compare a new run with this reference run. If a time is much longer, find the cause before a release.

| Measure | Time |
|---------|------|
| `setup`, with the download cache | 42 s |
| `plain`, first run | 0.5 s |
| `plain`, second run | 0.0 s |
| `code`, first run | 1.3 s |
| `code`, second run | 0.0 s |

The reference run used `ubuntu:24.04` in Docker, on an Apple M4 Pro, on 2026-11-11.

## Test in a sandbox

Run the tests, and each manual trial of the setup, in a sandbox. A sandbox is a throwaway system that you delete after the test, so that a test never changes your own machine.

### Linux: Docker containers

The Linux tests make their own containers, so they need only Docker, for example Docker Desktop, OrbStack, or Docker Engine. For a manual trial, start a new Ubuntu container:

```bash
docker run --rm -it ubuntu:24.04 bash
```

In the container, install `curl` and `sudo` with `apt-get`, and run the setup command from the README. The container goes away when you leave it.

### macOS: a Tart VM

A container cannot run macOS. On a Mac with Apple silicon, [Tart](https://github.com/openai/tart) runs macOS virtual machines (VMs) with Apple's Virtualization framework. A VM is a full macOS, so you can test the real setup with no stubs.

1. Install Tart. It needs `softnet`, a network helper from the same Homebrew tap, and Homebrew asks you to trust it:

   ```bash
   brew tap openai/tools
   ```

   ```bash
   brew trust --formula openai/tools/softnet
   ```

   ```bash
   brew install openai/tools/tart
   ```

2. Download a clean macOS image one time, and keep it. It has the user `admin`, Homebrew, and `sudo` with no password. The download is about 33 GB:

   ```bash
   tart clone ghcr.io/cirruslabs/macos-tahoe-base:latest tahoe-base
   ```

3. For each test, clone the image, and start the clone with no window. `--dir` shares this repository with the VM as read-only:

   ```bash
   tart clone tahoe-base hs-test
   ```

   ```bash
   tart run hs-test --no-graphics --dir=herdspace:$PWD:ro &
   ```

4. Run the setup in the VM:

   ```bash
   tart exec hs-test zsh -lc 'cp -R "/Volumes/My Shared Files/herdspace" ~/herdspace && cd ~/herdspace && ./bootstrap.sh both --yes </dev/null'
   ```

5. Delete the clone. The image stays for the next test:

   ```bash
   tart stop hs-test && tart delete hs-test
   ```

Apple allows two macOS VMs at a time on one Mac. If the VM cannot resolve host names, set a public DNS server in it, for example with `tart exec hs-test sudo networksetup -setdnsservers Ethernet 1.1.1.1`.

## The download cache

By default, the Linux tests keep their Docker images, and they share the apt downloads of each base image between runs. Each test still starts from a new container and runs the full setup. Only the downloads are reused, so a second run is faster, and a slow package mirror costs less time.

The downloads are in Docker volumes with names that start with `herdspace-test-apt-`. To test a fresh download, run a test with `NO_CACHE=1`:

```bash
NO_CACHE=1 tests/run-linux.sh
```

If the default mirror is slow or does not answer, give a mirror that is near you. apt tries that mirror first. If it fails, apt uses the default mirror:

```bash
APT_MIRROR_UBUNTU=http://<mirror>/ubuntu-ports APT_MIRROR_DEBIAN=http://<mirror>/debian tests/run-linux.sh
```

To remove the cache, remove the volumes:

```bash
docker volume ls -q --filter name=herdspace-test-apt- | xargs docker volume rm
```

## Make the screenshots and videos again

`tests/capture-media.sh` records the images and videos in `docs/media` with real Ghostty and real key presses. The files go to `tests/.work/media`. Look at them, and then copy the ones that you want to `docs/media`.

```bash
tests/capture-media.sh
```

The GIF files play 3 times faster than the recording. To change the speed, set `SPEED`, for example `SPEED=2`.

## Before a release

Run every test above. All tests must pass. Then follow [Make a release](updating.md#make-a-release).

## After a release

`tests/run-release-check.sh` installs the published release in the same way as a person. It uses a fresh container for each Linux image, and a fresh clone of the Tart image. In each one, `tests/tour-release.sh` tries each `hopen` feature: the menu, folders, approval, `env_file`, completion, tasks, find and search, ports, the palette, templates, `--convert`, and attach and detach.

```bash
tests/run-release-check.sh --version 0.5.0
```

The check runs only the sandboxes that the machine supports. It prints a `SKIP` line for each one that it cannot run. `--only linux` or `--only macos` runs one kind. The macOS part needs Tart and the `tahoe-base` image. See [macOS: a Tart VM](#macos-a-tart-vm). The VM and the containers are deleted at the end.

Do not run `tests/tour-release.sh` on your own machine. It starts a Herdr server and writes lists in the home folder.

## Pitfalls in tests

These mistakes broke tests before:

- A fixed port can be in use. Use a random port, and stop each server that a test starts.
- `pgrep -f` finds its own command line. Write a pattern such as `"hopen [-]-palette"`.
- If the keys hold a filter and Enter, fzf can take Enter first. Send only Enter.
- fzf draws nothing with no `TERM`. A test of the numbered menu sets `TERM=dumb`.
- The zsh setup loads `ff`, `fif`, and the completion only in a terminal. Run zsh with `tests/pty_run.py`, not with `zsh -ic` and no terminal.
- On macOS, `/var` is a link to `/private/var`. Compare folders by their real paths.
- A small Linux image has no `ss` or `lsof`. Do not depend on a tool that the setup does not install.
