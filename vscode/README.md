# Overview <!-- omit in toc -->

The example shows:

1. how to configure VSCode to deal with Python modules located under the workspace, or potentially anywhere not in the `PYTHONPATH` environment variable.
2. other miscellaneous example settings, including extensions

## 1. Python modules under workspace

### 1.1. Directory structure

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

### 1.2. `.vscode/settings.json`

Set `terminal.integrated.env.{osx,linux,windows}` to add `PYTHONPATH` when starting the integrated terminal

### 1.3. `.env`

This file contains the additional `PYTHONPATH` that intellisense uses.
