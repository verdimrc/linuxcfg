<https://github.com/dawsers/scroll>


Dependencies:
- <https://github.com/Vladimir-csp/uwsm>
  Reason: `scroll` relies on existing env vars, and I don't want to pollute my
  `.zshrc`.

  Also, I mix i3 (X11), lxqt (X11), and scroll (WC), hence need to keep 
  desktop-scoped env vars in systemd --user session (i.e., set env vars -> start
  desktop -> exit desktop -> clean env vars).
- `wl-copy` to screenshot to file and clipboard at the same time. On Archlinux,
   install with `sudo pacman -S wl-clipboard`.
