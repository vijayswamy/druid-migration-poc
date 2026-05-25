#!/bin/bash
# Step 1 — Deploy all apps on BOTH EKS (source) and AKS (destination)
# Run this after: terraform apply

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="druid-poc"
AWS_REGION="us-east-1"

echo "========================================"
echo " STEP 1: Deploy apps on both clusters"
echo "========================================"

# Get S3 bucket name and storage account details from Terraform outputs
cd "$REPO_ROOT/terraform"
S3_BUCKET=$(terraform output -raw s3_bucket_name)
STORAGE_ACCOUNT=$(terraform output -raw azure_storage_account)
STORAGE_KEY=$(terraform output -raw storage_account_key)
AKS_NAME=$(terraform output -raw aks_cluster_name)
AKS_RG=$(terraform output -raw aks_resource_group)
EKS_NAME=$(terraform output -raw eks_cluster_name)
cd -

echo ""
echo "--- Generating dynamic Helm overrides from Terraform outputs ---"

# DB_PASSWORD must be set as env var (from GitHub secret or export before running locally)
if [ -z "${DB_PASSWORD}" ]; then
  echo "ERROR: DB_PASSWORD env var is not set."
  echo "  Run: export DB_PASSWORD=yourpassword"
  exit 1
fi

cat > /tmp/druid-aws-override.yaml <<EOF
configVars:
  druid_storage_bucket: "${S3_BUCKET}"
  druid_metadata_storage_connector_password: "${DB_PASSWORD}"
EOF

cat > /tmp/druid-azure-override.yaml <<EOF
configVars:
  druid_azure_account: "${STORAGE_ACCOUNT}"
  druid_azure_key: "${STORAGE_KEY}"
  druid_metadata_storage_connector_password: "${DB_PASSWORD}"
  druid_indexer_logs_container: druid-segments
EOF

echo ""
echo "--- Adding Helm repos ---"
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add druid-helm https://raw.githubusercontent.com/asdf2014/druid-helm/master
helm repo update

# ─────────────────────────────────────────
# DEPLOY ON AWS EKS (Source)
# ─────────────────────────────────────────
echo ""
echo "=== Configuring kubectl for EKS (source) ==="
aws eks update-kubeconfig --region "${AWS_REGION}" --name "${EKS_NAME}" --alias eks-source

echo ""
echo "=== Deploying PostgreSQL on EKS ==="
kubectl create namespace databases --context eks-source --dry-run=client -o yaml | kubectl apply --context eks-source -f -
helm upgrade --install postgresql bitnami/postgresql \
  --kube-context eks-source \
  --namespace databases \
  --values $REPO_ROOT/helm/postgresql-values.yaml \
  --set auth.postgresPassword="${DB_PASSWORD}" \
  --wait --timeout 10m --cleanup-on-fail

echo ""
echo "=== Deploying MongoDB on EKS ==="
helm upgrade --install mongodb bitnami/mongodb \
  --kube-context eks-source \
  --namespace databases \
  --values $REPO_ROOT/helm/mongodb-values.yaml \
  --set auth.rootPassword="${DB_PASSWORD}" \
  --set auth.password="${DB_PASSWORD}" \
  --wait --timeout 10m --cleanup-on-fail

echo ""
echo "=== Deploying Druid on EKS ==="
kubectl create namespace druid --context eks-source --dry-run=client -o yaml | kubectl apply --context eks-source -f -
helm upgrade --install druid druid-helm/druid \
  --kube-context eks-source \
  --namespace druid \
  --values $REPO_ROOT/helm/druid-aws-values.yaml \
  --values /tmp/druid-aws-override.yaml \
  --timeout 10m

# Remove bundled postgresql StatefulSet — we use our own in 'databases' namespace
echo "  Removing bundled druid-postgresql StatefulSet..."
kubectl delete statefulset druid-postgresql -n druid --context eks-source 2>/dev/null || true

echo ""
echo "=== EKS deployments done ==="

# ─────────────────────────────────────────
# DEPLOY ON AZURE AKS (Destination)
# ─────────────────────────────────────────
echo ""
echo "=== Configuring kubectl for AKS (destination) ==="
az aks get-credentials \
  --resource-group "${AKS_RG}" \
  --name "${AKS_NAME}" \
  --context aks-destination \
  --overwrite-existing

echo ""
echo "=== Deploying PostgreSQL on AKS ==="
kubectl create namespace databases --context aks-destination --dry-run=client -o yaml | kubectl apply --context aks-destination -f -
helm upgrade --install postgresql bitnami/postgresql \
  --kube-context aks-destination \
  --namespace databases \
  --values $REPO_ROOT/helm/postgresql-values.yaml \
  --set auth.postgresPassword="${DB_PASSWORD}" \
  --wait --timeout 10m --cleanup-on-fail

echo ""
echo "=== Deploying MongoDB on AKS ==="
helm upgrade --install mongodb bitnami/mongodb \
  --kube-context aks-destination \
  --namespace databases \
  --values $REPO_ROOT/helm/mongodb-values.yaml \
  --set auth.rootPassword="${DB_PASSWORD}" \
  --set auth.password="${DB_PASSWORD}" \
  --wait --timeout 10m --cleanup-on-fail

echo ""
echo "=== Deploying Druid on AKS ==="
kubectl create namespace druid --context aks-destination --dry-run=client -o yaml | kubectl apply --context aks-destination -f -
helm upgrade --install druid druid-helm/druid \
  --kube-context aks-destination \
  --namespace druid \
  --values $REPO_ROOT/helm/druid-azure-values.yaml \
  --values /tmp/druid-azure-override.yaml \
  --timeout 10m

# Remove bundled postgresql StatefulSet — we use our own in 'databases' namespace
echo "  Removing bundled druid-postgresql StatefulSet..."
kubectl delete statefulset druid-postgresql -n druid --context aks-destination 2>/dev/null || true

echo ""
echo "=== AKS deployments done ==="
echo ""
echo "========================================"
echo " DONE: Both clusters are ready!"
echo " Next: Run scripts/2-load-data.sh"
echo "========================================"
