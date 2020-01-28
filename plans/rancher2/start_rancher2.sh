#!/bin/bash

set -e

if [ -z "$AWS_PROFILE" ] || [ -z "$AWS_REGION" ]; then
  echo "Required environment variables:"
  echo "* AWS_PROFILE"
  echo "* AWS_REGION"
  echo "Aborting"
  exit 1
fi

cd ~/plans/rancher2
export PUBLIC_IP=$(dig -4 +short myip.opendns.com @resolver1.opendns.com)
export KUBECONFIG=$(pwd)/kube_config_rancher-cluster.yml

create_default_storageclass_on_current_aws_region() {
  kubectl --kubeconfig $KUBECONFIG apply -f - <<COINCOIN
    kind: StorageClass
    apiVersion: storage.k8s.io/v1
    metadata:
      name: aws.pg2.default
    provisioner: kubernetes.io/aws-ebs
    parameters:
      type: gp2
      zones: "${AWS_REGION}a, ${AWS_REGION}b, ${AWS_REGION}c"
    reclaimPolicy: Retain
    allowVolumeExpansion: true
    mountOptions:
      - debug
    volumeBindingMode: Immediate
COINCOIN
}

start_cloud_cluster() {
  # Provision cluster VM sur cloud
  terraform init
  terraform validate
  terraform plan -var aws_profile="$AWS_PROFILE" -var aws_region="$AWS_REGION" -var authorized_ip="$PUBLIC_IP/32" -out rancher2.plan
  terraform apply -auto-approve rancher2.plan
  terraform show
  # Préparation Rancher2
  inventory-template.sh
  ansible-playbook -v playbook.yml
  ansible-playbook -v playbook-rancher2.yml
}

# https://rancher.com/docs/rancher/v2.x/en/installation/ha/

# Démarrage Kubernetes via RKE
start_k8s_cluster() {
  rancher-cluster-template.sh
  rke up --config ./rancher-cluster.yml
  kubectl get nodes

  # Installation Helm
  kubectl -n kube-system create serviceaccount tiller
  kubectl create clusterrolebinding tiller \
      --clusterrole=cluster-admin \
      --serviceaccount=kube-system:tiller
  helm init --service-account tiller
  kubectl -n kube-system rollout status deploy/tiller-deploy
  helm version

  # Install cert-manager
  # https://rancher.com/docs/rancher/v2.x/en/installation/ha/helm-rancher/#optional-install-cert-manager
  kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.12/deploy/manifests/00-crds.yaml
  kubectl create namespace cert-manager
  # kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true
  helm repo add jetstack https://charts.jetstack.io
  helm repo update
  # helm install \
  #     --name cert-manager \
  #     --namespace cert-manager \
  #     --version v0.9.1 \
  #     jetstack/cert-manager
  helm install \
    --name cert-manager \
    --namespace cert-manager \
    --version v0.12.0 \
    jetstack/cert-manager

  kubectl -n cert-manager rollout status deploy/cert-manager
  kubectl -n cert-manager rollout status deploy/cert-manager-cainjector
  kubectl -n cert-manager rollout status deploy/cert-manager-webhook
  kubectl get pods --namespace cert-manager

  # Install Rancher
  helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
  helm install rancher-stable/rancher \
    --name rancher \
    --namespace cattle-system \
    --set hostname=$(jq -r '.resources[] | select(.type == "aws_lb") | .instances[].attributes.dns_name' terraform.tfstate)
    # --set hostname=cyrille.aws.zenika.com
  kubectl -n cattle-system rollout status deploy/rancher

  # Génération password admin dans rancher_admin_password.txt
  kubectl -n cattle-system exec $(kubectl -n cattle-system get pods -l app=rancher | grep '1/1' | head -1 | awk '{ print $1 }') -- reset-password | tail -n 1 > rancher_admin_password.txt
  cat rancher_admin_password.txt

  # Ajout storage-class pour activer l'EBS
  create_default_storageclass_on_current_aws_region
}

start_cloud_cluster && start_k8s_cluster
