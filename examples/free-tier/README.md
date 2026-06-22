# Free-tier "try it" — SecureVector engine on Azure Container Apps

The cheapest way to stand up the SecureVector engine on Azure: a scale-to-zero
Container App with a public HTTPS FQDN (managed TLS) and Azure Files
persistence, in a fresh resource group.

```bash
terraform init
terraform apply -var="location=eastus" -var="securevector_api_key=$(openssl rand -hex 24)"
terraform output dashboard_url      # https://...azurecontainerapps.io — local engine, device-level detection
terraform output -raw runtime_snippet
terraform destroy                   # clean teardown
```

> **Scale-to-zero.** You pay only when a request hits it (plus a small storage
> cost for the Azure Files share). `terraform destroy` removes everything,
> including the resource group.

> **Open endpoint.** This example serves a public HTTPS FQDN with no auth — fine
> for a quick trial. For anything internet-facing, set `ingress_token`
> (app-layer auth) and/or `allow_unauthenticated = false` (internal-only) /
> `ingress_cidrs` (CIDR allowlist).

See the [module README](../../README.md) for all inputs and the Option 1 vs
Option 2 (fleet + advanced cloud ML) paths.
