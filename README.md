This module deploys OpenShift using the official CloudFomation examples for [AWS][ocp_docs_aws] & [GCP][ocp_docs_gcp].

The aim it to delploy [CloudFomation][installer_repo_aws] & [Deployment Manager][installer_repo_gcp] templates from the OpenShift installer repo, without having to fork them and without manually translating them to Terraform.

This modules largely relies on [`aws_cloudformation_stack`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack) & [`google_deployment_manager_deployment`](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/deployment_manager_deployment),
with additional resources managed by Terraform directly (e.g. AWS VPC Endpoint for S3, ingress rules for Cilium ports, GCP DNS zone).

The `openshift-install` binary is downlaoded at runtime (based on `openshift_version` and `openshift_distro` parameters, it is used for generating Ignition conigs and manifests.

Cilium manifests are sourced from [Cilium OLM repo](https://github.com/cilium/cilium-olm/).

For up-to-date list of input parameters see `variables.tf` in each variant.

- [`aws/variables.tf`](aws/variables.tf)
- [`gcp/variables.tf`](gcp/variables.tf)

Cannonical outputs `cluster_name` and `cluster_kubeconfig` are exported by each variant.

[installer_repo_aws]: https://github.com/openshift/installer/tree/7e02fe75a583242e4cbb8c60472b105acf7a8266/upi/aws/cloudformation
[ocp_docs_aws]: https://docs.openshift.com/container-platform/4.7/installing/installing_aws/installing-aws-user-infra.html

[installer_repo_gcp]: https://github.com/openshift/installer/tree/dd560e2b2bea5f8192cc87ab1fe4acc899701261/upi/gcp
[ocp_docs_gcp]: https://docs.openshift.com/container-platform/4.6/installing/installing_gcp/installing-gcp-user-infra.html
