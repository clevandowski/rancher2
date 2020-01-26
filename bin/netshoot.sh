#!/bin/sh

# https://github.com/nicolaka/netshoot
usage() {
  echo "usage: $(basename $0) <namespace>"
}

if [ -z "$1" ]; then
  usage
  exit 1
fi

kubectl -n $1 run --generator=run-pod/v1 tmp-shell --rm -i --tty --image nicolaka/netshoot -- /bin/bash

