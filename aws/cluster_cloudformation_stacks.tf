# docs: https://docs.openshift.com/container-platform/4.6/installing/installing_aws/installing-aws-user-infra.html

resource aws_cloudformation_stack vpc {
  name = format("openshift-ci-%s-vpc", local.infrastructure_name)

  template_body = file(format("%s/01_vpc.yaml", local.cloudformation_templates))
}

resource aws_cloudformation_stack cluster_infra {
  name = format("openshift-ci-%s-cluster-infra", local.infrastructure_name)

  template_body = file(format("%s/02_cluster_infra.yaml", local.cloudformation_templates))

  capabilities = ["CAPABILITY_NAMED_IAM"]

  parameters = {
    ClusterName = var.cluster_name

    InfrastructureName = local.infrastructure_name

    HostedZoneId = var.hosted_zone_id
    HostedZoneName = var.hosted_zone_name
    PublicSubnets = local.public_subnets
    PrivateSubnets = local.private_subnets
    VpcId = aws_cloudformation_stack.vpc.outputs["VpcId"]
  }
}
 
resource aws_cloudformation_stack cluster_security {
  name = format("openshift-ci-%s-cluster-security", local.infrastructure_name)

  template_body = file(format("%s/03_cluster_security.yaml", local.cloudformation_templates))

  capabilities = ["CAPABILITY_IAM"]

  parameters = {
    InfrastructureName = local.infrastructure_name

    PrivateSubnets = local.private_subnets
    VpcId = aws_cloudformation_stack.vpc.outputs["VpcId"]
  }
}

resource aws_cloudformation_stack cluster_bootstrap {
  name = format("openshift-ci-%s-cluster-bootstrap", local.infrastructure_name)

  depends_on = [ aws_s3_bucket_object.cluster_boostrap_inginition_object ]

  template_body = file(format("%s/04_cluster_bootstrap.yaml", local.cloudformation_templates))

  capabilities = ["CAPABILITY_IAM"]

  parameters = {
    InfrastructureName = local.infrastructure_name

    PublicSubnet = element(split(",", local.public_subnets), 0)
    MasterSecurityGroupId = local.master_sg
    VpcId = aws_cloudformation_stack.vpc.outputs["VpcId"]
    BootstrapIgnitionLocation = format("s3://openshift-cilium-ci-%s-cluster-bootstrap/bootstrap.ign", local.infrastructure_name)

    RhcosAmi = var.rhcos_ami

    AutoRegisterELB = "yes"
    ExternalApiTargetGroupArn = aws_cloudformation_stack.cluster_infra.outputs["ExternalApiTargetGroupArn"]
    RegisterNlbIpTargetsLambdaArn = aws_cloudformation_stack.cluster_infra.outputs["RegisterNlbIpTargetsLambda"]
    InternalApiTargetGroupArn = aws_cloudformation_stack.cluster_infra.outputs["InternalApiTargetGroupArn"]
    InternalServiceTargetGroupArn = aws_cloudformation_stack.cluster_infra.outputs["InternalServiceTargetGroupArn"]
  }
}

resource aws_cloudformation_stack cluster_master_nodes {
  name = format("openshift-ci-%s-cluster-master-nodes", local.infrastructure_name)

  # force dependency to avoid target group errors
  depends_on = [ aws_cloudformation_stack.cluster_bootstrap ]

  template_body = file(format("%s/05_cluster_master_nodes.yaml", local.cloudformation_templates))

  parameters = {
    InfrastructureName = local.infrastructure_name

    IgnitionLocation = format("https://%s:22623/config/master", aws_cloudformation_stack.cluster_infra.outputs["ApiServerDnsName"])

    Master0Subnet = local.private_subnets_list[0]
    Master1Subnet = local.private_subnets_list[1]
    Master2Subnet = local.private_subnets_list[2]

    MasterSecurityGroupId = local.master_sg

    MasterInstanceType = var.control_plane_instance_type

    RhcosAmi = var.rhcos_ami

    PrivateHostedZoneId = aws_cloudformation_stack.cluster_infra.outputs["PrivateHostedZoneId"]
    PrivateHostedZoneName = format("%s.%s", var.cluster_name, var.hosted_zone_name)

    CertificateAuthorities = local.master_ca

    MasterInstanceProfileName = aws_cloudformation_stack.cluster_security.outputs["MasterInstanceProfile"]

    AutoRegisterELB = "yes"
    ExternalApiTargetGroupArn = aws_cloudformation_stack.cluster_infra.outputs["ExternalApiTargetGroupArn"]
    RegisterNlbIpTargetsLambdaArn = aws_cloudformation_stack.cluster_infra.outputs["RegisterNlbIpTargetsLambda"]
    InternalApiTargetGroupArn = aws_cloudformation_stack.cluster_infra.outputs["InternalApiTargetGroupArn"]
    InternalServiceTargetGroupArn = aws_cloudformation_stack.cluster_infra.outputs["InternalServiceTargetGroupArn"]
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
}