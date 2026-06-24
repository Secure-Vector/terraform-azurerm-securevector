# EU-region example (Azure)

Deploys the SecureVector engine into an **EU Azure location** for data residency. Identical to [`../free-tier`](../free-tier) except `location` defaults to `westeurope`.

```bash
terraform init
terraform apply -var="location=westeurope" -var="securevector_api_key=$(openssl rand -hex 24)"
terraform output -raw runtime_snippet
terraform destroy
```

Use `-var="location=northeurope"` for Ireland.

## Data residency

Every resource this module creates — the Container App, its Azure Files persistence share, the resource group, and the Log Analytics workspace — lives in the `location` you set above. The engine processes and stores agent activity, threats, tool-audit, and governance data **only in your own Azure subscription and location**. SecureVector does not receive that data, and this module does not replicate it to any other region.

If you later enable Cloud Connect to view your governance posture in the SecureVector cloud, only metadata + hashes (never raw text) are forwarded, and only after you explicitly accept the governance terms. Keeping the deployment in an EU location keeps the resident copy of your data in the EU.
