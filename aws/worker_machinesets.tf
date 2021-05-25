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

                placement = { region = var.aws_region }

                instanceType = var.compute_instance_type

                ami = { id = local.rhcos_image }
                blockDevices = [{
                  ebs = {
                    encrypted = true
                    volumeSize = var.compute_root_volume_size
                    volumeType = var.compute_root_volume_type
                    iops = var.compute_root_volume_iops
                  }
                }]

                iamInstanceProfile = { id = aws_cloudformation_stack.cluster_security.outputs["WorkerInstanceProfile"] }
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
