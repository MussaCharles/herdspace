#!/usr/bin/env bash
# Steps that are the same on a Linux server and on a macOS server.

STARTED_SERVER=0
# The integrations of Herdr 0.9.5, by their name in "herdr integration".
AGENTS="claude codex pi omp opencode hermes copilot cursor grok devin droid kimi kilo qodercli qwen letta mastracode antigravity-cli"

HERDR_CONFIG_BEFORE=""

setup_server_files() {
  local lazygit_dir="$1"
  HERDR_CONFIG_BEFORE="$(file_sha "${HOME}/.config/herdr/config.toml" 2>/dev/null || true)"
  install_file "${REPO_ROOT}/config/herdr/config.toml" "${HOME}/.config/herdr/config.toml"
  install_file "${REPO_ROOT}/config/lazygit/config.yml" "${lazygit_dir}/config.yml"
  move_old_nvim
  # Neovim owns lazy-lock.json after the first start. :Lazy update changes it.
  SEED_ONLY="lazy-lock.json" install_tree "${REPO_ROOT}/config/nvim" "$NVIM_DIR"
  install_file "${REPO_ROOT}/bin/hopen" "${HOME}/.local/bin/hopen" 755
  install_file "${REPO_ROOT}/bin/herdr-update-check" "${HOME}/.local/bin/herdr-update-check" 755
  install_tree "${REPO_ROOT}/config/templates" "${HOME}/.config/hopen/templates"
}

# The herdspace editor is Neovim with NVIM_APPNAME=herdspace-nvim: its files are
# in ~/.config/herdspace-nvim, and its plugins in ~/.local/share/herdspace-nvim.
# ~/.config/nvim stays the folder of the person.
export HS_NVIM_APPNAME="herdspace-nvim"
NVIM_DIR="${HOME}/.config/${HS_NVIM_APPNAME}"
NVIM_DATA="${HOME}/.local/share/${HS_NVIM_APPNAME}"
OLD_NVIM_DIR="${HOME}/.config/nvim"

# hs_nvim runs the herdspace editor.
hs_nvim() { NVIM_APPNAME="$HS_NVIM_APPNAME" nvim "$@"; }

# old_nvim_is_herdspace succeeds if ~/.config/nvim holds only files that an
# older herdspace wrote and no person changed, the files that Neovim writes
# itself, and the backups of the setup.
old_nvim_is_herdspace() {
  local file src sha status
  [ -d "$OLD_NVIM_DIR" ] && [ ! -L "$OLD_NVIM_DIR" ] || return 1
  while IFS= read -r file <&3; do
    case "$file" in lazy-lock.json | lazyvim.json | *.bak-*) continue ;; esac
    src="${REPO_ROOT}/config/nvim/${file}"
    [ -f "${OLD_NVIM_DIR}/${file}" ] && [ ! -L "${OLD_NVIM_DIR}/${file}" ] || return 1
    if [ -f "$src" ]; then
      status="$(file_status "$src" "${OLD_NVIM_DIR}/${file}")"
      case "$status" in current | outdated) ;; *) return 1 ;; esac
    else
      # A file that herdspace no longer ships, from an older version.
      sha="$(file_sha "${OLD_NVIM_DIR}/${file}")"
      known_old "$src" "$sha" || return 1
    fi
  done 3< <(cd "$OLD_NVIM_DIR" && find . \( -type f -o -type l \) | sed 's|^\./||')
}

# move_old_nvim moves the Neovim files of an older herdspace out of
# ~/.config/nvim, to a backup folder. A folder with a file of the person stays.
move_old_nvim() {
  old_nvim_is_herdspace || return 0
  if [ "$MODE" = "check" ]; then
    note_todo "${OLD_NVIM_DIR} holds the Neovim files of an older herdspace"
    return 0
  fi
  local backup="${OLD_NVIM_DIR}.bak-${STAMP}"
  mv "$OLD_NVIM_DIR" "$backup"
  BACKUP_LIST="${BACKUP_LIST}${OLD_NVIM_DIR}
"
  info "The herdspace Neovim files are now in $(short_home "$NVIM_DIR"). The old $(short_home "$OLD_NVIM_DIR") is in $(short_home "$backup")."
  info "The old plugins in $(short_home "${HOME}/.local/share/nvim") stay. You can remove them."
  CHANGED=$((CHANGED + 1))
}

