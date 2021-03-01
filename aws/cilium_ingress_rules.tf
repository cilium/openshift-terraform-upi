locals {
  cilium_ports = [
      {
        port = 8472
        protocol = "udp"
      },
      {
        port = 4240
        protocol = "tcp"
      },
      {
        port = -1
        protocol = "icmp"
      },
  ]

  cilium_ingress_rules = flatten([
    for pair in setproduct(local.cilium_ports, [[local.worker_sg, local.master_sg], [local.master_sg, local.worker_sg]]) : [
      {
        port = pair[0].port
        protocol = pair[0].protocol
        security_group_id = pair[1][0]
        source_security_group_id = pair[1][0]
      },
      {
        port = pair[0].port
        protocol = pair[0].protocol
        security_group_id = pair[1][0]
        source_security_group_id = pair[1][1]
      },
    ]
  ])
}


resource aws_security_group_rule cilium_ingress_rules {
  for_each = {
    for index, rule in local.cilium_ingress_rules : "rule_${index}_${rule.port}_${rule.protocol}" => rule
  }

  type = "ingress"

  from_port = each.value.port
  to_port = each.value.port
  protocol = each.value.protocol
  security_group_id = each.value.security_group_id 
  source_security_group_id = each.value.source_security_group_id 
}
