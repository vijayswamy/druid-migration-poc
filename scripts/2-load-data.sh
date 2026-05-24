#!/bin/bash
# Step 2 — Load dummy data into EKS (source cluster)
# PostgreSQL: employees table | MongoDB: orders collection | Druid: Wikipedia sample

set -e

echo "========================================"
echo " STEP 2: Load dummy data into EKS"
echo "========================================"

# ─────────────────────────────────────────
# PostgreSQL — dummy employees table
# ─────────────────────────────────────────
echo ""
echo "=== Loading dummy data into PostgreSQL (EKS) ==="

kubectl exec -n databases postgresql-0 --context eks-source -- \
  psql -U postgres -d druid_metadata -c "
    CREATE TABLE IF NOT EXISTS employees (
      id        SERIAL PRIMARY KEY,
      name      VARCHAR(100),
      dept      VARCHAR(50),
      salary    NUMERIC,
      joined_on DATE
    );
    INSERT INTO employees (name, dept, salary, joined_on) VALUES
      ('Vijay',  'DevOps',   85000, '2022-01-15'),
      ('Raj',    'Backend',  75000, '2021-06-10'),
      ('Priya',  'Frontend', 70000, '2023-03-01'),
      ('Ankit',  'QA',       65000, '2022-09-20'),
      ('Deepa',  'DevOps',   80000, '2020-11-05')
    ON CONFLICT DO NOTHING;
    SELECT COUNT(*) AS total_employees FROM employees;
  "

echo "PostgreSQL dummy data loaded."

# ─────────────────────────────────────────
# MongoDB — dummy orders collection
# ─────────────────────────────────────────
echo ""
echo "=== Loading dummy data into MongoDB (EKS) ==="

kubectl exec -n databases mongodb-0 --context eks-source -- \
  mongosh appdb -u appuser -p pocpassword123 --authenticationDatabase appdb --eval "
    db.orders.drop();
    db.orders.insertMany([
      { order_id: 1, customer: 'Vijay',  product: 'Laptop',  amount: 75000, status: 'delivered' },
      { order_id: 2, customer: 'Raj',    product: 'Phone',   amount: 25000, status: 'shipped'   },
      { order_id: 3, customer: 'Priya',  product: 'Tablet',  amount: 35000, status: 'pending'   },
      { order_id: 4, customer: 'Ankit',  product: 'Monitor', amount: 18000, status: 'delivered' },
      { order_id: 5, customer: 'Deepa',  product: 'Keyboard',amount: 3000,  status: 'delivered' }
    ]);
    print('Orders count: ' + db.orders.countDocuments());
  "

echo "MongoDB dummy data loaded."

# ─────────────────────────────────────────
# Druid — Wikipedia sample dataset (built-in)
# ─────────────────────────────────────────
echo ""
echo "=== Loading Wikipedia sample into Druid (EKS) ==="
echo "    This uses Druid's built-in sample — no data files needed."

DRUID_POD=$(kubectl get pods -n druid --context eks-source -l app=druid,component=router -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n druid --context eks-source "${DRUID_POD}" -- \
  curl -s -X POST http://localhost:8888/druid/indexer/v1/task \
  -H 'Content-Type: application/json' \
  -d '{
    "type": "index_parallel",
    "spec": {
      "ioConfig": {
        "type": "index_parallel",
        "inputSource": {
          "type": "http",
          "uris": ["https://druid.apache.org/data/wikipedia.json.gz"]
        },
        "inputFormat": { "type": "json" }
      },
      "dataSchema": {
        "dataSource": "wikipedia",
        "timestampSpec": { "column": "timestamp", "format": "iso" },
        "dimensionsSpec": {
          "dimensions": ["page","language","user","unpatrolled","newPage","robot","anonymous","namespace","continent","country","region","city"]
        },
        "metricsSpec": [
          { "type": "count",     "name": "count" },
          { "type": "doubleSum", "name": "added",   "fieldName": "added"   },
          { "type": "doubleSum", "name": "deleted",  "fieldName": "deleted" },
          { "type": "doubleSum", "name": "delta",    "fieldName": "delta"   }
        ],
        "granularitySpec": {
          "type": "uniform",
          "segmentGranularity": "DAY",
          "queryGranularity": "HOUR"
        }
      },
      "tuningConfig": { "type": "index_parallel" }
    }
  }'

echo ""
echo "Druid Wikipedia ingestion submitted. Wait 3-5 mins for segments to appear."
echo ""
echo "========================================"
echo " DONE: Dummy data loaded on EKS!"
echo ""
echo " Verify:"
echo "  PostgreSQL: kubectl exec -n databases postgresql-0 --context eks-source -- psql -U postgres -d druid_metadata -c 'SELECT * FROM employees;'"
echo "  MongoDB:    kubectl exec -n databases mongodb-0 --context eks-source -- mongosh appdb -u appuser -p pocpassword123 --authenticationDatabase appdb --eval 'db.orders.find()'"
echo "  Druid UI:   kubectl port-forward -n druid svc/druid-router 8888:8888 --context eks-source"
echo ""
echo " Next: Run scripts/3-migrate.sh"
echo "========================================"
