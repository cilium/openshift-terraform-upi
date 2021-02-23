#!/bin/bash

# Copyright 2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

cluster_name="${1}"

rm -rf "${cluster_name}"
mkdir "${cluster_name}"
cp "${cluster_name}.install-config.yaml" "${cluster_name}/install-config.yaml"

/Users/ilya/Code/openshift/openshift-install-ocp-4.6.12 create manifests --dir "${cluster_name}"
