#
# /etc/bash.bashrc
#
# If not running interactively, don't do anything
[[ $- != *i* ]] && return

[[ $DISPLAY ]]

PS1='[\u@\h \W]\$ '

case ${TERM} in
        Eterm*|alacritty*|aterm*|foot*|gnome*|konsole*|kterm*|putty*|rxvt*|tmux*|xterm*)
    PROMPT_COMMAND+=('printf "\033]0;%s@%s:%s\007" "${USER}" "${HOSTNAME%%.*}" "${PWD/#$HOME/\~}"')

    ;;
  screen*)
    PROMPT_COMMAND+=('printf "\033_%s@%s:%s\033\\" "${USER}" "${HOSTNAME%%.*}" "${PWD/#$HOME/\~}"')
    ;;
esac

## Source files
source /etc/.sh_alias

## Source plugins
source /usr/share/doc/pkgfile/command-not-found.bash
source $HOME/.config/broot/launcher/bash/br
if [[ -f /usr/share/bash-completion/bash_completion ]]; then
    source /usr/share/bash-completion/bash_completion
fi

## Exports
export EDITOR=vim
export VISUAL=vim

## History completion
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'
export HISTCONTROL="erasedups:ignorespace"

## History settings
HISTFILE=$HOME/.config/.histfile
HISTSIZE=69000
SAVEHIST=69000
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS

## Prevent file clobbering (overwriting)
# to bypass this intentionally: echo "output" >| file.txt
set -o noclobber

## Autocd
shopt -s autocd

## Line wrap on window resize
shopt -s checkwinsize

## Rice, rice, baby
eval "$(zoxide init bash)"
eval "$(starship init bash)"

clear
neofetch