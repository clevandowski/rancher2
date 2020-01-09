# Avec start_rancher2.sh

```
cd ~/plans/rancher2
start_rancher2.sh
```

## Conf kubectl

```
export KUBECONFIG=$(pwd)/kube_config_rancher-cluster.yml
kubectl get nodes
```

## Définition mdp rancher admin

```
kubectl --kubeconfig $KUBECONFIG -n cattle-system exec $(kubectl --kubeconfig $KUBECONFIG -n cattle-system get pods -l app=rancher | grep '1/1' | head -1 | awk '{ print $1 }') -- reset-password | tail -n 1 > rancher_admin_password.txt
cat rancher_admin_password.txt
```

## Conf Rancher2 CLI
&
### Création API Key

Rancher UI obligatoire ?

Creéz via Rancher UI une API Key (Scope "noscope")
Récupérer les 4 infos suivantes pour les mettre dans un fichier (genre .rancher-cli-noscope)
```
$ cat .rancher-cli-noscope
export RANCHER_URL=https://rancher2-nlb-****************.elb.eu-central-1.amazonaws.com/v3
export RANCHER_ACCESS_KEY=token-*****
export RANCHER_SECRET_KEY=******************************************************
export RANCHER_BEARER_TOKEN=token-*****:******************************************************
```

## Login

```
. .rancher-cli-noscope
rancher login --token $RANCHER_BEARER_TOKEN $RANCHER_URL --skip-verify
rancher server current
```

```
rancher namespaces ls --all-namespaces --format json | jq
```

```
rancher settings
```

# Création nouveau cluster

## Via IHM

* Création cloud credential

Name: aws-credential

* Création node template

IAM Instance Profile Name: "rancher2-instance-profile"
Name: basic-node-template

* Création cluster

Amazon EC2
!!! ATTENTION !!! Si le champ "Kubernetes version" est vide, faire "Tools -> Drivers -> Refresh Kubernetes Metadata" dans l'ihm rancher 2

## kubectl

Récupérer le kubeconfig dans un fichier (ex: sandbox.yml)
```
export KUBECONFIG=$KUBECONFIG:$(pwd)/sandbox.yml
kubectl config use-context sandbox-master1
kubectl get nodes
```

# Provisionning détaillé

## Provision des 3 masters

```
cd ~/plans/rancher2
terraform init
terraform validate
terraform plan -out rancher2.plan
terraform apply -auto-approve rancher2.plan
terraform show
```

Arrêt/Destruction cluster
```
terraform destroy -auto-approve
```

## Préparation Rancher2

cf https://rancher.com/docs/rke/latest/en/os/

```
inventory-template.sh
ansible-playbook playbook.yml
ansible-playbook playbook-rancher2.yml
```

## Démarrage Kubernetes via RKE

```
rancher-cluster-template.sh
rke up --config ./rancher-cluster.yml
export KUBECONFIG=$(pwd)/kube_config_rancher-cluster.yml
kubectl get nodes
```

Arrêt/Suppression cluster
```
rke remove --config ./rancher-cluster.yml --force
```

## Installation Helm

```
kubectl -n kube-system create serviceaccount tiller
kubectl create clusterrolebinding tiller \
    --clusterrole=cluster-admin \
    --serviceaccount=kube-system:tiller
helm init --service-account tiller

kubectl -n kube-system rollout status deploy/tiller-deploy
helm version
```

## Install cert-manager (pour ca interne ou letsencrypt)

```
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.9/deploy/manifests/00-crds.yaml
kubectl create namespace cert-manager
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install \
    --name cert-manager \
    --namespace cert-manager \
    --version v0.9.1 \
    jetstack/cert-manager
kubectl get pods --namespace cert-manager -w
```

## Install Rancher

```
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm install rancher-stable/rancher \
  --name rancher \
  --namespace cattle-system \
  --set hostname=$(jq -r '.resources[] | select(.type == "aws_lb") | .instances[].attributes.dns_name' terraform.tfstate)
```

## Arrêt/Suppression rancher
```
helm del --purge rancher
```

## Suppression tout

Note: suppression cluster supplémentaire par IHM pour le moment
```
helm del --purge rancher
rke remove --config ./rancher-cluster.yml --force
terraform destroy -auto-approve
```

