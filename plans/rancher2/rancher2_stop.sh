#!/bin/bash

set -eo pipefail

cd $(dirname $0)
source config.sh

. _remove_cloud_cluster.sh

remove_rancher() {
  helm del --purge rancher
}

remove_k8s_cluster() {
  if [ -f ./rancher-cluster.yml ]; then
    rke remove --config ./rancher-cluster.yml --force
  fi
  if [ -f ./dev-cluster.yml ]; then
    rke remove --config ./dev-cluster.yml --force
  fi
}

remove_k8s_cluster && remove_cloud_cluster
