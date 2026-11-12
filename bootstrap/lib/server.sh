#!/usr/bin/env bash
# Steps that are the same on a Linux server and on a macOS server.

STARTED_SERVER=0
AGENTS="claude codex pi opencode hermes copilot cursor grok"

setup_server_files() {
  local lazygit_dir="$1"
  install_file "${REPO_ROOT}/config/herdr/config.toml" "${HOME}/.config/herdr/config.toml"
  install_file "${REPO_ROOT}/config/lazygit/config.yml" "${lazygit_dir}/config.yml"
  # Neovim owns lazy-lock.json after the first start. :Lazy update changes it.
  SEED_ONLY="lazy-lock.json" install_tree "${REPO_ROOT}/config/nvim" "${HOME}/.config/nvim"
  install_file "${REPO_ROOT}/bin/hopen" "${HOME}/.local/bin/hopen" 755
  install_file "${REPO_ROOT}/bin/herdr-update-check" "${HOME}/.local/bin/herdr-update-check" 755
  install_tree "${REPO_ROOT}/config/templates" "${HOME}/.config/hopen/templates"
}

# done_ready and done_mark use small files to record finished long steps.
done_ready() { [ -f "${STATE_DIR}/done/$1" ] && [ "$(cat "${STATE_DIR}/done/$1")" = "$2" ]; }

done_mark() {
  mkdir -p "${STATE_DIR}/done"
  printf '%s' "$2" >"${STATE_DIR}/done/$1"
}

nvim_lock_sha() { file_sha "${REPO_ROOT}/config/nvim/lazy-lock.json"; }

nvim_plugins_ready() {
  have nvim && [ -d "${HOME}/.local/share/nvim/lazy/LazyVim" ] && done_ready nvim-plugins "$(nvim_lock_sha)"
}

# install_nvim_plugins restores the plugins of lazy-lock.json. Lazy can exit 0
# when a download fails, so the step looks for LazyVim, and tries one more
# time. With LazyVim still missing, it writes no done mark, and the next run
# tries again.
# nvim_plugin_total and nvim_plugin_count give the progress of the plugin step:
# the plugins in lazy-lock.json, and the plugin folders that exist.
nvim_plugin_total() { grep -c '": {' "${HOME}/.config/nvim/lazy-lock.json" 2>/dev/null || echo 0; }
nvim_plugin_count() { find "${HOME}/.local/share/nvim/lazy" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' '; }

install_nvim_plugins() {
  local _try
  for _try in 1 2; do
    nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 &
    ui_wait $! "Neovim plugins" "$(nvim_plugin_total)" nvim_plugin_count || true
    [ -d "${HOME}/.local/share/nvim/lazy/LazyVim" ] && break
  done
  if [ ! -d "${HOME}/.local/share/nvim/lazy/LazyVim" ]; then
    warn "Neovim could not download its plugins. Check the network, and run the setup again."
    return 0
  fi
  done_mark nvim-plugins "$(nvim_lock_sha)"
}

nvim_tools_ready() {
  [ "${SKIP_NVIM_TOOLS:-0}" = "1" ] && return 0
  have nvim && done_ready nvim-tools "$(nvim_lock_sha)"
}

# The language servers that tools/nvim-wait.lua installs, and the progress of the step.
NVIM_SERVERS="vtsls json-lsp lua-language-server marksman pyright ruff taplo"
nvim_tool_count() {
  local name n=0
  for name in $NVIM_SERVERS; do
    [ ! -d "${HOME}/.local/share/nvim/mason/packages/${name}" ] || n=$((n + 1))
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
    nvim --headless "${REPO_ROOT}/README.md" "+luafile ${REPO_ROOT}/tools/nvim-wait.lua" >/dev/null 2>&1 &
    ui_wait $! "Neovim language tools" "$total" nvim_tool_count || warn "Neovim did not finish all its language tools."
  done
  done_mark nvim-tools "$(nvim_lock_sha)"
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
agent_folder() {
  case "$1" in
    claude) echo "${HOME}/.claude" ;;
    codex) echo "${HOME}/.codex" ;;
    pi) echo "${HOME}/.pi/agent/extensions" ;;
    opencode) echo "${HOME}/.config/opencode" ;;
    hermes) echo "${HOME}/.hermes" ;;
    copilot) echo "${HOME}/.copilot" ;;
    cursor) echo "${HOME}/.cursor" ;;
    grok) echo "${HOME}/.grok" ;;
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
    have "$agent" || continue
    [ -d "$(agent_folder "$agent")" ] || continue
    if ! grep -q "^${agent}: current" <<<"$status"; then
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
    have "$agent" || continue
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

setup_server_common() {
  run_part "Neovim plugins" nvim_plugins_ready install_nvim_plugins
  run_part "Neovim language tools" nvim_tools_ready install_nvim_tools
  run_part "Auto Title plugin" auto_title_ready install_auto_title
  run_part "Agent integrations and skill" agents_ready install_agents
  stop_setup_server
}