# done_ready and done_mark use small files to record finished long steps.
done_ready() { [ -f "${STATE_DIR}/done/$1" ] && [ "$(cat "${STATE_DIR}/done/$1")" = "$2" ]; }

done_mark() {
  mkdir -p "${STATE_DIR}/done"
  printf '%s' "$2" >"${STATE_DIR}/done/$1"
}

nvim_lock_sha() { file_sha "${REPO_ROOT}/config/nvim/lazy-lock.json"; }

nvim_plugins_ready() {
  have nvim && [ -d "${NVIM_DATA}/lazy/LazyVim" ] && done_ready herdspace-nvim-plugins "$(nvim_lock_sha)"
}

# install_nvim_plugins restores the plugins of lazy-lock.json. Lazy can exit 0
# when a download fails, so the step looks for LazyVim, and tries one more
# time. With LazyVim still missing, it writes no done mark, and the next run
# tries again.
# nvim_plugin_total and nvim_plugin_count give the progress of the plugin step:
# the plugins in lazy-lock.json, and the plugin folders that exist.
nvim_plugin_total() { grep -c '": {' "${NVIM_DIR}/lazy-lock.json" 2>/dev/null || echo 0; }
nvim_plugin_count() { find "${NVIM_DATA}/lazy" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' '; }

install_nvim_plugins() {
  local _try
  for _try in 1 2; do
    hs_nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 &
    ui_wait $! "Neovim plugins" "$(nvim_plugin_total)" nvim_plugin_count || true
    [ -d "${NVIM_DATA}/lazy/LazyVim" ] && break
  done
  if [ ! -d "${NVIM_DATA}/lazy/LazyVim" ]; then
    warn "Neovim could not download its plugins. Check the network, and run the setup again."
    return 0
  fi
  done_mark herdspace-nvim-plugins "$(nvim_lock_sha)"
}

nvim_tools_ready() {
  [ "${SKIP_NVIM_TOOLS:-0}" = "1" ] && return 0
  have nvim && done_ready herdspace-nvim-tools "$(nvim_lock_sha)"
}

# The language servers that tools/nvim-wait.lua installs, and the progress of the step.
NVIM_SERVERS="vtsls json-lsp lua-language-server marksman pyright ruff taplo"
nvim_tool_count() {
  local name n=0
  for name in $NVIM_SERVERS; do
    [ ! -d "${NVIM_DATA}/mason/packages/${name}" ] || n=$((n + 1))
  done
  echo "$n"
}

install_nvim_tools() {
  info "This can take some minutes."
  # The first start installs the parser compiler. The second start builds the
  # parsers, and Neovim builds them only after it opens a file.
  local _pass total
  total="$(echo $NVIM_SERVERS | wc -w | tr -d ' ')"
  for _pass in 1 2; do
    hs_nvim --headless "${REPO_ROOT}/README.md" "+luafile ${REPO_ROOT}/tools/nvim-wait.lua" >/dev/null 2>&1 &
    ui_wait $! "Neovim language tools" "$total" nvim_tool_count || warn "Neovim did not finish all its language tools."
  done
  done_mark herdspace-nvim-tools "$(nvim_lock_sha)"
}

server_answers() {
  case "$(herdr workspace list 2>/dev/null)" in
    *workspace_list*) return 0 ;;
    *) return 1 ;;
  esac
}

