#!/usr/bin/env python3
"""Run a command in a pseudo terminal, print its output, and exit with its status."""
import fcntl, os, pty, re, select, signal, struct, sys, termios, time

limit, keys, command = float(sys.argv[1]), sys.argv[2], sys.argv[3:]
pid, fd = pty.fork()
if pid == 0:
    os.execvp(command[0], command)
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 45, 180, 0, 0))
os.kill(pid, signal.SIGWINCH)
start, output, sent = time.time(), b"", False
while time.time() - start < limit:
    ready, _, _ = select.select([fd], [], [], 0.2)
    if ready:
        try:
            data = os.read(fd, 65536)
        except OSError:
            break
        if not data:
            break
        output += data
    if keys and not sent and time.time() - start > limit / 2:
        os.write(fd, keys.encode().decode("unicode_escape").encode())
        sent = True
status = 124
for _ in range(20):
    done, code = os.waitpid(pid, os.WNOHANG)
    if done:
        status = os.waitstatus_to_exitcode(code)
        break
    time.sleep(0.1)
else:
    os.kill(pid, signal.SIGKILL)
    os.waitpid(pid, 0)
text = re.sub(rb"\x1b\[[0-9;?<>=]*[a-zA-Z]|\x1b\][^\x07\x1b]*(\x07|\x1b\\)|\x1b[()=>][A-Z0-9]?", b"", output)
sys.stdout.write(text.decode("utf-8", "ignore").replace("\r", ""))
sys.exit(status)
