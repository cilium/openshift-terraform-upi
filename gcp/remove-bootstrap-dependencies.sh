#!/bin/bash -x

# Copyright 2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

deployment_uri="${1}"

infrastructure_name="${2}"

deployment_name="$(gcloud deployment-manager deployments describe "${deployment_uri}" --format="value(deployment.name)")"

forwarding_rule_url="$(gcloud deployment-manager resources list --deployment="${deployment_name}" --filter="type:compute.v1.forwardingRule AND name ~ .*api-internal-forwarding-rule"  --format="value(url)")"

backend_service_url="$(gcloud compute forwarding-rules describe "${forwarding_rule_url}" --format="value(backendService)" || true)"

if [ -z "${backend_service_url}" ] ; then
  backend_service_url="$(gcloud compute backend-services list --filter="name ~ ${infrastructure_name}-api-internal-backend-service"  --format="value(selfLink)")"
fi

instance_group_url="$(gcloud compute backend-services describe "${backend_service_url}" --format="value(backends[3].group)" || true)"

if [ -n "${instance_group_url}" ] ; then
  gcloud compute backend-services remove-backend "${backend_service_url}" --instance-group="${instance_group_url}" || true
fi
