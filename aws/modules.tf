module cloudformation_templates {
  source = "git::https://github.com/openshift/installer.git//upi/aws/cloudformation?ref=a6597edd93133f88bb5280a3cd0660f25e8d77e9"
}

locals {
  cloudformation_templates = ".terraform/modules/cloudformation_templates/upi/aws/cloudformation"
}

module cilium_olm {
  source = "git::https://github.com/cilium/cilium-olm.git?ref=f6440a3d9ea3656fd976241ba2d6afb556e2dd7b"
}

locals {
  cilium_olm = ".terraform/modules/cilium_olm"
}
