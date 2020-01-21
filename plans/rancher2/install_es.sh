#!/bin/bash

git clone git@github.com:elastic/helm-charts.git

helm install ./helm-charts/elasticsearch --name elasticsearch \
  --namespace elasticsearch \
  --set clusterName=es-rancher-master \
  --set imageTag=7.5.2 \
  --set esJavaOpts="-Xmx1g -Xms1g" \
  --set tolerations[0].key=node.elasticsearch.io/unschedulable \
  --set tolerations[0].operator=Exists \
  --set tolerations[0].effect=NoSchedule \
  --set volumeClaimTemplate.accessModes[0]=ReadWriteOnce \
  --set volumeClaimTemplate.resources.requests.storage=30Gi \
  --set volumeClaimTemplate.storageClassName=aws.pg2.eu-central-1a
#  --set resources="requests.cpu:100m,requests.memory:12Gi,limits.cpu:3500m,limits.memory:12Gi" \
