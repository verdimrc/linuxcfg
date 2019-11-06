# Overview

The example shows how to configure VSCode to deal with Python modules located under the workspace, or potentially anywhere not in the `PYTHONPATH` environment variable.

# Directory structure

The example configuration is for the following directory structure. The custom module `my_module` is located under`workspaceFolder/01-lambdas/prep`.


```
workspaceFolder
├── .vscode
│   ├── settings.json
│   └── launch.json
├── .env
├── 01-lambdas
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

# `.vscode/settings.json`

- set `python.envFile` to add custom module `my_module` to the code intellisense (to enable code completion, etc.)
- set `terminal.integrated.env.osx` to add the `my_module` location to the integrated terminal's `PYTHONPATH`.

# `.env`

- It's important to end the `PYTHONPATH` line with a `:` even it specifies only one path.
- Must use absolute path names
