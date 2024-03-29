#!/bin/bash

# Copyright 2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$#" -lt 5 ] ; then
  echo "$0 supports at least 5 argument"
  echo "example: '$0 test-1 aws ocp 4.6.18 1.9.5'"
  exit 1
fi

name="${1}"
cloud_provider="${2}"
openshift_distro="${3}"
openshift_version="${4}"
cilium_version="${5}"

if [ "$#" -eq 6 ]; then
  extra_params_file="${6}"
fi

if ! [ -f "${script_dir}/pull-secret.txt" ] ; then
  echo "${script_dir}/pull-secret.txt does not exist"
  echo "you cat obtain one from https://console.redhat.com/openshift/downloads#tool-pull-secret"
  exit 2
fi
pull_secret="$(cat "${script_dir}/pull-secret.txt")"

# OpenShift makes a copy of clould provider credentials, hence these cannot
# be handled in a way that Terraform would handle them normally; in particular
# AWS session credentials will not work and for GCP a service account must be
# used...
cloud_provider_params=""
case "${cloud_provider}" in
  aws)
    if [ -z "${AWS_DEFAULT_REGION+x}" ] || [ -z "${AWS_ACCESS_KEY_ID+x}" ] || [ -z "${AWS_SECRET_ACCESS_KEY+x}" ] ; then
      echo "AWS_DEFAULT_REGION, AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY must be set"
      exit 3
    fi
    cloud_provider_params="$(printf 'aws_region = "%s"\naws_access_key = "%s"\naws_secret_key = "%s"\n' "${AWS_DEFAULT_REGION}" "${AWS_ACCESS_KEY_ID}" "${AWS_SECRET_ACCESS_KEY}")"
    ;;
  gcp)
    if [ -z "${GCP_PROJECT+x}" ] || [ -z "${GCP_REGION+x}" ] || [ -z "${GOOGLE_CREDENTIALS+x}" ] ; then
      echo "GCP_REGION, GCP_PROJECT and GOOGLE_CREDENTIALS must be set"
      exit 3
    fi
    cloud_provider_params="$(printf 'gcp_region = "%s"\ngcp_project = "%s"\ngcp_credentials = "%s"\n' "${GCP_PROJECT}" "${GCP_REGION}" "${GOOGLE_CREDENTIALS}")"
    ;;
  *)
    echo "cloud provider ${cloud_provider} is not supported"
    exit 3
    ;;
esac

extra_params=""
if [ -n "${extra_params_file+x}" ] ; then
  if ! [ -f "${extra_params_file}" ] ; then
    echo "optional parameters file ${extra_params_file} does not exist"
    exit 4
  else
    extra_params="$(cat "${extra_params_file}")"
  fi
fi

module_path="$(pwd)/${name}"

if [ -n "${FORCE+x}" ] ; then
  mkdir -p "${module_path}"
else
  mkdir "${module_path}"
fi

cat > "${module_path}/main.tf" <<EOF
module cluster {

source = "${script_dir}/../${cloud_provider}"
cilium_version = "${cilium_version}"

cluster_name = "${name}"

pull_secret = <<EOPS
${pull_secret}
EOPS

openshift_distro = "${openshift_distro}"
openshift_version = "${openshift_version}"

${cloud_provider_params}
${extra_params}
}
EOF

cat > "${module_path}/outputs.tf" <<EOF
output cluster_name {
  value = module.cluster.cluster_name
}

output cluster_kubeconfig {
  value = module.cluster.cluster_kubeconfig
  sensitive = true
}

output cluster_kubeadmin_password {
  value = module.cluster.cluster_kubeadmin_password
  sensitive = true
}

output cluster_ssh_key {
  value = module.cluster.cluster_ssh_key
  sensitive = true
}
EOF

cd "${module_path}"

terraform init
terraform apply -auto-approve

kubeconfig_path="${script_dir}/${name}.kubeconfig"

terraform output -raw cluster_kubeconfig | base64 -d > "${kubeconfig_path}"

echo "INFO: wrote ${kubeconfig_path}"

KUBECONFIG="${kubeconfig_path}" "${script_dir}/../common/wait-cluster-ready.sh" "${name}" "${openshift_distro}" "${openshift_version}" "${cilium_version}"
