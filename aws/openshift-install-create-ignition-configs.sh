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

shift 3

worker_machinesets=("${@}")

binary="${script_dir}/bin/openshift-install-${distro}-${version}"

# add generated worker machinesets here as it's most convenient
# having another null_resource for this wouldn't make a lot of sense
cp "${worker_machinesets[@]}" "${config_dir}/openshift"

"${binary}" create ignition-configs --dir "${config_dir}"
