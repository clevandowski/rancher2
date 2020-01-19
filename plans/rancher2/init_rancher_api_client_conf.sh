#/bin/bash

mkdir -p ~/.rancher
chmod 700 ~/.rancher

cat << COINCOIN > ~/.rancher/credential
export RANCHER_ADMIN_CLUSTER_MASTER_API_URL=
export RANCHER_ADMIN_CLUSTER_MASTER_ACCESS_KEY=
export RANCHER_ADMIN_CLUSTER_MASTER_SECRET_KEY=
export RANCHER_ADMIN_CLUSTER_MASTER_BEARER_TOKEN=
COINCOIN
chmod 600 ~/.rancher/credential

echo "Please complete credential parameters in ~/.rancher/credential"
