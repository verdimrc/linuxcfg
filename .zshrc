export PATH=$HOME/bin:$PATH
setopt interactive_comments

###############################################################################
# Command not found
###############################################################################
command_not_found_handler() {
	local pkgs cmd="$1" files=()
	printf 'zsh: command not found: %s' "$cmd" # print command not found asap, then search for packages
	files=(${(f)"$(pacman -F --machinereadable -- "/usr/bin/${cmd}")"})
	if (( ${#files[@]} )); then
		printf '\r%s may be found in the following packages:\n' "$cmd"
		local res=() repo package version file
		for file in "$files[@]"; do
			res=("${(0)file}")
			repo="$res[1]"
			package="$res[2]"
			version="$res[3]"
			file="$res[4]"
			printf '  %s/%s %s: /%s\n' "$repo" "$package" "$version" "$file"
		done
	else
		printf '\n'
	fi
	return 127
}


###############################################################################
# CLI
###############################################################################
# https://wiki.archlinux.org/index.php/Color_output_in_console
export CLICOLOR=1
export LESS='-FMRX'
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

alias diff='diff --color=auto'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias ip='ip -color=auto'
alias l='ls -CF'
alias la='ls -A'
alias ll='ls -alF'
alias vi='vim'
alias gbvv="git branch -vv | egrep '^.*(behind|ahead).*|$'"


################################################################################
# Platform-specific behaviors
################################################################################
# Based on Lubuntu 19.10 ~/.bashrc

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    [[ ${TERM_PROGRAM} == "vscode" ]] && alias ls='ls --color=auto' || alias ls='ls --color=auto --hyperlink=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

if [[ -n "$DISPLAY" ]]; then
   man() {
       env \
           LESS_TERMCAP_mb=$(printf "\e[1;31m") \
           LESS_TERMCAP_md=$(printf "\e[1;31m") \
           LESS_TERMCAP_me=$(printf "\e[0m") \
           LESS_TERMCAP_se=$(printf "\e[0m") \
           LESS_TERMCAP_so=$(printf "\e[1;44;33m") \
           LESS_TERMCAP_ue=$(printf "\e[0m") \
           LESS_TERMCAP_us=$(printf "\e[1;32m") \
           man "$@"
   }
fi


################################################################################
# Somewhat bash-like history
################################################################################
HISTFILE=~/.zsh_history
HISTSIZE=99999
SAVEHIST=99999
HISTFILESIZE=99999
unsetopt hist_beep
unsetopt inc_append_history
unsetopt share_history
setopt append_history
setopt hist_find_no_dups
setopt hist_reduce_blanks
#setopt histignorealldups


################################################################################
# Completion
################################################################################
autoload -Uz compinit
compinit

command -v kitty &> /dev/null && kitty + complete setup zsh | source /dev/stdin

autoload bashcompinit && bashcompinit

#-------------------------------------------------------------------------------
# Based on auto-generated by Lubuntu 19.10 (but some removed)
zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
eval "$(dircolors -b)"
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'
#-------------------------------------------------------------------------------

setopt autoparamslash

# https://superuser.com/a/1020116
zstyle ':completion:*:*:*:*:*' menu select


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

prompt_prefix() {
    local retval=""

    # Be aware when some CLI toolkits (e.g., assume role) spawns a new shell.
    if [[ ${JUPYTER_SERVER_ROOT} != "" ]]; then
        # Normalize Jlab terminal to level 1. This must precedes the vscode
        # check, because Jlab can be started from vscode integrated terminal.
        local let effective_shlvl=$(($SHLVL-$JLAB_BASE_SHLVL+1))
        [[ ${effective_shlvl} -gt 1 ]] && retval=${retval}"%B%F{yellow}[${effective_shlvl}]%f%b "
    elif [[ ${VSCODE_BASE_SHLVL} != "" ]]; then
        # Normalize to level 1
        local let effective_shlvl=$(($SHLVL-$VSCODE_BASE_SHLVL+1))
        [[ ${effective_shlvl} -gt 1 ]] && retval=${retval}"%B%F{yellow}[${effective_shlvl}]%f%b "
    else
        [[ ${SHLVL} -gt 1 ]] && retval=${retval}"%B%F{yellow}[${SHLVL}]%f%b "
    fi

    # Be aware when running under midnight commander.
    [[ -v MC_SID ]] && retval=${retval}"%B%F{red}[mc]%f%b "

    # VScode uses pyenv shell instead of pyenv activate
    if [[ (${TERM_PROGRAM} == "vscode") && (! -v VIRTUAL_ENV) && (-v PYENV_VERSION) ]]; then
        retval=${retval}"($PYENV_VERSION) "
    fi

    echo -n "${retval}"
}

# Shlvl of zsh when started from VSCode.
if [[ ${TERM_PROGRAM} == "vscode" ]]; then
    # Start an integrated terminal
    local pcmd=$(ps -c -o command= -p $(ps -o ppid= -p $$))
    [[ "$pcmd" =~ "[Cc]ode*" ]] && export VSCODE_BASE_SHLVL=$SHLVL
elif [[ $__CFBundleIdentifier == "" ]]; then  # __CF* env var is set if on OSX.
    # Linux-specific heuristic when starting an external terminal (VSCode -> ctrl+shift+c).
    # This is how the process tree looks like:
    #
    #     lxqt-sessions
    #      \_ code-insider
    #          \_ kitty
    #              \_ kitty
    #              \_ /usr/bin/zsh  # SHLVL=2, but closing the VSCode GUI won't close this kitty.
    #                               # Instead, when the VSCode GUI is closed, the zsh parent kitty
    #                               # will have lxqt-sessions as its new owner.
    local -i pid_term_emu=$(ps -o ppid= -p $(ps -o ppid= -p $$))
    local pcmd=$(ps -c -o command= -p $pid_term_emu)
    [[ "$pcmd" =~ "[Cc]ode*" ]] && export VSCODE_BASE_SHLVL=$SHLVL
fi

# Must use single quote for vsc_info_msg_0_ to work correctly
#export PROMPT='$(prompt_prefix)%F{cyan}%n@%F{green}%m:%F{white}%~%B%F{magenta}${vcs_info_msg_0_}%b$(aws_profile)%F{gray}

# Use this when screencasting, to strip-off unecessary details in the prompt
#export PROMPT='[%F{green}%~%F{white}]%B%F{magenta}${vcs_info_msg_0_}%b%F{gray}

export PROMPT='$(prompt_prefix)[%B%F{green}%~%b%F{white}]%B%F{magenta}${vcs_info_msg_0_}%b$(aws_profile)%F{gray}
%# '


################################################################################
# PyEnv
#
# NOTE for archlinux: if autocompletion is not working, apply the suggestion
# from https://bbs.archlinux.org/viewtopic.php?pid=1957176#p1957176 to
# /usr/share/zsh/site-functions/_pyenv
################################################################################
export PATH="$HOME/.pyenv/bin:$PATH"
if command -v pyenv 1>/dev/null 2>&1; then
    export PYENV_ROOT=$HOME/.pyenv
    export PATH=$PYENV_ROOT/bin:$PATH

    # Speed-up pyenv init -- https://github.com/pyenv/pyenv/issues/784#issuecomment-404850327
    # NOTE: run 'pyenv rehash' after installing executables.
    #eval "$(pyenv init - --no-rehash zsh)"
    eval "$(pyenv init - zsh)"

    # Prefer manual activation even if per-project virtualenv is defined.
    # Apart from full control, want to be able to 'reset' on tmux or jupyter
    #if which pyenv-virtualenv-init > /dev/null; then
    #    eval "$(pyenv virtualenv-init - zsh)"
    #fi

    # Note that these will have no effect if pyenv-virtualenv-init is enabled.
    [[ -z "$TMUX" ]] || pyenv deactivate
    [[ -z "$JUPYTER_SERVER_ROOT" ]] || pyenv deactivate
fi


################################################################################
# Keybindings
################################################################################
source ~/.zshrc-keybindings.linux

# pipx
export PATH="$PATH:$HOME/.local/bin"
eval "$(register-python-argcomplete pipx)"


################################################################################
# Specific stuffs for vscode terminal
################################################################################
if [[ (${TERM_PROGRAM} == "vscode") ]]; then
    GITROOT=$(git rev-parse --show-toplevel 2> /dev/null)
    if [[ $? -eq 0 ]]; then
        [[ -e $GITROOT/.env.unversioned ]] && source $GITROOT/.env.unversioned
    fi
fi
