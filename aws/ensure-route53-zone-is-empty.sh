#!/bin/bash

# Copyright 2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  
export AWS_SHARED_CREDENTIALS_FILE="${script_dir}/aws_credentials.ini"

zone_id="${1}"

env > test-script-env
 
# it should be sufficient to clear *.apps record for Cilium CI use-cases,
# but in a more general cases it's possible for users to add other records
change_batch="$(aws route53 list-resource-record-sets --hosted-zone-id "${zone_id}" \
  | jq '.ResourceRecordSets[] | select(.Name | contains("052.apps.")) | {Changes: [{Action: "DELETE", ResourceRecordSet: . }]}')"

if [ -n "${change_batch}" ] ; then
  aws route53 change-resource-record-sets --hosted-zone-id "${zone_id}" --change-batch "${change_batch}"
fi
