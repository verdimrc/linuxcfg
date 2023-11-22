#!/bin/bash

CONDA_DIR=~/.pyenv/versions/miniforge3
CONDA=$CONDA_DIR/bin/conda

# Update the conda
$CONDA update --all -n base -c conda-forge conda

# updating conda environments
for i in base $CONDA_DIR/envs/base-*; do
    echo "Updating conda environments $(basename $i)..."
    $CONDA update --all --yes -n `basename $i`
done

# clean
$CONDA clean --all --yes
