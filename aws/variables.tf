variable cilium_version {
  type = string
  default = "1.10.3"
}

variable cilium_olm_repo {
  type = string
  default = "cilium/cilium-olm"
}

variable cilium_olm_rev {
  type = string
  # this needs to be kept up-to-date as new Cilium releases get added to the repo
  default = "fa72d872248448356f0cb1103daf10fbb8a9efd4"
}

variable custom_cilium_config_values {
  type = any
  default = {}
}

variable cluster_name {
  type = string
}

variable dns_zone_name {
  type = string
  default = "openshift-ci-aws.cilium.rocks"
}

variable aws_hosted_zone_id {
  type = string
  default = "Z05258822OMYT9BEZ9ZTR"
}

variable pull_secret {
  type = string
  default = ""
}

variable openshift_distro {
  type = string
  default = "ocp"
}

variable openshift_version {
  type = string
  default = "4.7.11"
}

variable without_kube_proxy {
  type = bool
  default = false
}

variable compute_instance_type {
  type = string
  default = "m5.large"
}

variable compute_machines_per_az {
  type = number
  default = 1
}

variable compute_root_volume_size {
  type = number
  default = 120
}

variable compute_root_volume_type {
  type = string
  default = "gp2"
}

variable compute_root_volume_iops {
  type = number
  default = 0
}

variable control_plane_instance_type {
  type = string
  default = "m5.xlarge"
}

variable aws_region {
  type = string
  default = "eu-west-1"
}

variable aws_access_key {
  type = string
}

variable aws_secret_key {
  type = string
}

provider aws {
  region = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}
