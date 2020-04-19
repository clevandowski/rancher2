#!/usr/bin/env bash

set -euo pipefail

cd $(dirname $0)
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
  ansible-playbook -e rancher_lb_dns=$RANCHER_LB_DNS -e aws_region=$AWS_REGION customize_bastion.yml
}

# Main
if ! (provision_cloud_cluster \
    && bootstrap_ec2_instances \
    && provision_rke_cluster \
    && install_rancher2); then
  echo "[ERROR] Installation failed"
  exit 1
fi

# if [ -f custom_bastion_provisionning.sh ]; then
#   ./custom_bastion_provisionning.sh
# fi
ssh -F ssh_config rancher2-bastion "~/.local/bin/kubectl -n cattle-system exec \$(~/.local/bin/kubectl -n cattle-system get pods -l app=rancher | grep '1/1' | head -1 | awk '{ print \$1 }') -- reset-password | tail -n 1 > rancher_admin_password.txt"
ssh -F ssh_config rancher2-bastion 'cat rancher_admin_password.txt'

echo "Connect to bastion:"
echo "  ssh -F ssh_config rancher2-bastion"
