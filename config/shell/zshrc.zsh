# Managed by herdspace. A new run replaces this file.
# Put your own lines in ~/.zshrc.local.

# This line must stay above the instant prompt, which redirects the terminal.
[[ -t 0 && -t 1 ]] && bootstrap_has_tty=1 || bootstrap_has_tty=0

if (( bootstrap_has_tty )) && [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

[[ -r "$HOME/.config/herdspace/env.zsh" ]] && source "$HOME/.config/herdspace/env.zsh"

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

# The fzf keys, zoxide, the completion of hopen, ff and fif, and eza and bat.
[[ -r "$HOME/.config/herdspace/extras.zsh" ]] && source "$HOME/.config/herdspace/extras.zsh"
# The prompt only in a real terminal.
if (( bootstrap_has_tty )); then
  [[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
fi

if [[ -f "$HOME/.zshrc.local" ]]; then
  source "$HOME/.zshrc.local"
fi
