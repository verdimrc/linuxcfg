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

# updating conda under pyenv
for i in base ~/miniforge3/envs/base-*; do
    echo "Updating conda environments $(basename $i)..."
    ~/miniforge3/bin/conda update --all --yes -n `basename $i`
done
~/miniforge3/bin/conda clean --all --yes

## No longer uses miniconda. Left here for historical context only.
##
#declare -a conda_env=( $(for i in ~/miniconda3/envs/*; do [[ -d $i && ! $i =~ '^.' ]] && echo $(basename $i);done) )
#for i in base "${conda_env[@]}"; do
#    echo Updating conda environment: $i
#    ~/miniconda3/bin/conda update -n $i --all -y
#done
#~/miniconda3/bin/conda clean --all -y
#~/miniconda3/bin/conda build purge
