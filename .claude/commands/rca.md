---
name: rca
description: Start a structured Root Cause Analysis for an incident during the Druid migration POC
---

You are conducting a Root Cause Analysis. Follow these phases strictly.

## Phase 1 — Gather incident details
Ask the user:
1. Which stage failed? (terraform / deploy / load / migrate / validate)
2. Which component? (Druid / PostgreSQL / MongoDB / EKS / AKS / S3 / Azure Blob)
3. What was the error message?
4. When did it happen?

## Phase 2 — Investigate
Based on the stage and component:

**Terraform failure:**
```bash
cd ~/druid-migration-poc/terraform
terraform show
terraform state list
terraform plan -var-file=terraform.tfvars
```

**Druid issue:**
```bash
kubectl get pods -n druid --context eks-source
kubectl get pods -n druid --context aks-destination
kubectl logs -l app.kubernetes.io/component=coordinator -n druid --context aks-destination
```

**Database issue:**
```bash
kubectl get pods -n databases --context eks-source
kubectl get pods -n databases --context aks-destination
```

**Migration failure:**
```bash
# Check S3 segments
aws s3 ls s3://druid-poc-druid-segments/segments/ --recursive | wc -l
# Check Azure Blob
az storage blob list --container-name druid-segments --account-name druidpocdruid | wc -l
```

**Validation mismatch:**
```bash
bash ~/druid-migration-poc/scripts/4-validate.sh
```

**Pipeline failure:**
```bash
gh run list --repo vijayswamy/druid-migration-poc --limit 5
gh run view <run-id> --repo vijayswamy/druid-migration-poc --log-failed
```

## Phase 3 — Write RCA
Create: rca/RCA-<YYYY-MM-DD>-<short-title>.md

```markdown
# RCA: <title>

**Date:** <date>
**Status:** Resolved / Investigating
**Severity:** P1 / P2 / P3
**Stage:** terraform / deploy / load / migrate / validate
**Component:** Druid / PostgreSQL / MongoDB / EKS / AKS
**Duration:** <how long it was broken>

## Summary
One paragraph — what broke, why, how it was fixed.

## Timeline
| Time | Event |
|---|---|
| HH:MM | Error first observed |
| HH:MM | Investigation started |
| HH:MM | Root cause identified |
| HH:MM | Fix applied |
| HH:MM | Confirmed resolved |

## Root Cause
What specifically failed.

## Impact
Did migration data get corrupted? Was any cloud resource left running (cost impact)?

## Fix Applied
What was done to resolve it.

## Prevention
What to add/change so this doesn't happen again.
```
