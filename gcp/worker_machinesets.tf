locals {
  worker_machinesets = [
    for index, zone in local.zones : {
      apiVersion = "machine.openshift.io/v1beta1"
      kind = "MachineSet"
      metadata = {
        labels = {
          "machine.openshift.io/cluster-api-cluster" = local.infrastructure_name
          "machine.openshift.io/cluster-api-machine-role" = "worker"
        }
        name = "${local.infrastructure_name}-worker-${index}"
        namespace = "openshift-machine-api"
      }
      spec = {
        replicas = var.compute_machines_per_zone
        selector = {
          matchLabels = {
            "machine.openshift.io/cluster-api-cluster" = local.infrastructure_name
            "machine.openshift.io/cluster-api-machineset" = "${local.infrastructure_name}-worker-${index}"
          }
        }
        template = {
          metadata = {
            labels = {
              "machine.openshift.io/cluster-api-cluster" = local.infrastructure_name
              "machine.openshift.io/cluster-api-machine-role" = "worker"
              "machine.openshift.io/cluster-api-machine-type" = "worker"
              "machine.openshift.io/cluster-api-machineset" = "${local.infrastructure_name}-worker-${index}"
            }
          }
          spec = {
            providerSpec = {
              value = {
                apiVersion = "gcpprovider.openshift.io/v1beta1"
                kind = "GCPMachineProviderSpec"

                projectID = var.gcp_project
                region = var.gcp_region
                zone = zone

                machineType = var.compute_machine_type

                disks = [{
                  autoDelete = true
                  boot = true
                  image = local.rhcos_image
                  labels = null
                  sizeGb = var.compute_root_volume_size
                  type = var.compute_root_volume_type
                }]

                serviceAccounts = [{
                  email = data.google_service_account.worker.email
                  scopes = [ "https://www.googleapis.com/auth/cloud-platform" ]
                }]

                tags = [ "${local.infrastructure_name}-worker" ]
                networkInterfaces = [{
                  network = "${local.infrastructure_name}-network"
                  subnetwork = "${local.infrastructure_name}-worker-subnet"
                }]
                canIPForward = false

                deletionProtection = false

                credentialsSecret = { name = "gcp-cloud-credentials" }
                userDataSecret = { name = "worker-user-data" }
              }
            }
          }
        }
      }
    }
  ]
}
