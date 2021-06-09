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
