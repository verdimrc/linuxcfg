#!/bin/bash

[[ -d $HOME/.local/pipx/venvs/pipupgrade/ ]] && rm -fr $HOME/.local/pipx/venvs/pipupgrade
pipx install pipupgrade
pipx inject pipupgrade setuptools wheel
[[ -L $HOME/.local/bin/pipupgrade ]] || ln -s $HOME/.local/pipx/venvs/pipupgrade/bin/pipupgrade $HOME/.local/bin/pipupgrade
