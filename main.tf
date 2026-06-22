###############################################################################
# SecureVector engine on Azure Container Apps
#
# One `terraform apply` stands up the SecureVector threat-monitor engine in YOUR
# Azure subscription: a Container App (managed HTTPS FQDN, scale-to-zero) with an
# optional Azure Files-backed persistence volume for the tamper-evident audit
# chain. Container Apps is the closest Azure analog to GCP Cloud Run — managed
# TLS, a public URL, and scale-to-zero out of the box.
###############################################################################

locals {
  resource_group_name = var.resource_group_name != "" ? var.resource_group_name : "${var.name}-rg"

  # Storage account names are globally unique, 3-24 chars, lowercase alphanumeric.
  storage_account_name = var.storage_account_name != "" ? var.storage_account_name : substr(replace(lower("${var.name}svdata"), "/[^a-z0-9]/", ""), 0, 24)

  # Cloud-specific: the deployed engine's HTTPS URL. The shared runtime.tf
  # consumes this local — every cloud module must define local.base_url.
  base_url = "https://${azurerm_container_app.this.ingress[0].fqdn}"

  # Sensitive engine credentials are stored as Container App secrets and
  # referenced by env vars (never inlined into the revision spec). Map key =
  # secret name (lowercase/hyphen), value.env = the env var the app reads.
  #
  #   SECUREVECTOR_INGRESS_TOKEN — INBOUND gate (Authorization: Bearer / X-Api-Key);
  #                             /health stays open. ingress_auth middleware.
  #   SECUREVECTOR_API_KEY    — engine's OUTBOUND cloud key (X-Api-Key via cloud_sync).
  #   SECUREVECTOR_ENROLL_TOKEN — svet_* org enroll (entrypoint runs `enroll`).
  secret_env = merge(
    var.ingress_token != "" ? { "securevector-ingress-token" = { env = "SECUREVECTOR_INGRESS_TOKEN", value = var.ingress_token } } : {},
    var.securevector_api_key != "" ? { "securevector-api-key" = { env = "SECUREVECTOR_API_KEY", value = var.securevector_api_key } } : {},
    var.cloud_connect_token != "" ? { "securevector-enroll-token" = { env = "SECUREVECTOR_ENROLL_TOKEN", value = var.cloud_connect_token } } : {},
  )

  # Non-sensitive env (plain values). Host/port are NOT env — they are CLI args
  # on the launch command (see var.container_command).
  plain_env = merge(
    var.securevector_api_url != "" ? { SECUREVECTOR_API_URL = var.securevector_api_url } : {},
    var.extra_env,
  )
}

###############################################################################
# Resource group (create by default, or use an existing one)
###############################################################################

resource "azurerm_resource_group" "this" {
  count = var.create_resource_group ? 1 : 0

  name     = local.resource_group_name
  location = var.location
  tags     = var.tags
}

data "azurerm_resource_group" "existing" {
  count = var.create_resource_group ? 0 : 1

  name = local.resource_group_name
}

locals {
  rg_name     = var.create_resource_group ? azurerm_resource_group.this[0].name : data.azurerm_resource_group.existing[0].name
  rg_location = var.create_resource_group ? azurerm_resource_group.this[0].location : data.azurerm_resource_group.existing[0].location
}

###############################################################################
# Container Apps environment (+ its required Log Analytics workspace)
###############################################################################

resource "azurerm_log_analytics_workspace" "this" {
  name                = "${var.name}-logs"
  resource_group_name = local.rg_name
  location            = local.rg_location
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = var.tags
}

resource "azurerm_container_app_environment" "this" {
  name                       = "${var.name}-env"
  resource_group_name        = local.rg_name
  location                   = local.rg_location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  tags                       = var.tags
}

###############################################################################
# Persistence — Azure Files share mounted into the engine's data dir
###############################################################################

resource "azurerm_storage_account" "data" {
  count = var.enable_persistence ? 1 : 0

  name                     = local.storage_account_name
  resource_group_name      = local.rg_name
  location                 = local.rg_location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = var.tags
}

resource "azurerm_storage_share" "data" {
  count = var.enable_persistence ? 1 : 0

  name                 = "securevector-data"
  storage_account_name = azurerm_storage_account.data[0].name
  quota                = var.storage_share_quota_gb
}

resource "azurerm_container_app_environment_storage" "data" {
  count = var.enable_persistence ? 1 : 0

  name                         = "data"
  container_app_environment_id = azurerm_container_app_environment.this.id
  account_name                 = azurerm_storage_account.data[0].name
  share_name                   = azurerm_storage_share.data[0].name
  access_key                   = azurerm_storage_account.data[0].primary_access_key
  access_mode                  = "ReadWrite"
}

###############################################################################
# Container App — the engine
###############################################################################

resource "azurerm_container_app" "this" {
  name                         = var.name
  resource_group_name          = local.rg_name
  container_app_environment_id = azurerm_container_app_environment.this.id
  revision_mode                = "Single"
  tags                         = var.tags

  dynamic "secret" {
    for_each = local.secret_env
    content {
      name  = secret.key
      value = secret.value.value
    }
  }

  template {
    min_replicas = var.min_instances
    max_replicas = var.max_instances

    container {
      name    = var.name
      image   = var.image
      cpu     = var.cpu
      memory  = var.memory
      command = length(var.container_command) > 0 ? var.container_command : null

      dynamic "env" {
        for_each = local.plain_env
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = local.secret_env
        content {
          name        = env.value.env
          secret_name = env.key
        }
      }

      # Wait for the engine to finish booting (rules + Guardian ML load) before
      # the revision is marked healthy. /health is exempt from the ingress-auth
      # gate, so the probe works even when ingress_token is set.
      startup_probe {
        transport               = "HTTP"
        path                    = "/health"
        port                    = var.container_port
        interval_seconds        = 10
        failure_count_threshold = 18
      }

      liveness_probe {
        transport = "HTTP"
        path      = "/health"
        port      = var.container_port
      }

      dynamic "volume_mounts" {
        for_each = var.enable_persistence ? [1] : []
        content {
          name = "data"
          path = var.persistence_mount_path
        }
      }
    }

    dynamic "volume" {
      for_each = var.enable_persistence ? [1] : []
      content {
        name         = "data"
        storage_type = "AzureFile"
        storage_name = azurerm_container_app_environment_storage.data[0].name
      }
    }
  }

  # external_enabled = public FQDN over the internet (network layer). Pair with
  # ingress_token for app-layer auth, or set allow_unauthenticated = false for an
  # internal-only (VNet) endpoint. Optional ip_security_restriction narrows the
  # public surface to specific CIDRs.
  ingress {
    external_enabled = var.allow_unauthenticated
    target_port      = var.container_port
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }

    dynamic "ip_security_restriction" {
      for_each = { for idx, cidr in var.ingress_cidrs : idx => cidr }
      content {
        name             = "allow-${ip_security_restriction.key}"
        ip_address_range = ip_security_restriction.value
        action           = "Allow"
      }
    }
  }
}
