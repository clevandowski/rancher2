remove_cloud_cluster() {
  terraform destroy -auto-approve -var aws_profile="$AWS_PROFILE" -var aws_region="$AWS_REGION"
}
