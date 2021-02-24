variable cilium_version {
  type = string
  default = "1.9.4"
}

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

variable pull_secret {
  type = string
  default = ""
  sensitive = true
}

variable ssh_key {
  type = string
  default = ""
  sensitive = true
}

variable openshift_distro {
  type = string
  default = "ocp"
}

variable openshift_version {
  type = string
  default = "4.7.0"
}

variable aws_region {
  type = string
  default = "eu-west-1"
}

variable aws_access_key {
  type = string
  # sensitive = true
}

variable aws_secret_key {
  type = string
  # sensitive = true
}

provider aws {
  region = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}
