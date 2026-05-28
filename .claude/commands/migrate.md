---
name: migrate
description: Walk through the full migration from EKS to AKS step by step with pre-checks and post-validation at each stage
---

You are running the Druid migration workflow. Follow all phases carefully.

## Phase 1 — Pre-migration checklist
```bash
# Both clusters are reachable
kubectl get nodes --context eks-source
kubectl get nodes --context aks-destination

# All pods running on EKS (source)
kubectl get pods -n druid --context eks-source
kubectl get pods -n databases --context eks-source

# All pods running on AKS (destination)
kubectl get pods -n druid --context aks-destination
kubectl get pods -n databases --context aks-destination

# Data exists on EKS
aws s3 ls s3://druid-poc-druid-segments/segments/ --recursive | wc -l
```

## Phase 2 — Migrate PostgreSQL
```bash
bash ~/druid-migration-poc/scripts/3-migrate.sh postgres
```
Then validate:
```bash
# EKS count
kubectl exec -n databases --context eks-source \
  $(kubectl get pod -n databases --context eks-source -l app.kubernetes.io/name=postgresql \
  --no-headers -o custom-columns=":metadata.name" | head -1) -- \
  psql -U postgres -c "SELECT COUNT(*) FROM employees;" druid

# AKS count — must match
kubectl exec -n databases --context aks-destination \
  $(kubectl get pod -n databases --context aks-destination -l app.kubernetes.io/name=postgresql \
  --no-headers -o custom-columns=":metadata.name" | head -1) -- \
  psql -U postgres -c "SELECT COUNT(*) FROM employees;" druid
```

## Phase 3 — Migrate MongoDB
```bash
bash ~/druid-migration-poc/scripts/3-migrate.sh mongodb
```
Validate counts match on both clusters.

## Phase 4 — Copy Druid segments (S3 → Azure Blob)
```bash
bash ~/druid-migration-poc/scripts/3-migrate.sh druid
```
Monitor AzCopy progress. This is the longest step.

## Phase 5 — Full validation
```bash
bash ~/druid-migration-poc/scripts/4-validate.sh
```
All 3 checks must show PASS:
- PostgreSQL: ✅ PASS
- MongoDB: ✅ PASS
- Druid: ✅ PASS

## Phase 6 — Record the change
Create: changes/CHG-<YYYY-MM-DD>-migration-eks-to-aks.md

## Phase 7 — Cost cleanup
```bash
make destroy
```
Do NOT skip this. ~$0.38/hr adds up fast.
