#!/bin/bash

if command -v apt &> /dev/null; then
    # OS packages
    echo Updating Ubuntu packages...
    sudo apt update
    sudo apt dist-upgrade -V -y
else
    echo "Command apt not found. Skip updating Ubuntu packages..."
fi

# updating pyenv
echo 'Running pyenv rehash...'
pyenv rehash

# updating pipx
echo 'Updating pipx packages...'
pipx upgrade-all

# Updating conda's python under pyenv. Special case for base python.
echo "Updating conda's base python..."
~/.pyenv/versions/miniforge3-latest/bin/conda update --yes --update-all -n base python
~/.pyenv/versions/miniforge3-latest/bin/conda update --yes --update-all -n base

# Updating all conda's environment.
for i in ~/.pyenv/versions/miniforge3-latest/envs/base-*; do
    echo "Updating conda environments $(basename $i)..."
    ## DEPRECATED: conda results in (python-3.13.7, libffi-3.4.6) => (python-3.13.2, libffi-3.5.2)
    ## Solution: mamba
    #PY_VER=$($i/bin/python -c 'import sys ; print(f"{sys.version_info.major}.{sys.version_info.minor}", end="")' )
    #~/.pyenv/versions/miniforge3-latest/bin/conda update --all --yes -n `basename $i` "python~=${PY_VER}.0"
    #~/.pyenv/versions/miniforge3-latest/bin/conda update --all --yes -n `basename $i`
    ~/.pyenv/versions/miniforge3-latest/bin/mamba update --all --yes -n `basename $i`
done
~/.pyenv/versions/miniforge3-latest/bin/conda clean --all --yes

## Enable / disable this pipupgrade stanza as you like.
echo Upgrading all packages under virtualenv \'jlab\'...
export VIRTUAL_ENV=~/.pyenv/versions/miniforge3-latest/envs/jlab
pipupgrade --pip-path $VIRTUAL_ENV/bin/pip3 --pip -l --upgrade-type major --yes
export -n VIRTUAL_ENV
#
# NOTE: VIRTUAL_ENV=xxx pipupgrade ... still pipupgrade the current environment!

exit $?


###############################################################################
# DEPRECATED. Left here for historical context only
###############################################################################
# No longer uses miniconda. Left here for historical context only.
declare -a conda_env=( $(for i in ~/miniconda3/envs/*; do [[ -d $i && ! $i =~ '^.' ]] && echo $(basename $i);done) )
for i in base "${conda_env[@]}"; do
    echo Updating conda environment: $i
    ~/miniconda3/bin/conda update -n $i --all -y
done
~/miniconda3/bin/conda clean --all -y
~/miniconda3/bin/conda build purge
