###############################################################################
# Placement & naming
###############################################################################

variable "location" {
  description = "Azure region for all resources (e.g. eastus, westeurope). Pick the region closest to your agents / data-residency requirement."
  type        = string
  default     = "eastus"
}

variable "name" {
  description = "Base name for the Container App and derived resources. Lowercase, must be a valid Container App name (alphanumeric + hyphens, <= 32 chars)."
  type        = string
  default     = "securevector"

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]*[a-z0-9])?$", var.name)) && length(var.name) <= 32
    error_message = "name must be lowercase, start with a letter, contain only letters/digits/hyphens, and be <= 32 chars."
  }
}

variable "create_resource_group" {
  description = "Create the resource group (true, default) or use an existing one named resource_group_name (false)."
  type        = bool
  default     = true
}

variable "resource_group_name" {
  description = "Resource group name. Empty = derive \"<name>-rg\". When create_resource_group = false this must name an existing group."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to all created resources."
  type        = map(string)
  default     = {}
}

###############################################################################
# Container image
###############################################################################

variable "image" {
  description = "Container image for the SecureVector engine. Defaults to the public ghcr.io image published from securevector-ai-threat-monitor. Pin to a version tag for production."
  type        = string
  default     = "ghcr.io/secure-vector/securevector-ai-threat-monitor:latest"
}

variable "container_port" {
  description = "Port the engine listens on inside the container. Container Apps ingress routes HTTPS traffic to this port. The image/command must bind this port on 0.0.0.0."
  type        = number
  default     = 8741

  validation {
    condition     = var.container_port >= 1 && var.container_port <= 65535
    error_message = "container_port must be between 1 and 65535."
  }
}

variable "container_command" {
  description = "Override the container entrypoint. Empty (default) defers to the image ENTRYPOINT. The app takes host/port as CLI args (NOT env), so a working override looks like [\"securevector-app\", \"--web\", \"--host\", \"0.0.0.0\", \"--port\", \"8741\"]. (Enrollment from SECUREVECTOR_ENROLL_TOKEN must be handled by the image entrypoint, not this command.)"
  type        = list(string)
  default     = []
}

###############################################################################
# Scaling & resources (scale-to-zero capable, like Cloud Run)
#
# Container Apps cpu/memory must form a valid combo (0.25/0.5Gi, 0.5/1Gi,
# 0.75/1.5Gi, 1.0/2Gi, ... up to 2.0/4Gi on the Consumption profile).
###############################################################################

variable "cpu" {
  description = "vCPU per replica (e.g. 0.5, 1.0). Must pair with memory per Container Apps' valid combos. Default 0.5 gives the Guardian ML model headroom."
  type        = number
  default     = 0.5
}

variable "memory" {
  description = "Memory per replica as a Container Apps string (e.g. \"1Gi\", \"2Gi\"). Must pair with cpu. Default \"1Gi\"."
  type        = string
  default     = "1Gi"
}

variable "min_instances" {
  description = "Minimum replicas. 0 = scale-to-zero (cheapest; cold start on first request). Set to 1 to keep the dashboard warm."
  type        = number
  default     = 0

  validation {
    condition     = var.min_instances >= 0
    error_message = "min_instances must be >= 0."
  }
}

variable "max_instances" {
  description = "Maximum replicas."
  type        = number
  default     = 2

  validation {
    condition     = var.max_instances >= 1
    error_message = "max_instances must be >= 1."
  }
}

###############################################################################
# Access & auth
#
# Two independent layers:
#   - ingress_token  -> SECUREVECTOR_INGRESS_TOKEN: APP-LAYER inbound gate. When
#     set, the engine requires the credential on every request (Authorization:
#     Bearer or X-Api-Key); /health stays open. Validated by the ingress_auth
#     middleware in securevector-ai-threat-monitor (pending release).
#   - allow_unauthenticated / ingress_cidrs -> Container App ingress: NETWORK
#     layer (public FQDN vs internal-only; optional CIDR allowlist).
# Use either or both. securevector_api_key below is the engine's OUTBOUND cloud
# key, NOT an inbound gate — don't confuse the two.
###############################################################################

