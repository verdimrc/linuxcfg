#!/bin/bash

set -e
sudo -u ec2-user mkdir -p ~ec2-user/.jupyter/custom/
cat << EOF > ~ec2-user/.jupyter/custom/custom.css
#ipython-main-app {
    position: relative;
}
#jupyter-main-app {
    position: relative;
}

.CodeMirror-lines {
  padding: 0.1em 0;
}

.CodeMirror pre {
    font-size: 7.5pt;
    font-family: Monaco;
}

.output_text pre {
    font-size: 7.5pt;
    font-family: Monaco;
}

.input_prompt {
  font-size: 7.5pt;
  font-family: Monaco;
}

.output_prompt {
  font-size: 7.5pt;
  font-family: Monaco;
  border-top: 4.9px solid transparent;
}
EOF

chown -R ec2-user:ec2-user ~ec2-user/.jupyter/custom
