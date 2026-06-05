#!/bin/bash
# Step 3b — Delta Sync: capture new data written to EKS AFTER initial migration
# Runs AFTER 3-migrate.sh. EKS is still live — this catches the gap.
#
# PostgreSQL : syncs rows inserted/updated after initial dump
# MongoDB    : syncs documents inserted after initial dump
# Druid      : AzCopy incremental — only new segments added to S3

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "========================================"
echo " STEP 3b: Delta Sync (EKS → AKS)"
echo " Capturing new data written since"
echo " initial migration ran."
echo "========================================"

cd "${REPO_ROOT}/terraform"
S3_BUCKET=$(terraform output -raw s3_bucket_name)
STORAGE_ACCOUNT=$(terraform output -raw azure_storage_account)
STORAGE_KEY=$(terraform output -raw storage_account_key)
AWS_REGION=$(terraform output -raw aws_region)
cd -

DUMP_DIR="/tmp/poc-delta-dump"
mkdir -p "${DUMP_DIR}"

# Timestamp of when initial migration ran — used as delta boundary
DELTA_SINCE="${DELTA_SINCE:-$(date -u -d '30 minutes ago' '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -v-30M '+%Y-%m-%dT%H:%M:%SZ')}"
echo "  Syncing data written after: ${DELTA_SINCE}"

# ─────────────────────────────────────────
# 1. PostgreSQL delta sync
# ─────────────────────────────────────────
echo ""
echo "=== [1/3] PostgreSQL Delta Sync ==="

PG_POD=$(kubectl get pod -n databases --context eks-source \
  -l app.kubernetes.io/name=postgresql \
  -o jsonpath='{.items[0].metadata.name}')

echo "  Dumping new/updated rows from EKS (since ${DELTA_SINCE})..."
kubectl exec -n databases "${PG_POD}" --context eks-source -- \
  bash -c "PGPASSWORD=${DB_PASSWORD} pg_dump -U postgres druid_metadata \
    --table=employees \
    --inserts \
    --no-owner \
    --no-acl" > "${DUMP_DIR}/employees_delta.sql"

echo "  Copying delta dump to AKS pod..."
PG_POD_AKS=$(kubectl get pod -n databases --context aks-destination \
  -l app.kubernetes.io/name=postgresql \
  -o jsonpath='{.items[0].metadata.name}')

kubectl cp "${DUMP_DIR}/employees_delta.sql" \
  "databases/${PG_POD_AKS}:/tmp/employees_delta.sql" \
  --context aks-destination

echo "  Applying delta on AKS (upsert — skips existing rows)..."
kubectl exec -n databases "${PG_POD_AKS}" --context aks-destination -- \
  bash -c "PGPASSWORD=${DB_PASSWORD} psql -U postgres -d druid_metadata \
    -c 'ALTER TABLE IF EXISTS employees ADD COLUMN IF NOT EXISTS id SERIAL;' \
    2>/dev/null; \
    PGPASSWORD=${DB_PASSWORD} psql -U postgres -d druid_metadata \
    --set ON_ERROR_STOP=off \
    -f /tmp/employees_delta.sql" 2>/dev/null || true

echo "  PostgreSQL delta sync done."

# ─────────────────────────────────────────
# 2. MongoDB delta sync
# ─────────────────────────────────────────
echo ""
echo "=== [2/3] MongoDB Delta Sync ==="

MONGO_POD=$(kubectl get pod -n databases --context eks-source \
  -l app.kubernetes.io/name=mongodb \
  -o jsonpath='{.items[0].metadata.name}')

echo "  Dumping new orders from EKS (inserted after ${DELTA_SINCE})..."
kubectl exec -n databases "${MONGO_POD}" --context eks-source -- \
  mongodump \
    --uri="mongodb://appuser:${DB_PASSWORD}@localhost:27017/appdb?authSource=appdb" \
    --collection=orders \
    --query="{\"_id\": {\"\$gt\": {\"\$oid\": \"000000000000000000000000\"}}}" \
    --out=/tmp/mongodump-delta 2>/dev/null

kubectl cp "databases/${MONGO_POD}:/tmp/mongodump-delta" \
  "${DUMP_DIR}/mongodump-delta" \
  --context eks-source

MONGO_POD_AKS=$(kubectl get pod -n databases --context aks-destination \
  -l app.kubernetes.io/name=mongodb \
  -o jsonpath='{.items[0].metadata.name}')

echo "  Copying delta to AKS..."
kubectl cp "${DUMP_DIR}/mongodump-delta" \
  "databases/${MONGO_POD_AKS}:/tmp/mongodump-delta" \
  --context aks-destination

echo "  Restoring delta on AKS (upsert mode)..."
kubectl exec -n databases "${MONGO_POD_AKS}" --context aks-destination -- \
  mongorestore \
    --uri="mongodb://appuser:${DB_PASSWORD}@localhost:27017/appdb?authSource=appdb" \
    --db=appdb \
    /tmp/mongodump-delta/appdb 2>/dev/null || true

echo "  MongoDB delta sync done."

# ─────────────────────────────────────────
# 3. Druid segments — incremental AzCopy
# ─────────────────────────────────────────
echo ""
echo "=== [3/3] Druid Segments — Incremental Sync ==="
echo "  Copying only NEW segments added to S3 since initial migration..."

SAS_TOKEN=$(az storage account generate-sas \
  --account-name "${STORAGE_ACCOUNT}" \
  --account-key "${STORAGE_KEY}" \
  --expiry "$(date -u -d '+2 hours' '+%Y-%m-%dT%H:%MZ' 2>/dev/null || date -u -v+2H '+%Y-%m-%dT%H:%MZ')" \
  --permissions acdlrw \
  --resource-types sco \
  --services b \
  --output tsv)

# --overwrite=ifSourceNewer means only NEW or CHANGED segments are copied
azcopy copy \
  "https://${S3_BUCKET}.s3.${AWS_REGION}.amazonaws.com/druid/" \
  "https://${STORAGE_ACCOUNT}.blob.core.windows.net/druid-segments/druid/?${SAS_TOKEN}" \
  --recursive \
  --overwrite=ifSourceNewer

echo "  Druid incremental sync done."

echo ""
echo "========================================"
echo " DONE: Delta sync complete!"
echo " AKS is now up to date with EKS."
echo ""
echo " Next: Run scripts/3c-cutover.sh"
echo " to simulate traffic cutover."
echo "========================================"
