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
}