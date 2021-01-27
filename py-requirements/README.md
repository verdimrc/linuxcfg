Sample `requirements*.txt` files for frequently-used packages.

`environment_kernels` allows Jupyter to autoscan virtual envs that have
`ipython`. This removes the need for the virtual envs to have `ipykernel`.

However, vscode needs the virtual envs to have `ipykernel`.

Thus, in summary:

- venv must have `ipython` to be discoverable by jupyter + `environment_kernels`.
- venv must have `ipykernel` to be usable by vscode.
