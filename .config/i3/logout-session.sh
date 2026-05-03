#!/bin/bash

if [[ "$XDG_SESSION_DESKTOP" == "i3" ]]; then
    i3-nagbar -t warning -m 'You pressed the exit shortcut. Do you really want to end your X session?' -B 'Yes, exit' 'i3-msg exit' --font 'pango:Ubuntu 28'
elif [[ "$XDG_SESSION_DESKTOP" == "LXQt" ]]; then
    lxqt-leave --logout
fi
