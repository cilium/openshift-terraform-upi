#!/bin/bash

# Copyright 2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$#" -ne 3 ] ; then
  echo "$0 supports exactly 3 argument"
  echo "example: '$0 gcp test-1 v4.7'"
  exit 1
fi

cloud_provider="${1}"
cluster_name="${2}"
image_tag="${3}"


image="registry.redhat.io/openshift4/ose-tests:${image_tag}"

KUBECONFIG="${KUBECONFIG:-${script_dir}/../openshift_install_config/config/${cluster_name}/state/auth/kubeconfig}"

results_dir="${script_dir}/../${cluster_name}.test_results_$(date +%s)"

mkdir -p "${results_dir}"

docker_args=(
  --volume="${KUBECONFIG}":"/data/kubeconfig"
  --env="KUBECONFIG=/data/kubeconfig"
  --volume="${results_dir}:/data/results"
)

case "${cloud_provider}" in
  gcp)
    docker_args+=(
      --volume="${script_dir}/../gcp/config/${cluster_name}/input/master-sa.json":"/data/master-sa.json"
      --env="GOOGLE_APPLICATION_CREDENTIALS=/data/master-sa.json"
    )
    ;;
  aws)
    ;;
esac

docker run --rm --interactive --tty "${docker_args[@]}" "${image}" openshift-tests run openshift/network/third-party --junit-dir /data/results --output-file /data/results/e2e.log
