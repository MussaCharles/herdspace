#!/bin/sh
# open-demo.sh is the command that the test Ghostty window runs on the client.
exec ssh -tt my-server 'zsh -lc "hopen work"'
