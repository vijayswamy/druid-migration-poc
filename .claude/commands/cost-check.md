---
name: cost-check
description: Check current AWS and Azure cloud costs and warn if resources are still running
---

You are checking cloud costs for the druid-migration-poc. Resources left running cost ~$0.38/hr.

## Step 1 — Check if clusters still exist
```bash
# AWS EKS
aws eks list-clusters --region us-east-1

# Azure AKS
az aks list --query "[].{name:name, rg:resourceGroup, state:powerState.code}" -o table
```

## Step 2 — Check Terraform state
```bash
cd ~/druid-migration-poc/terraform
terraform state list
```
If state is empty → resources are destroyed (good).
If state has resources → they are still running (cost accumulating).

## Step 3 — AWS cost this month
```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --query "ResultsByTime[0].Total.BlendedCost.Amount"
```

## Step 4 — If resources are still running
**Destroy immediately:**
```bash
cd ~/druid-migration-poc
make destroy
```
Or trigger via GitHub Actions:
```bash
gh workflow run destroy.yml \
  --repo vijayswamy/druid-migration-poc \
  --field confirm=destroy
```

## Cost reference
| Resource | Cost/hr |
|---|---|
| EKS control plane | $0.10 |
| 2x t3.medium nodes | $0.09 |
| AKS control plane | Free |
| 2x Standard_DC2s_v3 | $0.23 |
| **Total** | **~$0.38/hr** |

A full day of forgetting to destroy = **$9.12**. Always destroy after demo.
