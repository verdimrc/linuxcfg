#!/bin/bash

role_arn=$1
parent_profile=$2
arn_array=(${role_arn//:/ })
account_id=${arn_array[3]}
profile_path=${arn_array[4]}
profile_name="ephemeral-${account_id}-${profile_path}-`date +%Y%m%d%H%M%S`"

session_name="${USER}-`hostname`-`date +%Y%m%d`"
if [ -n "$parent_profile" ]; then
    profile_argument="--profile $parent_profile"
fi
sts=( $(
    aws sts assume-role \
    ${profile_argument} \
    --role-arn "$role_arn" \
    --role-session-name "$session_name" \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
    --output text
) )
