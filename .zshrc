export CLICOLOR=1
export LESS='--window -2 -FMRX'

alias l='ls -CF'
alias la='ls -A'
alias ll='ls -alF'
alias vi='vim'

export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

################################################################################
# Platform-specific behaviors
################################################################################
if [[ $(uname) == 'Darwin' ]]; then
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
else
    # Based on Lubuntu 19.10 ~/.bashrc

    # enable color support of ls and also add handy aliases
    if [ -x /usr/bin/dircolors ]; then
        test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
        alias ls='ls --color=auto'
        alias grep='grep --color=auto'
        alias fgrep='fgrep --color=auto'
        alias egrep='egrep --color=auto'
    fi

    # Add an "alert" alias for long running commands.  Use like so:
    #   sleep 10; alert
    alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

    # make less more friendly for non-text input files, see lesspipe(1)
    [ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

    # set variable identifying the chroot you work in (used in the prompt below)
    if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
        debian_chroot=$(cat /etc/debian_chroot)
    fi

    [ -z "$DISPLAY" ] || export TERM=xterm-256color

    # set a fancy prompt (non-color, unless we know we "want" color)
    case "$TERM" in
        xterm-color|*-256color) color_prompt=yes;;
    esac

    #if [ -n "$force_color_prompt" ]; then
    #    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
    #	# We have color support; assume it's compliant with Ecma-48
    #	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
    #	# a case would tend to support setf rather than setaf.)
    #	color_prompt=yes
    #    else
    #	color_prompt=
    #    fi
    #fi
    #
    #if [ "$color_prompt" = yes ]; then
    #    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
    #else
    #    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
    #fi
    #unset color_prompt force_color_prompt

    # If this is an xterm set the title to user@host:dir
    #case "$TERM" in
    #xterm*|rxvt*)
    #    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    #    ;;
    #*)
    #    ;;
    #esac
fi


################################################################################
# Somewhat bash-like History
################################################################################
HISTFILE=~/.zsh_history
HISTSIZE=9999
SAVEHIST=9999
HISTFILESIZE=9999
unsetopt hist_beep
unsetopt inc_append_history
unsetopt share_history
setopt append_history
setopt hist_find_no_dups
setopt hist_reduce_blanks
#setopt histignorealldups


################################################################################
# Misc. zsh settings
################################################################################
autoload -Uz compinit
for dump in ~/.zcompdump(N.mh+24); do
    # https://medium.com/@dannysmith/little-thing-2-speeding-up-zsh-f1860390f92
    # Section "What else is slow then?"
    compinit
done

if [[ $(uname) == 'Linux' ]]; then
    # These are auto-generated by Lubuntu 19.10
    zstyle ':completion:*' auto-description 'specify: %d'
    zstyle ':completion:*' completer _expand _complete _correct _approximate
    zstyle ':completion:*' format 'Completing %d'
    zstyle ':completion:*' group-name ''
    zstyle ':completion:*' menu select=2
    eval "$(dircolors -b)"
    zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
    zstyle ':completion:*' list-colors ''
    zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
    zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'
    zstyle ':completion:*' menu select=long
    zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
    zstyle ':completion:*' use-compctl false
    zstyle ':completion:*' verbose true

    zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
    zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'
fi


################################################################################
# Bash-like keystrokes
################################################################################
# Alt-backspace -- https://unix.stackexchange.com/a/319854
backward-kill-dir () {
    local WORDCHARS=${WORDCHARS/\/}
    zle backward-kill-word
}
zle -N backward-kill-dir
bindkey '^[^?' backward-kill-dir

# https://stackoverflow.com/a/52714907
bindkey "\e\e[D" backward-word  # Alt-left
bindkey "\e\e[C" forward-word   # Alt-right


################################################################################
# Enriched prompt
################################################################################
autoload -Uz vcs_info && vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:*' formats ' (%b)'
setopt PROMPT_SUBST
precmd() { vcs_info }
aws_profile() {
    # For https://github.com/remind101/assume-role/ which adds ASSUME_ROLE
    # to the current shell process.
    local assumed_role=""
    if [[ -n "$ASSUMED_ROLE" ]]; then
        assumed_role="%B%F{yellow}$ASSUMED_ROLE%f%b"
    fi

    # Isengard cli spanws a new shell process.
    local profile_name=""
    if [[ -n "$AWS_DEFAULT_PROFILE" ]]; then
        profile_name="%B%F{red}$AWS_DEFAULT_PROFILE%f%b"
    elif [[ -n "$AWS_PROFILE" ]]; then
        profile_name="%B%F{red}$AWS_PROFILE%f%b"
    fi

    if [[ -n "$profile_name" && -n "$assumed_role" ]]; then
        echo -n " %F{white}[$profile_name, $assumed_role%F{white}]"
    elif [[ -n "$assumed_role" ]]; then
        echo -n " %F{white}[$assumed_role%F{white}]"
    elif [[ -n "$profile_name" ]]; then
        echo -n " %F{white}[$profile_name%F{white}]"
    fi
}
# Must use single quote for vsc_info_msg_0_ to work correctly
export PROMPT='%F{cyan}%n@%F{green}%m:%F{white}%~%B%F{magenta}${vcs_info_msg_0_}%b$(aws_profile)%F{gray}
%# '

# This causes a minor annoyance on OSX + iTerm2 + tmux: after vim, must `reset`.
function winch_handler() {
    setopt localoptions nolocaltraps
    COLUMNS=$(tput cols)
    LINES=$(expr `tput lines` - $1)
    stty rows $LINES cols $COLUMNS
}
winch_handler 1
#trap 'winch_handler 1' WINCH
functions[TRAPWINCH]="${functions[TRAPWINCH]//winch_handler}"
