export PATH=/usr/local/opt/openssl/bin:$HOME/.local/bin:$PATH

eval "$(/opt/homebrew/bin/brew shellenv)"

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

source ~/.git-completion.sh
source ~/.git-prompt.sh
source ~/.bashrc
