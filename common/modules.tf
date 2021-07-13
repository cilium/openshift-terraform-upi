module cilium_olm {
  # this needs to be kept up-to-date as new Cilium releases get added to the repo
  source = "git::https://github.com/cilium/cilium-olm.git?ref=37ec9a4c3e1adecfc6fdee2a7b3351d1faf20687"
}

locals {
  cilium_olm = format("%s/.terraform/modules/common.cilium_olm", abspath(path.root))
}
