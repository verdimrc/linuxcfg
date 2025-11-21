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

# Retain layout, but do not reopen files, terminals, consoles.
def __haha():
    '''Use an unlikely function name.

    ---
    # YAML fragment of elements to drop
    data:
      file-browser-filebrowser:openState    # ALL GONE
      layout-restorer:data
        main              # ALL GONE
      docmanager:recents  # ALL GONE
      console:asdf        # ALL GONE
      editor:asdf         # ALL GONE
      notebook:asdf       # ALL GONE
      terminal:asdf       # ALL GONE
    ---
    '''
    import glob
    import os

    def update_workspace(fname):
        import json

        with open(fname, 'r') as f:
            d = json.load(f)

        try: del d['data']['layout-restorer:data']['main']
        except Exception as e: print(e)

        for k in list(d['data'].keys()):
            if (k.startswith('docmanager:recents')
                or k.startswith('console:')
                or k.startswith('editor:')
                or k.startswith('notebook:')
                or k.startswith('terminal:')
                or k.startswith('file-browser-filebrowser:openState')
            ):
                try: del d['data'][k]
                except Exception as e: print(e)

        with open(fname, 'w') as f:
            json.dump(d, f)

    # Scan hardcoded path because c.LabApp.workspace_dir = LazyConfigXxx('')
    workspaces = glob.glob(os.path.expanduser('~/.jupyter/lab/workspaces/default-*.jupyterlab-workspace'))
    for fname in workspaces:
        update_workspace(fname)

__haha()
del __haha


###############################################################################
# Disabling workspace: other approaches tried
###############################################################################
# Official way is ineffective. Terminals still reopen.
#c.ServerApp.default_url = '/lab?reset'

# This nukes everything, but I still like to retain some layout
# https://github.com/jupyterlab/jupyterlab/issues/7330#issuecomment-2540017454
#import tempfile
#c.LabApp.workspaces_dir = tempfile.mkdtemp()
###############################################################################
