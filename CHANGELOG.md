# Changelog

All notable changes to this module are documented here. This project adheres to
[Semantic Versioning](https://semver.org/). The Terraform Registry publishes a
release per `vX.Y.Z` git tag.

## [Unreleased]

### Added
- Initial Azure module: deploys the SecureVector engine to the user's own Azure
  subscription on **Azure Container Apps** — managed HTTPS FQDN, scale-to-zero,
  and a clean `terraform destroy`. Creates the resource group, Container Apps
  environment, and its required Log Analytics workspace (or uses an existing RG
  via `create_resource_group = false`).
- Optional **Azure Files-backed persistence volume** for the tamper-evident
  audit hash-chain (`enable_persistence`, default on): a Standard LRS storage
  account + file share, linked to the environment and mounted at the app data
  dir.
- Application-layer inbound gate (`ingress_token` → `SECUREVECTOR_INGRESS_TOKEN`,
  stored as a Container App **secret**) — when set, the engine requires
  `Authorization: Bearer` / `X-Api-Key` (`/health` stays open for probes),
  validated by the `ingress_auth` middleware in securevector-ai-threat-monitor
  (fail-open when unset). Network-layer gate via `allow_unauthenticated`
  (external vs internal ingress) + optional `ingress_cidrs`
  (`ip_security_restriction`).
- Engine **outbound** cloud credentials, both stored as Container App secrets:
  `securevector_api_key` (`svpk_`/legacy → `SECUREVECTOR_API_KEY`, personal cloud
  mode) and `cloud_connect_token` (`svet_*` → `SECUREVECTOR_ENROLL_TOKEN`, fleet +
  policy sync).
- `securevector_runtime` variable that emits a copy-paste SDK/plugin wiring
  snippet as a Terraform output, pre-pointed at the new FQDN. Covers all
  SecureVector clients: SDKs (langchain / langgraph / crewai) and plugins
  (claude-code / cursor / codex / copilot-cli / openclaw).
- Shared `runtime.tf` — **byte-identical** with the other
  `terraform-<cloud>-securevector` repos so every cloud exposes the same
  clients/snippets/contract.
- HTTP/startup/liveness probes on `/health` (startup allows ~3 min for the
  engine boot — rules + Guardian ML load).

### Terraform best-practices / DevOps notes
- Sensitive tokens are Container App **secrets** referenced by env (`secret_name`),
  never inlined into the revision spec.
- `min_replicas = 0` (scale-to-zero) by default, matching the Cloud Run posture.
- cpu/memory must form a valid Container Apps combo (0.25/0.5Gi … 2.0/4Gi);
  default 0.5 vCPU / 1Gi gives the Guardian ML model headroom.
- Storage account name is derived (globally-unique constraint) and overridable
  via `storage_account_name` if the derived name collides.
- Input validation on `name` (≤32), `container_port` (1–65535), `min_instances`
  (≥0), `max_instances` (≥1).

### Notes
- The engine image is published to ghcr
  (`ghcr.io/secure-vector/securevector-ai-threat-monitor`, tags `latest` + `4.7.1`,
  multi-arch): its entrypoint binds `0.0.0.0:$PORT`, stores data at the mount
  path, and enrolls from `SECUREVECTOR_ENROLL_TOKEN`. Engine-side inbound-auth
  enforcement ships in a later release; until then gate internet-facing
  deployments at the network layer.
