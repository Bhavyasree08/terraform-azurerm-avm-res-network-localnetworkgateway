terraform {
  required_version = "~> 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.74"
    }
    modtm = {
      source  = "azure/modtm"
      version = "~> 0.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  features {}
}


## Section to provide a random Azure region for the resource group
# This allows us to randomize the region for the resource group.
module "regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "~> 0.1"
}

# This allows us to randomize the region for the resource group.
resource "random_integer" "region_index" {
  max = length(module.regions.regions) - 1
  min = 0
}
## End of section to provide a random Azure region for the resource group

# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.3"
}

# We need this to get the object_id of the current user
data "azurerm_client_config" "current" {}

# We use the role definition data source to get the id of the Contributor role
data "azurerm_role_definition" "example" {
  name = "Contributor"
}

# This is required for resource modules
resource "azurerm_resource_group" "this" {
  location = module.regions.regions[random_integer.region_index.result].name
  name     = module.naming.resource_group.name_unique
}

module "local_network_gateway" {
  source = "../.."
  #source             = "Azure/terraform-azurerm-avm-res-network-localnetworkgateway/azurerm"

  # Resource group variables
  location = azurerm_resource_group.this.location                         
  name     = "example-local-network"           
  tags     = {}   

  # Local network gateway variables
  resource_group_name = azurerm_resource_group.this.name    
  gateway_address     = "192.168.1.1"               
  address_space       = ["192.168.0.0/24"]          

  # BGP settings (optional)
  bgp_settings = {
    asn                 = 65010                      
    bgp_peering_address = "192.168.2.1"               
    peer_weight         = 0                          
  }
  enable_telemetry = var.enable_telemetry # see variables.tf

  role_assignments = {
    role_assignment_1 = {
      role_definition_id_or_name       = data.azurerm_role_definition.example.name
      principal_id                     = coalesce(var.msi_id, data.azurerm_client_config.current.object_id)
      skip_service_principal_aad_check = false
    },
    role_assignment_2 = {
      role_definition_id_or_name       = "Owner"
      principal_id                     = data.azurerm_client_config.current.object_id
      skip_service_principal_aad_check = false
    },
  }

  diagnostic_settings = {
    lan = {
      name                                     = "diag"
      workspace_resource_id                    = azurerm_log_analytics_workspace.this.id
      log_categories                           = ["audit", "alllogs"]
      metric_categories                        = ["Capacity", "Transaction"]
      eventhub_name                            = azurerm_eventhub.this.name
      event_hub_authorization_rule_resource_id = "${azurerm_eventhub_namespace.this.id}/authorizationRules/RootManageSharedAccessKey"
    }
  }
}

#Log Analytics Workspace for diagnostic settings
resource "azurerm_log_analytics_workspace" "this" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.log_analytics_workspace.name_unique
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
}

resource "azurerm_eventhub_namespace" "this" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.eventhub_namespace.name_unique
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"
  capacity            = 2
  tags = {
    environment = "Production"
  }
}

resource "azurerm_eventhub" "this" {
  message_retention   = 7
  name                = module.naming.eventhub_namespace.name_unique
  namespace_name      = azurerm_eventhub_namespace.this.name
  partition_count     = 2
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_eventhub_authorization_rule" "this" {
  eventhub_name       = azurerm_eventhub.this.name
  name                = module.naming.eventhub_authorization_rule.name_unique
  namespace_name      = azurerm_eventhub_namespace.this.name
  resource_group_name = azurerm_resource_group.this.name
  listen              = true
  manage              = false
  send                = false
}