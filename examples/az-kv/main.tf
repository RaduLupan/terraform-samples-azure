# This template deploys the following Azure resources:
# - 1 x Key Vault in existing resource group
# - The Key Vault firewall allows traffic from existing vnet subnet via service endpoint
# - Key Vault Access Policies for multiple existing VMs allowing them to access keys/secrets/certificates

# Terraform 0.12 syntax is used so 0.12 is the minimum required version
terraform {
  required_version = ">= 0.12"
}

provider "azurerm" {
    version = "2.10.0"
    subscription_id = var.subscriptionID
    features {
        # Terraform will automatically recover a soft-deleted Key Vault during creation if one is found.
        # This feature opts out of this behaviour.
        key_vault {
            purge_soft_delete_on_destroy = true
        }
    }
}

locals {
    project = "terraform-samples"
    environment = "dev"
}

## Use this data source to access the configuration of the AzureRM provider.
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "az_key_vault" {
  name                        = "kv-1-${local.environment}"
  location                    = var.location
  resource_group_name         = var.resourceGroup
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_enabled         = true
  purge_protection_enabled    = false

  sku_name = "standard"

  # Boolean flag to specify whether Azure Virtual Machines are permitted to retrieve certificates stored as secrets from the key vault. Defaults to false.
  enabled_for_deployment = true

  # Uncomment this line if Azure Disk Encryption is permitted to retrieve secrets from the vault and unwrap keys.
  # enabled_for_disk_encryption = true

  # Uncomment this line if Azure Resource Manager is permitted to retrieve secrets from the key vault.
  # enabled_for_template_deployment = true

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    # To allow this vnet subnet through the key vault firewall, a service endpoint for Microsoft.KeyVault must be enabled at the subnet level.
    virtual_network_subnet_ids = var.subnetIds
  }

  tags = {
    environment = "${local.environment}"
    project     = "${local.project}"
  }
}

# Use this data source to access information about an existing Virtual Machine. Uses same naming pattern as the az-lb-vm template that provisioned the VMs.
data "azurerm_virtual_machine" "web" {
  count = var.vmNumber

  name                = "vm-${var.serverName}-${count.index}"
  resource_group_name = var.resourceGroup
}

resource "azurerm_key_vault_access_policy" "web_key_vault_access_policy" {
  count = var.vmNumber

  key_vault_id = azurerm_key_vault.az_key_vault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  
  # In order to be able to export the identity of a VM I had to upgrade the provider version to 2.10.0.
  # https://github.com/terraform-providers/terraform-provider-azurerm/pull/6826
  # Also, had to check the properties of a VM in terraform.tfstate file to figure out that identity is a list, identity[0] is the first object in that list
  # and principal_id is one of its properties.
  # Finally, in order to resolve ${count.index} you need to enclose it in quotes, NOT the entire expresion as a Powershel user might think!
  object_id    = data.azurerm_virtual_machine.web["${count.index}"].identity[0].principal_id
  
  key_permissions = [
    "get",
    "list",
    "create",
    "update",
  ]

  secret_permissions = [
    "get",
    "list",
    "set",
    "restore",
  ]

  certificate_permissions = [
    "get",
    "list",
    "create",
    "update",
  ]
}