variable cluster_name {
  type = string
  default = "test-1"
}

variable hosted_zone_id {
  type = string
  default = "Z02916301G8QAGZFPQZUP"
}

variable hosted_zone_name {
  type = string
  default = "ilya-openshift-test-1.cilium.rocks"
}

variable rhcos_ami {
  # TODO: find a way to update this automatically
  # https://github.com/openshift/openshift-docs/blob/master/modules/installation-aws-user-infra-rhcos-ami.adoc
  type = string
  default = "ami-0b4024fa5cb2588bd"
}

variable aws_region {
  type = string
  default = "eu-west-1"
}

provider aws {
  region = var.aws_region
}

