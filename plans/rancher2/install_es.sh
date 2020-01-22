#!/bin/bash

if [ ! -d "helm-charts" ]; then
  git clone git@github.com:elastic/helm-charts.git
fi

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
  --set volumeClaimTemplate.storageClassName=aws.pg2.eu-central-1 \
  --set nodeSelector.elasticsearch=reserved
#  --set resources="requests.cpu:100m,requests.memory:12Gi,limits.cpu:3500m,limits.memory:12Gi" \

helm install --name filebeat ./helm-charts/filebeat \
  --set tolerations[0].operator=Exists \
  --set tolerations[0].effect=NoSchedule \
  --set extraEnvs[0].name=ELASTICSEARCH_HOSTS \
  --set extraEnvs[0].value=es-rancher-master-master.elasticsearch.svc.cluster.local

helm install --name kibana ./helm-charts/kibana \
  --set imageTag=7.5.2 \
  --set elasticsearchHosts=http://es-rancher-master-master.elasticsearch.svc.cluster.local:9200

# kubectl -n default port-forward svc/kibana-kibana 5601