#!/bin/bash

sudo apt update && sudo apt dist-upgrade -V -y
sudo apt clean
brew update
brew upgrade
brew cleanup -s

# No longer use miniconda.
exit

# miniconda
declare -a conda_env=( $(for i in ~/miniconda3/envs/*; do [[ -d $i && ! $i =~ '^.' ]] && echo $(basename $i);done) )
for i in base "${conda_env[@]}"; do
    echo Updating conda environment: $i
    ~/miniconda3/bin/conda update -n $i --all -y
done
~/miniconda3/bin/conda clean --all -y
~/miniconda3/bin/conda build purge
