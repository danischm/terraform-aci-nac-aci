module "aci_firmware_group" {
  source  = "netascode/firmware-group/aci"
  version = "0.1.0"

  for_each = { for np in try(local.node_policies.update_groups, {}) : np.name => np if local.modules.aci_firmware_group && var.manage_node_policies }
  name     = "${each.value.name}${local.defaults.apic.node_policies.update_groups.name_suffix}"
  node_ids = [for node in try(local.node_policies.nodes, []) : node.id if try(node.update_group, "") == each.value.name]
}

module "aci_maintenance_group" {
  source  = "netascode/maintenance-group/aci"
  version = "0.1.0"

  for_each = { for np in try(local.node_policies.update_groups, {}) : np.name => np if local.modules.aci_maintenance_group && var.manage_node_policies }
  name     = "${each.value.name}${local.defaults.apic.node_policies.update_groups.name_suffix}"
  node_ids = [for node in try(local.node_policies.nodes, []) : node.id if try(node.update_group, "") == each.value.name]
}

module "aci_vpc_group" {
  source  = "netascode/vpc-group/aci"
  version = "0.2.0"

  count = local.modules.aci_vpc_group == true && var.manage_node_policies ? 1 : 0
  mode  = try(local.node_policies.vpc_groups.mode, local.defaults.apic.node_policies.vpc_groups.mode)
  groups = [for group in try(local.node_policies.vpc_groups.groups, []) : {
    name     = try(group.name, replace("${group.id}:${group.switch_1}:${group.switch_2}", "/^(?P<id>.+):(?P<switch1_id>.+):(?P<switch2_id>.+)$/", replace(replace(replace(try(local.access_policies.vpc_group_name, local.defaults.apic.access_policies.vpc_group_name), "\\g<id>", "$${id}"), "\\g<switch1_id>", "$${switch1_id}"), "\\g<switch2_id>", "$${switch2_id}")))
    id       = group.id
    policy   = try(group.policy, "")
    switch_1 = group.switch_1
    switch_2 = group.switch_2
  }]

  depends_on = [
    module.aci_access_leaf_switch_profile_auto,
    module.aci_access_leaf_switch_profile_manual,
  ]
}

module "aci_node_registration" {
  source  = "netascode/node-registration/aci"
  version = "0.1.1"

  for_each       = { for node in try(local.node_policies.nodes, []) : node.id => node if contains(["leaf", "spine"], node.role) && local.modules.aci_node_registration && var.manage_node_policies }
  name           = each.value.name
  node_id        = each.value.id
  pod_id         = try(each.value.pod, local.defaults.apic.node_policies.nodes.pod)
  serial_number  = each.value.serial_number
  type           = try(each.value.type, "unspecified")
  remote_pool_id = try(each.value.remote_pool_id, 0)

  depends_on = [
    module.aci_l3out_interface_profile_auto, # Remote leafs need to be removed before infra l3out
    module.aci_l3out_interface_profile_manual,
  ]
}

module "aci_inband_node_address" {
  source  = "netascode/inband-node-address/aci"
  version = "0.2.0"

  for_each            = { for node in try(local.node_policies.nodes, []) : node.id => node if(try(node.inb_address, null) != null || try(node.inb_v6_address, null) != null) && local.modules.aci_inband_node_address && var.manage_node_policies }
  node_id             = each.value.id
  pod_id              = try(each.value.pod, local.defaults.apic.node_policies.nodes.pod)
  ip                  = try(each.value.inb_address, "")
  gateway             = try(each.value.inb_gateway, "")
  v6_ip               = try(each.value.inb_v6_address, "")
  v6_gateway          = try(each.value.inb_v6_gateway, "")
  endpoint_group      = try(local.node_policies.inb_endpoint_group, local.defaults.apic.node_policies.inb_endpoint_group)
  endpoint_group_vlan = [for epg in local.inband_endpoint_groups : epg.vlan if epg.name == try(local.node_policies.inb_endpoint_group, local.defaults.apic.node_policies.inb_endpoint_group)][0]
}

module "aci_oob_node_address" {
  source  = "netascode/oob-node-address/aci"
  version = "0.1.3"

  for_each       = { for node in try(local.node_policies.nodes, []) : node.id => node if(try(node.oob_address, null) != null || try(node.oob_v6_address, null) != null) && local.modules.aci_oob_node_address && var.manage_node_policies }
  node_id        = each.value.id
  pod_id         = try(each.value.pod, local.defaults.apic.node_policies.nodes.pod)
  ip             = try(each.value.oob_address, "")
  gateway        = try(each.value.oob_gateway, "")
  v6_ip          = try(each.value.oob_v6_address, "")
  v6_gateway     = try(each.value.oob_v6_gateway, "")
  endpoint_group = try(local.node_policies.oob_endpoint_group, local.defaults.apic.node_policies.oob_endpoint_group)
}
