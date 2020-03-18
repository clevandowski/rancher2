#!/bin/bash

set -e

cd ~/plans/rancher2
export KUBECONFIG=$(pwd)/kube_config_rancher-cluster.yml
remove_rancher() {
  helm del --purge rancher
}

remove_k8s_cluster() {
  rke remove --config ./rancher-cluster.yml --force
}

remove_aws_cluster() {
  terraform destroy -auto-approve -var aws_profile="$AWS_PROFILE" -var aws_region="$AWS_REGION"
}

remove_k8s_cluster && remove_aws_cluster
