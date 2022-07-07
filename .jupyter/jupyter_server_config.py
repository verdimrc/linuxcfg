# https://jupyter-server.readthedocs.io/en/stable/operators/migrate-from-nbserver.html

#c.ServerApp.browser = 'chromium-browser'
#c.ServerApp.terminado_settings = { "shell_command": ["/usr/bin/env", "bash"] }
c.ServerApp.open_browser = False
c.ServerApp.port_retries = 0
c.KernelSpecManager.ensure_native_kernel = False

# Needs: pip install environment_kernels
c.ServerApp.kernel_spec_manager_class = 'environment_kernels.EnvironmentKernelSpecManager'
c.EnvironmentKernelSpecManager.find_conda_envs = False
c.EnvironmentKernelSpecManager.virtualenv_env_dirs = ['/home/verdi/.pyenv/versions']

c.FileCheckpoints.checkpoint_dir = '/tmp/.ipynb_checkpoints'
c.FileContentsManager.delete_to_trash = False
