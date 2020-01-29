export KUBECONFIG=$(pwd)/kube_config_rancher-cluster.yml
export KUBECONFIG=$KUBECONFIG:$(pwd)/sandbox.yml
export AWS_PROFILE=clevandowski-ops-zenika
export AWS_REGION=eu-north-1
export RANCHER_LB_DNS=cyrille.aws.zenika.com
