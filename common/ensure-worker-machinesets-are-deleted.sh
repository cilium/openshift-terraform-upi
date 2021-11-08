#!/bin/bash

# Copyright 2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

# it's not possible to pass "external" parameter to destroy provisioneres,
# so this script has to use a few non-trivial ways of getting hold of the
# kubeconfig
if [ -n "${CLUSTER_KUBECONFIG+x}" ] ; then
  # dev-scripts/delete-cluster.sh sets CLUSTER_KUBECONFIG explicilty,
  # so it can be used easily with local backend, becuse outputs are cleared
  # form the state file on deletion...
  export KUBECONFIG="${CLUSTER_KUBECONFIG}"
else
  # in case when Kubernetes state backend and especially the terraform-controller,
  # the name of the cluster and kubeconfig must be obtained for terraform outputs;
  # the terraform-controller execution context doesn't have the files on deletion
  name="$(terraform output -json cluster_name | jq -r)"

  terraform output -json cluster_kubeconfig | jq -r | base64 -d > "${name}.kubeconfig" || exit 0

  # export this separately as it breaks terrafrom interacing with state backend in some cases
  export KUBECONFIG="${name}.kubeconfig"
fi

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

echo "INFO: the worker machinesets should be deleted now"
