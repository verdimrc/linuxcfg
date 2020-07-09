export PATH=/usr/local/opt/openssl/bin:$PATH

if [[ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]]; then
    . "$HOME/miniconda3/etc/profile.d/conda.sh"
    [[ -z "$TMUX" ]] || conda deactivate
    [[ -z "$JUPYTER_SERVER_ROOT" ]] || conda deactivate
fi
