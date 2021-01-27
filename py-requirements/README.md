Sample `requirements*.txt` files for frequently-used packages.

`environment_kernels` allows Jupyter to autoscan virtual envs that have
`ipython`.

However, to actually run the kernel, the venv must have `ipykernel` installed,
otherwise jlab log will say `cannot find ipykernel module` or something like
that.

In addition, vscode also requires the venv to have `ipykernel`.

Thus, in summary:

- venv must have `ipython` to be discoverable by jupyter + `environment_kernels`.
- venv must have `ipykernel` to be usable by vscode and jupyter.
