provision_cloud_cluster() {
  # Provision cluster VM sur cloud
  terraform init
  if terraform validate; then
    terraform plan \
      -var aws_profile="$AWS_PROFILE" \
      -var aws_region="$AWS_REGION" \
      -var authorized_ip="$PUBLIC_IP/32" \
      -var rancher2-lb-dns="$RANCHER_LB_DNS" \
      -var rancher2-hosted-zone-id="$RANCHER_LB_DNS_HOSTED_ZONE_ID" \
      -out rancher2.plan
  else
    return 1
  fi

  if ! terraform apply -auto-approve rancher2.plan; then
    echo "Error in terraform apply"
    return 1
  fi
}
