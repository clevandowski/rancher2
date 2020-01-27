# Avec start_rancher2.sh

```
cd ~/plans/rancher2
start_rancher2.sh
```
Récupérer l'URL de l'IHM ainsi que le mdp du compte admin

## Conf kubectl

```
export KUBECONFIG=$(pwd)/kube_config_rancher-cluster.yml
kubectl get nodes
```

## Conf Rancher2 CLI (pas super nécessaire)

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

### Trucs à faire pour le moment via l'IHM Rancher au démarrage

* Pour débloquer la listbox de la version de kubernetes lors de la création d'un cluster (sinon champ vide puis bug à la création): 
  * Context: Cluster Global (à droite de l'icone de rancher en haut à gauche)
  * Tools > Drivers > Refresh Kubernetes Metadata

* Définir un storage class par défaut:
  * Context: Cluster local (à droite de l'icone de rancher en haut à gauche)
  * Storage > Storage Classes > Set as Default (sur le lien paramètre d'un des storage class)

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

Name: sandbox
Amazon EC2
!!! ATTENTION !!! Si le champ "Kubernetes version" est vide, faire "Tools -> Drivers -> Refresh Kubernetes Metadata" dans l'ihm rancher 2

## kubectl

Récupérer le kubeconfig dans un fichier (ex: sandbox.yml)
```
export KUBECONFIG=$KUBECONFIG:$(pwd)/sandbox.yml
kubectl config use-context sandbox-master1
kubectl get nodes
```

## Suppression tout

Note: suppression cluster supplémentaire par IHM pour le moment
```
helm del --purge rancher
rke remove --config ./rancher-cluster.yml --force
terraform destroy -auto-approve
```

