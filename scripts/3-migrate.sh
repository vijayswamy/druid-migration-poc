#!/bin/bash
# Step 3 — Migrate data from EKS (source) to AKS (destination)
# Migrates: PostgreSQL dump, MongoDB dump, Druid segments (S3 → Azure Blob)

set -e

echo "========================================"
echo " STEP 3: Migrate data EKS → AKS"
echo "========================================"

cd "$(dirname "$0")/../terraform"
S3_BUCKET=$(terraform output -raw s3_bucket_name)
STORAGE_ACCOUNT=$(terraform output -raw azure_storage_account)
STORAGE_KEY=$(terraform output -raw storage_account_key)
AWS_REGION=$(terraform output -raw aws_region)
cd -

DUMP_DIR="/tmp/poc-migration-dump"
mkdir -p "${DUMP_DIR}"

# ─────────────────────────────────────────
# 1. PostgreSQL — dump from EKS, restore on AKS
# ─────────────────────────────────────────
echo ""
echo "=== [1/3] Migrating PostgreSQL ==="

echo "  Dumping from EKS..."
kubectl exec -n databases postgresql-0 --context eks-source -- \
  pg_dump -U postgres druid_metadata > "${DUMP_DIR}/druid_metadata.sql"

echo "  Copying dump into AKS pod..."
kubectl cp "${DUMP_DIR}/druid_metadata.sql" \
  databases/postgresql-0:/tmp/druid_metadata.sql \
  --context aks-destination

echo "  Restoring on AKS..."
kubectl exec -n databases postgresql-0 --context aks-destination -- \
  psql -U postgres -d druid_metadata -f /tmp/druid_metadata.sql

echo "  PostgreSQL migration done."

# ─────────────────────────────────────────
# 2. MongoDB — dump from EKS, restore on AKS
# ─────────────────────────────────────────
echo ""
echo "=== [2/3] Migrating MongoDB ==="

echo "  Dumping from EKS..."
kubectl exec -n databases mongodb-0 --context eks-source -- \
  mongodump --uri="mongodb://appuser:pocpassword123@localhost:27017/appdb?authSource=appdb" \
  --out=/tmp/mongodump

kubectl cp databases/mongodb-0:/tmp/mongodump "${DUMP_DIR}/mongodump" \
  --context eks-source

echo "  Copying dump into AKS pod..."
kubectl cp "${DUMP_DIR}/mongodump" \
  databases/mongodb-0:/tmp/mongodump \
  --context aks-destination

echo "  Restoring on AKS..."
kubectl exec -n databases mongodb-0 --context aks-destination -- \
  mongorestore --uri="mongodb://appuser:pocpassword123@localhost:27017/appdb?authSource=appdb" \
  /tmp/mongodump

echo "  MongoDB migration done."

# ─────────────────────────────────────────
# 3. Druid segments — copy S3 → Azure Blob using AzCopy
# ─────────────────────────────────────────
echo ""
echo "=== [3/3] Migrating Druid segments (S3 → Azure Blob) ==="

# Check AzCopy is installed
if ! command -v azcopy &>/dev/null; then
  echo "  Installing AzCopy..."
  curl -sL https://aka.ms/downloadazcopy-v10-linux -o /tmp/azcopy.tar.gz
  tar -xf /tmp/azcopy.tar.gz -C /tmp/
  sudo mv /tmp/azcopy_linux_amd64_*/azcopy /usr/local/bin/
  echo "  AzCopy installed."
fi

echo "  Waiting for Druid Wikipedia segments to appear in S3..."
until aws s3 ls "s3://${S3_BUCKET}/druid/segments/wikipedia/" --region "${AWS_REGION}" > /dev/null 2>&1; do
  echo "  No segments yet — sleeping 30s..."
  sleep 30
done
echo "  Segments found in S3. Proceeding with copy."

echo "  Generating SAS token for Azure Blob..."
SAS_TOKEN=$(az storage account generate-sas \
  --account-name "${STORAGE_ACCOUNT}" \
  --account-key "${STORAGE_KEY}" \
  --expiry "$(date -u -d '+2 hours' '+%Y-%m-%dT%H:%MZ' 2>/dev/null || date -u -v+2H '+%Y-%m-%dT%H:%MZ')" \
  --permissions acdlrw \
  --resource-types sco \
  --services b \
  --output tsv)

echo "  Copying segments from S3 to Azure Blob..."
echo "  Source:      s3://${S3_BUCKET}/druid/"
echo "  Destination: https://${STORAGE_ACCOUNT}.blob.core.windows.net/druid-segments/druid/"

# Virtual-hosted style S3 URL with region — preserves druid/ prefix in destination
azcopy copy \
  "https://${S3_BUCKET}.s3.${AWS_REGION}.amazonaws.com/druid/" \
  "https://${STORAGE_ACCOUNT}.blob.core.windows.net/druid-segments/druid/?${SAS_TOKEN}" \
  --recursive

echo "  Druid segments copied to Azure Blob."

echo ""
echo "========================================"
echo " DONE: Migration complete!"
echo ""
echo " Segments are now in Azure Blob."
echo " PostgreSQL and MongoDB data restored on AKS."
echo ""
echo " Next: Run scripts/4-validate.sh"
echo "========================================"
