variable cilium_version {
  type = string
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
}

variable pull_secret {
  type = string
}

variable openshift_distro {
  type = string
}

variable openshift_version {
  type = string
}

variable platform {
  type = any
  default = {}
}

variable platform_env {
  type = map(string)
  default = {}
}

variable worker_machinesets {
  type = list(any)
  default = []
}
