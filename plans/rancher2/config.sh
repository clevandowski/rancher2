#!/usr/bin/env bash

source setenv.sh

export KUBECONFIG=$(pwd)/kube_config_rancher-cluster.yml
export PUBLIC_IP=$(dig -4 +short myip.opendns.com @resolver1.opendns.com)
# La hosted zone (ex: example.com pour un DNS rancher.example.com) référencée doit exister dans AWS route 53
export HOSTED_ZONE_NAME=$(echo "$RANCHER_LB_DNS" | sed -e 's|^[^\.]\+\.\(.*\)$|\1|')
export RANCHER_LB_DNS_HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name | jq -r ".HostedZones[] | select(.Name==\"${HOSTED_ZONE_NAME}.\") | .Id")

