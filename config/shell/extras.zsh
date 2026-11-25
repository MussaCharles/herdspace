# Shell extras from herdspace: the fzf keys, zoxide, the completion of hopen,
# ff and fif, and eza and bat for ls and cat. A marked block in ~/.zshrc loads
# this file. A new run of the setup replaces it. Put your own lines elsewhere.
#
# The extras add and never replace: each alias, function, variable, and key
# that you set before this file stays yours. To see what the extras skipped:
#   print -l $HERDSPACE_EXTRAS_SKIPPED
# In the herdspace shell (HERDSPACE_SHELL=1), the aliases of the extras
# replace the ls and ll aliases of Oh My Zsh.

typeset -ga HERDSPACE_EXTRAS_SKIPPED
HERDSPACE_EXTRAS_SKIPPED=()

# Only in a real terminal, so that agents and scripts keep ls and cat.
if [[ -t 0 && -t 1 ]]; then
  # _hs_free NAME: true if NAME is not an alias or a function yet.
  _hs_free() {
    if (( ${+aliases[$1]} || ${+functions[$1]} )); then
      HERDSPACE_EXTRAS_SKIPPED+=("$1")
      return 1
    fi
  }
  # _hs_alias NAME VALUE: the alias, if NAME is free or this is the herdspace shell.
  _hs_alias() {
    if (( ${HERDSPACE_SHELL:-0} )) && (( ! ${+functions[$1]} )); then
      alias "$1=$2"
    elif _hs_free "$1"; then
      alias "$1=$2"
    fi
  }
  # _hs_func NAME: true if the extras may define the function NAME: NAME is
  # free, or this is the herdspace shell and NAME is no function yet. In the
  # herdspace shell, it removes an alias NAME first.
  _hs_func() {
    if (( ${HERDSPACE_SHELL:-0} )) && (( ! ${+functions[$1]} )); then
      unalias "$1" 2>/dev/null
      return 0
    fi
    _hs_free "$1"
  }
  # _hs_export NAME VALUE: the variable, if it has no value yet.
  _hs_export() {
    if [[ -n "${(P)1}" ]]; then
      HERDSPACE_EXTRAS_SKIPPED+=("$1")
    else
      export "$1=$2"
    fi
  }

  _hs_export BAT_THEME "TwoDark"
  _hs_export FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude .git'
  _hs_export FZF_DEFAULT_OPTS '--height 40% --layout=reverse --border --cycle'
  # nvim starts the herdspace editor, from ~/.config/herdspace-nvim, unless you
  # have your own ~/.config/nvim. Then nvim stays yours.
  if [[ ! -e "${XDG_CONFIG_HOME:-$HOME/.config}/nvim" ]]; then
    _hs_export NVIM_APPNAME herdspace-nvim
  fi

  if command -v fzf >/dev/null; then
    if (( ${+functions[fzf-history-widget]} )); then
      HERDSPACE_EXTRAS_SKIPPED+=("fzf keys")
    else
      # fzf binds Ctrl+R, Ctrl+T, and Alt+C. A key that you bound to another
      # widget before keeps your widget.
      typeset -A _hs_keys
      local _hs_key _hs_widget _hs_bound
      # zsh 5.8 cannot unset a key with a [ in it, such as ^[c, so the list
      # gets only the keys that have another widget.
      for _hs_key _hs_widget in '^R' history-incremental-search-backward '^T' transpose-chars '^[c' capitalize-word; do
        _hs_bound="${${(z)$(bindkey -- "$_hs_key")}[2]}"
        [[ "$_hs_bound" == ("$_hs_widget"|undefined-key|) ]] || _hs_keys[$_hs_key]="$_hs_bound"
      done
      source <(fzf --zsh)
      for _hs_key in "${(@k)_hs_keys}"; do
        bindkey -- "$_hs_key" "${_hs_keys[$_hs_key]}"
        HERDSPACE_EXTRAS_SKIPPED+=("fzf key ${_hs_key}")
      done
      unset _hs_keys _hs_key _hs_widget _hs_bound
    fi
  fi

  if command -v zoxide >/dev/null; then
    if (( ${+functions[__zoxide_z]} )); then
      :
    elif _hs_free z && _hs_free zi; then
      eval "$(zoxide init zsh)"
    fi
  fi

  if command -v hopen >/dev/null; then
    source <(hopen --completion zsh)
    # Like Ctrl+P and Ctrl+Shift+F in VS Code: open a file, or a search result.
    _hs_alias ff 'hopen --find'
    _hs_free fif && fif() { hopen --grep "$*"; }
  fi
  if command -v eza >/dev/null; then
    # ls and ll run eza only with flags that mean the same in eza: -l, -a, -A,
    # -R, -d, -1, -r, -h (eza shows human sizes with no flag), and -F (eza
    # needs --classify=always, because its -F takes a value). With any
    # other flag, for example -t, -S, -G, or a long option, they run the
    # standard ls, so that ls -ltr works as people expect.
    _herdspace_ls() {
      local a f i=0 classify=0
      local -a eza_args
      for a in "$@"; do
        (( i++ ))
        case "$a" in
          --) eza_args+=("${@[i,-1]}"); break ;;
          --* | -*[!laARFd1rh]*) command ls "$@"; return ;;
          -*)
            [[ "$a" != *F* ]] || classify=1
            f="${${a//h/}//F/}"
            [[ "$f" == - ]] || eza_args+=("$f")
            ;;
          *) eza_args+=("$a") ;;
        esac
      done
      (( ! classify )) || eza_args=(--classify=always "${eza_args[@]}")
      eza "${eza_args[@]}"
    }
    # The function keyword keeps an alias ls from changing the name.
    _hs_func ls && function ls { _herdspace_ls "$@"; }
    _hs_func ll && function ll { _herdspace_ls -la "$@"; }
    _hs_alias tree "eza --tree"
  fi
  command -v bat >/dev/null && _hs_alias cat "bat"
  # One line when a new herdspace release exists, at most once a day. The
  # check runs in the background. HERDSPACE_UPDATE_CHECK=0 turns it off. The
  # line comes before the first prompt, after the shell start, so that the
  # instant prompt of Powerlevel10k does not warn about output.
  if [[ "${HERDSPACE_UPDATE_CHECK:-1}" != 0 ]] && (( ${+commands[herdspace]} )); then
    _hs_update_notice() {
      add-zsh-hook -d precmd _hs_update_notice
      unfunction _hs_update_notice
      herdspace notice
    }
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd _hs_update_notice
  fi

  unfunction _hs_free _hs_alias _hs_func _hs_export
fi
