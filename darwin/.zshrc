# JLab (early Nov'22 version) refuses to load config from ~/.jupyter
export JUPYTER_CONFIG_PATH=~/.jupyter

# Don't use golang proxy
export GOPROXY=direct
export HOMEBREW_GOPROXY=direct

# pipx default python interpreter
export PIPX_DEFAULT_PYTHON=/opt/homebrew/bin/python3

export PATH=$HOME/bin:$PATH
export CLICOLOR=1

# Need: brew install coreutils
alias ls='gls --color=auto --hyperlink=auto'
alias ll='ls -al'

alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias vi='vim'
alias ncdu='ncdu --color dark'
alias reset_title='echo -e "\033];\007"'
alias gbvv="git branch -vv | egrep '^.*(behind|ahead).*|$'"

export LANG=en_US.utf-8
export LC_ALL=${LANG}
export LESS='-FMRX'

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

setopt interactive_comments

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
FPATH=/usr/local/share/zsh-completions:$FPATH
autoload -Uz compinit
compinit

# https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-completion.html#cli-command-completion-configure
autoload bashcompinit && bashcompinit
complete -C '/opt/homebrew/bin/aws_completer' aws

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
    #
    # NOTE: segfault on MBP M1.
    local assumed_role=""
    if [[ -n "$ASSUMED_ROLE" ]]; then
        assumed_role="%B%F{yellow}$ASSUMED_ROLE%f%b"
    elif [[ -n "$AWSUME_PROFILE" ]]; then
        # Replacement of assume-role for MBP M1
        #
        # AWSUME_SKIP_ALIAS_SETUP=true pipx install awsume
        # . awsume <aws-profile>
        assumed_role="%B%F{yellow}$AWSUME_PROFILE%f%b"
    else
        # Isengard cli spanws a new shell process.
        local profile_name=""
        if [[ -n "$AWS_DEFAULT_PROFILE" ]]; then
            profile_name="%B%F{red}$AWS_DEFAULT_PROFILE%f%b"
        elif [[ -n "$AWS_PROFILE" ]]; then
            profile_name="%B%F{red}$AWS_PROFILE%f%b"
        fi
    fi

    if [[ -n "$profile_name" && -n "$assumed_role" ]]; then
        echo -n " %F{white}[$profile_name, $assumed_role%F{white}]"
    elif [[ -n "$assumed_role" ]]; then
        echo -n " %F{white}[$assumed_role%F{white}]"
    elif [[ -n "$profile_name" ]]; then
        echo -n " %F{white}[$profile_name%F{white}]"
    fi
}

amplify_env() {
    # Based on https://www.xiegerts.com/post/show-current-aws-amplify-environment/#display-the-active-amplify-env
    local PROJECT_DIR=$(git rev-parse --show-toplevel 2>/dev/null)
    local ENV=$PROJECT_DIR/amplify/.config/local-env-info.json

    if [ -f "$ENV" ]; then
        local env=$(cat $ENV | jq -r ".envName")

        [[ -f "$PROJECT_DIR/amplify/.config/project-config.json" ]] \
            && local project=$(cat "$PROJECT_DIR/amplify/.config/project-config.json" | jq -r ".projectName")

        [[ -f "$PROJECT_DIR/amplify/team-provider-info.json" ]] \
            && local region=$(cat "$PROJECT_DIR/amplify/team-provider-info.json" | jq -r ".${env}.awscloudformation.Region")

        local amplify_env="%B%F{yellow}$region/$project/$env%f%b"
        echo -n " %F{white}{$amplify_env%F{white}}"
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

# Shlvl of JLab's terminal
if [[ ${JUPYTER_SERVER_ROOT} != "" ]]; then
    local pcmd=$(ps -c -o command=,args= -p $(ps -o ppid= -p $$))
    [[ "$pcmd" == "python jupyter-lab" ]] && export JLAB_BASE_SHLVL=$SHLVL
fi

# Must use single quote for vsc_info_msg_0_ to work correctly
#export PROMPT='$(prompt_prefix)[%F{green}%~%F{white}]%B%F{magenta}${vcs_info_msg_0_}%b$(aws_profile)%F{gray}

# Use this when screencasting, to strip-off unecessary details in the prompt
#export PROMPT='[%F{green}%~%F{white}]%B%F{magenta}${vcs_info_msg_0_}%b%F{gray}

export PROMPT='$(prompt_prefix)[%F{green}%~%F{white}]%B%F{magenta}${vcs_info_msg_0_}%b$(amplify_env)%b$(aws_profile)%F{gray}
%# '


################################################################################
# PyEnv
################################################################################
if command -v pyenv 1>/dev/null 2>&1; then
    export PYENV_ROOT=$HOME/.pyenv
    export PATH=$PYENV_ROOT/bin:$PATH

    # Speed-up pyenv init -- https://github.com/pyenv/pyenv/issues/784#issuecomment-404850327
    # NOTE: run 'pyenv rehash' after installing executables.
    eval "$(pyenv init - --no-rehash zsh)"

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
source ~/.zshrc-keybindings.darwin

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

    # Underlines make integrated terminal too noisy
    alias ls='gls --color=auto'
fi
