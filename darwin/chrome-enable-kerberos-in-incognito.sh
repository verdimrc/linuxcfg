#!/bin/bash

# https://chromeenterprise.google/policies/?policy=AmbientAuthenticationInPrivateModesEnabled
defaults write com.google.Chrome AmbientAuthenticationInPrivateModesEnabled -int 3
