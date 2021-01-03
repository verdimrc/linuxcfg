Steps:

1. Install [themes](https://github.com/dexpota/kitty-themes)
2. Linux:
   - Install [Hack](https://github.com/source-foundry/Hack) font
3. For OSX, edit `kitty.conf`:
   - Install [Monego](https://github.com/cseelus/monego) font
   - Disable Lubuntu stanza
   - Enable OSX stanza

Additional setups:

1. Fix `sudo` behavior -- see [this](https://sw.kovidgoyal.net/kitty/faq.html#keys-such-as-arrow-keys-backspace-delete-home-end-etc-do-not-work-when-using-su-or-sudo)

   ```bash
   sudo visudo

   # Add this line:
   Defaults env_keep += "TERM TERMINFO"
   ```

   or straight away add the line to `/etc/sudoers`:

   ```bash
   echo 'Defaults env_keep += "TERM TERMINFO"' | sudo tee -a /etc/sudoers
   ```

2. When [ssh to a remote host](https://sw.kovidgoyal.net/kitty/faq.html#i-get-errors-about-the-terminal-being-unknown-or-opening-the-terminal-failing-when-sshing-into-a-different-computer):
   - make sure the remote has the `xterm-kitty` termcap installed, or
   - connect as `kitty +kitten ssh myserver`
