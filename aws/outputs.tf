output cluster_name {
  value = var.cluster_name
}

output cluster_kubeconfig {
  value = data.local_file.kubeconfig.content_base64
  sensitive = true
}

output cluster_kubeadmin_password {
  value = data.local_file.kubeadmin_password.content
  sensitive = true
}
