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
    sshKey = var.ssh_key
  })

  filename = local.install_config_path
}

resource null_resource get_openshift_install {
  triggers = {
    openshift_distro = var.openshift_distro
    openshift_version = var.openshift_version
  }

  provisioner "local-exec" {
    command = "${path.cwd}/get-openshift-install.sh ${var.openshift_distro} ${var.openshift_version}"
  }
}

resource null_resource manifests {
  depends_on = [ local_file.install_config, null_resource.get_openshift_install ]

  triggers = {
    openshift_distro = var.openshift_distro
    openshift_version = var.openshift_version
    install_config = local_file.install_config.id
  }

  provisioner "local-exec" {
    command = "${path.cwd}/openshift-install-create-manifests.sh ${var.openshift_distro} ${var.openshift_version} ${local.config_dir} ${local.install_config_path}"
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
  depends_on = [ null_resource.cilium_manifests, local_file.worker_machinesets, null_resource.get_openshift_install ]

  triggers = {
    manifests = null_resource.manifests.id
    cilium_manifests = null_resource.cilium_manifests.id
    worker_machinesets = join("-", [for file in local_file.worker_machinesets : file.id])
  }

  provisioner "local-exec" {
    command = "${path.cwd}/openshift-install-create-ignition-configs.sh ${var.openshift_distro} ${var.openshift_version} ${local.config_dir} ${local.worker_machinesets_path}"
    environment = {
      AWS_ACCESS_KEY_ID = var.aws_access_key
      AWS_SECRET_ACCESS_KEY = var.aws_secret_key
    }
  }
}

data local_file metadata_json {
  depends_on = [ null_resource.manifests ]

  filename = format("%s/metadata.json", local.config_dir)
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

locals {
  config_dir = format("%s/config/%s", abspath(path.module), var.cluster_name)
  install_config_path = format("%s/config/%s.install-config.yaml", abspath(path.module), var.cluster_name)

  infrastructure_name = jsondecode(data.local_file.metadata_json.content).infraID
  worker_ca = jsondecode(data.local_file.master_ign.content).ignition.security.tls.certificateAuthorities[0].source
  master_ca = jsondecode(data.local_file.worker_ign.content).ignition.security.tls.certificateAuthorities[0].source
}
