#!/bin/bash

if [ -d "helm-charts" ]; then
  git -C helm-charts pull
else
  git clone https://github.com/elastic/helm-charts.git
fi

if ! kubectl get namespace elasticsearch; then
  kubectl create namespace elasticsearch
fi

# Depuis helm 3 je ne sais pas comment mettre les valeurs cpu à null pour que ES utilise tous ceux de la VM qque soit le nombre de CPU
helm --debug install elasticsearch ./helm-charts/elasticsearch \
  --namespace elasticsearch \
  --set clusterName=es-rancher \
  --set resources.requests.cpu=3 \
  --set resources.limits.cpu=3 \
  --set resources.requests.memory=12Gi \
  --set resources.limits.memory=12Gi \
  --set esJavaOpts="-Xmx6g -Xms6g" \
  --set tolerations[0].key=node.elasticsearch.io/unschedulable \
  --set tolerations[0].operator=Exists \
  --set tolerations[0].effect=NoSchedule \
  --set volumeClaimTemplate.accessModes[0]=ReadWriteOnce \
  --set volumeClaimTemplate.resources.requests.storage=30Gi \
  --set volumeClaimTemplate.storageClassName=aws.pg2.default \
  --set nodeSelector.elasticsearch=reserved \
  --set service.type=LoadBalancer \
  --set service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-internal"=\"true\" \
  --set service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-backend-protocol"=http
# --set imageTag=7.5.2 \

helm install filebeat ./helm-charts/filebeat \
  --set tolerations[0].operator=Exists \
  --set tolerations[0].effect=NoSchedule \
  --set extraEnvs[0].name=ELASTICSEARCH_HOSTS \
  --set extraEnvs[0].value=es-rancher-master.elasticsearch.svc.cluster.local
# --set imageTag=7.5.2 \

helm install kibana ./helm-charts/kibana \
  --set elasticsearchHosts=http://es-rancher-master.elasticsearch.svc.cluster.local:9200 \
  --namespace default
# --set imageTag=7.5.2 \

echo "Start following command to access kibana at http://localhost:5601"
echo "kubectl -n default port-forward svc/kibana-kibana 5601"
