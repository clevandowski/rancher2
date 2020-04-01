#!/bin/bash

set -eo pipefail

export ROOT_DNS="aws.zenika.com"
export TRAEFIK_LB_DNS="*.cyrille.aws.zenika.com"
export HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name | jq -r ".HostedZones[] | select(.Name==\"${ROOT_DNS}.\") | .Id" | sed -e 's|^.*/\([^/]*\)$|\1|')

getLoadBalancerDNS() {
  # Comme je ne sais pas encore donner un petit nom au load balancer généré par traefik
  # Je choppe le dernier qui a été créé
  aws --region $AWS_REGION elbv2 describe-load-balancers \
  | jq -r '.LoadBalancers | sort_by(.CreatedTime) | last | .DNSName'
}
getLoadBalancerHostedZoneId() {
  # Comme je ne sais pas encore donner un petit nom au load balancer généré par traefik
  # Je choppe le dernier qui a été créé
  aws --region $AWS_REGION elbv2 describe-load-balancers \
  | jq -r '.LoadBalancers | sort_by(.CreatedTime) | last | .CanonicalHostedZoneId'
}

getRecordSetConfig() {
  local hostedZoneId="$1"
  local publicTraefikLBDNS="$2"
  local internalTraefikLBDNS="$3"
  local internalTraefifLBHostedZoneId="$4"
  cat << COINCOIN
{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "${publicTraefikLBDNS}",
      "Type": "A",
      "AliasTarget": {
        "HostedZoneId": "${internalTraefifLBHostedZoneId}",
        "DNSName": "${internalTraefikLBDNS}",
        "EvaluateTargetHealth": true
      }
    }}]
}
COINCOIN
}

createAliasRecordSet() {
  local hostedZoneId="$1"
  local publicTraefikLBDNS="$2"
  local internalTraefikLBDNS="$(getLoadBalancerDNS)"
  local internalTraefifLBHostedZoneId="$(getLoadBalancerHostedZoneId)"
  local recordSetConfig="$(getRecordSetConfig "$hostedZoneId" "$publicTraefikLBDNS" "$internalTraefikLBDNS" "$internalTraefifLBHostedZoneId")"
  # echo "recordSetConfig: $recordSetConfig"
  aws route53 change-resource-record-sets --hosted-zone-id "$hostedZoneId" --change-batch "$recordSetConfig"
}

if ! kubectl get clusterrolebinding traefik-ingress-controller 2>/dev/null; then
  echo "Traefik cluster role and cluster role binding not defined"
  kubectl apply -f traefik-rbac.yaml
else
  echo "Traefik cluster role and cluster role binding already defined"
fi

if helm list --namespace default | grep traefik 2>/dev/null; then
  helm upgrade traefik stable/traefik --values values.yaml --namespace default \
    --set acme.dnsProvider.name=route53 \
    --set acme.dnsProvider.route53.AWS_ACCESS_KEY_ID=$(cat ~/.aws/credentials | grep ${AWS_PROFILE} -A 2 | grep aws_access_key_id | awk '{ print $3 }') \
    --set acme.dnsProvider.route53.AWS_SECRET_ACCESS_KEY=$(cat ~/.aws/credentials | grep ${AWS_PROFILE} -A 2 | grep aws_secret_access_key | awk '{ print $3 }') \
    --set acme.dnsProvider.route53.AWS_REGION=${AWS_REGION}
else
  helm install traefik stable/traefik --values values.yaml --namespace default \
    --set acme.dnsProvider.name=route53 \
    --set acme.dnsProvider.route53.AWS_ACCESS_KEY_ID=$(cat ~/.aws/credentials | grep ${AWS_PROFILE} -A 2 | grep aws_access_key_id | awk '{ print $3 }') \
    --set acme.dnsProvider.route53.AWS_SECRET_ACCESS_KEY=$(cat ~/.aws/credentials | grep ${AWS_PROFILE} -A 2 | grep aws_secret_access_key | awk '{ print $3 }') \
    --set acme.dnsProvider.route53.AWS_REGION=${AWS_REGION}
fi

kubectl -n default rollout status deploy/traefik

echo "Creating DNS Recordset $TRAEFIK_LB_DNS on internal traefik DNS"
createAliasRecordSet "$HOSTED_ZONE_ID" "$TRAEFIK_LB_DNS"

if ! kubectl get service kibana-kibana 2>/dev/null; then
  kubectl apply -f kibana-ingress.yml
fi
