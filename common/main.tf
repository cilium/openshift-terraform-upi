resource local_file install_config {

  content = yamlencode({
    apiVersion = "v1"
    metadata = { name = var.cluster_name }
    baseDomain = var.dns_zone_name
    compute = [{
      architecture = "amd64"
      name = "worker"
      # machinesets created by the installer are not valid for UPI
      replicas = 0
    }]
    networking = {
      clusterNetwork = [{
        cidr = "10.128.0.0/14"
        hostPrefix = 23
      }]
      machineNetwork = [{
        cidr = "10.0.0.0/16"
      }]
      networkType = "Cilium"
      serviceNetwork = [ "172.30.0.0/16" ]
    }
    platform = var.platform
    publish = "External"
    pullSecret = var.pull_secret
    sshKey = tls_private_key.ssh_key.public_key_openssh
  })

  filename = local.install_config_path
}

resource local_file custom_cilium_config {

  content = yamlencode({
    apiVersion = "cilium.io/v1alpha1"
    kind = "CiliumConfig"
    metadata = {
      name = "cilium"
      namespace = "cilium"
    }
    spec = merge(yamldecode(data.local_file.cilium_config.content)["spec"], var.custom_cilium_config_values)
  })

  filename = local.custom_cilium_config_path
}

resource null_resource get_openshift_install {
  triggers = {
    openshift_distro = var.openshift_distro
    openshift_version = var.openshift_version
    script_get_openshift_install = filesha256(local.script_get_openshift_install)
  }

  provisioner "local-exec" {
    command = "${local.script_get_openshift_install} ${var.openshift_distro} ${var.openshift_version}"
  }
}

resource null_resource manifests {
  depends_on = [ local_file.install_config, null_resource.get_openshift_install ]

  triggers = {
    openshift_distro = var.openshift_distro
    openshift_version = var.openshift_version
    install_config = local_file.install_config.id
    script_create_manifests = filesha256(local.script_create_manifests)
    # workaround to pass this as argument to destroy provisioner
    config_dir = local.config_dir
  }

  provisioner "local-exec" {
    command = "${local.script_create_manifests} ${var.openshift_distro} ${var.openshift_version} ${local.config_dir} ${local.install_config_path}"
    environment = var.platform_env
  }

  provisioner "local-exec" {
    when = destroy
    command = "rm -rf ${self.triggers.config_dir}"
  }
}

resource null_resource cilium_manifests {
  depends_on = [ null_resource.manifests, null_resource.get_openshift_install ]

  triggers = {
    cilium_version = var.cilium_version
    cilium_olm_repo = var.cilium_olm_repo
    cilium_olm_rev = var.cilium_olm_rev
    manifests = null_resource.manifests.id
  }

  provisioner "local-exec" {
    command = "${local.script_get_olm_manifests} ${var.cilium_olm_repo} ${var.cilium_olm_rev} ${var.cilium_version} ${local.config_dir}/manifests"
  }
}

resource null_resource ignition_configs {
  depends_on = [
    null_resource.cilium_manifests,
    null_resource.get_openshift_install,
    local_file.custom_cilium_config,
  ]

  triggers = {
    manifests = null_resource.manifests.id
    cilium_manifests = null_resource.cilium_manifests.id
    worker_machinesets = join("-", local.worker_machinesets_hashes)
    script_create_ignition_configs = filesha256(local.script_create_ignition_configs)
    custom_cilium_config = local_file.custom_cilium_config.id
  }

  provisioner "local-exec" {
    command = join(" ", flatten([
      local.script_create_ignition_configs,
      var.openshift_distro,
      var.openshift_version,
      local.config_dir,
      local.worker_machinesets_paths,
      [ for file in fileset(path.module, "manifests/*") : "${abspath(path.module)}/${file}" ],
      length(var.custom_cilium_config_values) > 0 ? [local.custom_cilium_config_path] : [],
    ]))
    environment = var.platform_env
  }
}

data local_file openshift_install_state_json {
  # metadata.json is not generated when the InfraID is needed, so read it from installer state
  # this must depend on manifests also because local.rhcos_image is populated only after manifests are generated
  depends_on = [ null_resource.manifests ]

  filename = format("%s/.openshift_install_state.json", local.config_dir)
}

data local_file bootstrap_ign {
  depends_on = [ null_resource.ignition_configs ]

  filename = format("%s/bootstrap.ign", local.config_dir)
}

data local_file master_ign {
  depends_on = [ null_resource.ignition_configs ]

  filename = format("%s/master.ign", local.config_dir)
}

data local_file worker_ign {
  depends_on = [ null_resource.ignition_configs ]

  filename = format("%s/worker.ign", local.config_dir)
}

data local_file kubeconfig {
  depends_on = [ null_resource.ignition_configs ]

  filename = format("%s/auth/kubeconfig", local.config_dir)
}

data local_file kubeadmin_password {
  depends_on = [ null_resource.ignition_configs ]

  filename = format("%s/auth/kubeadmin-password", local.config_dir)
}

data local_file cilium_config {
  depends_on = [ null_resource.cilium_manifests ]

  filename = format("%s/manifests/cluster-network-07-cilium-ciliumconfig.yaml", local.config_dir)
}

resource local_file worker_machinesets {
  for_each = {
    for index, machineset in var.worker_machinesets : "worker-machineset-${index}" => machineset
  }

  content = yamlencode(each.value)

  filename = format("%s/config/%s/input/%s.yaml", abspath(path.module), var.cluster_name, each.key)
}

locals {
  config_dir = format("%s/config/%s/state", abspath(path.module), var.cluster_name)
  install_config_path = format("%s/config/%s/input/install-config.yaml", abspath(path.module), var.cluster_name)
  custom_cilium_config_path = format("%s/config/%s/input/cluster-network-07-cilium-ciliumconfig.yaml", abspath(path.module), var.cluster_name)

  infrastructure_name = jsondecode(data.local_file.openshift_install_state_json.content)["*installconfig.ClusterID"]["InfraID"]
  rhcos_image = jsondecode(data.local_file.openshift_install_state_json.content)["*rhcos.Image"]

  worker_ca = jsondecode(data.local_file.master_ign.content).ignition.security.tls.certificateAuthorities[0].source
  master_ca = jsondecode(data.local_file.worker_ign.content).ignition.security.tls.certificateAuthorities[0].source

  script_get_openshift_install = format("%s/get-openshift-install.sh", abspath(path.module))
  script_get_olm_manifests = format("%s/get-olm-manifests.sh", abspath(path.module))
  script_create_manifests = format("%s/openshift-install-create-manifests.sh", abspath(path.module))
  script_create_ignition_configs = format("%s/openshift-install-create-ignition-configs.sh", abspath(path.module))

  worker_machinesets_paths = [ for index, machineset in var.worker_machinesets : format("%s/config/%s/input/worker-machineset-%s.yaml", abspath(path.module), var.cluster_name, index) ]
  worker_machinesets_hashes = [ for file in local_file.worker_machinesets : file.id ]
}
