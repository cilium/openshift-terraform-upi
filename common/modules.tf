module cilium_olm {
  # this needs to be kept up-to-date as new Cilium releases get added to the repo
  source = "git::https://github.com/cilium/cilium-olm.git?ref=5d31d493f7d0d60454dca19ef0f938f4631a86ff"
}

locals {
  cilium_olm = format("%s/.terraform/modules/common.cilium_olm", abspath(path.root))
}
