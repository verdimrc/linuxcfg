# 1. Overview

The example shows:

1. how to configure VSCode to deal with Python modules located under the workspace, or potentially anywhere not in the `PYTHONPATH` environment variable.
2. other miscellaneous example settings, including extensions

# 2. Python modules under workspace

## 2.1. Directory structure

The example configuration is for the following directory structure. The custom module `my_module` is located under `src/prep`.

```text
workspaceFolder
├── .vscode
│   ├── settings.json
│   └── launch.json
├── .env
├── src
│   ├── README.md
│   ├── prep
│   │   ├── __init__.py
│   │   ├── lambda_function.py
│   │   ├── requirements.txt
│   │   └── my_module
│   │       ├── __init__.py
│   │       ├── submodule1
│   │       ├── submodule2
│   │       ├── ...
```

## 2.2. `.vscode/settings.json`

- set `python.envFile` to the sample `.vscenv` file, to allow intellisense to recognize the custom module `my_module` (to enable code completion, etc.)
- set `terminal.integrated.env.osx` to add `PYTHONPATH` when starting the integrated terminal
- Use `terminal.integrated.env.linux` or `terminal.integrated.env.windows` for Linux or Windows, respectively. See [here for further details](https://vscode.readthedocs.io/en/latest/getstarted/settings/).

## 2.3. `.vscenv`

This file contains the additional `PYTHONPATH` that intellisense uses.
