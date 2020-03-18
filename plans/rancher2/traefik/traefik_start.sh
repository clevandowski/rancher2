#!/bin/bash

if ! kubectl get clusterrolebinding traefik-ingress-controller 2>/dev/null; then
  echo "Traefik cluster role and cluster role binding not defined"
  kubectl apply -f traefik-rbac.yaml
else
  echo "Traefik cluster role and cluster role binding already defined"
fi

if helm list traefik | grep traefik 2>/dev/null; then
  helm upgrade traefik stable/traefik --values values.yaml --namespace default \
    --set acme.dnsProvider.name=route53 \
    --set acme.dnsProvider.route53.AWS_ACCESS_KEY_ID=$(cat ~/.aws/credentials | grep ${AWS_PROFILE} -A 2 | grep aws_access_key_id | awk '{ print $3 }') \
    --set acme.dnsProvider.route53.AWS_SECRET_ACCESS_KEY=$(cat ~/.aws/credentials | grep ${AWS_PROFILE} -A 2 | grep aws_secret_access_key | awk '{ print $3 }') \
    --set acme.dnsProvider.route53.AWS_REGION=${AWS_REGION}
else
  helm install stable/traefik --values values.yaml --name traefik --namespace default \
    --set acme.dnsProvider.name=route53 \
    --set acme.dnsProvider.route53.AWS_ACCESS_KEY_ID=$(cat ~/.aws/credentials | grep ${AWS_PROFILE} -A 2 | grep aws_access_key_id | awk '{ print $3 }') \
    --set acme.dnsProvider.route53.AWS_SECRET_ACCESS_KEY=$(cat ~/.aws/credentials | grep ${AWS_PROFILE} -A 2 | grep aws_secret_access_key | awk '{ print $3 }') \
    --set acme.dnsProvider.route53.AWS_REGION=${AWS_REGION}
fi

if kubectl get service kibana-kibana 2>/dev/null; then
  kubectl apply -f kibana-ingress.yml
fi