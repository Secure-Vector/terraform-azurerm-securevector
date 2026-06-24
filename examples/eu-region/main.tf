###############################################################################
# EU-region example — SecureVector engine on Azure Container Apps, deployed in the EU
#
# Same shape as ../free-tier, but pinned to an EU location for data residency.
# Every resource this module creates is placed in `location`, so setting an EU
# region keeps all governance/runtime data inside the EU. Nothing in this module
# replicates data to another region.
#
# Data residency: the engine processes and stores agent/governance data only in
# the Azure subscription and location you deploy into. SecureVector never
# receives it. See the module README for the residency posture.
#
# Default location here is westeurope; northeurope also works
# — just override -var="location=northeurope".
#
# Usage:
#   terraform init
#   terraform apply -var="location=westeurope" -var="securevector_api_key=$(openssl rand -hex 24)"
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
  type        = string
  default     = "westeurope" # use northeurope for Ireland
  description = "EU Azure region to deploy into. All resources are created here, so this is what governs data residency."
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
