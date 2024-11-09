resource "azurerm_local_network_gateway" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  gateway_address     = var.gateway_address
  address_space       = var.address_space

 dynamic "bgp_settings" {
    for_each = var.bgp_settings != null ? [var.bgp_settings] : []
    content {
      asn                 = lookup(bgp_settings.value, "asn", null)
      bgp_peering_address = lookup(bgp_settings.value, "bgp_peering_address", null)
      peer_weight         = lookup(bgp_settings.value, "peer_weight", null)
    }
  }
  tags = var.tags
}

# required AVM resources interfaces
resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = azurerm_local_network_gateway.this.id 
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}

resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  principal_id                           = each.value.principal_id
  scope                                  = azurerm_local_network_gateway.this.id
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  role_definition_id                     = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? each.value.role_definition_id_or_name : null
  role_definition_name                   = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? null : each.value.role_definition_id_or_name
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}