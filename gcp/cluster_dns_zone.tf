resource google_dns_managed_zone private {
  name = format("%s-private-zone", local.infrastructure_name)
  depends_on = [ google_deployment_manager_deployment.vpc ]

  dns_name = "${local.cluster_domain}."

  visibility = "private"

  private_visibility_config {
    networks {
      network_url = data.google_compute_network.cluster.self_link
    }
  }

  force_destroy = true
}

data google_compute_instance master {
  count = 3
  name = format("%s-master-%d", local.infrastructure_name, count.index)
  depends_on = [ google_deployment_manager_deployment.cluster_master_nodes ]
  zone = data.google_compute_zones.available.names[count.index]
}

data google_compute_address private {
  name = format("%s-cluster-ip", local.infrastructure_name)
  depends_on = [ google_deployment_manager_deployment.cluster_infra ]
}

data google_compute_address public {
  name = format("%s-cluster-public-ip", local.infrastructure_name)
  depends_on = [ google_deployment_manager_deployment.cluster_infra ]
}

resource google_dns_record_set etcd_a_records {
  count = 3

  name = format("etcd-%d.%s", count.index, google_dns_managed_zone.private.dns_name)

  depends_on = [ google_deployment_manager_deployment.cluster_master_nodes ]

  managed_zone = google_dns_managed_zone.private.name

  type = "A"
  ttl  = 60

  rrdatas = [ data.google_compute_instance.master[count.index].network_interface[0].network_ip ]
}

resource google_dns_record_set etcd_srv_record {
  name = format("_etcd-server-ssl._tcp.%s", google_dns_managed_zone.private.dns_name)

  managed_zone = google_dns_managed_zone.private.name

  type = "SRV"
  ttl  = 60

  rrdatas = [
    for index, name in [ "etcd-0", "etcd-1", "etcd-2" ] : format("0 10 2380 %s.%s", name, google_dns_managed_zone.private.dns_name)
  ]
}

resource google_dns_record_set api_private_a_records {
  for_each = toset([ "api", "api-int" ])

  name = format("%s.%s", each.value, google_dns_managed_zone.private.dns_name)

  depends_on = [ google_deployment_manager_deployment.cluster_infra ]

  managed_zone = google_dns_managed_zone.private.name

  type = "A"
  ttl  = 60

  rrdatas = [ data.google_compute_address.private.address ]
}

resource google_dns_record_set api_public_a_record {
  name = format("api.%s.", local.cluster_domain)

  depends_on = [ google_deployment_manager_deployment.cluster_infra ]

  managed_zone = var.gcp_managed_zone_name

  type = "A"
  ttl  = 60

  rrdatas = [ data.google_compute_address.public.address ]
}

locals {
  cluster_domain = format("%s.%s", var.cluster_name, var.dns_zone_name)
}
