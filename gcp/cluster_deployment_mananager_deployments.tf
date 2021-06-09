resource google_deployment_manager_deployment vpc {
  name = format("openshift-ci-%s-vpc", local.infrastructure_name)

  target {
    config {
      content = yamlencode({
        imports = [{ path = "01_vpc.py" }]
        resources = [{
          name = "vpc"
          type = "01_vpc.py"
          properties = {
            infra_id = local.infrastructure_name
            region = var.gcp_region
            master_subnet_cidr = "10.0.0.0/17"
            worker_subnet_cidr = "10.0.128.0/17"
          }
        }]
      })
    }

    imports {
      name = "01_vpc.py"
      content = file(format("%s/01_vpc.py", local.deployment_manager_configs))
    }
  }

  labels {
    key = "cilium_openshift_infrastructure_name"
    value = local.infrastructure_name
  }

  labels {
    key = "cilium_openshift_cluster_name"
    value = var.cluster_name
  }
}

resource null_resource vpc_deletion_workaround {
  # vpc deployment cannot be deleted without removing firewall rules that were created by Kubernetes
  # and it's not possible to pass arguments to destroy provisioners, so this slightly
  # odd workardound is required
  # NOTE: AWS variant can attach destroy provisioners to the CloudFormation stack, as self.outputs
  # can be passed as args, but Deployment Manager doesn't have outputs
  # NOTE: dettach destroy provisioners are not as robust, as they only get triggered once and are
  # not bound to the state of resouces in question, i.e. if deployment keeps failing to get deleted,
  # this provisioner will not execute on each attemp

  triggers = {
    arg1 = google_deployment_manager_deployment.vpc.self_link
    google_credentials = var.gcp_credentials
  }

  provisioner "local-exec" {
    when = destroy

    command = "./remove-vpc-dependencies.sh ${self.triggers.arg1}"

    environment = {
      GOOGLE_CREDENTIALS = self.triggers.google_credentials
    }
  }
}

data google_compute_network cluster {
  name = format("%s-network", local.infrastructure_name)
  depends_on = [ google_deployment_manager_deployment.vpc ]
}

data google_compute_subnetwork worker {
  name = format("%s-master-subnet", local.infrastructure_name)
  depends_on = [ google_deployment_manager_deployment.vpc ]
}

data google_compute_subnetwork master {
  name = format("%s-master-subnet", local.infrastructure_name)
  depends_on = [ google_deployment_manager_deployment.vpc ]
}

resource google_deployment_manager_deployment cluster_infra {
  name = format("openshift-ci-%s-cluster-infra", local.infrastructure_name)

  depends_on = [ google_deployment_manager_deployment.vpc ]

  target {
    config {
      content = yamlencode({
        imports = [
          { path = "02_lb_ext.py" },
          { path = "02_lb_int.py" },
        ]
        resources = [
          # "02_dns.py" is not included here as it's trivial and
          # it is more convenient to manage with terraform, as
          # terraform supports forced deletion
          {
            name = "cluster-lb-ext"
            type = "02_lb_ext.py"
            properties = {
              infra_id = local.infrastructure_name
              region = var.gcp_region
            }
          },
          {
            name = "cluster-lb-int"
            type = "02_lb_int.py"
            properties = {
              infra_id = local.infrastructure_name
              region = var.gcp_region
              cluster_network = data.google_compute_network.cluster.self_link
              control_subnet = data.google_compute_subnetwork.master.self_link
              zones = local.zones
            }
          },
        ]
      })
    }

    imports {
      name = "02_lb_ext.py"
      content = file(format("%s/02_lb_ext.py", local.deployment_manager_configs))
    }

    imports {
      name = "02_lb_int.py"
      content = file(format("%s/02_lb_int.py", local.deployment_manager_configs))
    }
  }

  labels {
    key = "cilium_openshift_infrastructure_name"
    value = local.infrastructure_name
  }

  labels {
    key = "cilium_openshift_cluster_name"
    value = var.cluster_name
  }
}

