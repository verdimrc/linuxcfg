```bash
noctalia msg config-reload
pkill -x noctalia ; setsid noctalia > /dev/null 2>&1 &

noctalia msg bluetooth-toggle
```

sway-mode is a community plugin and it needs `~/.local/bin/swaymsg` (symlink-ed
to `/usr/bin/scrollmsg`).