# ensure_server starts a server for the setup steps. It never stops one that
# was already running, because a stop closes every pane.
ensure_server() {
  server_answers && return 0
  nohup herdr server >/dev/null 2>&1 &
  disown
  STARTED_SERVER=1
  local _try
  for _try in $(seq 1 40); do
    server_answers && return 0
    sleep 0.25
  done
  die "The Herdr server did not start."
}

stop_setup_server() {
  [ "$STARTED_SERVER" = "1" ] || return 0
  herdr server stop >/dev/null 2>&1 || true
  local _try
  for _try in $(seq 1 40); do
    server_answers || break
    sleep 0.25
  done
  STARTED_SERVER=0
}

auto_title_ready() {
  have herdr || return 1
  case "$(herdr plugin list 2>/dev/null)" in
    *herdr.auto-title*) return 0 ;;
    *) return 1 ;;
  esac
}

install_auto_title() {
  ensure_server
  herdr plugin install kryptamine/herdr-auto-title --ref "$AUTO_TITLE_REF" -y >/dev/null
  herdr plugin action invoke restart --plugin herdr.auto-title >/dev/null || warn "Auto Title did not start. It starts with the next server."
}

# agent_folder prints the folder that an agent program creates at its first start.
# agent_commands NAME prints the commands of an agent, as the integration
# registry of Herdr 0.9.5 names them. One of them is enough.
agent_commands() {
  case "$1" in
    cursor) echo "cursor-agent" ;;
    kilo) echo "kilo kilo-code" ;;
    qodercli) echo "qodercli qoder qoderclicn qodercn" ;;
    antigravity-cli) echo "agy" ;;
    *) echo "$1" ;;
  esac
}

# agent_found NAME is true when a command of the agent is on the PATH.
agent_found() {
  local cmd
  for cmd in $(agent_commands "$1"); do
    have "$cmd" && return 0
  done
  return 1
}

# agent_folder NAME prints the configuration folder that the integration of
# Herdr needs. The agent makes it at its first start. The folders and the
# variables come from the integration docs of Herdr.
agent_folder() {
  local config="${XDG_CONFIG_HOME:-${HOME}/.config}"
  case "$1" in
    claude) echo "${CLAUDE_CONFIG_DIR:-${HOME}/.claude}" ;;
    codex) echo "${CODEX_HOME:-${HOME}/.codex}" ;;
    pi) echo "${HOME}/.pi/agent/extensions" ;;
    omp) echo "${HOME}/.omp/agent" ;;
    opencode) echo "${HOME}/.config/opencode" ;;
    hermes) echo "${HERMES_HOME:-${HOME}/.hermes}" ;;
    copilot) echo "${COPILOT_HOME:-${HOME}/.copilot}" ;;
    cursor) echo "${CURSOR_CONFIG_DIR:-${HOME}/.cursor}" ;;
    grok) echo "${GROK_HOME:-${HOME}/.grok}" ;;
    devin) echo "${config}/devin" ;;
    droid) echo "${HOME}/.factory" ;;
    kimi) echo "${KIMI_CODE_HOME:-${HOME}/.kimi-code}" ;;
    kilo) echo "${HOME}/.config/kilo" ;;
    qodercli) echo "${QODER_CONFIG_DIR:-${HOME}/.qoder}" ;;
    qwen) echo "${QWEN_HOME:-${HOME}/.qwen}" ;;
    letta) echo "${HOME}/.letta" ;;
    mastracode) echo "${HOME}/.mastracode" ;;
    antigravity-cli) echo "${ANTIGRAVITY_CLI_CONFIG_DIR:-${HOME}/.gemini/config}" ;;
  esac
}

# agent_skill_path prints where a program reads the skill. OpenCode reads the
# Claude Code folder if Claude Code is on this machine.
agent_skill_path() {
  case "$1" in
    claude) echo "${HOME}/.claude/skills/herdr/SKILL.md" ;;
    codex) echo "${HOME}/.codex/skills/herdr/SKILL.md" ;;
    pi) echo "${HOME}/.pi/agent/skills/herdr/SKILL.md" ;;
    opencode) have claude || echo "${HOME}/.config/opencode/skills/herdr/SKILL.md" ;;
    hermes) echo "${HOME}/.hermes/skills/autonomous-ai-agents/herdr/SKILL.md" ;;
  esac
}

