#!/bin/bash
set -euo pipefail

rm -rf .terraform \
   terraform.tfstate* \
   ssh_config* \
   terraform.tfstate* \
   rancher-cluster.* \
   inventory.yml \
   kube_config_rancher-cluster.yml \
   rancher2.plan \
   rancher_admin_password.txt
