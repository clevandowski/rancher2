```
kubectl get nodes | tail +2 | grep -v controlplane | awk '{ print $1 }' | while read elastic_node; do kubectl taint nodes $elastic_node node.elasticsearch.io/unschedulable=:NoSchedule;  done
```

