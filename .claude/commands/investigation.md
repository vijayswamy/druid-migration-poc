---
name: investigation
description: Start a structured investigation for any unexpected behaviour during the Druid migration POC
---

You are starting a structured investigation. Follow these phases.

## Phase 1 — Open investigation
Ask the user:
1. What did you observe?
2. Which migration stage were you on? (terraform / deploy / load / migrate / validate)
3. Which cluster? (EKS / AKS / both)
4. Is it reproducible?

## Phase 2 — Snapshot current state
```bash
# Both clusters — pod health
kubectl get pods -n druid --context eks-source
kubectl get pods -n druid --context aks-destination
kubectl get pods -n databases --context eks-source
kubectl get pods -n databases --context aks-destination

# Events
kubectl get events -n druid --context aks-destination --sort-by='.lastTimestamp' | tail -20

# Terraform state
cd ~/druid-migration-poc/terraform && terraform state list

# S3 segments
aws s3 ls s3://druid-poc-druid-segments/segments/ --recursive | wc -l

# Azure Blob segments
az storage blob list --container-name druid-segments --account-name druidpocdruid --query "length(@)"
```

## Phase 3 — Dig deeper
- Terraform issue → use terraform agent
- Druid pod issue → use druid agent
- Database issue → use databases agent
- Cloud infra issue → use cloud-infra agent
- Pipeline issue → use github-actions agent

## Phase 4 — Document
Create: investigations/INV-<YYYY-MM-DD>-<short-title>.md

```markdown
# Investigation: <title>

**Opened:** <datetime>
**Status:** Open / Resolved
**Stage:** terraform / deploy / load / migrate / validate
**Affected:** <component>
**How Found:** <pipeline failure / manual check / validation mismatch>

## What Was Observed
<describe the symptom>

## Findings
### Check 1 — <what you checked>
<output and interpretation>

## Conclusion
<root cause>

## Action Taken
<what was done>

## Linked RCA
<link to rca/ file if escalated>
```
