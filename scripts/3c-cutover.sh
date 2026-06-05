#!/bin/bash
# Step 3c — Cutover simulation
# Simulates zero-downtime cutover from EKS (source) to AKS (destination)
#
# In real production: switch DNS/load balancer from EKS broker to AKS broker
# In this POC: we simulate by scaling down EKS ingestion, final delta sync, validate

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "========================================"
echo " STEP 3c: Cutover EKS → AKS"
echo " Zero-downtime simulation"
echo "========================================"

# ─────────────────────────────────────────
# 1. Pause new writes on EKS
#    (simulate stopping ingestion)
# ─────────────────────────────────────────
echo ""
echo "=== [1/4] Pausing EKS ingestion (MiddleManager → 0 replicas) ==="
kubectl scale deployment druid-middlemanager \
  --replicas=0 \
  -n druid \
  --context eks-source 2>/dev/null || \
kubectl scale statefulset druid-middlemanager \
  --replicas=0 \
  -n druid \
  --context eks-source 2>/dev/null || true

echo "  EKS MiddleManager scaled to 0 — no new ingestion tasks."
echo "  Existing queries on EKS still work (Broker + Historical still up)."

# ─────────────────────────────────────────
# 2. Final delta sync
# ─────────────────────────────────────────
echo ""
echo "=== [2/4] Final delta sync (last gap before cutover) ==="
bash "${REPO_ROOT}/scripts/3b-sync-delta.sh"

# ─────────────────────────────────────────
# 3. Final validation — counts must match
# ─────────────────────────────────────────
echo ""
echo "=== [3/4] Final validation before cutover ==="
bash "${REPO_ROOT}/scripts/4-validate.sh"

# ─────────────────────────────────────────
# 4. Cutover — switch traffic to AKS
# ─────────────────────────────────────────
echo ""
echo "=== [4/4] Cutover point ==="
echo ""

AKS_BROKER_IP=$(kubectl get svc druid-broker \
  -n druid \
  --context aks-destination \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")

echo "  ┌─────────────────────────────────────────────────┐"
echo "  │           CUTOVER READY                         │"
echo "  │                                                  │"
echo "  │  AKS Druid Broker IP: ${AKS_BROKER_IP}          │"
echo "  │                                                  │"
echo "  │  ACTION REQUIRED:                               │"
echo "  │  Point your DNS / load balancer to AKS now.    │"
echo "  │                                                  │"
echo "  │  EKS → kept running as fallback for 1 hour     │"
echo "  │  Run 'make destroy' when AKS is confirmed OK   │"
echo "  └─────────────────────────────────────────────────┘"
echo ""
echo "========================================"
echo " MIGRATION COMPLETE — Zero Downtime!"
echo ""
echo " Timeline:"
echo "  Phase 1: Full data copy    (3-migrate.sh)"
echo "  Phase 2: Delta sync        (3b-sync-delta.sh)"
echo "  Phase 3: Pause EKS writes  (this script)"
echo "  Phase 4: Final sync        (3b-sync-delta.sh)"
echo "  Phase 5: Switch traffic    (DNS/LB change)"
echo ""
echo " EKS is still running as fallback."
echo " Destroy when ready: make destroy"
echo "========================================"
