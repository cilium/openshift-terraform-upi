output cluster_name {
  value = var.cluster_name
}

output cluster_kubeconfig {
  value = base64encode(data.local_file.kubeconfig.sensitive_content)
  sensitive = true
}

output cluster_kubeconfig_kubeadmin_password {
  value = data.local_file.kubeadmin_password.sensitive_content
  sensitive = true
}
