#!/bin/sh
# open-shell.sh is the command that the media Ghostty window runs on the client.
# Wait until Ghostty gives the terminal a size, for 10 seconds at most.
# Herdr stops when the terminal has no size, and then the window closes.
i=0
while [ "$(stty size 2>/dev/null)" = "0 0" ] && [ "$i" -lt 50 ]; do
  sleep 0.2
  i=$((i + 1))
done
exec ssh -tt my-server
