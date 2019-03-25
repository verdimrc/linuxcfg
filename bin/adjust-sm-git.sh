#!/bin/bash

echo On your SageMaker notebook, store this file under ~/Sagemaker and set as executable.
echo Remember to change the name and email.

USER_NAME='Firstname Lastname'
USER_EMAIL='first.last@email.com'

echo Adjusting contact to $USER_NAME / $USER_EMAIL
git config --global user.name "$USER_NAME"
git config --global user.email $USER_EMAIL
echo You may need to run:
echo '    ' git commit --amend --reset-author

echo Adjusting log aliases...
git config --global alias.lol "log --graph --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(bold white)— %an%C(reset)%C(bold yellow)%d%C(reset)' --abbrev-commit --date=relative"
git config --global alias.lola "log --graph --all --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(bold white)— %an%C(reset)%C(bold yellow)%d%C(reset)' --abbrev-commit --date=relative"
