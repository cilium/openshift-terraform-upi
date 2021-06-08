resource google_compute_firewall cilium_ports {
  name    = format("%s-cilium", local.infrastructure_name)
  network = data.google_compute_network.cluster.self_link

  depends_on = [ google_deployment_manager_deployment.vpc ]

  allow {
    protocol = "udp"
    ports    = ["8472"]
  }

  allow {
    protocol = "tcp"
    ports    = ["4240"]
  }

  allow {
    protocol = "icmp"
  }

  source_tags = ["${local.infrastructure_name}-worker", "${local.infrastructure_name}-master"]
}
