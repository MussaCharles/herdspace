# shellcheck shell=bash
# The shell completion of hopen, for zsh and bash.
# bin/hopen loads this file. It defines functions and variables, and runs nothing.

# completion_script SHELL prints a completion script for zsh or bash. It asks
# "hopen --complete lists|templates" for the names, so that they stay current.
completion_script() {
  case "$1" in
    zsh)
      cat <<'ZSH'
#compdef hopen
_hopen() {
  local -a options
  options=(--all --list --templates --apply --convert --file --template --no-attach --trust --task --find --quick-open --grep --with-ignored --ports --palette --completion --version --help)
  case "${words[CURRENT-1]}" in
    --template | --apply) compadd -- ${(f)"$(hopen --complete templates 2>/dev/null)"}; return ;;
    --convert) compadd -- ${(f)"$(hopen --complete lists 2>/dev/null)"}; return ;;
    --task) compadd -- ${(f)"$(hopen --complete tasks 2>/dev/null)"}; return ;;
    --file) _files; return ;;
    --completion) compadd zsh bash; return ;;
  esac
  case "$PREFIX" in
    -*) compadd -- $options ;;
    */* | .*) _files -/ ;;
    *) compadd -- ${(f)"$(hopen --complete lists 2>/dev/null)"} ;;
  esac
}
compdef _hopen hopen
ZSH
      ;;
    bash)
      cat <<'BASH'
# This works with bash 3.2, the bash of macOS, which has no mapfile.
_hopen() {
  local cur="${COMP_WORDS[COMP_CWORD]}" prev="${COMP_WORDS[COMP_CWORD-1]}" words="" IFS=$'\n'
  case "$prev" in
    --template | --apply) words="$(hopen --complete templates 2>/dev/null)" ;;
    --convert) words="$(hopen --complete lists 2>/dev/null)" ;;
    --task) words="$(hopen --complete tasks 2>/dev/null)" ;;
    --completion) words=$'zsh\nbash' ;;
    --file) COMPREPLY=($(compgen -f -- "$cur")); return ;;
    *)
      case "$cur" in
        -*) words=$'--all\n--list\n--templates\n--apply\n--convert\n--file\n--template\n--no-attach\n--trust\n--task\n--find\n--quick-open\n--grep\n--ports\n--palette\n--completion\n--version\n--help' ;;
        */* | .*) COMPREPLY=($(compgen -d -- "$cur")); return ;;
        *) words="$(hopen --complete lists 2>/dev/null)" ;;
      esac
      ;;
  esac
  COMPREPLY=($(compgen -W "$words" -- "$cur"))
}
complete -o filenames -F _hopen hopen
BASH
      ;;
    *) die "hopen --completion needs zsh or bash." ;;
  esac
}
