#!/bin/bash

helm del --purge traefik
# kubectl --namespace elasticsearch delete pvc es-rancher-master-es-rancher-master-0

if kubectl get ingress kibana 2>/dev/null; then
  kubectl delete -f kibana-ingress.yml
fi

if kubectl get clusterrolebinding traefik-ingress-controller 2>/dev/null; then
  kubectl delete -f traefik-rbac.yaml
fi