###############################################################################
# Free-tier "try it" example — SecureVector engine on Azure Container Apps
#
# Cheapest possible SecureVector engine on Azure:
#   - scale-to-zero (you pay only when a request hits it)
#   - persistence on (Azure Files), in a fresh resource group
#   - public HTTPS FQDN (managed TLS)
#   - emits a wired LangChain snippet on apply
#
# Usage:
#   terraform init
#   terraform apply -var="location=eastus" -var="securevector_api_key=$(openssl rand -hex 24)"
#   terraform output -raw runtime_snippet
#   terraform destroy   # clean teardown
###############################################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.70, < 5.0"
    }
  }
}

variable "location" {
  type    = string
  default = "eastus"
}

variable "securevector_api_key" {
  type      = string
  sensitive = true
  default   = ""
}

provider "azurerm" {
  features {}
}

module "securevector" {
  source = "../../"

  name                 = "securevector"
  location             = var.location
  securevector_runtime = "langchain"

  # Cheapest trial posture
  min_instances        = 0
  securevector_api_key = var.securevector_api_key
}

output "dashboard_url" {
  value = module.securevector.dashboard_url
}

output "runtime_snippet" {
  value = module.securevector.runtime_snippet
}
