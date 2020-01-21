# Création api-key

Accès Rancher IHM en admin
Aller dans les options du user (logo en haut à droite)
> Menu "API & Keys" > Add Key (Description: admin, Automatically Expire: never, scope: noscope)
> Sauvez l'endpoint rancher api & les credentials (access key, secret key, bearer token)

# Connexion rancher2 CLI

```
~/plans/rancher2$ ./init_rancher_api_client_conf.sh
Please complete credential parameters in ~/.rancher/credential
~/plans/rancher2$ vi ./init_rancher_api_client_conf.sh
```

Remplir les champs en fonction des paramètres récupéré dans l'IHM de Rancher lors paragraphe précédent
```
export RANCHER_ADMIN_CLUSTER_MASTER_API_URL=<endpoint rancher api>
export RANCHER_ADMIN_CLUSTER_MASTER_ACCESS_KEY=<access key>
export RANCHER_ADMIN_CLUSTER_MASTER_SECRET_KEY=<secret key>
export RANCHER_ADMIN_CLUSTER_MASTER_BEARER_TOKEN=<bearer token>
```

Sourcer les credentials
```
~/plans/rancher2$ . ~/.rancher/credential
```

Se logguer
```
cyrille@34b0db091a17:~/plans/rancher2$ rancher login --token $RANCHER_ADMIN_CLUSTER_MASTER_BEARER_TOKEN $RANCHER_ADMIN_CLUSTER_MASTER_API_URL
The authenticity of server 'https://rancher2-nlb-55edde05676eedba.elb.eu-central-1.amazonaws.com' can't be established.
Cert chain is : [Certificate:
...
Do you want to continue connecting (yes/no)? yes
INFO[0003] Saving config to /home/cyrille/.rancher/cli2.json
```

Test
```
$ rancher clusters ls
CURRENT   ID        STATE     NAME      PROVIDER   NODES     CPU       RAM             PODS
*         local     active    local     Imported   6         1.73/24   0.17/90.68 GB   31/660
```

