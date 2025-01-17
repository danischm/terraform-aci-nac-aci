locals {
  access_fex_interface_profiles = flatten([
    for node in local.nodes : [
      for fex in try(node.fexes, []) : {
        key  = format("%s/%s", node.id, fex.id)
        name = replace("${node.id}:${node.name}:${fex.id}", "/^(?P<id>.+):(?P<name>.+):(?P<fex>.+)$/", replace(replace(replace(try(local.access_policies.fex_profile_name, local.defaults.apic.access_policies.fex_profile_name), "\\g<id>", "$${id}"), "\\g<name>", "$${name}"), "\\g<fex>", "$${fex}"))
      }
    ] if(try(local.apic.auto_generate_switch_pod_profiles, local.defaults.apic.auto_generate_switch_pod_profiles) || try(local.apic.auto_generate_access_leaf_switch_interface_profiles, local.defaults.apic.auto_generate_access_leaf_switch_interface_profiles)) && node.role == "leaf"
  ])
}

module "aci_access_fex_interface_profile_auto" {
  source  = "netascode/access-fex-interface-profile/aci"
  version = "0.1.0"

  for_each = { for profile in local.access_fex_interface_profiles : profile.key => profile if local.modules.aci_access_fex_interface_profile && var.manage_interface_policies }
  name     = each.value.name
}

locals {
  access_leaf_interface_selectors = flatten([
    for node in local.nodes : [
      for interface in try(node.interfaces, []) : {
        key                   = format("%s/%s/%s", node.id, try(interface.module, local.defaults.apic.access_policies.fex_interface_profiles.selectors.port_blocks.from_module), interface.port)
        name                  = replace(format("%s:%s", try(interface.module, local.defaults.apic.access_policies.leaf_interface_profiles.selectors.port_blocks.from_module), interface.port), "/^(?P<mod>.+):(?P<port>.+)$/", replace(replace(try(local.access_policies.leaf_interface_selector_name, local.defaults.apic.access_policies.leaf_interface_selector_name), "\\g<mod>", "$${mod}"), "\\g<port>", "$${port}"))
        interface_profile     = replace("${node.id}:${node.name}", "/^(?P<id>.+):(?P<name>.+)$/", replace(replace(try(local.access_policies.leaf_interface_profile_name, local.defaults.apic.access_policies.leaf_interface_profile_name), "\\g<id>", "$${id}"), "\\g<name>", "$${name}"))
        fex_id                = try(interface.fex_id, 0)
        fex_interface_profile = try(replace("${node.id}:${node.name}:${interface.fex_id}", "/^(?P<id>.+):(?P<name>.+):(?P<fex>.+)$/", replace(replace(replace(try(local.access_policies.fex_profile_name, local.defaults.apic.access_policies.fex_profile_name), "\\g<id>", "$${id}"), "\\g<name>", "$${name}"), "\\g<fex>", "$${fex}")), "")
        policy_group          = try("${interface.policy_group}${local.defaults.apic.access_policies.leaf_interface_policy_groups.name_suffix}", "")
        policy_group_type     = try([for pg in local.access_policies.leaf_interface_policy_groups : pg.type if pg.name == interface.policy_group][0], "access")
        port_blocks = [{
          description = try(interface.description, "")
          name        = format("%s-%s", try(interface.module, local.defaults.apic.access_policies.leaf_interface_profiles.selectors.port_blocks.from_module), interface.port)
          from_module = try(interface.module, local.defaults.apic.access_policies.leaf_interface_profiles.selectors.port_blocks.from_module)
          from_port   = interface.port
          to_module   = try(interface.module, local.defaults.apic.access_policies.leaf_interface_profiles.selectors.port_blocks.from_module)
          to_port     = interface.port
        }]
      }
    ] if(try(local.apic.auto_generate_switch_pod_profiles, local.defaults.apic.auto_generate_switch_pod_profiles) || try(local.apic.auto_generate_access_leaf_switch_interface_profiles, local.defaults.apic.auto_generate_access_leaf_switch_interface_profiles)) && node.role == "leaf" && (length(var.managed_interface_policies_nodes) == 0 || contains(var.managed_interface_policies_nodes, node.id))
  ])
}

module "aci_access_leaf_interface_selector_auto" {
  source  = "netascode/access-leaf-interface-selector/aci"
  version = "0.2.1"

  for_each              = { for selector in local.access_leaf_interface_selectors : selector.key => selector if local.modules.aci_access_leaf_interface_selector && var.manage_interface_policies }
  name                  = each.value.name
  interface_profile     = each.value.interface_profile
  fex_id                = each.value.fex_id
  fex_interface_profile = each.value.fex_interface_profile
  policy_group          = each.value.policy_group
  policy_group_type     = each.value.policy_group_type
  port_blocks           = each.value.port_blocks

  depends_on = [
    module.aci_access_leaf_interface_profile_auto
  ]
}

