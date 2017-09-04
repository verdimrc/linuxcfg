#!/bin/bash

# Require long-term credentials in ~/.aws/{config,credentials}

func() {
    [[ "${BASH_SOURCE[0]}" == "$0" ]] && echo "Please source the script" && exit -1
    local BIN_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

    echo Enter MFA:
    read token_code
    local -r temporary_credentials="$(aws \
        sts assume-role \
        --role-arn="arn:aws:iam::xxxxyyyyzzzz:role/targetRole" \
        --role-session-name="testdevsession" \
        --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
        --serial-number="arn:aws:iam::xxxxyyyyzzzz:mfa/deviceId" \
        --token-code="${token_code}"
    )"
    local -ri arole_retval=$?
    [ $arole_retval -ne 0 ] && return $arole_retval

    echo Setting environment variables...
    export AWS_ACCESS_KEY_ID=$(echo "${temporary_credentials}" | jq -re '.[0]')
    export AWS_SECRET_ACCESS_KEY=$(echo "${temporary_credentials}" | jq -re '.[1]')
    export AWS_SESSION_TOKEN=$(echo "${temporary_credentials}" | jq -re '.[2]')

    # Fix for boto2 which incorrectly uses this variable.
    # See: https://github.com/hashicorp/terraform/issues/3243#issuecomment-166474336
    export AWS_SECURITY_TOKEN=$AWS_SESSION_TOKEN

    . $BIN_DIR/awsenv.sh
}

func
