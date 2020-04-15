#!/bin/bash

set -eo pipefail

cd ~/plans/rancher2
export KUBECONFIG=$(pwd)/kube_config_rancher-cluster.yml

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

# remove_cloud_cluster() {
#   terraform destroy -auto-approve -var aws_profile="$AWS_PROFILE" -var aws_region="$AWS_REGION"
# }

remove_k8s_cluster && remove_cloud_cluster

# rm -rf .terraform \
#   terraform.tfstate* \
#   ssh_config* \
#   terraform.tfstate* \
#   rancher-cluster.* \
#   inventory.yml \
#   kube_config_rancher-cluster.yml \
#   rancher2.plan \
#   rancher_admin_password.txt
