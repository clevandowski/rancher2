#!/bin/bash

set -e

cd ~/plans/rancher2
remove_rancher() {
  helm del --purge rancher
}

remove_k8s_cluster() {
  rke remove --config ./rancher-cluster.yml --force
}

remove_aws_cluster() {
  terraform destroy -auto-approve
}

export KUBECONFIG=$(pwd)/kube_config_rancher-cluster.yml
remove_rancher && remove_k8s_cluster && remove_aws_cluster