resource google_deployment_manager_deployment cluster_security {
  name = format("openshift-ci-%s-cluster-security", local.infrastructure_name)

  depends_on = [ google_deployment_manager_deployment.vpc ]

  target {
    config {
      content = yamlencode({
        imports = [
          { path: "03_firewall.py" },
          { path: "03_iam.py" },
        ]
        resources = [
          {
            name = "cluster-firewall"
            type = "03_firewall.py"
            properties = {
              infra_id = local.infrastructure_name
              cluster_network = data.google_compute_network.cluster.self_link
              allowed_external_cidr = "0.0.0.0/0"
              network_cidr = "10.0.0.0/16"
            }
          },
          {
            name = "cluster-iam"
            type = "03_iam.py"
            properties = {
              infra_id = local.infrastructure_name
            }
          },
        ]
      })
    }

    imports {
      name = "03_firewall.py"
      content = file(format("%s/03_firewall.py", local.deployment_manager_configs))
    }

    imports {
      name = "03_iam.py"
      content = file(format("%s/03_iam.py", local.deployment_manager_configs))
    }
  }

  labels {
    key = "cilium_openshift_infrastructure_name"
    value = local.infrastructure_name
  }

  labels {
    key = "cilium_openshift_cluster_name"
    value = var.cluster_name
  }
}

data google_service_account worker {
  depends_on = [ google_deployment_manager_deployment.cluster_security ]
  account_id = "${local.infrastructure_name}-w"
}

resource google_project_iam_member worker {
  for_each = toset([
    "roles/compute.viewer",
    "roles/storage.admin",
  ])

  member = "serviceAccount:${data.google_service_account.worker.email}"
  role = each.value
}

data google_service_account master {
  depends_on = [ google_deployment_manager_deployment.cluster_security ]
  account_id = "${local.infrastructure_name}-m"
}

resource google_service_account_key master {
  depends_on = [ google_deployment_manager_deployment.cluster_security ]
  service_account_id = "${local.infrastructure_name}-m"
}

resource local_file master_service_account_key {
  depends_on = [ google_deployment_manager_deployment.cluster_security ]
  content = base64decode(google_service_account_key.master.private_key)
  filename = format("%s/config/%s/input/master-sa.json", abspath(path.module), var.cluster_name)
}

resource google_project_iam_member master {
  for_each = toset([
    "roles/storage.admin",
    "roles/compute.instanceAdmin",
    "roles/compute.networkAdmin",
    "roles/compute.securityAdmin",
    "roles/iam.serviceAccountUser",
  ])

  member = "serviceAccount:${data.google_service_account.master.email}"
  role = each.value
}

resource google_deployment_manager_deployment cluster_bootstrap {
  name = format("openshift-ci-%s-cluster-bootstrap", local.infrastructure_name)

  depends_on = [
    google_deployment_manager_deployment.vpc,
    google_deployment_manager_deployment.cluster_infra,
    google_deployment_manager_deployment.cluster_security,
  ]

  target {
    config {
      content = yamlencode({
        imports = [{ path = "04_bootstrap.py" }]
        resources = [{
          name = "cluster-bootstrap"
          type = "04_bootstrap.py"
          properties = {
            infra_id = local.infrastructure_name
            region = var.gcp_region
            cluster_network = data.google_compute_network.cluster.self_link
            control_subnet = data.google_compute_subnetwork.master.self_link
            zone = local.zones[0]

            image = local.rhcos_image
            bootstrap_ign = data.google_storage_object_signed_url.cluster_boostrap_inginition_object_signed_url.signed_url

            machine_type = var.control_plane_machine_type
            root_volume_size = var.control_plane_root_volume_size
          }
        }]
      })
    }

    imports {
      name = "04_bootstrap.py"
      content = file(format("%s/04_bootstrap.py", local.deployment_manager_configs))
    }
  }

  labels {
    key = "cilium_openshift_infrastructure_name"
    value = local.infrastructure_name
  }

  labels {
    key = "cilium_openshift_cluster_name"
    value = var.cluster_name
  }

  provisioner "local-exec" {
    command = join("&&", [
      "gcloud compute instance-groups unmanaged add-instances ${local.infrastructure_name}-bootstrap-instance-group --project=${var.gcp_project} --zone=${local.zones[0]} --instances=${local.infrastructure_name}-bootstrap",
      "gcloud compute backend-services add-backend ${local.infrastructure_name}-api-internal-backend-service --project=${var.gcp_project} --region=${var.gcp_region} --instance-group=${local.infrastructure_name}-bootstrap-instance-group --instance-group-zone=${local.zones[0]}",
    ])

    environment = {
      GOOGLE_CREDENTIALS = var.gcp_credentials
    }
  }
}

