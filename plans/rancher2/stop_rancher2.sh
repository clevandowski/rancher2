#!/bin/bash

set -e

cd ~/plans/rancher2

helm del --purge rancher
rke remove --config ./rancher-cluster.yml --force
terraform destroy -auto-approve
