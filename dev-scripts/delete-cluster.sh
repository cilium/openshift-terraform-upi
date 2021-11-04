#!/bin/bash

# Copyright 2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$#" -eq 1 ] ; then
  echo "$0 supports exactl one argument"
  echo "example: '$0 test-1'"
  exit 1
fi

name="${1}"
kubeconfig_path="${script_dir}/${name}.kubeconfig"

module_path="$(pwd)/${name}"
cd "${module_path}"

terraform destroy -auto-approve

rm -f "${kubeconfig_path}"
rm -rf "${module_path}
