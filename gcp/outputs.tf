output cluster_name {
  value = var.cluster_name
}

output cluster_kubeconfig {
  value = module.openshift_install_config.cluster_kubeconfig
  sensitive = true
}

output cluster_kubeadmin_password {
  value = module.openshift_install_config.cluster_kubeadmin_password
  sensitive = true
}

output cluster_ssh_key {
  value = module.openshift_install_config.cluster_ssh_key
  sensitive = true
}
