module cloudformation_templates {
  # it assumed that these CloudFormation templates are broadly compatible with any OKD or OCP version, so the revision here
  # should be just some recent commit and there is no need to map it to openshift_version/openshift_distro
  source = "git::https://github.com/openshift/installer.git//upi/aws/cloudformation?ref=a6597edd93133f88bb5280a3cd0660f25e8d77e9"
}

module cilium_olm {
  # this needs to be kept up-to-date as new Cilium releases get added to the repo
  source = "git::https://github.com/cilium/cilium-olm.git?ref=94ceae9bd4843a8ffdf2a1f5b366186a2238b4af"
}

locals {
  modules_path = format("%s/.terraform/modules", abspath(path.root))

  cloudformation_templates = format("%s/cloudformation_templates/upi/aws/cloudformation", local.modules_path)
  cilium_olm = format("%s/cilium_olm", local.modules_path)
}
