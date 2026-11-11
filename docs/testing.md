# Testing

Scope: the tests of this repository, what each test proves, and how to run it.

The Linux tests use throwaway Docker containers. The macOS test runs on a Mac with a temporary home folder. No test changes your own account.

## The tests

| Test | What it proves |
|------|----------------|
| `tests/run-linux.sh` | A full server setup works in Ubuntu and Debian containers, and a second run changes nothing. |
| `tests/run-systemd.sh` | The login service starts Herdr in a container with real systemd, and it starts Herdr again after a crash. |
| `tests/run-client-linux.sh` | A Linux client connects to a server in a second container. Real Ghostty key presses reach Herdr over SSH. |
| `tests/run-macos.sh` | The macOS scripts work with a temporary home folder and stub commands. |
| `tests/test-install.sh` | A release builds, `install.sh` installs `hopen`, and `bootstrap.sh` from `curl` picks the right script. |
| `tests/run-prereqs.sh` | The prerequisites step finds and installs a missing locale, stops with a fix when `sudo` is missing, works as root, and reports a server with no SSH. |
| `tests/test-hopen-list.sh` | `hopen` reads each list setting, refuses crafted lists, and keeps session names safe. It needs no Herdr, and it runs in a second. |
| `tests/test-skills.sh` | Each skill follows the Agent Skills specification, and each Claude Code link points at its skill. |

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
