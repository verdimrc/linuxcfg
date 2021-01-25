Example of system-wide vs per-project installations of dev toolkits. This is
specific for OSX. The purpose is to not replicate common CLI toolkits across
per-projet venvs.

General ideas:

1. install whatever CLI available from `homebrew`.
2. install some CLI with `pipx`.
3. install jupyterlab + its extensions to `basedev` venv.
4. install per-project CLIs and libraries to per-project venv.

CLIs in number 1-3 are available globally, and number 4 are on per-project
basis. Of course, the "shared" CLI can be further installed to per-project
venvs too, should specific version is required.
