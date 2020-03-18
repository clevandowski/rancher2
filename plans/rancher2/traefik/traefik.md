# Créer les cluster role / binding

```
kubectl apply -f traefik-rbac.yaml
```

# Démarrer

```
./traefik_start.sh
```
Vérifier les logs que traefik est bien démarré

# Associer \*.cyrille.aws.zenika.com au LB créé par le ingress controller traefik via IHM AWS

# Dans le security group "rancher2-sg", autoriser les ingress pour les ports associés au 80/443 (voir service traefik ou lb de traefik dans aws) au security group (sg-) du lb de traefik dans aws
