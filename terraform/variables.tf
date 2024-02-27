variable "azurerm_resource_group" {
  description = "The name for the Azure resource group."
  type        = string
  default     = "airflow-app-rg"
}

variable "location" {
  description = "The location for Azure resources."
  type        = string
  default     = "West Europe"
}

variable "azurerm_log_analytics_workspace_name" {
  description = "The name for the Azure Log Analytics Workspace."
  type        = string
  default     = "airflow-app-analytic"
}

variable "azurerm_container_app_environment_name" {
  description = "The name for the Azure Container App Environment."
  type        = string
  default     = "airflow-app-environment"
}

variable "azurerm_container_app_name" {
  description = "The name for the Azure Container App."
  type        = string
  default     = "airflow-app"
}

# variable "subscription_id" {
#   description = "Azure subscription ID"
# }

# variable "client_id" {
#   description = "Azure client ID"
# }

# variable "client_secret" {
#   description = "Azure client secret"
# }

# variable "tenant_id" {
#   description = "Azure tenant ID"
# }
