#!/bin/bash

if [[ -t 1 ]] && [[ $(tput colors) -ge 8 ]]; then
    # All colors are bold
    RED="\033[1;31m"
    GREEN="\033[1;32m"
    PURPLE="\033[1;35m"
    YELLOW="\033[1;33m"
    BLUE="\033[01;34m"
    OFF="\033[0m"
else
    RED=''
    GREEN=''
    PURPLE=''
    YELLOW=''
    BLUE=''
    OFF=''
fi

show_info() {
   echo -e "${BLUE}[INFO]${OFF} ${GREEN}${@}${OFF}"
}

show_warn() {
   echo -e "${YELLOW}[WARN]${OFF} ${PURPLE}${@}${OFF}"
}

if command -v apt &> /dev/null; then
    # OS packages
    show_info "Updating Ubuntu packages..."
    sudo apt update
    sudo apt dist-upgrade -V -y
else
    show_warn "Command apt not found. Skip updating Ubuntu packages..."
fi

! command -v pyenv &> /dev/null && {
    show_warn "Command pyenv not found. Skip all."
    exit 0
}

# updating pyenv
if [[ $(stat -c '%U' $(pyenv which pyenv)) == "root" ]]; then
    show_warn "Skip pyenv update because it's a system-wide installation..."
else
    show_info "Updating pyenv..."
    show_info "pyenv before update: ${YELLOW}$(pyenv --version)${GREEN}"
    pyenv update
    show_info "pyenv after update: ${YELLOW}$(pyenv --version)${GREEN}"
fi
pyenv rehash

# updating pipx
show_info 'Updating pipx packages...'
pipx upgrade-all

# Updating conda's python under pyenv. Special case for base python.
show_info "Updating conda's base python..."
~/.pyenv/versions/miniforge3-latest/bin/conda update --yes --update-all -n base python
~/.pyenv/versions/miniforge3-latest/bin/conda update --yes --update-all -n base

# Updating all conda's environment.
for i in ~/.pyenv/versions/miniforge3-latest/envs/base-*; do
    show_info "Updating conda environments ${YELLOW}$(basename $i)${GREEN}..."
    ~/.pyenv/versions/miniforge3-latest/bin/mamba update --all --yes -n `basename $i`
done
~/.pyenv/versions/miniforge3-latest/bin/conda clean --all --yes

## Enable / disable this pipupgrade stanza as you like.
show_info Upgrading all packages under virtualenv ${YELLOW}jlab${GREEN}...
export VIRTUAL_ENV=~/.pyenv/versions/miniforge3-latest/envs/jlab
pipupgrade --pip-path $VIRTUAL_ENV/bin/pip3 --pip -l --upgrade-type major --yes
export -n VIRTUAL_ENV
#
# NOTE: VIRTUAL_ENV=xxx pipupgrade ... still pipupgrade the current environment!

show_info "All done."
exit $?


###############################################################################
# DEPRECATED. Left here for historical context only
# Reverse chronological order
###############################################################################
# DEPRECATED: conda downgrades python: (python-3.13.7, libffi-3.4.6) => (python-3.13.2, libffi-3.5.2)
# Solution: mamba
for i in ~/.pyenv/versions/miniforge3-latest/envs/base-*; do
    show_info "Updating conda environments ${YELLOW}$(basename $i)${GREEN}..."
    PY_VER=$($i/bin/python -c 'import sys ; print(f"{sys.version_info.major}.{sys.version_info.minor}", end="")' )
    ~/.pyenv/versions/miniforge3-latest/bin/conda update --all --yes -n `basename $i` "python~=${PY_VER}.0"
    ~/.pyenv/versions/miniforge3-latest/bin/conda update --all --yes -n `basename $i`
done

# No longer uses miniconda.
declare -a conda_env=( $(for i in ~/miniconda3/envs/*; do [[ -d $i && ! $i =~ '^.' ]] && echo $(basename $i);done) )
for i in base "${conda_env[@]}"; do
    echo Updating conda environment: $i
    ~/miniconda3/bin/conda update -n $i --all -y
done
~/miniconda3/bin/conda clean --all -y
~/miniconda3/bin/conda build purge
