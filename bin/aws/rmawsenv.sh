#!/bin/bash

[[ "${BASH_SOURCE[0]}" == "$0" ]] && echo "Please source the script" && exit -1

for i in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_SECURITY_TOKEN; do
    unset $i
done
