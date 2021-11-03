module common {
  source = "./common"

  cilium_version = var.cilium_version
  cilium_olm_repo = var.cilium_olm_repo
  cilium_olm_rev = var.cilium_olm_rev
  custom_cilium_config_values = var.custom_cilium_config_values

  cluster_name = var.cluster_name
  dns_zone_name = var.dns_zone_name

  pull_secret = var.pull_secret

  openshift_distro = var.openshift_distro
  openshift_version = var.openshift_version

  without_kube_proxy = var.without_kube_proxy

  platform = {
    gcp = {
      region = var.gcp_region
      projectID = var.gcp_project
    }
  }
  platform_env = {
    GOOGLE_CREDENTIALS = var.gcp_credentials
  }

  worker_machinesets = local.worker_machinesets
}

locals {
  infrastructure_name = module.common.infrastructure_name
  rhcos_image = module.common.rhcos_image
}

module deployment_manager_configs {
  # it assumed that these Deployment Manager configs are broadly compatible with any OKD or OCP version, so the revision here
  # should be just some recent commit and there is no need to map it to openshift_version/openshift_distro
  source = "git::https://github.com/openshift/installer.git//upi/gcp?ref=a6597edd93133f88bb5280a3cd0660f25e8d77e9"
}

locals {
  modules_path = format("%s/.terraform/modules", abspath(path.root))

  deployment_manager_configs = format("%s/deployment_manager_configs/upi/gcp", local.modules_path)
}
