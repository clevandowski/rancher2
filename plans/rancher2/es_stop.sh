#!/bin/bash

helm del --purge kibana
helm del --purge filebeat
helm del --purge elasticsearch
kubectl --namespace elasticsearch delete pvc es-rancher-master-master-es-rancher-master-master-0
kubectl --namespace elasticsearch delete pvc es-rancher-master-master-es-rancher-master-master-1
kubectl --namespace elasticsearch delete pvc es-rancher-master-master-es-rancher-master-master-2
