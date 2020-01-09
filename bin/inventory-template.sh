#!/bin/bash

export DIRNAME=$(dirname $0)

extract_tfstate_aws_instances_to_ansible_inventory_hosts() {
  jq '.resources[] | select(.type == "aws_instance")
  | .instances[].attributes
  | {
      (.tags.Name): { 
        id: .id,
        ansible_host: .public_ip,
        public_dns: .public_dns,
        private_dns: .private_dns,
        private_ip: .private_ip,
        tags: .tags
      }
    }' terraform.tfstate
}

format_ansible_inventory_hosts_json() {
  jq -c '.' \
  | while read line; do
    if [ "$is_first" != "false" ]; then
      is_first="false"
      echo ".all.hosts += $line"
    else
      echo "| .all.hosts += $line"
      fi
    done
}

# inventory-base.json:
# {
#   "all": {
#     "vars": {
#       "ansible_connection": "ssh",
#       "ansible_ssh_user": "ubuntu",
#       "ansible_port": 22
#     },
#     "hosts": {}
#   }
# }
process_jq_template() {
  jq "$(extract_tfstate_aws_instances_to_ansible_inventory_hosts | format_ansible_inventory_hosts_json)" $DIRNAME/inventory-base.json
}

process_jq_template | json2yaml.sh > inventory.yml
