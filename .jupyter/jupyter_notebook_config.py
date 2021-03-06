# Show only modified options

#c.NotebookApp.browser = 'chromium-browser'
#c.NotebookApp.terminado_settings = { "shell_command": ["/usr/bin/env", "bash"] }
c.NotebookApp.open_browser = False
c.NotebookApp.port_retries = 0
c.KernelSpecManager.ensure_native_kernel = False

# Needs: pip install environment_kernels
c.NotebookApp.kernel_spec_manager_class = 'environment_kernels.EnvironmentKernelSpecManager'
c.EnvironmentKernelSpecManager.virtualenv_env_dirs = ['/home/verdi/.pyenv/versions']
