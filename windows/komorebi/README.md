Steps:
- Install komorebi: <https://lgug2z.github.io/komorebi/installation.html>
- Install whkd from its own GitHub repo
- Install yasb from its own GitHub repo (optionally, yasb-gui)
  * On the install wizard, choose to generate sample configs => `C:\Users\username\.config\yasb\{config.yaml,styles.css}` 
- Generate configs: `komorebic quickstart`
- Use the modified config files. Place them under `C:\Users\username\`.
- Powershell: `komorebic start --whkd` and `komorebic stop --whkd`
- Start `yasb` application
