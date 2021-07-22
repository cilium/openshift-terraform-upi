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
  default = "3525270a719243eca47f9c1d3bcbc3dfe53eeb73"
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
  default = "openshift-dev-gcp.cilium.rocks"
}

variable gcp_managed_zone_name {
  type = string
  default = "openshift-dev-gcp-cilium-rocks"
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

variable compute_machine_type {
  type = string
  default = "n1-standard-4"
}

variable compute_machines_per_zone {
  type = number
  default = 1
}

variable compute_root_volume_size {
  type = number
  default = 128
}

variable compute_root_volume_type {
  type = string
  default = "pd-ssd"
}

variable control_plane_machine_type {
  type = string
  default = "n1-standard-4"
}

variable control_plane_root_volume_size {
  type = string
  default = "128"
}

variable gcp_region {
  type = string
  default = "europe-west1"
}

variable gcp_project {
  type = string
  # default = "cilium-ci"
  default = "cilium-dev"
}

variable gcp_credentials {
  type = string
}

provider google {
  region = var.gcp_region
  project = var.gcp_project
  credentials = var.gcp_credentials
}
