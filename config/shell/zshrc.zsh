# Managed by herdr-bootstrap. A new run replaces this file.
# Put your own lines in ~/.zshrc.local.

# This line must stay above the instant prompt, which redirects the terminal.
[[ -t 0 && -t 1 ]] && bootstrap_has_tty=1 || bootstrap_has_tty=0

if (( bootstrap_has_tty )) && [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

[[ -r "$HOME/.config/herdr-bootstrap/env.zsh" ]] && source "$HOME/.config/herdr-bootstrap/env.zsh"

export ZSH="$HOME/.oh-my-zsh"
export DISABLE_AUTO_UPDATE=true
# Without a real terminal, the Powerlevel10k git status helper prints an error.
if (( bootstrap_has_tty )); then
  ZSH_THEME="powerlevel10k/powerlevel10k"
else
  ZSH_THEME=""
fi
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source "$ZSH/oh-my-zsh.sh"

case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac

# Only in a real terminal, so that agents and scripts keep ls and cat.
if (( bootstrap_has_tty )); then
  export BAT_THEME="TwoDark"
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --cycle'
  command -v fzf >/dev/null && source <(fzf --zsh)
  command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
  if command -v eza >/dev/null; then
    alias ls="eza"
    alias ll="eza -la"
    alias tree="eza --tree"
  fi
  command -v bat >/dev/null && alias cat="bat"
  [[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
fi

[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
