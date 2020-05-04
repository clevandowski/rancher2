export KUBECONFIG=$(pwd)/kube_config_rancher-cluster.yml:$(pwd)/kube_config_dev-cluster.yml
export PUBLIC_IP=$(dig -4 +short myip.opendns.com @resolver1.opendns.com)
