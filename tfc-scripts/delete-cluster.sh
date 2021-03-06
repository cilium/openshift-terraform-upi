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
  until [ "$(kubectl --namespace="${namespace}" get executions "${execution_name}" --output="jsonpath={.status.mostRecentJob.action}")" = "Destroy" ] ; do sleep 0.5 ; done
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
  # the job can get deleted quite quickly on success, so need to check that first
  pods=($(kubectl get pods --namespace="${namespace}" --selector="job-name=${job_name}" --output="jsonpath={range .items[*]}{.metadata.name}{\"\n\"}{end}"))
  if [ "${#pods[@]}" -eq 1 ] ; then
    kubectl get pods --namespace="${namespace}" --selector="job-name=${job_name}" --output="jsonpath={.items[0].status.containerStatuses[0].state.terminated.exitCode}"
  else
    # assume success
    echo 0
  fi
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


echo "INFO: deleting ${name}..."

kubectl delete --namespace="${namespace}" execution "${execution_name}" --wait=false

wait_for_job

wait_for_pod

follow_logs

if ! container_status ; then
  bail 1
fi

bail 0