resource null_resource bootstrap_deletion_workaround {
  # bootstrap deployment cannot be deleted without undoing backend association that provisioner
  # has setup, but it's not possible to pass arguments to destroy provisioners, so this slightly
  # odd workardound is required
  # NOTE: AWS variant can attach destroy provisioners to the CloudFormation stack, as self.outputs
  # can be passed as args, but Deployment Manager doesn't have outputs
  # NOTE: dettach destroy provisioners are not as robust, as they only get triggered once and are
  # not bound to the state of resouces in question, i.e. if deployment keeps failing to get deleted,
  # this provisioner will not execute on each attemp
  depends_on = [ google_deployment_manager_deployment.cluster_bootstrap ]

  triggers = {
    arg1 = google_deployment_manager_deployment.cluster_infra.self_link
    arg2 = local.infrastructure_name
    google_credentials = var.gcp_credentials
  }

  provisioner "local-exec" {
    when = destroy

    command = "./remove-bootstrap-dependencies.sh ${self.triggers.arg1} ${self.triggers.arg2}"

    environment = {
      GOOGLE_CREDENTIALS = self.triggers.google_credentials
    }
  }
}

resource google_deployment_manager_deployment cluster_master_nodes {
  name = format("openshift-ci-%s-cluster-master-nodes", local.infrastructure_name)

  depends_on = [
    google_deployment_manager_deployment.cluster_bootstrap,
    google_compute_firewall.cilium_ports,
    # destroy provision will break if DNS gets wiped before this deployment,
    # as DNS record would normaly gets deleted first because nothing depends
    # on them; it's possible that other DNS records get wiped, but that normally
    # should not affect the control plane, i.e. the chances of all API servers
    # restaring and trying to resolve etcd hosts are very very slim
    google_dns_record_set.api_public_a_record,
  ]

  target {
    config {
      content = yamlencode({
        imports = [{ path = "05_control_plane.py" }]
        resources = [{
          name = "cluster-control-plane"
          type = "05_control_plane.py"
          properties = {
            infra_id = local.infrastructure_name
            region = var.gcp_region
            cluster_network = data.google_compute_network.cluster.self_link
            control_subnet = data.google_compute_subnetwork.master.self_link
            zones = local.zones

            image = local.rhcos_image
            ignition = module.common.master_ign

            machine_type = var.control_plane_machine_type
            root_volume_size = var.control_plane_root_volume_size

            service_account_email = data.google_service_account.master.email
          }
        }]
      })
    }

    imports {
      name = "05_control_plane.py"
      content = file(format("%s/05_control_plane.py", local.deployment_manager_configs))
    }
  }

  labels {
    key = "cilium_openshift_infrastructure_name"
    value = local.infrastructure_name
  }

  labels {
    key = "cilium_openshift_cluster_name"
    value = var.cluster_name
  }

  provisioner "local-exec" {
    command = join("&&", flatten([
      for index, zone in local.zones : [
        "gcloud compute instance-groups unmanaged add-instances ${local.infrastructure_name}-master-${zone}-instance-group --project=${var.gcp_project} --zone=${zone} --instances=${local.infrastructure_name}-master-${index}",
        "gcloud compute target-pools add-instances ${local.infrastructure_name}-api-target-pool --project=${var.gcp_project} --instances=${local.infrastructure_name}-master-${index} --instances-zone=${zone}",
      ]
    ]))

    environment = {
      GOOGLE_CREDENTIALS = var.gcp_credentials
    }
  }

  provisioner "local-exec" {
    when = destroy
    # the worker machinesets will block deletion of most resources, so these need to be deleted first
    command = format("%s/ensure-worker-machinesets-are-deleted.sh", abspath("${path.module}/../common"))
  }
}

data google_compute_zones available {
  status = "UP"
}

locals {
  zones = [
    data.google_compute_zones.available.names[0],
    data.google_compute_zones.available.names[1],
    data.google_compute_zones.available.names[2],
  ]
}
