variable cilium_version {
  type = string
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

variable without_kube_proxy {
  type = bool
  default = false
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
