#!/usr/bin/env bash

EXT_LIST=extensions.list
EVAL_CMD=1

# Parse args
while [[ $# -gt 0 ]]; do
    key="$1"
    case ${key} in
    -i|--input)
        EXT_LIST="$2"
        shift 2
        ;;
    -v|--verbose)
        VERBOSE=1
        shift
        ;;
    -h|--help)
        echo "Usage: ${BASH_SOURCE[0]} [-i|--input EXT_LIST] [-d|--dry-run] [-v|--verbose] [-h| --help]"
        exit 0
        ;;
    -d|--dry-run)
        VERBOSE=1
        EVAL_CMD=0
        shift
        ;;
    *)
        echo "Unknown arg: ${key}"
        exit 1
        ;;
    esac
done

while read line
do
    [[ ${line} =~ ^# ]] && continue
    cmd="code --install-extension ${line}"
    [[ ${VERBOSE} == 1 ]] && echo ${cmd}
    [[ ${EVAL_CMD} == 1 ]] && eval ${cmd}
done < ${EXT_LIST}
