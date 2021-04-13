locals {
  worker_machinesets = [
    for index, subnet in local.private_subnets_list : {
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
        replicas = var.compute_machines_per_az
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
                apiVersion = "awsproviderconfig.openshift.io/v1beta1"
                kind = "AWSMachineProviderConfig"
                instanceType = var.compute_instance_type
                ami = { id = local.ami }
                blockDevices = [{
                  ebs = {
                    encrypted: true
                    volumeSize: var.compute_root_volume_size
                    volumeType: var.compute_root_volume_type
                    iops = var.compute_root_volume_iops
                  }
                }]
                iamInstanceProfile = { id = aws_cloudformation_stack.cluster_security.outputs["WorkerInstanceProfile"] }
                placement = { region = var.aws_region }
                securityGroups = [{ id = local.worker_sg }]
                subnet =  { id = subnet }
                credentialsSecret = { name = "aws-cloud-credentials" }
                userDataSecret = { name = "worker-user-data" }
              }
            }
          }
        }
      }
    }
  ]
}

resource local_file worker_machinesets {
  for_each = {
    for index, machineset in local.worker_machinesets : "worker-machineset-${index}" => machineset
  }

  content = yamlencode(each.value)

  filename = format("%s/config/%s.%s.yaml", abspath(path.module), var.cluster_name, each.key)
}

locals {
  worker_machinesets_paths = join(" ", [ for index, machineset in local.worker_machinesets : format("%s/config/%s.worker-machineset-%s.yaml", abspath(path.module), var.cluster_name, index) ])
}
