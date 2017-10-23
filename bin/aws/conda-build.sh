#!/bin/bash

to_build() {
    regex=$(python ~ec2-user/tobuild_awscli.py)
    verdimrc_pkgs=$(conda search --full-name --override-channels --channel verdimrc --json 'awscli|botocore' | egrep "${regex}" | grep verdimrc | sed 's/-py[2,3].*$//' | sort | uniq)
    [[ $(echo "$verdimrc_pkgs" | wc -l) != 2 ]]
}

build() {
    conda skeleton pypi --output-dir /tmp awscli botocore
    conda build /tmp/{botocore,awscli}
    conda build --python 2.7 /tmp/{botocore,awscli}
}

source ~ec2-user/miniconda3/bin/activate
rm -fr /tmp/{awscli,botocore}
rm -fr ~ec2-user/miniconda3/conda-bld/linux-64/*.tar.bz2
conda index ~ec2-user/miniconda3/conda-bld/linux-64/

to_build
if [[ $? != 0 ]]; then
    echo 'Nothing to build'
    exit 1
fi

echo 'Something to build'

build
if [[ $? != 0 ]]; then
    echo 'Failed build'
    exit 1
fi
#echo 'Build successful, but not going to upload'; exit 1

anaconda upload ~ec2-user/miniconda3/conda-bld/linux-64/*.tar.bz2
conda build purge
conda clean --all -y
source deactivate
