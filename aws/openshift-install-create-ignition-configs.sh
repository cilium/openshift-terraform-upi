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

binary="${script_dir}/bin/openshift-install-${distro}-${version}"

"${binary}" create ignition-configs --dir "${config_dir}"