locals {
  access_sub_interface_selectors = flatten([
    for node in local.nodes : [
      for interface in try(node.interfaces, []) : [
        for sub in try(interface.sub_ports, []) : {
          key                   = format("%s/%s/%s/%s", node.id, try(interface.module, local.defaults.apic.access_policies.fex_interface_profiles.selectors.port_blocks.from_module), interface.port, sub.port)
          name                  = replace(format("%s:%s:%s", try(interface.module, local.defaults.apic.access_policies.leaf_interface_profiles.selectors.port_blocks.from_module), interface.port, sub.port), "/^(?P<mod>.+):(?P<port>.+):(?P<sport>.+)$/", replace(replace(replace(try(local.access_policies.leaf_interface_selector_sub_port_name, local.defaults.apic.access_policies.leaf_interface_selector_sub_port_name), "\\g<mod>", "$${mod}"), "\\g<port>", "$${port}"), "\\g<sport>", "$${sport}"))
          interface_profile     = replace("${node.id}:${node.name}", "/^(?P<id>.+):(?P<name>.+)$/", replace(replace(try(local.access_policies.leaf_interface_profile_name, local.defaults.apic.access_policies.leaf_interface_profile_name), "\\g<id>", "$${id}"), "\\g<name>", "$${name}"))
          fex_id                = try(sub.fex_id, 0)
          fex_interface_profile = try(replace("${node.id}:${node.name}:${sub.fex_id}", "/^(?P<id>.+):(?P<name>.+):(?P<fex>.+)$/", replace(replace(replace(try(local.access_policies.fex_profile_name, local.defaults.apic.access_policies.fex_profile_name), "\\g<id>", "$${id}"), "\\g<name>", "$${name}"), "\\g<fex>", "$${fex}")), "")
          policy_group          = try("${sub.policy_group}${local.defaults.apic.access_policies.leaf_interface_policy_groups.name_suffix}", "")
          policy_group_type     = try([for pg in local.access_policies.leaf_interface_policy_groups : pg.type if pg.name == sub.policy_group][0], "access")
          sub_port_blocks = [{
            description   = try(sub.description, "")
            name          = format("%s-%s-%s", try(interface.module, local.defaults.apic.access_policies.leaf_interface_profiles.selectors.port_blocks.from_module), interface.port, sub.port)
            from_module   = try(interface.module, local.defaults.apic.access_policies.leaf_interface_profiles.selectors.port_blocks.from_module)
            from_port     = interface.port
            to_module     = try(interface.module, local.defaults.apic.access_policies.leaf_interface_profiles.selectors.port_blocks.from_module)
            to_port       = interface.port
            from_sub_port = sub.port
            to_sub_port   = sub.port
          }]
        }
      ]
    ] if(try(local.apic.auto_generate_switch_pod_profiles, local.defaults.apic.auto_generate_switch_pod_profiles) || try(local.apic.auto_generate_access_leaf_switch_interface_profiles, local.defaults.apic.auto_generate_access_leaf_switch_interface_profiles)) && node.role == "leaf" && (length(var.managed_interface_policies_nodes) == 0 || contains(var.managed_interface_policies_nodes, node.id))
  ])
}

module "aci_access_leaf_interface_selector_sub_auto" {
  source  = "netascode/access-leaf-interface-selector/aci"
  version = "0.2.1"

  for_each              = { for selector in local.access_sub_interface_selectors : selector.key => selector if local.modules.aci_access_leaf_interface_selector && var.manage_interface_policies }
  name                  = each.value.name
  interface_profile     = each.value.interface_profile
  fex_id                = each.value.fex_id
  fex_interface_profile = each.value.fex_interface_profile
  policy_group          = each.value.policy_group
  policy_group_type     = each.value.policy_group_type
  sub_port_blocks       = each.value.sub_port_blocks

  depends_on = [
    module.aci_access_leaf_interface_profile_auto
  ]
}

