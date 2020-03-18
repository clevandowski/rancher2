#!/bin/bash

set -euo pipefail

source config.sh

if [ -z "$AWS_PROFILE" ] || [ -z "$AWS_REGION" ]; then
  echo "Required environment variables:"
  echo "* AWS_PROFILE"
  echo "* AWS_REGION"
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
      -out ml.plan
  else
    return 1
  fi

  if terraform apply -auto-approve ml.plan; then
    terraform show
  else
    echo "Error in terraform apply"
    return 1
  fi
}

# Préparation Rancher2
# bootstrap_ec2_instances() {
#   inventory-template.sh && create-ssh-config.sh
#   ansible-playbook bootstrap-ec2.yml
# }

# Main
provision_cloud_cluster
# && bootstrap_ec2_instances \
# && provision_rke_cluster \
# && install_rancher2
