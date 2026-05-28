---
name: validate
description: Run a full validation comparing data counts between EKS and AKS — PostgreSQL rows, MongoDB documents, and Druid segments
---

You are running migration validation. Check all 3 data stores.

## Step 1 — PostgreSQL row count (both clusters)
```bash
EKS_POD=$(kubectl get pod -n databases --context eks-source \
  -l app.kubernetes.io/name=postgresql --no-headers \
  -o custom-columns=":metadata.name" | head -1)

AKS_POD=$(kubectl get pod -n databases --context aks-destination \
  -l app.kubernetes.io/name=postgresql --no-headers \
  -o custom-columns=":metadata.name" | head -1)

echo "EKS count:"
kubectl exec "$EKS_POD" -n databases --context eks-source -- \
  psql -U postgres -c "SELECT COUNT(*) FROM employees;" druid

echo "AKS count:"
kubectl exec "$AKS_POD" -n databases --context aks-destination -- \
  psql -U postgres -c "SELECT COUNT(*) FROM employees;" druid
```

## Step 2 — MongoDB document count (both clusters)
```bash
MONGO_EKS=$(kubectl get pod -n databases --context eks-source \
  -l app.kubernetes.io/name=mongodb --no-headers \
  -o custom-columns=":metadata.name" | head -1)

MONGO_AKS=$(kubectl get pod -n databases --context aks-destination \
  -l app.kubernetes.io/name=mongodb --no-headers \
  -o custom-columns=":metadata.name" | head -1)

echo "EKS count:"
kubectl exec "$MONGO_EKS" -n databases --context eks-source -- \
  mongosh --eval "db.orders.countDocuments()" druid

echo "AKS count:"
kubectl exec "$MONGO_AKS" -n databases --context aks-destination -- \
  mongosh --eval "db.orders.countDocuments()" druid
```

## Step 3 — Druid segment count (both storage)
```bash
echo "S3 segments:"
aws s3 ls s3://druid-poc-druid-segments/segments/ --recursive | wc -l

echo "Azure Blob segments:"
az storage blob list \
  --container-name druid-segments \
  --account-name druidpocdruid \
  --query "length(@)"
```

## Step 4 — Druid query validation
Port-forward both Druid UIs and run the same SQL:
```bash
kubectl port-forward -n druid svc/druid-router 8888:8888 --context eks-source &
kubectl port-forward -n druid svc/druid-router 8889:8888 --context aks-destination &
```
Open http://localhost:8888 and http://localhost:8889 → run:
```sql
SELECT page, COUNT(*) AS edits FROM wikipedia GROUP BY page ORDER BY edits DESC LIMIT 10
```
Results must be identical.

## Summarise results
| Check | EKS | AKS | Status |
|---|---|---|---|
| PostgreSQL rows | | | PASS / FAIL |
| MongoDB documents | | | PASS / FAIL |
| Druid segments | | | PASS / FAIL |
| Druid SQL result | | | PASS / FAIL |
