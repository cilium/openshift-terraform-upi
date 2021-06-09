#!/bin/bash

# Copyright 2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "${script_dir}"

if [ "$#" -ne 1 ] ; then
  echo "$0 supports exactly 1 argument"
  echo "example: '$0 test-1'"
  exit 1
fi

name="${1}"

namespace="terraform-system"
execution_name="openshift-ci-${name}"

job_name="$(kubectl --namespace="${namespace}" get executions "${execution_name}" --output="jsonpath={.status.mostRecentJob.jobName}")"

kubectl --namespace="${namespace}" get secrets "${job_name}" --output="jsonpath={.data.outputFile}" | base64 -d | jq -r .cluster_kubeadmin_password.value
