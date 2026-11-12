# Shell extras from herdspace: the fzf keys, zoxide, the completion of hopen,
# ff and fif, and eza and bat for ls and cat. The herdspace ~/.zshrc loads this
# file. A person who keeps their own ~/.zshrc can load it from a marked block.
# A new run of the setup replaces this file. Put your own lines elsewhere.

# Only in a real terminal, so that agents and scripts keep ls and cat.
if [[ -t 0 && -t 1 ]]; then
  export BAT_THEME="TwoDark"
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --cycle'
  command -v fzf >/dev/null && source <(fzf --zsh)
  command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
  if command -v hopen >/dev/null; then
    source <(hopen --completion zsh)
    # Like Ctrl+P and Ctrl+Shift+F in VS Code: open a file, or a search result.
    alias ff='hopen --find'
    fif() { hopen --grep "$*"; }
  fi
  if command -v eza >/dev/null; then
    alias ls="eza"
    alias ll="eza -la"
    alias tree="eza --tree"
  fi
  command -v bat >/dev/null && alias cat="bat"
fi
