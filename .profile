export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"

# See also: https://stackoverflow.com/a/55485991
# NOTE: not effective on lxqt which sources from .config/lxqt/session.conf.
export GOOGLE_API_KEY=""
export GOOGLE_DEFAULT_CLIENT_ID=""
export GOOGLE_DEFAULT_CLIENT_SECRET=""
