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
- SSH on the server machine. On macOS, turn on Remote Login in System Settings, in General, then Sharing. On Debian or Ubuntu, install it with `sudo apt install openssh-server`.

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

## Problems

| Problem | Fix |
|---------|-----|
| `Permission denied (publickey)` | The server does not have your key. Do step 2 again. |
| `Could not resolve hostname my-server` | The name is not in `~/.ssh/config`. Do step 3 again, and make sure that the name is the same. |
| `Connection refused` or `Connection timed out` | SSH is not on, or the address is wrong. Read [Before you start](#before-you-start) again. |
| The client setup says `Could not connect to my-server, so this script skips it` | Step 4 does not print `ok`. Fix the connection, and run the client setup again. |

## References

- [man ssh_config](https://man.openbsd.org/ssh_config): the `Host`, `HostName`, and `User` lines.
- [man ssh-keygen](https://man.openbsd.org/ssh-keygen): make a key.
- [man ssh-copy-id](https://manpages.debian.org/bookworm/openssh-client/ssh-copy-id.1.en.html): copy a key to a server.
