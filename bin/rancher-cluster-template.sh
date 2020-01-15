#!/bin/bash

export DIRNAME=$(dirname $0)

extract_tfstate_aws_controlplane_instances_to_rancher_cluster_nodes() {
  jq '.resources[] | select(.type == "aws_instance" and .instances[].attributes.tags.role_controlplane == "true")
  | .instances[].attributes
  | {
      address: .public_ip,
      internal_address: .private_ip,
      user: "ubuntu",
      role: [
        "controlplane",
        "etcd",
        "worker"
      ]
    }' terraform.tfstate
}

extract_tfstate_aws_worker_instances_to_rancher_cluster_nodes() {
  jq '.resources[] | select(.type == "aws_instance" and .instances[].attributes.tags.role_worker == "true")
  | .instances[].attributes
  | {
      address: .public_ip,
      internal_address: .private_ip,
      user: "ubuntu",
      role: [
        "worker"
      ]
    }' terraform.tfstate
}

format_rancher_cluster_nodes_json() {
  jq -c '.' \
  | while read line; do
    if [ "$is_first" != "false" ]; then
      is_first="false"
      echo ".nodes += [ $line ]"
    else
      echo "| .nodes += [ $line ]"
      fi
    done
}

process_jq_template() {
  jq "$((extract_tfstate_aws_controlplane_instances_to_rancher_cluster_nodes && extract_tfstate_aws_worker_instances_to_rancher_cluster_nodes) | format_rancher_cluster_nodes_json)" $DIRNAME/rancher-cluster-base.json
}

process_jq_template | json2yaml.sh > rancher-cluster.yml
