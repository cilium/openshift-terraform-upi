#!/bin/bash

# Copyright 2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$#" -ne 1 ] ; then
  echo "$0 supports exactly 1 argument"
  echo "example: '$0 test-1'"
  exit 1
fi

name="${1}"

export KUBECONFIG="${script_dir}/${name}.kubeconfig"

scale_down_worker_machinesets() {
  kubectl scale machinesets --namespace=openshift-machine-api --selector="machine.openshift.io/cluster-api-machine-role=worker" --replicas=0
}

has_zero_machines() {
  machines=($(kubectl get machines --namespace=openshift-machine-api --selector="machine.openshift.io/cluster-api-machine-role=worker" --output="jsonpath={range .items[*]}{.metadata.name}{\"\n\"}{end}" 2> /dev/null))
  test "${#machines[@]}" -eq 0
}

echo "INFO: scaling down all worker machinesets..."

scale_down_worker_machinesets

echo "INFO: waiting for machines to be deleted..."

until has_zero_machines ; do sleep 0.5 ; done
