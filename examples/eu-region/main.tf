###############################################################################
# EU-region example — SecureVector engine on Azure Container Apps, deployed in the EU
#
# Same shape as ../free-tier, but pinned to an EU location for data residency.
# Every resource this module creates is placed in `location`, so setting an EU
# region keeps the resident copy of governance/runtime data in-region. Nothing in this module
# replicates data to another region.
#
# Data residency: the engine processes and stores agent/governance data only in
# the Azure subscription and location you deploy into. SecureVector does not store it. (NOTE: with Cloud Mode on, the engine sends
# prompt text to scan.securevector.io (US) for ML analysis — not stored, but it
# leaves the region; leave Cloud Mode off for strict EU residency. See README.) See the module README for the residency posture.
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

  # EU data residency: keep ALL prompt analysis local even with Cloud Mode on.
  # The v4.8+ engine honors SV_DATA_RESIDENCY=eu (locks local-only analysis on;
  # the toggle is enforced/locked and cloud /analyze is forced local). Harmless
  # no-op on older engine images.
  extra_env = { SV_DATA_RESIDENCY = "eu" }
}

output "dashboard_url" {
  value = module.securevector.dashboard_url
}

output "runtime_snippet" {
  value = module.securevector.runtime_snippet
}