agents_ready() {
  have herdr || return 1
  local agent status skill path
  status="$(herdr integration status 2>/dev/null)"
  skill="$(mktemp)"
  herdr --skill >"$skill"
  for agent in $AGENTS; do
    agent_found "$agent" || continue
    [ -d "$(agent_folder "$agent")" ] || continue
    if ! grep -Eq "^${agent}( \(experimental\))?: current" <<<"$status"; then
      rm -f "$skill"
      return 1
    fi
    path="$(agent_skill_path "$agent")"
    if [ -n "$path" ] && ! cmp -s "$skill" "$path"; then
      rm -f "$skill"
      return 1
    fi
  done
  rm -f "$skill"
}

# install_agents adds an integration and the skill for each agent program on
# this machine. It does not install the agent programs.
install_agents() {
  local agent skill path
  skill="$(mktemp)"
  herdr --skill >"$skill"
  for agent in $AGENTS; do
    agent_found "$agent" || continue
    if [ ! -d "$(agent_folder "$agent")" ]; then
      warn "Start ${agent} one time, and then run this script again."
      continue
    fi
    herdr integration install "$agent" >/dev/null 2>&1 || warn "The integration for ${agent} failed."
    path="$(agent_skill_path "$agent")"
    [ -z "$path" ] || install_file "$skill" "$path"
    ok "$agent"
  done
  rm -f "$skill"
}

# running_sessions prints the name of each Herdr session with a running server.
running_sessions() {
  herdr session list --json 2>/dev/null | python3 -I -c '
import json, sys
try:
    data = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
for session in data.get("sessions", []):
    if session.get("running"):
        print(session["name"])
' 2>/dev/null || true
}

# update_running_sessions changes nothing in the panes of a running session.
# A changed config.toml reaches each running server with reload-config, which
# keeps the panes. A server that runs an older Herdr than the one installed
# keeps running, and a note says how to restart it.
update_running_sessions() {
  [ "$MODE" != "check" ] && have herdr || return 0
  local name out installed version old=""
  installed="$(herdr --version 2>/dev/null | awk '{print $2}')"
  local changed=0
  [ "$(file_sha "${HOME}/.config/herdr/config.toml" 2>/dev/null || true)" = "$HERDR_CONFIG_BEFORE" ] || changed=1
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    if [ "$changed" -eq 1 ]; then
      out="$(herdr --session "$name" server reload-config 2>&1)" || true
      case "$out" in
        *'"diagnostics":[]'*) ok "Session ${name}: the new Herdr configuration is active" ;;
        *) warn "Session ${name}: Herdr did not apply all of the new configuration. Run: herdr --session ${name} server reload-config" ;;
      esac
    fi
    version="$(herdr --session "$name" status server 2>/dev/null | awk '$1 == "version:" {print $2}')"
    [ -z "$version" ] || [ -z "$installed" ] || [ "$version" = "$installed" ] || old="${old} ${name}"
  done < <(running_sessions)
  [ -n "$old" ] || return 0
  info "These sessions still run an older Herdr than ${installed}:${old}. Their programs keep running, and Herdr ${installed} attaches to them."
  info "To use Herdr ${installed} in a session, run: herdr session stop <name>, and open the session again. A stop ends the programs in its panes. The layout comes back."
}

setup_server_common() {
  run_part "Neovim plugins" nvim_plugins_ready install_nvim_plugins
  run_part "Neovim language tools" nvim_tools_ready install_nvim_tools
  run_part "Auto Title plugin" auto_title_ready install_auto_title
  run_part "Agent integrations and skill" agents_ready install_agents
  stop_setup_server
  update_running_sessions
}
