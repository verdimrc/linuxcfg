#!/bin/bash

# OS packages
echo Updating OS packages...
sudo apt update
sudo apt dist-upgrade -V -y

# updating pyenv
echo 'Running pyenv rehash...'
pyenv rehash

# updating pipx
echo 'Updating pipx packages...'
pipx upgrade-all

# Updating conda's python under pyenv. Special case for base python.
echo "Updating conda's base python..."
~/.pyenv/versions/miniforge3-latest/bin/conda update --yes --update-all -n base python

# Updating all conda's environment.
for i in base ~/.pyenv/versions/miniforge3-latest/envs/base-*; do
    echo "Updating conda environments $(basename $i)..."
    PY_VER=$($i/bin/python -c 'import sys ; print(f"{sys.version_info.major}.{sys.version_info.minor}", end="")' )
    ~/.pyenv/versions/miniforge3-latest/bin/conda update --all --yes -n `basename $i` "python==$PY_VER"
    ~/.pyenv/versions/miniforge3-latest/bin/conda update --all --yes -n `basename $i`
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
