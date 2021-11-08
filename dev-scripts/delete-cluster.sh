#!/bin/bash

# Copyright 2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$#" -ne 2 ] ; then
  echo "$0 supports exactl two arguments"
  echo "example: '$0 test-1 aws'"
  exit 1
fi

name="${1}"
cloud_provider="${2}"

kubeconfig_path="${script_dir}/${name}.kubeconfig"

module_path="$(pwd)/${name}"
cd "${module_path}"

# AWS credentials are required for deletion hooks to work properly (see aws/ensure-*.sh)
if [ "${cloud_provider}" = "aws" ] ; then
  if [ -z "${AWS_ACCESS_KEY_ID+x}" ] || [ -z "${AWS_SECRET_ACCESS_KEY+x}" ] ; then
    echo "AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY must be set"
    exit 3
  fi
fi

CLUSTER_KUBECONFIG="${kubeconfig_path}" terraform destroy -auto-approve


rm -f "${kubeconfig_path}"
rm -rf "${module_path}
