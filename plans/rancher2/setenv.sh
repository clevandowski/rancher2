# export KUBECONFIG=$(pwd)/kube_config_rancher-cluster.yml
# export AWS_PROFILE=default
# export AWS_REGION=eu-west-3
# export RANCHER_LB_DNS=rancher2.example.com
export KUBECONFIG=$(pwd)/kube_config_rancher-cluster.yml
#export KUBECONFIG=$KUBECONFIG:$(pwd)/sandbox.yml
export AWS_PROFILE=clevandowski-ops-zenika
export AWS_REGION=eu-north-1
export RANCHER_LB_DNS=cyrille.aws.zenika.com
#export PUBLIC_IP=$(dig -4 +short myip.opendns.com @resolver1.opendns.com)

