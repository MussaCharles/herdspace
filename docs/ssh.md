# Connect to the server with SSH

Scope: what the name `my-server` means, and how to set up the SSH connection from the client machine to the server machine.

## What `my-server` means

`my-server` is an example of an SSH name. An SSH name is a short name for a server in the file `~/.ssh/config` on the client machine. The file keeps the address of the server and the user name for each name. With a name, `ssh my-server` connects to the server, and you do not type the address.

The commands in these docs use `my-server`. Use the name of your server in its place.

The client setup uses SSH with an SSH key. A password does not work for the setup. The steps below make a key and a name.

## Before you start

You need these items:

- The address of the server machine: an IP address such as `203.0.113.10`, or a host name such as `my-server.local`.
- Your user name on the server machine.
- SSH access to the server machine. The owner of the server turns it on. See [Before you start](setup.md#before-you-start) in the setup guide for the official guides.

In the examples, the user on the server is `me`, and the address of the server is `203.0.113.10`.

## Set up the connection

Do these steps on the client machine. On Windows, do them inside WSL.

1. If you do not have an SSH key, make one. Press Enter at each question.

   ```bash
   ssh-keygen -t ed25519
   ```

2. Copy the key to the server. Type the password of the server one more time.

   ```bash
   ssh-copy-id me@203.0.113.10
   ```

3. Give the server a name. Add these lines to `~/.ssh/config`:

   ```text
   Host my-server
     HostName 203.0.113.10
     User me
   ```

4. Make sure that the connection works with no password. The command prints `ok`.

   ```bash
   ssh -o BatchMode=yes my-server true && echo ok
   ```

Then use `--server my-server` in the client setup, and connect each day with `ssh my-server`.

## Use an address with no name

You can give the address to the setup with no name: `--server me@203.0.113.10`. Steps 1 and 2 are still necessary. A name is shorter to type each day.

## If the address changes

If the server machine gets a new address, change only the `HostName` line in `~/.ssh/config`. The name stays the same, so the commands and the setup do not change.

## A server without herdspace

Ghostty sets the terminal type `xterm-ghostty`. A server needs a terminal description (terminfo) for that type. Without it, `clear` and other commands fail with `'xterm-ghostty': unknown terminal type`.

The client setup copies the description to each server of `--server`. For every other server, herdspace turns on the `ssh-env` feature of Ghostty in the `herdspace ssh` block of your Ghostty file. When you type `ssh`, Ghostty then sends the type `xterm-256color`, which each server knows. It writes nothing on the server, so it works on a server where you only copy files. This needs Ghostty 1.2.0 or later.

The feature works only for the `ssh` command that you type in a Ghostty shell. It does not work for `scp`, `sftp`, `rsync`, or a script. For those, or for an older Ghostty, use one of these fixes:

- Copy the description to the server one time. This writes a file in your home folder on the server:

  ```bash
  infocmp -x xterm-ghostty | ssh my-server -- tic -x -
  ```

- Or send `xterm-256color` to one server always. Add this line to the `Host` entry of the server in `~/.ssh/config` (OpenSSH 8.7 or later):

  ```text
  SetEnv TERM=xterm-256color
  ```

To let Ghostty copy the description to each new server for you, add your own line below the herdspace blocks of your Ghostty file:

```text
shell-integration-features = ssh-env,ssh-terminfo
```

## Problems

| Problem | Fix |
|---------|-----|
| `Permission denied (publickey)` | The server does not have your key. Do step 2 again. |
| `Could not resolve hostname my-server` | The name is not in `~/.ssh/config`. Do step 3 again, and make sure that the name is the same. |
| `Connection refused` or `Connection timed out` | SSH is not on, or the address is wrong. Read [Before you start](#before-you-start) again. |
| `'xterm-ghostty': unknown terminal type` on a server | See [A server without herdspace](#a-server-without-herdspace). |
| The client setup says `Could not connect to my-server, so this script skips it` | Step 4 does not print `ok`. Fix the connection, and run the client setup again. |

## References

- [man ssh_config](https://man.openbsd.org/ssh_config): the `Host`, `HostName`, and `User` lines.
- [man ssh-keygen](https://man.openbsd.org/ssh-keygen): make a key.
- [man ssh-copy-id](https://manpages.debian.org/bookworm/openssh-client/ssh-copy-id.1.en.html): copy a key to a server.
