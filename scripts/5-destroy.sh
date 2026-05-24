#!/bin/bash
# Step 5 — Destroy all infrastructure (AWS EKS + Azure AKS)
# Run this after the demo to stop all cloud costs.

set -e

echo "========================================"
echo " STEP 5: Destroy all infrastructure"
echo " AWS EKS + S3 + Azure AKS + Blob"
echo "========================================"
echo ""
echo "  This will permanently delete ALL cloud resources."
echo "  Cloud billing stops after this completes."
echo ""

# Stop any running port-forwards
echo "--- Stopping any running port-forwards ---"
pkill -f "kubectl port-forward" 2>/dev/null || true

echo ""
echo "--- Running terraform destroy ---"
cd "$(dirname "$0")/../terraform"
terraform destroy -auto-approve

echo ""
echo "========================================"
echo " DONE: Everything destroyed!"
echo " Zero cloud cost from this point."
echo ""
echo " To recreate: run scripts/0-create.sh"
echo "  or: make up"
echo "========================================"
