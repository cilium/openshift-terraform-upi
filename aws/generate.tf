resource local_file install_config {

  content = yamlencode({
    apiVersion = "v1"
    metadata = { name = var.cluster_name }
    baseDomain = var.hosted_zone_name
    compute = [{
      architecture = "amd64"
      hyperthreading = "Enabled"
      name = "worker"
      platform = {}
      replicas = 3
    }]
    controlPlane = {
      architecture = "amd64"
      hyperthreading = "Enabled"
      name = "master"
      platform = {}
      replicas = 3
    }
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

  filename = format("%s.install-config.yaml", var.cluster_name)
  
}

resource null_resource get_openshift_install {
  triggers = {
    openshift_distro = var.openshift_distro
    openshift_version = var.openshift_version
  }

  provisioner "local-exec" {
    command = "./get-openshift-install.sh ${var.openshift_distro} ${var.openshift_version}"
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
    command = "./openshift-install-create-manifests.sh ${var.cluster_name}"
  }
}

resource null_resource cilium_manifests {
  depends_on = [ null_resource.manifests, null_resource.get_openshift_install ]

  triggers = {
    cilium_version = var.cilium_version
    manifests = null_resource.manifests.id
  }

  provisioner "local-exec" {
    command = format("cp %s/manifests/cilium.v${var.cilium_version}/* %s/manifests", local.cilium_olm, var.cluster_name)
  }
}

resource null_resource ignition_configs {
  depends_on = [ null_resource.cilium_manifests, null_resource.get_openshift_install ]

  triggers = {
    manifests = null_resource.manifests.id
    cilium_manifests = null_resource.cilium_manifests.id
  }

  provisioner "local-exec" {
    command = "./openshift-install-create-ignition-configs.sh ${var.cluster_name}"
  }
}

data local_file metadata_json {
  depends_on = [ null_resource.ignition_configs ]

  filename = format("%s/metadata.json", var.cluster_name)
}

data local_file master_ign {
  depends_on = [ null_resource.ignition_configs ]

  filename = format("%s/master.ign", var.cluster_name)
}

data local_file worker_ign {
  depends_on = [ null_resource.ignition_configs ]

  filename = format("%s/worker.ign", var.cluster_name)
}

locals {
  infrastructure_name = jsondecode(data.local_file.metadata_json.content).infraID
  worker_ca = jsondecode(data.local_file.master_ign.content).ignition.security.tls.certificateAuthorities[0].source
  master_ca = jsondecode(data.local_file.worker_ign.content).ignition.security.tls.certificateAuthorities[0].source
}