locals {
  access_fex_interface_selectors = flatten([
    for node in local.nodes : [
      for fex in try(node.fexes, []) : [
        for interface in try(fex.interfaces, []) : {
          key               = format("%s/%s/%s/%s", node.id, fex.id, try(interface.module, local.defaults.apic.access_policies.fex_interface_profiles.selectors.port_blocks.from_module), interface.port)
          name              = replace(format("%s:%s", try(interface.module, local.defaults.apic.access_policies.fex_interface_profiles.selectors.port_blocks.from_module), interface.port), "/^(?P<mod>.+):(?P<port>.+)$/", replace(replace(try(local.access_policies.fex_interface_selector_name, local.defaults.apic.access_policies.fex_interface_selector_name), "\\g<mod>", "$${mod}"), "\\g<port>", "$${port}"))
          profile_name      = replace("${node.id}:${node.name}:${fex.id}", "/^(?P<id>.+):(?P<name>.+):(?P<fex>.+)$/", replace(replace(replace(try(local.access_policies.fex_profile_name, local.defaults.apic.access_policies.fex_profile_name), "\\g<id>", "$${id}"), "\\g<name>", "$${name}"), "\\g<fex>", "$${fex}"))
          policy_group      = try("${interface.policy_group}${local.defaults.apic.access_policies.leaf_interface_policy_groups.name_suffix}", "")
          policy_group_type = try([for pg in local.access_policies.leaf_interface_policy_groups : pg.type if pg.name == interface.policy_group][0], "access")
          port_blocks = [{
            description = try(interface.description, "")
            name        = format("%s-%s", try(interface.module, local.defaults.apic.access_policies.fex_interface_profiles.selectors.port_blocks.from_module), interface.port)
            from_module = try(interface.module, local.defaults.apic.access_policies.fex_interface_profiles.selectors.port_blocks.from_module)
            from_port   = interface.port
            to_module   = try(interface.module, local.defaults.apic.access_policies.fex_interface_profiles.selectors.port_blocks.from_module)
            to_port     = interface.port
          }]
        }
      ]
    ] if(try(local.apic.auto_generate_switch_pod_profiles, local.defaults.apic.auto_generate_switch_pod_profiles) || try(local.apic.auto_generate_access_leaf_switch_interface_profiles, local.defaults.apic.auto_generate_access_leaf_switch_interface_profiles)) && node.role == "leaf" && (length(var.managed_interface_policies_nodes) == 0 || contains(var.managed_interface_policies_nodes, node.id))
  ])
}

module "aci_access_fex_interface_selector_auto" {
  source  = "netascode/access-fex-interface-selector/aci"
  version = "0.2.0"

  for_each          = { for selector in local.access_fex_interface_selectors : selector.key => selector if local.modules.aci_access_fex_interface_selector && var.manage_interface_policies }
  name              = each.value.name
  interface_profile = each.value.profile_name
  policy_group      = each.value.policy_group
  policy_group_type = each.value.policy_group_type
  port_blocks       = each.value.port_blocks

  depends_on = [
    module.aci_access_fex_interface_profile_auto
  ]
}

locals {
  access_spine_interface_selectors = flatten([
    for node in local.nodes : [
      for interface in try(node.interfaces, []) : {
        key               = format("%s/%s/%s", node.id, try(interface.module, local.defaults.apic.access_policies.fex_interface_profiles.selectors.port_blocks.from_module), interface.port)
        name              = replace(format("%s:%s", try(interface.module, local.defaults.apic.access_policies.spine_interface_profiles.selectors.port_blocks.from_module), interface.port), "/^(?P<mod>.+):(?P<port>.+)$/", replace(replace(try(local.access_policies.spine_interface_selector_name, local.defaults.apic.access_policies.spine_interface_selector_name), "\\g<mod>", "$${mod}"), "\\g<port>", "$${port}"))
        interface_profile = replace("${node.id}:${node.name}", "/^(?P<id>.+):(?P<name>.+)$/", replace(replace(try(local.access_policies.spine_interface_profile_name, local.defaults.apic.access_policies.spine_interface_profile_name), "\\g<id>", "$${id}"), "\\g<name>", "$${name}"))
        policy_group      = try("${interface.policy_group}${local.defaults.apic.access_policies.spine_interface_policy_groups.name_suffix}", "")
        port_blocks = [{
          name        = format("%s-%s", try(interface.module, local.defaults.apic.access_policies.spine_interface_profiles.selectors.port_blocks.from_module), interface.port)
          description = try(interface.description, "")
          from_module = try(interface.module, local.defaults.apic.access_policies.spine_interface_profiles.selectors.port_blocks.from_module)
          from_port   = interface.port
          to_module   = try(interface.module, local.defaults.apic.access_policies.spine_interface_profiles.selectors.port_blocks.from_module)
          to_port     = interface.port
        }]
      }
    ] if(try(local.apic.auto_generate_switch_pod_profiles, local.defaults.apic.auto_generate_switch_pod_profiles) || try(local.apic.auto_generate_access_spine_switch_interface_profiles, local.defaults.apic.auto_generate_access_spine_switch_interface_profiles)) && node.role == "spine" && (length(var.managed_interface_policies_nodes) == 0 || contains(var.managed_interface_policies_nodes, node.id))
  ])
}

module "aci_access_spine_interface_selector_auto" {
  source  = "netascode/access-spine-interface-selector/aci"
  version = "0.2.0"

  for_each          = { for selector in local.access_spine_interface_selectors : selector.key => selector if local.modules.aci_access_spine_interface_selector && var.manage_interface_policies }
  name              = each.value.name
  interface_profile = each.value.interface_profile
  policy_group      = each.value.policy_group
  port_blocks       = each.value.port_blocks

  depends_on = [
    module.aci_access_spine_interface_profile_auto
  ]
}
