# Install herdspace

These instructions are for a coding agent that installs herdspace for a person. Follow the steps in order. Do not clone the repository. Every command downloads a release.

herdspace is a workspace and session manager for Herdr. It uses two machines. The server machine runs Herdr, the projects, and the agents. The client machine is the machine that the person uses, and it connects to the server machine with SSH.

The release in these instructions is `v0.1.1`. All commands use this address:

```text
https://github.com/MussaCharles/herdspace/releases/download/v0.1.1
```

## 1. Find the task

If the person did not say it, ask which of these four tasks they want on this machine:

| Task | Use when |
|------|----------|
| `server` | This machine is the server machine. It will run Herdr and the projects. |
| `client` | This machine is the client machine. The person connects from it to a server machine. |
| `both` | This one machine is the server machine and the client machine. The person uses Herdr on it, with no SSH. |
| `hopen` | This machine has Herdr already. The person wants only the `hopen` command and its templates. |

For `client`, ask for the SSH name of each server, for example `my-server`. An address such as `me@203.0.113.10` also works.

## 2. Make sure that the system is supported

Run `uname -s`. herdspace supports macOS, Debian, Ubuntu, and Windows with WSL. On Windows, work inside WSL. On another system, stop and tell the person.

For `hopen`, make sure that `herdr`, `python3`, and `curl` are installed. If one is missing, tell the person and stop.

## 3. Install only hopen

Do this step only for the `hopen` task. Then go to step 7.

```bash
curl -fsSL https://github.com/MussaCharles/herdspace/releases/download/v0.1.1/install.sh | bash
```

## 4. Make sure that SSH works (client only)

For each server, run:

```bash
ssh -o BatchMode=yes -o ConnectTimeout=5 my-server true && echo ok
```

If the command does not print `ok`, the server needs an SSH key. Follow [Connect with an IP address](https://github.com/MussaCharles/herdspace/blob/v0.1.1/docs/setup.md#connect-with-an-ip-address):

- Before you change `~/.ssh/config`, ask the person.
- `ssh-copy-id` asks for the password of the server. Give the command to the person, and ask them to run it in their own terminal.

If a server still fails, tell the person and leave it out.

## 5. Look before you change

Run the setup with `--check`. It changes nothing. For `server`:

```bash
curl -fsSL https://github.com/MussaCharles/herdspace/releases/download/v0.1.1/bootstrap.sh | bash -s -- server --check
```

For `client`, with one `--server` for each server:

```bash
curl -fsSL https://github.com/MussaCharles/herdspace/releases/download/v0.1.1/bootstrap.sh | bash -s -- client --server my-server --check
```

For `both`, use this command. Do not run `server` and then `client` on one machine. Each one undoes a part of the other.

```bash
curl -fsSL https://github.com/MussaCharles/herdspace/releases/download/v0.1.1/bootstrap.sh | bash -s -- both --check
```

Show the output to the person, and tell them what a run changes:

- A line with `[todo]` is a part that the setup adds.
- A line with `[diff]` is a file that is different from the herdspace version. Ask the person if the setup can replace these files. The setup keeps a backup of each file that it replaces.
- On Linux, the setup makes zsh the login shell.
- On a macOS client or `both`, the setup changes four Mission Control shortcuts. Ask if they want to keep them. If they do, add `--skip-mission-control`.

Wait until the person agrees.

## 6. Run the setup

Run the same command as in step 5, without `--check`. Add one of these options from the answer of the person:

- `--replace-all`: replace each `[diff]` file, with a backup.
- `--keep-existing`: add only what is missing, and change no existing file.

When you run the setup, it cannot ask questions. For that reason, one of these options is necessary. Homebrew or `sudo` can ask for a password. If that happens, stop, give the full command to the person, and ask them to run it in their own terminal.

## 7. Make sure that it works

- `server` or `both`: run `herdr --version` and `hopen --version`. Then run the command of step 5 again. It must show no `[todo]` line.
- `client`: for each server, run `ssh my-server -- infocmp -x xterm-ghostty >/dev/null && echo ok`.
- `hopen`: run `hopen --version` and `hopen --templates`.

Tell the person what changed, and where the backups are. You cannot press keys in the terminal of the person. For a client or `both`, ask the person to do these steps:

1. Open a new Ghostty window.
2. For a client, connect with `ssh my-server`. Then run `herdr`.
3. Press `Cmd+T` on a Mac, or `Ctrl+Shift+T` on Linux, to open a tab.

## Rules

- Do not print the contents of `~/.ssh` or of another secret file.
- Do not edit the files that the setup installs. Run the setup again instead.
- Do not run a command with `sudo` yourself. Ask the person.
- If a step fails, show the error to the person. Do not try other install methods.
