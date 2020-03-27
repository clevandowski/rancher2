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

provision_cloud_cluster() {
  # Provision cluster VM sur cloud
  terraform init
  if terraform validate; then
    terraform plan \
      -var aws_profile="$AWS_PROFILE" \
      -var aws_region="$AWS_REGION" \
      -var authorized_ip="$PUBLIC_IP/32" \
      -var rancher_lb_dns="$RANCHER_LB_DNS" \
      -var rancher_hosted_zone_id="$RANCHER_LB_DNS_HOSTED_ZONE_ID" \
      -out rancher2.plan
  else
    return 1
  fi

  if terraform apply -auto-approve rancher2.plan; then
    terraform show
  else
    echo "Error in terraform apply"
    return 1
  fi
}

# Préparation Rancher2
bootstrap_ec2_instances() {
  inventory-template.sh && create-ssh-config.sh
  ansible-playbook bootstrap-ec2.yml
}

# Create kubernetes cluster via RKE
provision_rke_cluster() {
  rancher-cluster-template.sh
  rke up --config ./rancher-cluster.yml
}

# Install rancher2 over RKE.
install_rancher2() {
  ansible-playbook -e rancher_lb_dns=$RANCHER_LB_DNS -e aws_region=$AWS_REGION install-rancher2.yml
}

# Main
provision_cloud_cluster \
&& bootstrap_ec2_instances \
&& provision_rke_cluster \
&& install_rancher2 \

if [ -f custom_bastion_provisionning.sh ]; then
  ./custom_bastion_provisionning.sh
fi
