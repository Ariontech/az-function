terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.92.0"
    }
  }
}

provider "azurerm" {
  features {}
 
  subscription_id = "79d70fcd-2018-4a86-bbf8-9c1f7d4e54c3"
  tenant_id       = "28a8cfb8-bb7b-435e-9778-90829908e86d"
}
