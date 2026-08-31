
```powershell
winget install jcardama.LeopardWM
winget upgrade
winget upgrade jcardama.LeopardWM
```

Does not run yasb, though its config is included FYI only.
Reason: some yasb widgets (active window, and custom ps1 scripts which run in
the polling mode) causes MS Defender to be overly active, causing laptop to
become a rocketship, i.e., loud/max fan noise + excessive heat (can cook a
sunshine egg).

Notes on window rules:
- `window_rule` is ineffective on slack because this app autodisplays its last window size.
- outlook (classic and new): `config.toml` shows the working combo. Other combos swept and was found ineffective;
  consult Claude for a detailed explanation. TL/DR: Outlook starts a "helper" process/window whose values
  (class, exe, and/or title) differs from steady state's ones.
