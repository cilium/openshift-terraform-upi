module cloudformation_templates {
  source = "git::https://github.com/openshift/installer.git//upi/aws/cloudformation?ref=a6597edd93133f88bb5280a3cd0660f25e8d77e9"
}

module cilium_olm {
  source = "git::https://github.com/cilium/cilium-olm.git?ref=f6440a3d9ea3656fd976241ba2d6afb556e2dd7b"
}

locals {
  modules_path = format("%s/.terraform/modules", abspath(path.root))

  cloudformation_templates = format("%s/cloudformation_templates/upi/aws/cloudformation", local.modules_path)
  cilium_olm = format("%s/cilium_olm", local.modules_path)
}
