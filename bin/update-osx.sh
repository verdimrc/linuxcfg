#!/bin/bash

# brew
echo Updating brew packages...
brew update
brew upgrade
brew cleanup -s

# updating pyenv
echo 'Running pyenv rehash...'
pyenv rehash

# updating pipx
echo 'Updating pipx packages...'
pipx upgrade-all

# updating conda
echo 'Updating conda environments...'
for i in base ~/.pyenv/versions/miniforge3/envs/base-*; do
    ~/.pyenv/versions/miniforge3/bin/conda update --all --yes -n `basename $i`
done
~/.pyenv/versions/miniforge3/bin/conda clean --all --yes
