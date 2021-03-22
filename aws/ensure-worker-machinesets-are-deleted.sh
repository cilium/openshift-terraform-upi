#!/bin/bash

# Copyright 2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# name and kubeconfig must be obtained for terraform outputs because
# in the terraform-controller execution context these files written
# during provisioning are not available during destruction
name="$(terraform output -json cluster_name | jq -r)"

export KUBECONFIG="${script_dir}/${name}.kubeconfig"

terraform output -json cluster_kubeconfig | jq -r | base64 -d > "${KUBECONFIG}" || exit 0

scale_down_worker_machinesets() {
  kubectl scale machinesets --namespace=openshift-machine-api --selector="machine.openshift.io/cluster-api-machine-role=worker" --replicas=0
}

has_zero_machines() {
  machines=($(kubectl get machines --namespace=openshift-machine-api --selector="machine.openshift.io/cluster-api-machine-role=worker" --output="jsonpath={range .items[*]}{.metadata.name}{\"\n\"}{end}" 2> /dev/null))
  test "${#machines[@]}" -eq 0
}

echo "INFO: scaling down all worker machinesets..."

if scale_down_worker_machinesets ; then
  echo "INFO: waiting for machines to be deleted..."

  until has_zero_machines ; do sleep 0.5 ; done
fi
