# docs: https://docs.openshift.com/container-platform/4.6/installing/installing_aws/installing-aws-user-infra.html

resource aws_cloudformation_stack vpc {
  name = format("openshift-ci-%s-vpc", var.cluster_name)

  template_body = file(format("%s/01_vpc.yaml", local.cloudformation_templates))
}

resource aws_cloudformation_stack cluster_infra {
  name = format("openshift-ci-%s-cluster-infra", var.cluster_name)

  template_body = file(format("%s/02_cluster_infra.yaml", local.cloudformation_templates))

  capabilities = ["CAPABILITY_NAMED_IAM"]

  parameters = {
    ClusterName = var.cluster_name

    InfrastructureName = local.infrastructure_name

    HostedZoneId = var.hosted_zone_id
    HostedZoneName = var.hosted_zone_name
    PublicSubnets = aws_cloudformation_stack.vpc.outputs["PublicSubnetIds"]
    PrivateSubnets = aws_cloudformation_stack.vpc.outputs["PrivateSubnetIds"]
    VpcId = aws_cloudformation_stack.vpc.outputs["VpcId"]
  }
}
 
resource aws_cloudformation_stack cluster_security {
  name = format("openshift-ci-%s-cluster-security", var.cluster_name)

  template_body = file(format("%s/03_cluster_security.yaml", local.cloudformation_templates))

  capabilities = ["CAPABILITY_IAM"]

  parameters = {
    InfrastructureName = local.infrastructure_name

    PrivateSubnets = aws_cloudformation_stack.vpc.outputs["PrivateSubnetIds"]
    VpcId = aws_cloudformation_stack.vpc.outputs["VpcId"]
  }
}

resource aws_s3_bucket cluster_boostrap_inginition_bucket {
  bucket = format("openshift-cilium-ci-%s-cluster-bootstrap", local.config_dir)
  acl    = "private"
}

resource "aws_s3_bucket_policy" "cluster_boostrap_inginition_bucket" {
  bucket = aws_s3_bucket.cluster_boostrap_inginition_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      Effect = "Allow"
      Principal = "*"
      Action = "s3:GetObject"
      Resource = format("%s/*", aws_s3_bucket.cluster_boostrap_inginition_bucket.arn)
      Condition: {
        StringEquals: {
          "aws:sourceVpce": aws_vpc_endpoint.cluster_boostrap_inginition_bucket.id
        }
      }
    }
  })
}

resource "aws_s3_bucket_object" "cluster_boostrap_inginition_object" {
  depends_on = [ null_resource.ignition_configs ]
  key    = "bootstrap.ign"
  bucket = aws_s3_bucket.cluster_boostrap_inginition_bucket.id
  source = format("%s/bootstrap.ign", local.config_dir)
}

# VPC Endpoint is being used to enable EC2 instances to access the bucket and avoid having to either
# fork CloudFormation templates or make the bucket publically accessible
resource "aws_vpc_endpoint" "cluster_boostrap_inginition_bucket" {
  vpc_id       = aws_cloudformation_stack.vpc.outputs["VpcId"]
  service_name = format("com.amazonaws.%s.s3", var.aws_region)

  # vpc_endpoint_type = "Interface"

  # security_group_ids = [
  #   aws_cloudformation_stack.cluster_security.outputs["MasterSecurityGroupId"]
  # ]

  # subnet_ids = [ element(split(",", aws_cloudformation_stack.vpc.outputs["PublicSubnetIds"]), 0) ]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = {
      Effect = "Allow"
      Principal = "*"
      Action = "s3:GetObject"
      Resource = format("%s/*", aws_s3_bucket.cluster_boostrap_inginition_bucket.arn)
    }
  })
}

resource aws_cloudformation_stack cluster_bootstrap {
  name = format("openshift-ci-%s-cluster-bootstrap", var.cluster_name)

  depends_on = [ aws_s3_bucket_object.cluster_boostrap_inginition_object ]

  template_body = file(format("%s/04_cluster_bootstrap.yaml", local.cloudformation_templates))

  capabilities = ["CAPABILITY_IAM"]

  parameters = {
    InfrastructureName = local.infrastructure_name

    PublicSubnet = element(split(",", aws_cloudformation_stack.vpc.outputs["PublicSubnetIds"]), 0)
    MasterSecurityGroupId = aws_cloudformation_stack.cluster_security.outputs["MasterSecurityGroupId"]
    VpcId = aws_cloudformation_stack.vpc.outputs["VpcId"]
    BootstrapIgnitionLocation = format("s3://openshift-cilium-ci-%s-cluster-bootstrap/bootstrap.ign", var.cluster_name)

    RhcosAmi = var.rhcos_ami

    AutoRegisterELB = "yes"
    ExternalApiTargetGroupArn = aws_cloudformation_stack.cluster_infra.outputs["ExternalApiTargetGroupArn"]
    RegisterNlbIpTargetsLambdaArn = aws_cloudformation_stack.cluster_infra.outputs["RegisterNlbIpTargetsLambda"]
    InternalApiTargetGroupArn = aws_cloudformation_stack.cluster_infra.outputs["InternalApiTargetGroupArn"]
    InternalServiceTargetGroupArn = aws_cloudformation_stack.cluster_infra.outputs["InternalServiceTargetGroupArn"]
  }
}

resource aws_cloudformation_stack cluster_master_nodes {
  name = format("openshift-ci-%s-cluster-master-nodes", var.cluster_name)

  # force dependency to avoid target group errors
  depends_on = [ aws_cloudformation_stack.cluster_bootstrap ]

  template_body = file(format("%s/05_cluster_master_nodes.yaml", local.cloudformation_templates))

  parameters = {
    InfrastructureName = local.infrastructure_name

    IgnitionLocation = format("https://%s:22623/config/master", aws_cloudformation_stack.cluster_infra.outputs["ApiServerDnsName"])

    Master0Subnet = element(split(",", aws_cloudformation_stack.vpc.outputs["PrivateSubnetIds"]), 0)
    Master1Subnet = element(split(",", aws_cloudformation_stack.vpc.outputs["PrivateSubnetIds"]), 1)
    Master2Subnet = element(split(",", aws_cloudformation_stack.vpc.outputs["PrivateSubnetIds"]), 2)

    MasterSecurityGroupId = aws_cloudformation_stack.cluster_security.outputs["MasterSecurityGroupId"]

    RhcosAmi = var.rhcos_ami

    PrivateHostedZoneId = var.hosted_zone_id
    PrivateHostedZoneName = var.hosted_zone_name

    CertificateAuthorities = local.master_ca

    MasterInstanceProfileName = aws_cloudformation_stack.cluster_security.outputs["MasterInstanceProfile"]

    AutoRegisterELB = "yes"
    ExternalApiTargetGroupArn = aws_cloudformation_stack.cluster_infra.outputs["ExternalApiTargetGroupArn"]
    RegisterNlbIpTargetsLambdaArn = aws_cloudformation_stack.cluster_infra.outputs["RegisterNlbIpTargetsLambda"]
    InternalApiTargetGroupArn = aws_cloudformation_stack.cluster_infra.outputs["InternalApiTargetGroupArn"]
    InternalServiceTargetGroupArn = aws_cloudformation_stack.cluster_infra.outputs["InternalServiceTargetGroupArn"]
  }
}
