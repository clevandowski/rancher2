#!/bin/bash

if [ -z "$1" ]; then
  echo "usage: $(basename $0) <namespace>"
  exit 1
fi

kubectl -n $1 run tools -ti --image=clevandowski/container_toolkit:1.0 --generator=run-pod/v1 -- bash
