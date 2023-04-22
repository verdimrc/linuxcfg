#!/bin/bash

USER_NAME="Verdi March"
USER_EMAIL="default@email.haha.com"

case "$1" in
  vm)
    USER_EMAIL="verdimrc@noreply.users.github.com"
    ;;

  mv)
    ;;

  "")
    ;;

  *)
    echo "Unknown profile"
    exit -1
    ;;
esac

set -ex
git config user.name $USER_NAME
git config user.email $USER_EMAIL
