output cluster_name {
  value = var.cluster_name
}

output cluster_kubeconfig {
  value = module.common.cluster_kubeconfig
  sensitive = true
}

output cluster_kubeadmin_password {
  value = module.common.cluster_kubeadmin_password
  sensitive = true
}

output cluster_ssh_key {
  value = module.common.cluster_ssh_key
  sensitive = true
}

# it's not possible to pass environment variables to destroy provisioners,
# and local files cannot be used with terraform-controller at present,
# so a credentials file is stored as outout instead
output aws_config {
  value = join("\n", [
    "[default]",
    "region = ${var.aws_region}",
    "aws_access_key_id = ${var.aws_access_key}",
    "aws_secret_access_key = ${var.aws_secret_key}",
    "",
  ])
  sensitive = true
}
