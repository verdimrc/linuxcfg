#!/bin/bash

: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${DESKTOP_SESSION:=lxqt}"

cd $XDG_CONFIG_HOME

if [[ -L chromium-flags.conf ]] || [[ -e chromium-flags.conf ]]; then
    TARGET=$(realpath --relative-to=. chromium-flags-${DESKTOP_SESSION}.conf)
    SYMLINK=$(realpath --relative-to=. chromium-flags.conf)
    [[ "${SYMLINK}" == "${TARGET}" ]] && exit || rm chromium-flags.conf
fi

ln -s chromium-flags-${DESKTOP_SESSION}.conf chromium-flags.conf
