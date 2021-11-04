## OpenShift UPI Terraform module for Cilium

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

## Usage

This module can be used as any other Terraform module.

However, there are a few convenient scripts provided for certain use-cases.

- [`dev-scripts`](dev-scripts/) directory contains simple shell wrappers (more below)
- [`tfc-scripts`](tfc-scripts/) directory contains shell wrappers for use with Isovalent internal Terraform controller

### Using `dev-scripts/create-cluster.sh`

This script simplifies the setup of module parameters, it runs `terraform apply`, waits for cluster to become ready and extracts `kubeconfig` file.

Basic usage:

```
export AWS_ACCESS_KEY_ID=<...> AWS_SECRET_ACCESS_KEY=<...>
./dev-scripts/create-cluster.sh ilya-test-1 aws ocp 4.6.18 1.10.3
```

Setting custom Helm values for images and enabling KPR:

```
cat > custom-params-1.tf <<EOF
cilium_olm_rev = "master"

without_kube_proxy = true

custom_cilium_config_values = {
  image = {
    repository = "quay.io/cilium/cilium-ci"
    tag = "d42f456cde20"
    digest = "sha256:c027fdfdc9272490ae5c03b063af27e0546be5724ea1998913d0a4f58eff7970"
  }
  operator = {
    image = {
      repository = "quay.io/cilium/operator-generic-ci"
      tag = "b5285a179808"
      genericDigest = "sha256:20b94bc8c4c098834f145bd761f0c9e5d62d3b536f59d116637edc4c0e6a8427"
    }
  }
}
EOF
./dev-scripts/create-cluster.sh ilya-test-2-kpr aws ocp 4.6.18 1.10.3 custom-params-1.tf
```

### Using `dev-scripts/delete-cluster.sh`

This script simply deletes the cluster and all local state files associated with it.

```
./dev-scripts/create-cluster.sh ilya-test-1
```
