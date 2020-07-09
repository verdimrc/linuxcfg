export PATH=/usr/local/opt/openssl/bin:$PATH

source ~/.git-completion.sh
source ~/.git-prompt.sh
source ~/.bashrc

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
#__conda_setup="$('/Users/marcverd/miniconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
#if [ $? -eq 0 ]; then
#    eval "$__conda_setup"
#else
#    if [ -f "/Users/marcverd/miniconda3/etc/profile.d/conda.sh" ]; then
#        . "/Users/marcverd/miniconda3/etc/profile.d/conda.sh"
#    else
#        export PATH="/Users/marcverd/miniconda3/bin:$PATH"
#    fi
#fi
#unset __conda_setup
# <<< conda initialize <<<
. "/Users/marcverd/miniconda3/etc/profile.d/conda.sh"  # commented out by conda initialize
[[ -z "$TMUX" ]] || conda deactivate
[[ -z "$JUPYTER_SERVER_ROOT" ]] || conda deactivate
