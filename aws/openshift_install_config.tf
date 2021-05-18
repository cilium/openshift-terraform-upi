resource local_file install_config {

  content = yamlencode({
    apiVersion = "v1"
    metadata = { name = var.cluster_name }
    baseDomain = var.hosted_zone_name
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
    platform = {
      aws = {
        region = var.aws_region
      }
    }
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
    spec = merge(local.cilium_config_values, var.custom_cilium_config_values)
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
  }

  provisioner "local-exec" {
    command = "${local.script_create_manifests} ${var.openshift_distro} ${var.openshift_version} ${local.config_dir} ${local.install_config_path}"
    environment = {
      AWS_ACCESS_KEY_ID = var.aws_access_key
      AWS_SECRET_ACCESS_KEY = var.aws_secret_key
    }
  }
}

resource null_resource cilium_manifests {
  depends_on = [ null_resource.manifests, null_resource.get_openshift_install ]

  triggers = {
    cilium_version = var.cilium_version
    manifests = null_resource.manifests.id
  }

  provisioner "local-exec" {
    command = "cp ${local.cilium_olm}/manifests/cilium.v${var.cilium_version}/* ${local.config_dir}/manifests"
  }
}

resource null_resource ignition_configs {
  depends_on = [
    null_resource.cilium_manifests,
    local_file.worker_machinesets,
    null_resource.get_openshift_install,
    local_file.custom_cilium_config,
  ]

  triggers = {
    manifests = null_resource.manifests.id
    cilium_manifests = null_resource.cilium_manifests.id
    worker_machinesets = join("-", [for file in local_file.worker_machinesets : file.id])
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
      fileset(path.module, "cluster-network-08-cilium-test-*.yaml"),
      length(var.custom_cilium_config_values) > 0 ? [local.custom_cilium_config_path] : [],
    ]))
    environment = {
      AWS_ACCESS_KEY_ID = var.aws_access_key
      AWS_SECRET_ACCESS_KEY = var.aws_secret_key
    }
  }
}

data local_file openshift_install_state_json {
  # metadata.json is not generated when the InfraID is needed, so read it from installer state
  # this must depend on manifests also because AMI is populated only after manifests are generated
  depends_on = [ null_resource.manifests ]

  filename = format("%s/.openshift_install_state.json", local.config_dir)
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
  filename = format("%s/manifests/cilium.v%s/cluster-network-07-cilium-ciliumconfig.yaml", local.cilium_olm, var.cilium_version)
}

locals {
  config_dir = format("%s/config/%s/state", abspath(path.module), var.cluster_name)
  install_config_path = format("%s/config/%s/input/install-config.yaml", abspath(path.module), var.cluster_name)
  custom_cilium_config_path = format("%s/config/%s/input/cluster-network-07-cilium-ciliumconfig.yaml", abspath(path.module), var.cluster_name)

  infrastructure_name = jsondecode(data.local_file.openshift_install_state_json.content)["*installconfig.ClusterID"]["InfraID"]
  ami = jsondecode(data.local_file.openshift_install_state_json.content)["*installconfig.InstallConfig"]["config"]["controlPlane"]["platform"]["aws"]["amiID"]

  cilium_config_values = yamldecode(data.local_file.cilium_config.content)["spec"]

  common_tags = {
    CiliumOpenShiftInfrastructureName = local.infrastructure_name
    CiliumOpenShiftClusterName = var.cluster_name
  }

  worker_ca = jsondecode(data.local_file.master_ign.content).ignition.security.tls.certificateAuthorities[0].source
  master_ca = jsondecode(data.local_file.worker_ign.content).ignition.security.tls.certificateAuthorities[0].source

  script_get_openshift_install = format("%s/get-openshift-install.sh", abspath(path.module))
  script_create_manifests = format("%s/openshift-install-create-manifests.sh", abspath(path.module))
  script_create_ignition_configs = format("%s/openshift-install-create-ignition-configs.sh", abspath(path.module))
}
