#!/bin/bash
# Step 4 — Validate migration: compare EKS vs AKS data
# Checks PostgreSQL row counts, MongoDB doc counts, Druid segment counts

set -e

PASS=0
FAIL=0

check() {
  local label="$1"
  local eks_val="$2"
  local aks_val="$3"

  if [ "${eks_val}" = "${aks_val}" ]; then
    echo "  PASS: ${label} — EKS: ${eks_val} = AKS: ${aks_val}"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: ${label} — EKS: ${eks_val} != AKS: ${aks_val}"
    FAIL=$((FAIL + 1))
  fi
}

echo "========================================"
echo " STEP 4: Validate Migration"
echo "========================================"

# ─────────────────────────────────────────
# PostgreSQL — row count check
# ─────────────────────────────────────────
echo ""
echo "=== [1/3] PostgreSQL Validation ==="

EKS_PG_COUNT=$(kubectl exec -n databases postgresql-0 --context eks-source -- \
  psql -U postgres -d druid_metadata -t -c "SELECT COUNT(*) FROM employees;" | tr -d ' ')

AKS_PG_COUNT=$(kubectl exec -n databases postgresql-0 --context aks-destination -- \
  psql -U postgres -d druid_metadata -t -c "SELECT COUNT(*) FROM employees;" | tr -d ' ')

check "employees row count" "${EKS_PG_COUNT}" "${AKS_PG_COUNT}"

# ─────────────────────────────────────────
# MongoDB — document count check
# ─────────────────────────────────────────
echo ""
echo "=== [2/3] MongoDB Validation ==="

EKS_MONGO_COUNT=$(kubectl exec -n databases mongodb-0 --context eks-source -- \
  mongosh appdb -u appuser -p ${DB_PASSWORD} --authenticationDatabase appdb --quiet \
  --eval "db.orders.countDocuments()")

AKS_MONGO_COUNT=$(kubectl exec -n databases mongodb-0 --context aks-destination -- \
  mongosh appdb -u appuser -p ${DB_PASSWORD} --authenticationDatabase appdb --quiet \
  --eval "db.orders.countDocuments()")

check "orders document count" "${EKS_MONGO_COUNT}" "${AKS_MONGO_COUNT}"

# ─────────────────────────────────────────
# Druid — segment count via Coordinator API
# ─────────────────────────────────────────
echo ""
echo "=== [3/3] Druid Validation ==="

echo "  Port-forwarding Druid coordinators for segment count check..."

kubectl port-forward -n druid svc/druid-coordinator 8181:8081 --context eks-source &
EKS_PF_PID=$!

kubectl port-forward -n druid svc/druid-coordinator 8182:8081 --context aks-destination &
AKS_PF_PID=$!

sleep 5

EKS_SEGMENTS=$(curl -s http://localhost:8181/druid/coordinator/v1/datasources/wikipedia/segments | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
AKS_SEGMENTS=$(curl -s http://localhost:8182/druid/coordinator/v1/datasources/wikipedia/segments | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

kill ${EKS_PF_PID} ${AKS_PF_PID} 2>/dev/null

check "Druid wikipedia segment count" "${EKS_SEGMENTS}" "${AKS_SEGMENTS}"

# ─────────────────────────────────────────
# Summary
# ─────────────────────────────────────────
echo ""
echo "========================================"
echo " VALIDATION SUMMARY"
echo "  Passed: ${PASS}"
echo "  Failed: ${FAIL}"
echo ""
if [ "${FAIL}" -eq 0 ]; then
  echo " ALL CHECKS PASSED — Migration successful!"
  echo " You can now switch traffic to AKS."
else
  echo " SOME CHECKS FAILED — Review above before switching traffic."
fi
echo "========================================"
