module cilium_olm {
  # this needs to be kept up-to-date as new Cilium releases get added to the repo
  source = "git::https://github.com/cilium/cilium-olm.git?ref=e40f2209ea0e080ec89c249dedfaad88867bc2b0"
}

locals {
  cilium_olm = format("%s/.terraform/modules/common.cilium_olm", abspath(path.root))
}
