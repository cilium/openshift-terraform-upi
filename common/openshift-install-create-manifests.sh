#!/bin/bash

# Copyright 2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

distro="${1}"
version="${2}"

config_dir="${3}"

install_config_path="${4}"

binary="${script_dir}/bin/openshift-install-${distro}-${version}"

rm -rf "${config_dir}"
mkdir "${config_dir}"

cp "${install_config_path}" "${config_dir}/install-config.yaml"

"${binary}" create manifests --dir "${config_dir}"

# remove machines and machinesets, since these are not compatible
# with CloudFormation UPI, which is what's recommeded in the docs
cd "${config_dir}/openshift"
rm -f 99_openshift-cluster-api_master-machines-*.yaml
rm -f 99_openshift-cluster-api_worker-machineset-*.yaml