variable "allow_unauthenticated" {
  description = "Expose a public HTTPS FQDN over the internet (external ingress). Pair with ingress_token for app-layer auth, or set FALSE for an internal-only (VNet) endpoint."
  type        = bool
  default     = true
}

variable "ingress_cidrs" {
  description = "Optional CIDR allowlist on the ingress (ip_security_restriction, action Allow). Empty = no IP restriction. Narrows the public surface even when allow_unauthenticated = true."
  type        = list(string)
  default     = []
}

variable "ingress_token" {
  description = "App-layer inbound credential -> SECUREVECTOR_INGRESS_TOKEN (stored as a Container App secret). When set, the engine requires it on every request (Authorization: Bearer <token> or X-Api-Key: <token>); /health stays open for probes. Header-capable clients (OpenClaw, curl) can pass it today; SDK/JS-hook client-side forwarding is rolling out (#182). Empty = no app-layer gate."
  type        = string
  default     = ""
  sensitive   = true
}

variable "securevector_api_key" {
  description = "OUTBOUND cloud credential: a personal API key (svpk_* / legacy) the engine presents to the SecureVector cloud (sent as X-Api-Key by cloud_sync) for personal cloud mode / enhanced detection. Stored as a Container App secret. NOT an inbound gate. Empty = no cloud key."
  type        = string
  default     = ""
  sensitive   = true
}

variable "securevector_api_url" {
  description = "Optional override for the SecureVector cloud API base URL (SECUREVECTOR_API_URL). Empty = the app's built-in default."
  type        = string
  default     = ""
}

###############################################################################
# Cloud Connect bridge (optional) — turns this self-hosted node into a member
# of the SecureVector managed fleet (the OSS-self-host -> paid Pro/Enterprise
# on-ramp). Leave empty to stay fully self-hosted.
###############################################################################

variable "cloud_connect_token" {
  description = "Optional svet_* org ENROLLMENT token (passed as SECUREVECTOR_ENROLL_TOKEN, stored as a Container App secret). Enrolls the node into the org FLEET view AND receives signed policy bundles (Policy Sync ON). NOTE: only the svet_* enroll path enables policy sync; a personal key (svpk_*) goes in securevector_api_key instead. Requires the image entrypoint to run `securevector-app enroll` before serving (see README / #182). Empty = pure self-host."
  type        = string
  default     = ""
  sensitive   = true
}

# NOTE: variable "securevector_runtime" lives in the shared runtime.tf (kept
# identical across all terraform-<cloud>-securevector repos).

###############################################################################
# Persistence — durable audit hash-chain. v1 = SQLite on an Azure Files share.
###############################################################################

variable "enable_persistence" {
  description = "Mount an Azure Files share at persistence_mount_path so the audit hash-chain survives replica restarts. Disable for a stateless throwaway trial."
  type        = bool
  default     = true
}

variable "persistence_mount_path" {
  description = "Path the persistence volume mounts at inside the container. The app has NO data-dir env override — it stores its SQLite DB / audit chain at $HOME/.local/share/securevector/threat-monitor — so this MUST match that path in the published image. Default assumes HOME=/home/securevector."
  type        = string
  default     = "/home/securevector/.local/share/securevector/threat-monitor"
}

variable "storage_account_name" {
  description = "Name of the storage account backing the Azure Files share. Empty = derive from name. Storage account names are GLOBALLY unique, 3-24 lowercase alphanumeric chars — override if the derived name collides."
  type        = string
  default     = ""
}

variable "storage_share_quota_gb" {
  description = "Azure Files share quota in GiB."
  type        = number
  default     = 10
}

###############################################################################
# Operational
###############################################################################

variable "log_retention_days" {
  description = "Log Analytics workspace retention (days) for the Container Apps environment logs."
  type        = number
  default     = 30
}

variable "extra_env" {
  description = "Additional (non-sensitive) environment variables to pass to the engine container (advanced / forward-compat with future server-mode flags)."
  type        = map(string)
  default     = {}
}
