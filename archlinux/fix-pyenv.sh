#!/bin/bash

# Usage: sudo ./fix-pyenv.sh

set -euxo pipefail
mkdir -p /usr/share/zsh/site-functions/

cat << 'EOF' > /usr/share/zsh/site-functions/_pyenv
#compdef pyenv
if [[ ! -o interactive ]]; then
    return
fi

local state line
typeset -A opt_args

_arguments -C \
    {--help,-h}'[Show help]' \
    {--version,-v}'[Show pyenv version]' \
    '(-): :->command' \
    '*:: :->option-or-argument'

case "$state" in
    (command)
        local -a commands
        commands=(${(f)"$(pyenv commands)"})
        _describe -t commands 'command' commands
        ;;
    (option-or-argument)
        local -a args
        args=(${(f)"$(pyenv completions ${line[1]})"})
        _describe -t args 'arg' args
        ;;
esac

return
EOF

rm /home/${SUDO_USER}/.zcompdump
