#!/bin/bash

# Copyright 2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

cluster_name="${1}"

/Users/ilya/Code/openshift/openshift-install-ocp-4.6.12 create ignition-configs --dir "${cluster_name}"
