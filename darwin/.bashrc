export CLICOLOR=1

COLOR_BLUE="\[\033[36m\]"
COLOR_RED="\[\033[0;31m\]"
COLOR_YELLOW="\[\033[0;33m\]"
COLOR_GREEN="\[\033[0;32m\]"
COLOR_OFF="\[\033[0m\]"

aws_profile() {
    # For https://github.com/remind101/assume-role/ which adds ASSUME_ROLE
    # to the current shell process.
    local assumed_role=""
    if [[ -n "$ASSUMED_ROLE" ]]; then
        assumed_role="$ASSUMED_ROLE"
    fi

    # Isengard cli spanws a new shell process.
    local profile_name=""
    if [[ -n "$AWS_DEFAULT_PROFILE" ]]; then
        profile_name="$AWS_DEFAULT_PROFILE"
    elif [[ -n "$AWS_PROFILE" ]]; then
        profile_name="$AWS_PROFILE"
    fi

    if [[ -n "$profile_name""$assume_role" ]]; then
        echo -n " [$profile_name, $assumed_role]"
    elif [[ -n "$assumed_role" ]]; then
        echo -n " [$assumed_role]"
    elif [[ -n "$profile_name" ]]; then
        echo -n " [$profile_name]"
    fi
}

# Two liner
PS1="$COLOR_BLUE\u$COLOR_OFF@$COLOR_GREEN\h:\[\033[33;1m\]\w$COLOR_YELLOW\$(__git_ps1 \" (%s)\")\$(aws_profile)$COLOR_OFF
\$ "

[ -f $(brew --prefix)/etc/bash_completion ] && . $(brew --prefix)/etc/bash_completion
[ -f $(brew --prefix)/etc/bash_completion.d/git-completion.bash ] && . $(brew --prefix)/etc/bash_completion.d/git-completion.bash

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

alias ll='ls -al'
alias grep='grep --color=auto'
alias vi='vim'

export LANG=en_US.utf-8
export LC_ALL=${LANG}

# http://www.noah.org/wiki/Bash_notes#dynamic_COLUMNS_and_LINES_with_SIGWINCH_in_Bash
function winch_handler() {
    # This adds post-processing after the terminal handles SIGWINCH.
    # First, pass the SIGWINCH back to the terminal because
    # we can't get the new size until the terminal sees SIGWINCH.
    trap - SIGWINCH
    kill -SIGWINCH $$

    # Now tput can query the terminal for the new size.
    local COLUMNS=$(tput cols)
    local LINES=$(expr `tput lines` - 1)

    # verdi's addition
    stty rows $(expr `tput lines` - 1) cols $(tput cols)

    # Restore this winch handler so it will respond to future WINCH signals.
    trap "winch_handler" SIGWINCH
}

# Call the winch_handler to both initialize COLUMNS and LINES, and
# install the winch_handler trap.
winch_handler
