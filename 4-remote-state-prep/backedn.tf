terraform {
  backend "azurerm" {
    resource_group_name  = "Ned4"
    storage_account_name = "itma33868"
    container_name       = "terraform-state"
    key                  = "terraform.tfstate"
  }
}