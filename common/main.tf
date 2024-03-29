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
    # this might need to be replaced with JavaScript provider if gets any more complex,
    # e.g. if user-specified values need to be merged with any values added by the module
    # internally (like anything beyond top-level fields
    spec = merge(yamldecode(data.local_file.cilium_config.content)["spec"], local.cilium_config_values_without_kube_proxy, var.custom_cilium_config_values)
  })

  filename = local.custom_cilium_config_path
}

# when kube-proxy is disabled, the operator needs to access the API (see https://github.com/cilium/cilium-olm/issues/48),
# in order to do that the only option that is currently viable is to set environment variables;
# the reason for using JavaScript here is because the merge function is only able to perform a shallow merge
# and there is no obvious way to set update a field of an object
data javascript custom_cilium_olm_deployment {
  # it's not currently possible to just pass the object from terrafom and modify it, for some reason fields are marked read-only
  # that's why JSON data is passed instead
  source = "var deployment = JSON.parse(deploymentManifest); deployment.spec.template.spec.containers[0].env = deployment.spec.template.spec.containers[0].env.concat(env); deployment"

    vars = {
      deploymentManifest = jsonencode(yamldecode(data.local_file.cilium_olm_deployment.content))
      env = [
        {
          name = "KUBERNETES_SERVICE_HOST"
          value = "api.${var.cluster_name}.${var.dns_zone_name}"
        },
        {
          name = "KUBERNETES_SERVICE_PORT"
          value = "6443"
        },
      ]
    }
}

resource local_file custom_cilium_olm_deployment {

  content = yamlencode(data.javascript.custom_cilium_olm_deployment.result)

  filename = local.custom_cilium_olm_deployment_path
}

resource local_file custom_network_operator_config {

  content = yamlencode({
    apiVersion = "operator.openshift.io/v1"
    kind = "Network"
    metadata = {
      name = "cluster"
    }
    spec = {
      clusterNetwork = [{
        cidr = "10.128.0.0/14"
        hostPrefix = 23
      }]
      defaultNetwork = {
        type = "Cilium"
      }
      deployKubeProxy = !var.without_kube_proxy
      logLevel = "Normal"
      managementState = "Managed"
      operatorLogLevel = "Normal"
      serviceNetwork = [ "172.30.0.0/16" ]
    }
  })

  filename = local.custom_network_operator_config_path
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
    command = "${local.script_get_olm_manifests} ${var.cilium_olm_repo} ${var.cilium_olm_rev} ${var.cilium_version} ${local.manifests_dir} ${local.manifests_persist_dir}"
  }
}

resource null_resource ignition_configs {
  depends_on = [
    null_resource.cilium_manifests,
    null_resource.get_openshift_install,
    local_file.custom_cilium_config,
    local_file.custom_cilium_olm_deployment,
    local_file.custom_network_operator_config,
  ]

  triggers = {
    manifests = null_resource.manifests.id
    cilium_manifests = null_resource.cilium_manifests.id
    worker_machinesets = join("-", local.worker_machinesets_hashes)
    script_create_ignition_configs = filesha256(local.script_create_ignition_configs)
    custom_cilium_config = local_file.custom_cilium_config.id
    custom_network_operator_config = local_file.custom_network_operator_config.id
  }

  provisioner "local-exec" {
    command = join(" ", flatten([
      local.script_create_ignition_configs,
      var.openshift_distro,
      var.openshift_version,
      local.config_dir,
      local.worker_machinesets_paths,
      [ for file in fileset(path.module, "manifests/*") : "${abspath(path.module)}/${file}" ],
      (length(var.custom_cilium_config_values) > 0 || var.without_kube_proxy) ? [local.custom_cilium_config_path] : [],
      (var.without_kube_proxy) ? [local.custom_cilium_olm_deployment_path] : [],
      local.custom_network_operator_config_path,
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

  filename = format("%s/cluster-network-07-cilium-ciliumconfig.yaml", local.manifests_persist_dir)
}

data local_file cilium_olm_deployment {
  depends_on = [ null_resource.cilium_manifests ]

  filename = format("%s/cluster-network-06-cilium-00002-cilium-olm-deployment.yaml", local.manifests_persist_dir)
}

resource local_file worker_machinesets {
  for_each = {
    for index, machineset in var.worker_machinesets : "worker-machineset-${index}" => machineset
  }

  content = yamlencode(each.value)

  filename = format("%s/%s.yaml", local.input_dir, each.key)
}

locals {
  input_dir = format("%s/config/%s/input", abspath(path.module), var.cluster_name)
  manifests_persist_dir = format("%s/manifests", local.input_dir)

  config_dir = format("%s/config/%s/state", abspath(path.module), var.cluster_name)
  manifests_dir = format("%s/manifests", local.config_dir)

  install_config_path = format("%s/install-config.yaml", local.input_dir)
  custom_network_operator_config_path = format("%s/cluster-network-01-operator.yaml", local.input_dir)
  custom_cilium_config_path = format("%s/cluster-network-07-cilium-ciliumconfig.yaml", local.input_dir)
  custom_cilium_olm_deployment_path = format("%s/cluster-network-06-cilium-00002-cilium-olm-deployment.yaml", local.input_dir)

  infrastructure_name = jsondecode(data.local_file.openshift_install_state_json.content)["*installconfig.ClusterID"]["InfraID"]
  rhcos_image = jsondecode(data.local_file.openshift_install_state_json.content)["*rhcos.Image"]

  worker_ca = jsondecode(data.local_file.master_ign.content).ignition.security.tls.certificateAuthorities[0].source
  master_ca = jsondecode(data.local_file.worker_ign.content).ignition.security.tls.certificateAuthorities[0].source

  script_get_openshift_install = format("%s/get-openshift-install.sh", abspath(path.module))
  script_get_olm_manifests = format("%s/get-olm-manifests.sh", abspath(path.module))
  script_create_manifests = format("%s/openshift-install-create-manifests.sh", abspath(path.module))
  script_create_ignition_configs = format("%s/openshift-install-create-ignition-configs.sh", abspath(path.module))

  worker_machinesets_paths = [ for index, machineset in var.worker_machinesets : format("%s/worker-machineset-%s.yaml", local.input_dir, index) ]
  worker_machinesets_hashes = [ for file in local_file.worker_machinesets : file.id ]

  cilium_config_values_without_kube_proxy = (!var.without_kube_proxy) ? {} : {
    # NB: as this passed to merge function, only top-level fields can be set here,
    # setting anything else can accidentally collide with custom values provided by the user
    kubeProxyReplacement = "strict"
    k8sServiceHost = "api.${var.cluster_name}.${var.dns_zone_name}"
    k8sServicePort = "6443"
  }
}
