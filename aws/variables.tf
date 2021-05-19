variable cilium_version {
  type = string
  default = "1.9.4"
}

variable custom_cilium_config_values {
  type = any
  default = {}
}

variable cluster_name {
  type = string
  default = "test-1"
}

variable hosted_zone_id {
  type = string
  default = "Z02916301G8QAGZFPQZUP"
}

variable dns_zone_name {
  type = string
  default = "ilya-openshift-test-1.cilium.rocks"
}

variable pull_secret {
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
