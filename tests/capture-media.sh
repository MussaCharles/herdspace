#!/usr/bin/env bash
# capture-media.sh records the screenshots and the short videos in docs/media.
# It uses two throwaway containers, real Ghostty, and real key presses. A key
# display at the bottom of each video shows the keys.
#
# Usage: tests/capture-media.sh   The files go to tests/.work/media.
# The GIF plays SPEED times faster than the recording (default 3). The MP4 keeps
# the real speed.
# Review the files, and then copy the ones that you want to docs/media.
FULL="${FULL:-1}"
SPEED="${SPEED:-3}"
OPEN_CMD=/home/tester/repo/tests/open-shell.sh
# shellcheck source=tests/lib-pair.sh
source "$(dirname "$0")/lib-pair.sh"
out=tests/.work/media
mkdir -p "$out"

docker exec -u root "$cli" sh -c 'apt-get update -qq >/dev/null; DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends ffmpeg screenkey >/dev/null 2>&1' || fail 'media tools'
pair_setup
srv_user bash -c 'cat >~/my-projects.code-workspace <<JSON
{
  "folders": [
    { "name": "website", "path": "./projects/website" },
    { "name": "api", "path": "./projects/api" },
    { "name": "mobile-app", "path": "./projects/mobile-app" },
    { "name": "docs", "path": "./projects/docs" }
  ],
  "settings": {
    "hopen.templates": { "website": "code", "api": "agent", "mobile-app": "grid", "docs": "review" }
  }
}
JSON'
open_ghostty
eval "$(cli_user xdotool getwindowgeometry --shell "$win" | grep -E '^(X|Y|WIDTH|HEIGHT)=')"
WIDTH=$((WIDTH / 2 * 2))
HEIGHT=$((HEIGHT / 2 * 2))
cli_user xdotool mousemove 5 5
now() { python3 -c 'import time; print(f"{time.time():.2f}")'; }

# The key log holds "start end text" lines. ffmpeg draws each text at the
# bottom of the video, so a viewer sees which keys were pressed.
record_start() {
  KEYLOG="tests/.work/keys-$1.txt"
  : >"$KEYLOG"
  cli_user bash -c "nohup ffmpeg -y -loglevel error -f x11grab -framerate 15 -video_size ${WIDTH}x${HEIGHT} -i :9.0+${X},${Y} -c:v libx264 -preset veryfast -pix_fmt yuv420p /tmp/raw-$1.mp4 >/tmp/ff.log 2>&1 & echo \$! >/tmp/ff.pid"
  sleep 1
  T0="$(now)"
}

# say TEXT records TEXT in the key log at this moment.
say() {
  local t
  t="$(now)"
  python3 -c 'import sys; s = float(sys.argv[1]) - float(sys.argv[2]); print(f"{s:.2f} {s + 1.6:.2f} {sys.argv[3]}")' "$t" "$T0" "$1" >>"$KEYLOG"
}

# press KEY TEXT presses a key and shows TEXT.
press() { say "$2"; key "$1"; }
# write TEXT types a command, shows it, and presses Enter.
write() { say "$1"; type_text "$1"; }

record_stop() {
  local filter=/tmp/hb-filter.txt font=/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf
  # shellcheck disable=SC2016 # This command runs in the client container.
  cli_user bash -c 'kill -INT "$(cat /tmp/ff.pid)"; sleep 2'
  python3 - "$KEYLOG" "$font" >"tests/.work/filter-$1.txt" <<'PY2'
import sys
font = sys.argv[2]
parts = []
rows = [line.rstrip("\n").split(" ", 2) for line in open(sys.argv[1])]
for i, (start, end, text) in enumerate(rows):
    # A label stays until the next label, so that it is readable in a fast GIF.
    nxt = float(rows[i + 1][0]) if i + 1 < len(rows) else float(start) + 3
    end = f"{max(float(end), min(nxt, float(start) + 4)):.2f}"
    text = text.replace("\\", "\\\\").replace("'", "").replace(":", "\\:").replace("%", "\\%")
    parts.append(
        f"drawtext=fontfile={font}:text='{text}':fontsize=30:fontcolor=0x7ee787"
        f":box=1:boxcolor=0x0b0f14@0.92:boxborderw=16:x=(w-tw)/2:y=h-110"
        f":enable='between(t,{start},{end})'"
    )
print(",".join(parts) or "null")
PY2
  docker cp "tests/.work/filter-$1.txt" "$cli:$filter" >/dev/null
  cli_user ffmpeg -y -loglevel error -i "/tmp/raw-$1.mp4" -filter_script:v "$filter" -c:v libx264 -preset veryfast -pix_fmt yuv420p "/tmp/$1.mp4"
  cli_user ffmpeg -y -loglevel error -i "/tmp/$1.mp4" -vf "setpts=PTS/${SPEED},fps=12,scale=1000:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" "/tmp/$1.gif"
  docker cp "$cli:/tmp/$1.mp4" "$out/$1.mp4" >/dev/null
  docker cp "$cli:/tmp/$1.gif" "$out/$1.gif" >/dev/null
}

