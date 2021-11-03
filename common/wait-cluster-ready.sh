#!/bin/bash

# Copyright 2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

if [ "$#" -ne 4 ] ; then
  echo "$0 supports exactly 4 argument"
  echo "example: '$0 test-1 ocp 4.6.18 1.9.5'"
  exit 1
fi

name="${1}"
openshift_disro="${2}"
openshift_version="${3}"
cilium_version="${4}"

num_nodes="6" # this code assumes default configuration, i.e. 3 masters and one node per AZ

can_access() {
  kubectl api-versions 2> /dev/null > /dev/null
}

has_all_nodes() {
  # shellcheck disable=SC2207
  nodes=($(kubectl get nodes --output="jsonpath={range .items[*]}{.metadata.name}{\"\n\"}{end}" 2> /dev/null))
  test "${#nodes[@]}" -eq "${num_nodes}"
}

cilium_olm_operator_succeeded() {
  status="$(kubectl get clusterserviceversion --namespace=cilium --output="jsonpath={.items[0].status.phase}" 2> /dev/null)"
  test "${status}" = "Succeeded"
}

has_desired_openshift_version() {
  status="$(kubectl get clusterversion version --output="jsonpath={range .status.conditions[?(.type == \"Available\")]}{.type}={.status};{end} {range .status.conditions[?(.type == \"Failing\")]}{.type}={.status};{end} {range .status.conditions[?(.type == \"Progressing\")]}{.type}={.status};{end}" 2> /dev/null)"
  desired_state="Available=True; Failing=False; Progressing=False;"
  test "${status}" = "${desired_state}"
}

cilium_pods_are_ready() {
  ready="$(kubectl get daemonset --namespace=cilium cilium --output="jsonpath={.status.numberReady}" 2> /dev/null)"
  test -n "${ready}" && test "${ready}" -eq "${num_nodes}"
}

all_operators_are_happy() {
  desired_state="Available=True; Progressing=False; Degraded=False;"
  not_happy="$(kubectl get clusteroperators --output="jsonpath={range .items[*]}{.metadata.name}: {range .status.conditions[?(.type ==\"Available\")]}{.type}={.status}{end}; {range .status.conditions[?(.type ==\"Progressing\")]}{.type}={.status}{end}; {range .status.conditions[?(.type ==\"Degraded\")]}{.type}={.status}{end};{\"\n\"}{end}" 2> /dev/null| grep -v -c "${desired_state}")"
  test "${not_happy}" -eq 0
}

echo "INFO: waiting for the API..."

until can_access ; do sleep 0.5 ; done

echo "INFO: waiting for cluster to have ${num_nodes} nodes ready..."

until has_all_nodes ; do sleep 0.5 ; done

echo "INFO: waiting for Cilium OLM operator and agent pods..."

until cilium_olm_operator_succeeded ; do sleep 0.5 ; done
until cilium_pods_are_ready ; do sleep 0.5 ; done

echo "INFO: waiting for cluster to report desired version of OpenShift has been installed..."

until has_desired_openshift_version ; do sleep 0.5 ; done
until all_operators_are_happy ; do sleep 0.5 ; done

reported_openshift_version="$(kubectl get clusterversion version --output="jsonpath={.status.history[0].version}")"

if ! [ "${reported_openshift_version}" = "${openshift_version}" ] ; then
  echo "ERROR: version mismatch ${reported_openshift_version} (reported) is not the same as ${openshift_version} (requested)"
  exit 2
fi


