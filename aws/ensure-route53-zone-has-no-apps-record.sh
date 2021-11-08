#!/bin/bash

# Copyright 2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# dev-scripts/delete-cluster.sh sets AWS_ACCESS_KEY_ID & AWS_SECRET_ACCESS_KEY
# explicilty, so it can be used easily with local backend, becuse outputs are
# cleared form the state file on deletion...
if [ -z "${AWS_ACCESS_KEY_ID+x}" ] && [ -z "${AWS_SECRET_ACCESS_KEY+x}" ] ; then
  export AWS_CONFIG_FILE="${script_dir}/aws_config.ini"
  # get config from outpus when remote backends are used
  terraform output -json aws_config | jq -r > "${AWS_CONFIG_FILE}"
  aws configure list
fi

zone_id="${1}"

# any ad-hoc records block zone deletion in CloudFormation; it should be sufficient to clear *.apps record
# for Cilium CI use-cases, but in a more general cases it's possible for users to add other records

change_batch="$(aws route53 list-resource-record-sets --hosted-zone-id "${zone_id}" \
  | jq '.ResourceRecordSets[] | select(.Name | contains("052.apps.")) | {Changes: [{Action: "DELETE", ResourceRecordSet: . }]}')"

if [ -n "${change_batch}" ] ; then
  aws route53 change-resource-record-sets --hosted-zone-id "${zone_id}" --change-batch "${change_batch}"
fi

echo "INFO: the Route53 zone should have no *.apps record"
