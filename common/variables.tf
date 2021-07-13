variable cilium_version {
  type = string
}

variable cilium_olm_repo {
  type = string
  default = "cilium/cilium-olm"
}

variable cilium_olm_rev {
  type = string
  default = "37ec9a4c3e1adecfc6fdee2a7b3351d1faf20687"
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
