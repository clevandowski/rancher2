#!/usr/bin/env bash

set -euo pipefail

cd ~/plans/rancher2

source config.sh

if [ -z "$AWS_PROFILE" ] || [ -z "$AWS_REGION" ] || [ -z "$RANCHER_LB_DNS" ]; then
  echo "Required environment variables:"
  echo "* AWS_PROFILE"
  echo "* AWS_REGION"
  echo "* RANCHER_LB_DNS"
  echo "Aborting"
  exit 1
fi

. _provision_cloud_cluster.sh

# Préparation Rancher2
bootstrap_ec2_instances() {
  ./inventory-template.sh && create-ssh-config.sh
  ansible-playbook bootstrap-ec2.yml
}

# Create kubernetes cluster via RKE
provision_rke_cluster() {
  ./rke-rancher-cluster-template.sh rancher2 rancher-cluster.yml
  rke up --config ./rancher-cluster.yml

  ./rke-dev-cluster-template.sh dev dev-cluster.yml
  rke up --config ./dev-cluster.yml
}

# Install rancher2 over RKE.
install_rancher2() {
  ansible-playbook -e rancher_lb_dns=$RANCHER_LB_DNS -e aws_region=$AWS_REGION install-rancher2.yml
}

# Main
if ! provision_cloud_cluster \
    && bootstrap_ec2_instances \
    && provision_rke_cluster \
    && install_rancher2; then
  echo "[ERROR] Installation failed"
fi

if [ -f custom_bastion_provisionning.sh ]; then
  ./custom_bastion_provisionning.sh
fi
