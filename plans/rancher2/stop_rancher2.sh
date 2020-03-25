#!/bin/bash

set -e

cd ~/plans/rancher2
export KUBECONFIG=$(pwd)/kube_config_rancher-cluster.yml
remove_rancher() {
  helm del --purge rancher
}

remove_k8s_cluster() {
  if [ -f ./rancher-cluster.yml ]; then
    rke remove --config ./rancher-cluster.yml --force
  fi
}

remove_aws_cluster() {
  terraform destroy -auto-approve -var aws_profile="$AWS_PROFILE" -var aws_region="$AWS_REGION"
}

remove_k8s_cluster && remove_aws_cluster

# rm -rf .terraform \
#   terraform.tfstate* \
#   ssh_config* \
#   terraform.tfstate* \
#   rancher-cluster.* \
#   inventory.yml \
#   kube_config_rancher-cluster.yml \
#   rancher2.plan \
#   rancher_admin_password.txt
