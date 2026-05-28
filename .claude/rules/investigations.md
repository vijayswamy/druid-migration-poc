---
name: investigations
description: Rules for investigating failures during the migration POC
---

# Investigation Rules

## Rule 1 — Check which stage failed first
The migration has 5 stages: terraform → deploy → load → migrate → validate.
Always identify which stage failed before digging into logs.

## Rule 2 — Never destroy before capturing evidence
If something fails, DO NOT run `make destroy` to "start fresh" before capturing:
```bash
kubectl get pods -A --context eks-source > /tmp/evidence-eks.txt
kubectl get pods -A --context aks-destination > /tmp/evidence-aks.txt
kubectl get events -A --context aks-destination > /tmp/evidence-events.txt
terraform state list > /tmp/evidence-tf-state.txt
```

**Why:** Destroying removes all evidence. You'll have no idea what went wrong.

## Rule 3 — Check both clusters independently
A failure on AKS doesn't mean EKS is broken. Always check each cluster separately.
```bash
kubectl get pods -n druid --context eks-source
kubectl get pods -n druid --context aks-destination
```

## Rule 4 — S3 vs Azure Blob — check both sides
For Druid segment migration failures, check BOTH storage sides:
- S3: `aws s3 ls s3://druid-poc-druid-segments/segments/ --recursive | wc -l`
- Azure: `az storage blob list --container-name druid-segments ...`

## Rule 5 — Document before destroying
If the demo worked but something was unexpected — write it in investigations/ BEFORE running `make destroy`.
Once destroyed, you can't reproduce the state.

## Rule 6 — Check pipeline logs for silent failures
AzCopy can exit 0 even with partial transfers. Always verify:
```bash
aws s3 ls s3://druid-poc-druid-segments/segments/ --recursive | wc -l
az storage blob list --container-name druid-segments --account-name druidpocdruid --query "length(@)"
```
Both numbers must match.
