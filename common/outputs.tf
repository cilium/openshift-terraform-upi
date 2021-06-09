output infrastructure_name {
  value = local.infrastructure_name
}

output rhcos_image {
  value = local.rhcos_image
}

output worker_ca {
  value = local.worker_ca
}

output master_ca {
  value = local.master_ca
}

output cluster_kubeconfig {
  value = data.local_file.kubeconfig.content_base64
  sensitive = true
}

output cluster_kubeadmin_password {
  value = data.local_file.kubeadmin_password.content
  sensitive = true
}

output cluster_ssh_key {
  value = tls_private_key.ssh_key.private_key_pem
  sensitive = true
}

output bootstrap_ignition_config_path {
  value = format("%s/bootstrap.ign", local.config_dir)
}

output bootstrap_ign {
  value = data.local_file.bootstrap_ign.content
}

output master_ign {
  value = data.local_file.master_ign.content
}

output worker_ign {
  value = data.local_file.worker_ign.content
}
