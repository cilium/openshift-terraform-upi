#!/bin/bash

# Copyright 2021 Authors of Cilium
# SPDX-License-Identifier: Apache-2.0

set -o errexit
set -o pipefail
set -o nounset

deployment_uri="${1}"

deployment_name="$(gcloud deployment-manager deployments describe "${deployment_uri}" --format="value(deployment.name)")"

network_url="$(gcloud deployment-manager resources list --deployment="${deployment_name}" --filter="type:compute.v1.network"  --format="value(url)")"

firewall_rules_urls=($(gcloud compute firewall-rules list --filter="network:${network_url} AND name ~ ^k8s-.*$" --format="value(selfLink)"))

if [ "${#firewall_rules_urls[@]}" -gt 0 ] ; then
  gcloud compute firewall-rules delete --quiet "${firewall_rules_urls[@]}"
fi

forwarding_rules_urls=($(gcloud compute forwarding-rules list --filter="network:${network_url}" --format="value(selfLink)"))

if [ "${#forwarding_rules_urls[@]}" -gt 0 ] ; then
  gcloud compute forwarding-rules delete --quiet "${forwarding_rules_urls[@]}"
fi
