#!/bin/bash
# Step 0 — Create everything end-to-end
# Runs: infra → deploy apps → load data → migrate → validate

set -e

SCRIPT_DIR="$(dirname "$0")"

echo "========================================"
echo " Druid Migration POC — Full Setup"
echo " AWS EKS (source) → Azure AKS (dest)"
echo "========================================"

bash "${SCRIPT_DIR}/../terraform/apply.sh" 2>/dev/null || (
  echo "--- Spinning up infrastructure (Terraform) ---"
  cd "${SCRIPT_DIR}/../terraform"
  terraform init
  terraform apply -auto-approve
  cd -
)

echo ""
bash "${SCRIPT_DIR}/1-deploy-apps.sh"

echo ""
bash "${SCRIPT_DIR}/2-load-data.sh"

echo ""
bash "${SCRIPT_DIR}/3-migrate.sh"

echo ""
bash "${SCRIPT_DIR}/4-validate.sh"

echo ""
echo "========================================"
echo " DEMO READY!"
echo ""
echo " Open Druid UI on both clusters:"
echo "   kubectl port-forward -n druid svc/druid-router 8888:8888 --context eks-source &"
echo "   kubectl port-forward -n druid svc/druid-router 8889:8888 --context aks-destination &"
echo ""
echo "   EKS (source):      http://localhost:8888"
echo "   AKS (destination): http://localhost:8889"
echo ""
echo " When done: bash scripts/5-destroy.sh"
echo "========================================"
