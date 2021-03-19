#!/bin/bash

# Copyright 2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export AWS_CONFIG_FILE="${script_dir}/aws_config.ini"

terraform output -json aws_config | jq -r > "${AWS_CONFIG_FILE}"
aws configure list

vpc_id="${1}"
elb_desc_json="$(aws elb describe-load-balancers)"
elb_names=($(echo "${elb_desc_json}" | jq -r --arg vpc_id "${vpc_id}" '.LoadBalancerDescriptions[] | select(.VPCId == $vpc_id) | .LoadBalancerName'))
elb_security_groups=($(echo "${elb_desc_json}" | jq -r --arg vpc_id "${vpc_id}" '.LoadBalancerDescriptions[] | select(.VPCId == $vpc_id) | .SecurityGroups[]'))

for elb_name in "${elb_names[@]}" ; do
  aws elb delete-load-balancer --load-balancer-name "${elb_name}"
done

for elb_security_group in "${elb_security_groups[@]}" ; do
  aws ec2 delete-security-group --group-id "${elb_security_group}"
done
