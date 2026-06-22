# Cloud-specific outputs. The runtime/client snippet (output "runtime_snippet")
# lives in the shared runtime.tf. local.base_url is defined in main.tf.

output "dashboard_url" {
  description = "The HTTPS URL of the SecureVector engine dashboard (Container Apps managed TLS)."
  value       = local.base_url
}

output "health_url" {
  description = "Load-balancer / uptime health endpoint."
  value       = "${local.base_url}/health"
}

output "fqdn" {
  description = "The Container App ingress FQDN."
  value       = azurerm_container_app.this.ingress[0].fqdn
}

output "container_app_name" {
  description = "Name of the deployed Container App."
  value       = azurerm_container_app.this.name
}

output "resource_group" {
  description = "Resource group the engine was deployed into."
  value       = local.rg_name
}

output "location" {
  description = "Azure region the service was deployed to."
  value       = local.rg_location
}

output "persistence_storage_account" {
  description = "Storage account backing the audit hash-chain Azure Files share (null when persistence is disabled)."
  value       = var.enable_persistence ? azurerm_storage_account.data[0].name : null
}