# clear_idle sends Ctrl+L to every pane that shows only its shell, so that the
# screens start clean.
clear_idle() {
  srv_user python3 - <<'PY3'
import json, os, subprocess, time
env = dict(os.environ, HERDR_SESSION="my-projects")
def call(*args):
    return json.loads(subprocess.run(["herdr", *args], env=env, capture_output=True, text=True).stdout)
for pane in call("pane", "list")["result"]["panes"]:
    info = call("pane", "process-info", "--pane", pane["pane_id"])["result"]["process_info"]
    if info.get("shell_pid") and info.get("foreground_process_group_id") == info.get("shell_pid"):
        subprocess.run(["herdr", "pane", "send-keys", pane["pane_id"], "ctrl+l"], env=env, capture_output=True)
        time.sleep(0.3)
PY3
  sleep 1
}

media_shot() { shot "$1" && [ -f "tests/.work/shots/$1.png" ] && mv "tests/.work/shots/$1.png" "$out/$1.png"; }
# shellcheck disable=SC2016 # These commands run on the server.
focus_ws() { srv_user bash -c "HERDR_SESSION=my-projects herdr workspace focus \$(HERDR_SESSION=my-projects herdr workspace list | python3 -c \"import json,sys; print([w['workspace_id'] for w in json.load(sys.stdin)['result']['workspaces'] if w['label']=='$1'][0])\")" >/dev/null; sleep 3; }

# 1. Move between the projects. The video starts on a full screen, with every
# project open, because the first frame is also the preview of the GIF.
TYPE_DELAY=70 WAIT=16 type_text 'hopen --all my-projects'
clear_idle
focus_ws website
record_start open-projects
sleep 2
WAIT=3 press ctrl+Down 'Ctrl+Down: next project'
WAIT=3 press ctrl+Down 'Ctrl+Down: next project'
WAIT=3 press ctrl+Down 'Ctrl+Down: next project'
record_stop open-projects

clear_idle
focus_ws website
media_shot template-code
focus_ws api
media_shot template-agent
focus_ws mobile-app
media_shot template-grid
focus_ws docs
media_shot template-review

# 2. Move between panes, and zoom one pane.
focus_ws mobile-app
clear_idle
record_start move-panes
WAIT=2.5 press alt+Down 'Alt+Down: next pane'
WAIT=2.5 press alt+Down 'Alt+Down: next pane'
WAIT=2.5 press alt+Up 'Alt+Up: previous pane'
WAIT=0.6 press ctrl+b 'ctrl+b, z: zoom'
WAIT=3 key z
WAIT=0.6 press ctrl+b 'ctrl+b, z: zoom back'
WAIT=3 key z
WAIT=0.6 press ctrl+b 'ctrl+b, l: pane on the right'
WAIT=2.5 key l
WAIT=0.6 press ctrl+b 'ctrl+b, j: pane below'
WAIT=2.5 key j
record_stop move-panes

# 3. Split a pane, and close it again.
focus_ws my-projects
clear_idle
record_start split-panes
WAIT=0.6 press ctrl+b 'ctrl+b, v: split right'
WAIT=3 key v
WAIT=0.6 press ctrl+b 'ctrl+b, -: split down'
WAIT=3 key minus
WAIT=0.6 press ctrl+b 'ctrl+b, x: close the pane'
WAIT=3 key x
WAIT=0.6 press ctrl+b 'ctrl+b, x: close the pane'
WAIT=3 key x
record_stop split-panes

# 4. Use a template in a new tab.
focus_ws api
record_start apply-template
WAIT=3 press ctrl+shift+t 'Ctrl+Shift+T: new tab'
TYPE_DELAY=70 WAIT=10 write 'hopen --apply review'
WAIT=3 press ctrl+Left 'Ctrl+Left: previous tab'
WAIT=3 press ctrl+Right 'Ctrl+Right: next tab'
record_stop apply-template

# 5. Go to any project or pane by name.
record_start go-to
WAIT=3 press ctrl+shift+k 'Ctrl+Shift+K: go to'
WAIT=1.5 press slash '/: search'
say 'type: mobile'
cli_user xdotool type --delay 180 'mobile'
sleep 2
WAIT=4 press Return 'Enter: go'
record_stop go-to

find "$out" -maxdepth 1 -type f | sort
echo "RESULT exit=${status}"
exit "$status"
