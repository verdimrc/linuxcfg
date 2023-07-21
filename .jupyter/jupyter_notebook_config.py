# Show only modified options

#c.NotebookApp.browser = 'chromium-browser'
#c.NotebookApp.terminado_settings = { "shell_command": ["/usr/bin/env", "bash"] }
c.NotebookApp.open_browser = False
c.NotebookApp.port_retries = 0
c.KernelSpecManager.ensure_native_kernel = False

# Needs: pip install environment_kernels
c.NotebookApp.kernel_spec_manager_class = 'environment_kernels.EnvironmentKernelSpecManager'
c.EnvironmentKernelSpecManager.find_conda_envs = False
c.EnvironmentKernelSpecManager.use_conda_directly = False
c.EnvironmentKernelSpecManager.blacklist_envs = ['virtualenv_jlab']
c.EnvironmentKernelSpecManager.virtualenv_env_dirs = ['/home/verdi/.pyenv/versions']

c.FileCheckpoints.checkpoint_dir = '/tmp/.ipynb_checkpoints'
c.FileContentsManager.delete_to_trash = False
c.FileContentsManager.always_delete_dir = True
