#!/bin/bash

# Copyright 2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  
export AWS_CONFIG_FILE="${script_dir}/aws_config.ini"

region="${1}"
vpc_id="${2}"

elb_names=($(aws elb describe-load-balancers | jq -r --arg vpc_id "${vpc_id}" '.LoadBalancerDescriptions[] | select(.VPCId == $vpc_id) | .LoadBalancerName'))

for elb_name in "${elb_names[@]}" ; do
  aws elb delete-load-balancer --load-balancer-name "${elb_name}"
done
