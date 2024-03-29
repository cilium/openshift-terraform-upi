resource aws_cloudformation_stack vpc {
  name = format("openshift-ci-%s-vpc", local.infrastructure_name)

  template_body = file(format("%s/01_vpc.yaml", local.cloudformation_templates))

  tags = local.common_tags

  provisioner "local-exec" {
    when = destroy
    # the ingress operator creates a service with an ELB associtated with it, it's maybe possible to delete the service first,
    # but since there is already a similar deletion provisioner for Route53, it makes sense to use the same technique for the
    # deletion of the ELB
    command = format("%s/ensure-elb-is-deleted.sh %s", abspath(path.module), self.outputs["VpcId"])
  }
}

resource aws_cloudformation_stack cluster_infra {
  name = format("openshift-ci-%s-cluster-infra", local.infrastructure_name)

  template_body = file(format("%s/02_cluster_infra.yaml", local.cloudformation_templates))

  tags = local.common_tags

  capabilities = ["CAPABILITY_NAMED_IAM"]

  parameters = {
    ClusterName = var.cluster_name

    InfrastructureName = local.infrastructure_name

    HostedZoneId = var.aws_hosted_zone_id
    HostedZoneName = var.dns_zone_name
    PublicSubnets = local.public_subnets
    PrivateSubnets = local.private_subnets
    VpcId = aws_cloudformation_stack.vpc.outputs["VpcId"]
  }

  provisioner "local-exec" {
    when = destroy
    # the Route53 zone is populated by ingress operator based, it's not possible to delete the entry using the API
    # because the default object is mandated by the operator itself, and if it's deleted it gets re-created
    command = format("%s/ensure-route53-zone-has-no-apps-record.sh %s", abspath(path.module), self.outputs["PrivateHostedZoneId"])
  }
}

resource aws_cloudformation_stack cluster_security {
  name = format("openshift-ci-%s-cluster-security", local.infrastructure_name)

  template_body = file(format("%s/03_cluster_security.yaml", local.cloudformation_templates))

  tags = local.common_tags

  capabilities = ["CAPABILITY_IAM"]

  parameters = {
    InfrastructureName = local.infrastructure_name

    PrivateSubnets = local.private_subnets
    VpcId = aws_cloudformation_stack.vpc.outputs["VpcId"]
  }
}

resource aws_cloudformation_stack cluster_bootstrap {
  name = format("openshift-ci-%s-cluster-bootstrap", local.infrastructure_name)

  depends_on = [ aws_s3_object.cluster_boostrap_inginition_object ]

  template_body = file(format("%s/04_cluster_bootstrap.yaml", local.cloudformation_templates))

  tags = local.common_tags

  capabilities = ["CAPABILITY_IAM"]

  parameters = {
    InfrastructureName = local.infrastructure_name

    PublicSubnet = element(split(",", local.public_subnets), 0)
    MasterSecurityGroupId = local.master_sg
    VpcId = aws_cloudformation_stack.vpc.outputs["VpcId"]
    BootstrapIgnitionLocation = format("s3://%s/bootstrap.ign", local.cluster_boostrap_inginition_bucket_name)

    RhcosAmi = local.rhcos_image

    AutoRegisterELB = "yes"
    ExternalApiTargetGroupArn = aws_cloudformation_stack.cluster_infra.outputs["ExternalApiTargetGroupArn"]
    RegisterNlbIpTargetsLambdaArn = aws_cloudformation_stack.cluster_infra.outputs["RegisterNlbIpTargetsLambda"]
    InternalApiTargetGroupArn = aws_cloudformation_stack.cluster_infra.outputs["InternalApiTargetGroupArn"]
    InternalServiceTargetGroupArn = aws_cloudformation_stack.cluster_infra.outputs["InternalServiceTargetGroupArn"]
  }
}

resource aws_cloudformation_stack cluster_master_nodes {
  name = format("openshift-ci-%s-cluster-master-nodes", local.infrastructure_name)

  depends_on = [
    # force dependency to avoid target group errors
    aws_cloudformation_stack.cluster_bootstrap,
    # in all likelihood ingress rules would created before this stack,
    # however deletion of ingress rules happens first as nothing depends
    # on them, which causes Cilium connectivity to break and prevents
    # deletion of worker machinesets to complete, as Machine API controller
    # becomes unable to connect to the EC2 API
    aws_security_group_rule.cilium_ingress_rules,
  ]

  template_body = file(format("%s/05_cluster_master_nodes.yaml", local.cloudformation_templates))

  tags = local.common_tags

  parameters = {
    InfrastructureName = local.infrastructure_name

    IgnitionLocation = format("https://%s:22623/config/master", aws_cloudformation_stack.cluster_infra.outputs["ApiServerDnsName"])

    Master0Subnet = local.private_subnets_list[0]
    Master1Subnet = local.private_subnets_list[1]
    Master2Subnet = local.private_subnets_list[2]

    MasterSecurityGroupId = local.master_sg

    MasterInstanceType = var.control_plane_instance_type

    RhcosAmi = local.rhcos_image

    PrivateHostedZoneId = aws_cloudformation_stack.cluster_infra.outputs["PrivateHostedZoneId"]
    PrivateHostedZoneName = format("%s.%s", var.cluster_name, var.dns_zone_name)

    CertificateAuthorities = module.common.master_ca

    MasterInstanceProfileName = aws_cloudformation_stack.cluster_security.outputs["MasterInstanceProfile"]

    AutoRegisterELB = "yes"
    ExternalApiTargetGroupArn = aws_cloudformation_stack.cluster_infra.outputs["ExternalApiTargetGroupArn"]
    RegisterNlbIpTargetsLambdaArn = aws_cloudformation_stack.cluster_infra.outputs["RegisterNlbIpTargetsLambda"]
    InternalApiTargetGroupArn = aws_cloudformation_stack.cluster_infra.outputs["InternalApiTargetGroupArn"]
    InternalServiceTargetGroupArn = aws_cloudformation_stack.cluster_infra.outputs["InternalServiceTargetGroupArn"]
  }

  provisioner "local-exec" {
    when = destroy
    # the worker machinesets will block deletion of most resources, so these need to be deleted first
    command = abspath("${path.module}/common/ensure-worker-machinesets-are-deleted.sh")
  }
}

locals {
  worker_sg = aws_cloudformation_stack.cluster_security.outputs["WorkerSecurityGroupId"]
  master_sg = aws_cloudformation_stack.cluster_security.outputs["MasterSecurityGroupId"]

  public_subnets = aws_cloudformation_stack.vpc.outputs["PublicSubnetIds"]
  private_subnets = aws_cloudformation_stack.vpc.outputs["PrivateSubnetIds"]
  private_subnets_list = [
    # this is needed to ensure list length can be used to determine number of machinesets that will be generated
    element(split(",", aws_cloudformation_stack.vpc.outputs["PrivateSubnetIds"]), 0),
    element(split(",", aws_cloudformation_stack.vpc.outputs["PrivateSubnetIds"]), 1),
    element(split(",", aws_cloudformation_stack.vpc.outputs["PrivateSubnetIds"]), 2),
  ]

  common_tags = {
    CiliumOpenShiftInfrastructureName = local.infrastructure_name
    CiliumOpenShiftClusterName = var.cluster_name
  }
}
