This module deploys OpenShift on AWS using [the official CloudFomation examples][ocp_docs].

The aim it to delploy CloudFomation templates from the [OpenShift installer repo][installer_repo] having to fork them, or without translating them to terraform Terraform.

This modules largely relies on [`aws_cloudformation_stack`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack),
with additional resources managed by Terraform directly (e.g. VPC Endpoint for S3 and ingress rules for Cilium ports).

The `openshift-install` binary downlaoded at runtime (based on `openshift_version` and `openshift_distro` parameters, it is used for generating Ignition conigs and manifests.

Cilium manifests are sourced from [Cilium OLM repo](https://github.com/cilium/cilium-olm/).

For up-to-date list of input parameters see [`variables.tf`](variables.tf).

Cannonical outputs `cluster_name` and `cluster_kubeconfig` are exported by this module.

[installer_repo]: https://github.com/openshift/installer/tree/7e02fe75a583242e4cbb8c60472b105acf7a8266/upi/aws/cloudformation
[ocp_docs]: https://docs.openshift.com/container-platform/4.6/installing/installing_aws/installing-aws-user-infra.html
