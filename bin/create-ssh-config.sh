#!/usr/bin/env bash

declare -A PRIVATE_INSTANCES
declare -A SUBNETS

set -eo pipefail

mapAwsPrivateHostsToHostsIps() {
  local AWS_PRIVATE_INSTANCES=$(jq '.resources[] | select(.type == "aws_instance") | .instances[].attributes | select(.tags.Zone == "Private") | { (.tags.Name): (.private_ip) }' terraform.tfstate | grep : | tr -d '" ')
  for instance in ${AWS_PRIVATE_INSTANCES[@]}; do
    local instanceName=$(echo ${instance} | cut -d : -f 1)
    local instanceIp=$(echo ${instance} | cut -d : -f 2)
    PRIVATE_INSTANCES[$instanceName]=$instanceIp
  done
}

mapAwsSubnetCidrToHostIps() {
  local AWS_SUBNET_CIDR_BLOCKS=$(jq '.resources[] | select(.type == "aws_subnet") | .instances[].attributes | { (.tags.Name): (.cidr_block) }' terraform.tfstate | grep : | tr -d '" ')

  for nw in ${AWS_SUBNET_CIDR_BLOCKS[@]}; do
    local subnetName=$(echo ${nw} | cut -d : -f 1)
    local nwAddr=$(echo ${nw} | cut -d : -f 2)
    
    local network=(${nwAddr//\// })
    local networkIp=${network[0]}
    local cidr=${network[1]}

    local iparr=${networkIp//./ }
    local first=${networkIp%%.*}
    local last3=${networkIp#*.}
    local second=${last3%%.*}
    local last2=${last3#*.}
    local third=${last2%.*}
    local fourth=${last2#*.}

    case "$cidr" in 
    16) SUBNETS[$subnetName]="${first}.${second}.*.*"
        ;;

    24) SUBNETS[$subnetName]="${first}.${second}.${third}.*"
        # echo "${iparr[0]}.${iparr[1]).${iparr[2]}.\*"
        ;;
    
    *) echo "Not supported"
        ;;
    esac
  done
}

createSshBastionConfig() {
  if [ -f ssh_config ]; then
    cp ssh_config ssh_config.$(date +%Y%m%d%H%M%S)
  fi 

  ID_RSA_FILE=${TF_RANCHER_ID_RSA_PUB_PATH:-~/.ssh/id_rsa}
  if [ -f terraform.tfvars ]; then 
    ID_RSA_FILE=$(grep "rancher_id_rsa_pub_path" terraform.tfvars |  cut -d = -f 2 | tr -d '"' | sed 's/\.[^.]*$//')
  fi

  NAT_PUBLIC_IP=$(jq '.resources[] | select(.type == "aws_instance")
  | .instances[].attributes
  | select(.tags.Name = "rancher2-bastion")
  | select(.public_ip != "")
  | .public_ip' terraform.tfstate | tr -d '"')

  # Création de la configuration et injection dans le  ssh_config
  cat << EOF > ssh_config
Host rancher2-bastion
  Hostname ${NAT_PUBLIC_IP}
  User ec2-user
  IdentityFile ${ID_RSA_FILE}
  StrictHostKeyChecking no
EOF

  mapAwsPrivateHostsToHostsIps
  # Création de la configuration pour chacun des hosts 
  for hName in "${!PRIVATE_INSTANCES[@]}"; do
    cat << EOF >> ssh_config

Host $hName
  Hostname ${PRIVATE_INSTANCES[$hName]}
  User ubuntu
  ProxyCommand ssh -W %h:%p -F ssh_config rancher2-bastion
  StrictHostKeyChecking no
EOF
  done


  mapAwsSubnetCidrToHostIps

  # Création de la configuration pour les subnets
  for sName in "${!SUBNETS[@]}"; do
    cat << EOF >> ssh_config

# Allow to connect to any host in subnet $sName
Host ${SUBNETS[$sName]}
  User ubuntu
  ProxyCommand ssh -W %h:%p -F ssh_config rancher2-bastion
  StrictHostKeyChecking no
EOF
  done

}

createSshBastionConfig
