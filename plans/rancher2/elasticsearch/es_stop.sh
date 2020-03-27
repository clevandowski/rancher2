#!/bin/bash

helm del kibana --namespace default
helm del filebeat
helm del elasticsearch --namespace elasticsearch
kubectl --namespace elasticsearch delete pvc es-rancher-master-es-rancher-master-0
kubectl --namespace elasticsearch delete pvc es-rancher-master-es-rancher-master-1
kubectl --namespace elasticsearch delete pvc es-rancher-master-es-rancher-master-2
