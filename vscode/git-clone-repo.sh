#!/bin/bash

#mkdir -p ~/src
#cd ~/src
[[ "$(pwd)" == "$HOME/src" ]] || { echo "Wrong dir; pwd must be ~/src" ; exit -1 ; }

[[ -d Megatron-LM ]] || git clone https://github.com/NVIDIA/Megatron-LM
[[ -d Megatron-Bridge ]] || git clone https://github.com/NVIDIA-NeMo/Megatron-Bridge.git
[[ -d TransformerEngine ]] || git clone https://github.com/NVIDIA/TransformerEngine.git
[[ -d playground-nemo-2.0 ]] || git clone ssh://xxx/playground-nemo-2.0.git

[[ -e mbr.code-workspace ]] || \
cat << 'EOF' > mbr.code-workspace
{
  "folders": [
    {
      "name": "playground-nemo-2.0",
      "path": "playground-nemo-2.0"
    },
    {
      "name": "Megatron-Bridge",
      "path": "Megatron-Bridge"
    },
    {
      "name": "Megatron-LM",
      "path": "Megatron-LM"
    },
    {
      "name": "TransformerEngine",
      "path": "TransformerEngine"
    }
  ],
  "settings": {
    //"python-envs.defaultEnvManager": "ms-python.python:system",
    //"python-envs.pythonProjects": [],
    "python.envFile": "${workspaceFolder:playground-nemo-2.0}/.env",
    "terminal.integrated.env.linux": {
      "PYTHONPATH": "${workspaceFolder:Megatron-Bridge}/src:${workspaceFolder:Megatron-LM}:${workspaceFolder:TransformerEngine}:${env:PYTHONPATH}"
    }
  }
}
EOF

cat << EOF > playground-nemo-2.0/.env
PYTHONPATH=$HOME/src/Megatron-Bridge/src:$HOME/src/Megatron-LM:$HOME/src/TransformerEngine:\$PYTHONPATH
export PYTHONPATH
EOF
