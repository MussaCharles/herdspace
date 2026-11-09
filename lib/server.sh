#!/usr/bin/env bash
# Steps that are the same on a Linux server and on a macOS server.

STARTED_SERVER=0

setup_server_files() {
  local lazygit_dir="$1"
  step "Configuration files"
  install_file "${REPO_ROOT}/config/herdr/config.toml" "${HOME}/.config/herdr/config.toml"
  install_file "${REPO_ROOT}/config/lazygit/config.yml" "${lazygit_dir}/config.yml"
  install_tree "${REPO_ROOT}/config/nvim" "${HOME}/.config/nvim"
  install_file "${REPO_ROOT}/bin/hopen" "${HOME}/.local/bin/hopen" 755
  install_file "${REPO_ROOT}/bin/herdr-update-check" "${HOME}/.local/bin/herdr-update-check" 755
  ok "Herdr, lazygit, Neovim, hopen, and the update check"
}

setup_neovim() {
  step "Neovim plugins"
  nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 || warn "Neovim could not restore all its plugins."
  ok "Plugins are at the versions in lazy-lock.json"
  if [ "${SKIP_NVIM_TOOLS:-0}" = "1" ]; then
    info "Skipped the language tools. Neovim installs them when it first opens."
    return 0
  fi
  info "Installing language tools. This can take some minutes."
  # The first start installs the parser compiler. The second start builds the
  # parsers, and Neovim builds them only after it opens a file.
  local _pass
  for _pass in 1 2; do
    nvim --headless "${REPO_ROOT}/README.md" "+luafile ${REPO_ROOT}/tools/nvim-wait.lua" >/dev/null 2>&1 || warn "Neovim did not finish all its language tools."
  done
  ok "Language tools"
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

setup_auto_title() {
  step "Auto Title plugin"
  case "$(herdr plugin list 2>/dev/null)" in
    *herdr.auto-title*)
      ok "Already installed"
      return 0
      ;;
  esac
  herdr plugin install kryptamine/herdr-auto-title --ref "$AUTO_TITLE_REF" -y >/dev/null
  herdr plugin action invoke restart --plugin herdr.auto-title >/dev/null || warn "Auto Title did not start. It starts with the next server."
  ok "Installed at ${AUTO_TITLE_REF}"
}

# setup_agents installs an integration and the skill for each agent program on
# this computer. It does not install the agent programs.
setup_agents() {
  step "Agent integrations and skill"
  local agent found=0 skill
  skill="$(mktemp)"
  herdr --skill >"$skill"
  for agent in claude codex pi opencode hermes copilot cursor grok; do
    have "$agent" || continue
    found=1
    herdr integration install "$agent" >/dev/null 2>&1 || warn "The integration for ${agent} failed. Start ${agent} one time, and then run this script again."
    case "$agent" in
      claude) install_file "$skill" "${HOME}/.claude/skills/herdr/SKILL.md" ;;
      codex) install_file "$skill" "${HOME}/.codex/skills/herdr/SKILL.md" ;;
      pi) install_file "$skill" "${HOME}/.pi/agent/skills/herdr/SKILL.md" ;;
      opencode) have claude || install_file "$skill" "${HOME}/.config/opencode/skills/herdr/SKILL.md" ;;
      hermes) install_file "$skill" "${HOME}/.hermes/skills/autonomous-ai-agents/herdr/SKILL.md" ;;
    esac
    ok "$agent"
  done
  rm -f "$skill"
  [ "$found" = "1" ] || info "No agent programs found. Run this script again after you install one."
}

finish_server() {
  step "Done"
  ok "Connect with SSH and run: herdr"
  info "To open many projects, read docs/cheat-sheet.md."
}
