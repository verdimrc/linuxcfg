# https://jupyter-server.readthedocs.io/en/stable/operators/migrate-from-nbserver.html

#c.ServerApp.browser = 'chromium-browser'
#c.ServerApp.terminado_settings = { "shell_command": ["/usr/bin/env", "bash"] }
c.ServerApp.open_browser = False
c.ServerApp.port_retries = 0
c.KernelSpecManager.ensure_native_kernel = False
c.LabServerApp.notebook_starts_kernel = False

try:
    import environment_kernels
except:
    pass
else:
    # Needs: pip install environment_kernels (within the jlab env)
    c.ServerApp.kernel_spec_manager_class = 'environment_kernels.EnvironmentKernelSpecManager'
    c.EnvironmentKernelSpecManager.find_conda_envs = False   # Change to True as needed
    c.EnvironmentKernelSpecManager.use_conda_directly = False
    c.EnvironmentKernelSpecManager.blacklist_envs = ['virtualenv_jlab']
    import os.path
    c.EnvironmentKernelSpecManager.virtualenv_env_dirs = [os.path.expanduser('~/.pyenv/versions')]
    c.EnvironmentKernelSpecManager.conda_env_dirs = [os.path.expanduser('~/.pyenv/versions/miniforge3-latest/envs')]

c.FileCheckpoints.checkpoint_dir = '/tmp/.ipynb_checkpoints'
c.FileContentsManager.delete_to_trash = False
c.FileContentsManager.always_delete_dir = True
