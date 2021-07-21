module common {
  source = "../common"

  cilium_version = var.cilium_version
  custom_cilium_config_values = var.custom_cilium_config_values

  cluster_name = var.cluster_name
  dns_zone_name = var.dns_zone_name

  pull_secret = var.pull_secret

  openshift_distro = var.openshift_distro
  openshift_version = var.openshift_version

  without_kube_proxy = var.without_kube_proxy

  platform = {
    aws = {
      region = var.aws_region
    }
  }
  platform_env = {
    AWS_ACCESS_KEY_ID = var.aws_access_key
    AWS_SECRET_ACCESS_KEY = var.aws_secret_key
  }

  worker_machinesets = local.worker_machinesets
}

locals {
  infrastructure_name = module.common.infrastructure_name
  rhcos_image = module.common.rhcos_image
}

module cloudformation_templates {
  # it assumed that these CloudFormation templates are broadly compatible with any OKD or OCP version, so the revision here
  # should be just some recent commit and there is no need to map it to openshift_version/openshift_distro
  source = "git::https://github.com/openshift/installer.git//upi/aws/cloudformation?ref=a6597edd93133f88bb5280a3cd0660f25e8d77e9"
}

locals {
  modules_path = format("%s/.terraform/modules", abspath(path.root))

  cloudformation_templates = format("%s/cloudformation_templates/upi/aws/cloudformation", local.modules_path)
}
