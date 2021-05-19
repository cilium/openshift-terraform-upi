module cilium_olm {
  # this needs to be kept up-to-date as new Cilium releases get added to the repo
  source = "git::https://github.com/cilium/cilium-olm.git?ref=a19f3e5c73eee30ab0dfe6bec2bf614b467c5c21"
}

locals {
  cilium_olm = format("%s/.terraform/modules/openshift_install_config.cilium_olm", abspath(path.root))
}
