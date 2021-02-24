#!/bin/bash

# Copyright 2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

# this script downloads appropriate openshift-install binary based on the given distro
# and version; runtime downloads are preferred because it wouldn't be feasible to include
# all possible versions in the terraform executor image

set -o errexit
set -o pipefail
set -o nounset

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

distro="${1}"
version="${2}"

binary="${script_dir}/bin/openshift-install-${distro}-${version}"
mkdir -p "${script_dir}/bin"

if test -x "${binary}" ; then
  echo "${binary} exists"
  "${binary}" version
  exit
fi

client_os="linux"
if [ "$(uname)" = "Darwin" ] ; then
    client_os="mac"
fi

tarball="openshift-install-${client_os}-${version}.tar.gz"

url_prefix="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/${version}"

if [ "${distro}" = "okd" ] ; then
  url_prefix="https://github.com/openshift/okd/releases/download/${version}"
fi

temp_dir="$(mktemp -d)"
cd "${temp_dir}"
curl --silent --fail --show-error --location --remote-name "${url_prefix}/${tarball}"
tar xf "${tarball}" openshift-install
mv openshift-install "${binary}"
cd "${script_dir}"
rm -rf "${temp_dir}"

echo "${binary} installed"
"${binary}" version
