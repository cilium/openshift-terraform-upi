module cilium_olm {
  # this needs to be kept up-to-date as new Cilium releases get added to the repo
  source = "git::https://github.com/cilium/cilium-olm.git?ref=52649c05d4889f3a9c6f9f714cd52de659d1a30d"
}

locals {
  cilium_olm = format("%s/.terraform/modules/openshift_install_config.cilium_olm", abspath(path.root))
}
