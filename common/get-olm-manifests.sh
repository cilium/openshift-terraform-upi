#!/bin/bash

# Copyright 2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

# this script downloads appropriate version of OLM manifests from cilium/cilium-olm repo;
# this is runtime download as terraform modules don't allow using variables for revisions

set -o errexit
set -o pipefail
set -o nounset

cilium_olm_repo="${1}"
cilium_olm_rev="${2}"
cilium_version="${3}"
config_dir="${4}"

temp_file="$(mktemp)"
temp_dir="$(mktemp -d)"

curl --silent --location --fail --show-error "https://github.com/${cilium_olm_repo}/archive/${cilium_olm_rev}.tar.gz" --output "${temp_file}"

tar -C "${temp_dir}" -xf "${temp_file}"

cd "${temp_dir}/cilium-olm-${cilium_olm_rev}/manifests/cilium.v${cilium_version}"

manifests=($(ls))

for manifest in "${manifests[@]}" ; do
  mv -v "${manifest}" "${config_dir}"
done

cd -
rm -rf "${temp_file}" "${temp_dir}"

echo "wrote ${#manifests[@]} manifests to ${config_dir}: ${manifests[@]}"
echo "all files in ${config_dir}: $(ls "${config_dir}")"
