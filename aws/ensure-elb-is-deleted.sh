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
  echo "will delete ELB ${elb_name}"
  aws elb delete-load-balancer --load-balancer-name "${elb_name}"
done

for elb_security_group in "${elb_security_groups[@]}" ; do
  echo "will delete SG ${elb_security_group}"
  until aws ec2 delete-security-group --group-id "${elb_security_group}" ; do
    # it's expected for ELB deletion to take some time for all resources to go
    # it's also expected that this script succeeds on the first attempt, as on
    # second attempt there is no ELB any more, finding out the SG is would
    # require an additional API call, which doesn't seem necessary otherwise
    echo "failed to delete ${elb_security_group}, will keep trying..."
    sleep 1
  done
done
