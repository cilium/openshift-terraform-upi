module cilium_olm {
  # this needs to be kept up-to-date as new Cilium releases get added to the repo
  source = "git::https://github.com/cilium/cilium-olm.git?ref=ae233fd9433f29a14c165435fcedcf16a635cd3e"
}

locals {
  cilium_olm = format("%s/.terraform/modules/common.cilium_olm", abspath(path.root))
}
