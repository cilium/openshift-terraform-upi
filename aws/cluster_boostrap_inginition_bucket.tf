resource aws_s3_bucket cluster_boostrap_inginition_bucket {
  bucket = local.cluster_boostrap_inginition_bucket_name
  acl    = "private"

  tags = local.common_tags
}

resource aws_s3_bucket_policy cluster_boostrap_inginition_bucket {
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

resource aws_s3_bucket_object cluster_boostrap_inginition_object {
  depends_on = [ null_resource.ignition_configs ]
  key    = "bootstrap.ign"
  bucket = aws_s3_bucket.cluster_boostrap_inginition_bucket.id
  source = format("%s/bootstrap.ign", local.config_dir)
}

# VPC Endpoint is being used to enable EC2 instances to access the bucket and avoid having to either
# fork CloudFormation templates or make the bucket publically accessible
resource aws_vpc_endpoint cluster_boostrap_inginition_bucket {
  vpc_id       = aws_cloudformation_stack.vpc.outputs["VpcId"]
  service_name = format("com.amazonaws.%s.s3", var.aws_region)

  tags = local.common_tags

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

locals {
  cluster_boostrap_inginition_bucket_name = format("openshift-cilium-ci-%s-cluster-bootstrap", substr(sha256(local.infrastructure_name), 0, 24))
}
