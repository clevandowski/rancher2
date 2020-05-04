#!/bin/bash

export DIRNAME=$(dirname $0)

usage() {
  echo "usage: $(basename $0) <cluster name> <output file>"
}

if [ -n "$1" ]; then
  export CLUSTER_NAME="$1"
else
  usage
  exit 1
fi

if [ -n "$2" ]; then
  export OUTPUT_FILENAME="$2"
else
  usage
  exit 1
fi

extract_tfstate_id_rsa() {
  ID_RSA_FILE=${TF_RANCHER_ID_RSA_PUB_PATH:-~/.ssh/id_rsa}
  if [ -f terraform.tfvars ]; then
    ID_RSA_FILE=$(grep "rancher_id_rsa_pub_path" terraform.tfvars |  cut -d = -f 2 | tr -d '"' | sed 's/\.[^.]*$//' | tr -d ' ')
  fi

  export ID_RSA_FILE
}

extract_tfstate_aws_controlplane_instances_to_rke_nodes() {
 jq '.resources[] | select(.type == "aws_instance")
    | .instances[].attributes
    | select(.tags.role_controlplane == "true" and .tags.cluster == "'$CLUSTER_NAME'")
    | {
        hostname_override: .tags.Name,
        address: .private_ip,
        user: "ubuntu",
        ssh_key_path: "$ID_RSA_FILE",
        role: [
          "controlplane",
          "etcd",
          "worker"
        ]
      }' terraform.tfstate
}

extract_tfstate_aws_worker_instances_to_rke_nodes() {
  jq '.resources[] | select(.type == "aws_instance")
  | .instances[].attributes
  | select(.tags.role_worker == "true" and .tags.cluster == "'$CLUSTER_NAME'")
  | {
      hostname_override: .tags.Name,
      address: .private_ip,
      user: "ubuntu",
      ssh_key_path: "$ID_RSA_FILE",
      role: [
        "worker"
      ]
    }' terraform.tfstate
}

inject_taints_to_rke_nodes() {
  jq ". += { taints: [ { key: \"$1\", value: \"$2\", effect: \"$3\" } ] }"
}

inject_labels_to_rke_nodes() {
  jq ". += { labels: { $1: \"$2\" } }"
}

inject_rke_nodes_json() {
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

append_bastion_host() {
  jq '.resources[] | select(.type == "aws_instance")
  | .instances[].attributes
  | select(.tags.Name = "rancher2-bastion")
  | select(.public_ip != "")
  | {
      "bastion_host": {
        hostname_override: .tags.Name,
        address: .public_ip,
        user: "ec2-user",
        ssh_key_path: "$ID_RSA_FILE"
      }
    }' terraform.tfstate | envsubst | json2yaml.sh >> $OUTPUT_FILENAME
}


process_jq_template() {
  # jq "$((extract_tfstate_aws_controlplane_instances_to_rke_nodes && extract_tfstate_aws_worker_instances_to_rke_nodes) | inject_rke_nodes_json)" $DIRNAME/rke-cluster-base.json
  jq "$((extract_tfstate_aws_controlplane_instances_to_rke_nodes && extract_tfstate_aws_worker_instances_to_rke_nodes | inject_taints_to_rke_nodes "node.elasticsearch.io/unschedulable" "" "NoSchedule" | inject_labels_to_rke_nodes "elasticsearch" "reserved") | inject_rke_nodes_json)" $DIRNAME/rke-cluster-base.json
}

extract_tfstate_id_rsa
process_jq_template | envsubst | json2yaml.sh > $OUTPUT_FILENAME
append_bastion_host
echo "cluster_name: $CLUSTER_NAME" >> $OUTPUT_FILENAME
