
##################################################################################
# PROVIDERS
##################################################################################

provider "azurerm" {
  #version = "~> 1.0"
  subscription_id = var.sec_sub_id
  client_id       = var.sec_client_id
  client_secret   = var.sec_client_secret
  skip_provider_registration  = true
  skip_credentials_validation = true
  features {}
}


data "azurerm_client_config" "current" {}

##################################################################################
# RESOURCES
##################################################################################

resource "azurerm_resource_group" "setup" {
  name     = "${var.resource_group_name}-${terraform.workspace}"
  location = var.location
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity
resource "azurerm_user_assigned_identity" "mi" {
  resource_group_name = azurerm_resource_group.setup.name
  location            = azurerm_resource_group.setup.location

  name = var.managed_identity
}

resource "azurerm_storage_account" "sa" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.setup.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

}

resource "azurerm_storage_queue" "queue" {
  name                 = var.storage_queue_name
  storage_account_name = azurerm_storage_account.sa.name
}

# resource "azurerm_virtual_network" "vnet" {
#   name                = "example-vnet"
#   address_space       = ["10.0.0.0/16"]
#   location            = azurerm_resource_group.setup.location
#   resource_group_name = azurerm_resource_group.setup.name
# }

# resource "azurerm_subnet" "subnet" {
#   name                 = "boom-subnet"
#   resource_group_name  = "BoomDemo"
#   virtual_network_name = "boom-vnet"
#   address_prefixes     = ["10.0.1.0/24"]
#   service_endpoints    = ["Microsoft.Storage"]
# }

resource "azurerm_storage_account_network_rules" "networkrules" {
  resource_group_name  = azurerm_resource_group.setup.name
  storage_account_name = azurerm_storage_account.sa.name

  default_action             = "Deny"
  ip_rules                   = ["127.0.0.1", "124.170.37.169"]
  virtual_network_subnet_ids = ["/subscriptions/d3cfc052-05a7-44f5-a6de-33282fe81246/resourceGroups/BoomDemo/providers/Microsoft.Network/virtualNetworks/boom-vnet/subnets/boom-subnet"]
  bypass                     = ["Metrics","AzureServices","Logging"]
}

resource "azurerm_key_vault" "keyvault" {
  name                        = "kv-fbde-dev"
  location                    = azurerm_resource_group.setup.location
  resource_group_name         = azurerm_resource_group.setup.name
  enabled_for_template_deployment = true
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_enabled         = true
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    # key_permissions = [
    #   "get",
    #   "list",
    #   "ManageContacts",
    # ]

    secret_permissions = [
    "backup",
    "delete",
    "get",
    "list",
    "purge",
    "recover",
    "restore",
    "set"
  ]

    # storage_permissions = [
    #   "get","create","delete","list","update"
    # ]
  }

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    virtual_network_subnet_ids = var.virtual_network_subnet_ids
    ip_rules = ["124.170.37.169"]
  }

  tags = {
    environment = "Dev"
  }
}

resource "azurerm_key_vault_access_policy" "ap-fbde-dev" {
  key_vault_id = azurerm_key_vault.keyvault.id

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = azurerm_user_assigned_identity.mi.principal_id

  secret_permissions = [
    "get","list"
  ]
}

# resource "azurerm_key_vault_access_policy" "me" {
#   key_vault_id = azurerm_key_vault.keyvault.id

#   tenant_id = data.azurerm_client_config.current.tenant_id
#   object_id = "d41a6c93-050b-4169-970a-3f927ebb7c47"

#   secret_permissions = [
#     "backup",
#     "delete",
#     "get",
#     "list",
#     "purge",
#     "recover",
#     "restore",
#     "set"
#   ]
# }


resource "azurerm_key_vault_secret" "secret" {
  name         = "secret1"
  value        = "hey, what is happened!"
  key_vault_id = azurerm_key_vault.keyvault.id

  tags = {
    environment = "Dev"
  }
}

resource "azurerm_role_assignment" "storage-role" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.mi.principal_id
}

resource "azurerm_application_insights" "appi" {
  name                = "ai-notification-api-dev-aue"
  location            = azurerm_resource_group.setup.location
  resource_group_name = azurerm_resource_group.setup.name
  application_type    = "web"
}

##################################################################################
# OUTPUT
##################################################################################

output "storage_account_name" {
  value = azurerm_storage_account.sa.name
}

output "resource_group_name" {
  value = azurerm_resource_group.setup.name
}
