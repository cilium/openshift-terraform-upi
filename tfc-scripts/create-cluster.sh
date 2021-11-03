#!/bin/bash

# Copyright 2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

original_pwd="$(pwd)"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "${script_dir}"

if [ "$#" -ne 5 ] ; then
  echo "$0 supports exactly 5 argument"
  echo "example: '$0 test-1 aws/default-aws-execution.sh ocp 4.6.18 1.9.5'"
  exit 1
fi

name="${1}"
execution_template_path="${2}"
openshift_distro="${3}"
openshift_version="${4}"
cilium_version="${5}"

namespace="terraform-system"
execution_name="openshift-ci-${name}"

follow_logs() {
  echo "INFO: streaming container logs"
  kubectl logs --namespace="${namespace}" --selector="job-name=${job_name}" --follow || true
}

bail() {
  exit "$1"
}

one_pod_running() {
  # shellcheck disable=SC2207
  pods=($(kubectl get pods --namespace="${namespace}" --selector="job-name=${job_name}" --output="jsonpath={range .items[?(.status.phase == \"Running\")]}{.metadata.name}{\"\n\"}{end}"))
  test "${#pods[@]}" -eq 1
}

one_pod_failed() {
  # shellcheck disable=SC2207
  pods=($(kubectl get pods --namespace="${namespace}" --selector="job-name=${job_name}" --output="jsonpath={range .items[?(.status.phase == \"Failed\")]}{.metadata.name}{\"\n\"}{end}"))
  test "${#pods[@]}" -eq 1
}

wait_for_job() {
  echo "INFO: waiting for the terraform execution to create a job..."
  until [ "$(kubectl --namespace="${namespace}" get executions "${execution_name}" --output="jsonpath={.status.mostRecentJob.action}")" = "Apply" ] ; do sleep 0.5 ; done
  until [ "$(kubectl --namespace="${namespace}" get executions "${execution_name}" --output="jsonpath={.status.mostRecentJob.state}")" = "Running" ] ; do sleep 0.5 ; done
  job_name="$(kubectl --namespace="${namespace}" get executions "${execution_name}" --output="jsonpath={.status.mostRecentJob.jobName}")"
}

wait_for_pod() {
  echo "INFO: waiting for the terraform execution job to start..."
  # kubectl wait job only supports two condtions - complete or failed,
  # so wait for a pod to get scheduled
  # TODO: this doesn't check if job failed to create pods, which can happen
  # if there is configuration issue
  until kubectl wait pods --namespace="${namespace}" --selector="job-name=${job_name}" --for="condition=PodScheduled" --timeout="2m" 2> /dev/null ; do sleep 0.5 ; done
  # kubectl wait doesn't support multiple conditions, and `wait -n` is not
  # available in all common versions of bash, so poll pod status instead
  until one_pod_running || one_pod_failed ; do
    kubectl get pods --namespace="${namespace}" --selector="job-name=${job_name}" --show-kind --no-headers
    sleep 0.5
  done
}

get_container_exit_code() {
  kubectl get pods --namespace="${namespace}" --selector="job-name=${job_name}" --output="jsonpath={.items[0].status.containerStatuses[0].state.terminated.exitCode}"
}

container_status() {
  echo "INFO: getting container status..."
  # sometimes the value doesn't parse as a number, before this is re-written in Go
  # it will have to be done like this
  until test -n "$(get_container_exit_code)" ; do sleep 0.5 ; done
  exit_code="$(get_container_exit_code)"
  echo "INFO: container exited with ${exit_code}"
  return "${exit_code}"
}

if [ -e "${original_pwd}/${execution_template_path}" ] ; then
  source "${original_pwd}/${execution_template_path}"
else
  source "${execution_template_path}"
fi

wait_for_job

wait_for_pod

follow_logs

if ! container_status ; then
  bail 1
fi

kubeconfig_path="${script_dir}/${name}.kubeconfig"

kubectl --namespace="${namespace}" get secrets "${job_name}" --output="jsonpath={.data.outputFile}" | base64 -d | jq -r .cluster_kubeconfig.value | base64 -d > "${kubeconfig_path}"

echo "INFO: wrote ${kubeconfig_path}"

KUBECONFIG="${kubeconfig_path}" "${script_dir}/../common/wait-cluster-ready.sh" "${name}" "${openshift_distro}" "${openshift_version}" "${cilium_version}"

bail 0
