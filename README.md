# Druid Migration POC — AWS EKS → Azure AKS (Zero Downtime)

This POC proves that Apache Druid, PostgreSQL, and MongoDB can be migrated
from AWS EKS to Azure AKS with zero downtime using shared deep storage.

---

## What This POC Does

```
AWS EKS (Source)                  Azure AKS (Destination)
────────────────                  ───────────────────────
Apache Druid  ──── migrate ────►  Apache Druid
PostgreSQL    ──── migrate ────►  PostgreSQL
MongoDB       ──── migrate ────►  MongoDB
     │                                   │
     └────── S3 → Azure Blob ────────────┘
              (segments copied)
```

---

## Folder Structure

```
druid-migration-poc/
├── Makefile                        ← Single commands to apply/destroy
├── terraform/
│   ├── main.tf                     ← Root: calls AWS + Azure modules
│   ├── variables.tf                ← Common variables (prefix, regions)
│   ├── outputs.tf                  ← Outputs from both modules
│   ├── terraform.tfvars            ← Your values go here
│   ├── aws/
│   │   ├── main.tf                 ← EKS cluster + S3 bucket + VPC + IAM
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── azure/
│       ├── main.tf                 ← AKS cluster + Azure Blob Storage
│       ├── variables.tf
│       └── outputs.tf
├── helm/
│   ├── druid-aws-values.yaml       ← Druid config for EKS (S3 deep storage)
│   ├── druid-azure-values.yaml     ← Druid config for AKS (Azure Blob)
│   ├── postgresql-values.yaml      ← PostgreSQL config (same for both)
│   └── mongodb-values.yaml         ← MongoDB config (same for both)
└── scripts/
    ├── 1-deploy-apps.sh            ← Helm install on both clusters
    ├── 2-load-data.sh              ← Load dummy data into EKS
    ├── 3-migrate.sh                ← Migrate data EKS → AKS
    └── 4-validate.sh              ← Compare counts EKS vs AKS
```

---

## Pre-requisites

Install these tools before running:

| Tool      | Install                                      |
|-----------|----------------------------------------------|
| Terraform | https://developer.hashicorp.com/terraform/install |
| AWS CLI   | https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html |
| Azure CLI | https://learn.microsoft.com/en-us/cli/azure/install-azure-cli |
| kubectl   | https://kubernetes.io/docs/tasks/tools/ |
| Helm      | https://helm.sh/docs/intro/install/ |
| AzCopy    | https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-v10 |

Configure credentials:
```bash
aws configure          # enter AWS Access Key, Secret, region: us-east-1
az login               # browser login for Azure
```

---

## How to Run the POC

### ONE COMMAND — Full demo end-to-end

```bash
make up
```

Runs everything in sequence: infra → deploy apps → load data → migrate → validate.
Takes ~30-40 minutes total. When done, prints the port-forward commands to open both UIs.

---

### Step by step (alternative to `make up`)

#### Step 1 — Spin up all infrastructure

```bash
make apply
```

Creates in one shot:
- AWS: VPC + EKS cluster (2x t3.medium) + S3 bucket
- Azure: Resource Group + AKS cluster (2x Standard_DC2s_v3) + Blob Storage

Takes ~20-25 minutes.

---

#### Step 2 — Deploy apps on both clusters

```bash
make deploy
```

Installs via Helm:
- Apache Druid (on both EKS and AKS)
- PostgreSQL (on both)
- MongoDB (on both)

---

#### Step 3 — Load dummy data into EKS (source)

```bash
make load
```

Loads:
- PostgreSQL: `employees` table (5 rows)
- MongoDB: `orders` collection (5 documents)
- Druid: Wikipedia sample dataset (built-in, auto-waits for segments)

---

#### Step 4 — Migrate data from EKS to AKS

```bash
make migrate
```

Runs:
1. `pg_dump` from EKS PostgreSQL → restore on AKS PostgreSQL
2. `mongodump` from EKS MongoDB → restore on AKS MongoDB
3. AzCopy: S3 Druid segments → Azure Blob (waits until segments exist)

---

#### Step 5 — Validate migration

```bash
make validate
```

Compares:
- PostgreSQL row counts (EKS vs AKS)
- MongoDB document counts (EKS vs AKS)
- Druid segment counts (EKS vs AKS)

All checks must show PASS before switching traffic.

---

### Destroy everything (after demo)

```bash
make destroy
```

Tears down all AWS and Azure resources. Zero cost after this.
Safe to run `make up` again any time — fully reusable.

---

## Verify the Migration (UI Proof)

After `make up` completes, open the Druid Web Console on both clusters:

```bash
# Source (AWS EKS)
kubectl port-forward -n druid svc/druid-router 8888:8888 --context eks-source &

# Destination (Azure AKS)
kubectl port-forward -n druid svc/druid-router 8889:8888 --context aks-destination &
```

| UI | URL | What to check |
|----|-----|---------------|
| EKS (source) | http://localhost:8888 | Datasources → `wikipedia` exists |
| AKS (destination) | http://localhost:8889 | Datasources → `wikipedia` exists |

Run this SQL on both — results must match:

```sql
SELECT page, COUNT(*) AS edits
FROM wikipedia
GROUP BY page
ORDER BY edits DESC
LIMIT 10
```

Same output on both = migration proven.

---

## Cost Estimate

| Resource              | Cost/hr  |
|-----------------------|----------|
| EKS control plane     | $0.10    |
| 2x t3.medium nodes    | $0.09    |
| AKS control plane     | Free     |
| 2x Standard_DC2s_v3  | $0.23    |
| S3 + Azure Blob       | ~$0.00   |
| **Total**             | **~$0.38/hr** |

A 2-hour demo costs approximately **$0.76**.
Always run `make destroy` after the demo.

---

## Key Concepts Demonstrated

| Concept | Where |
|---------|-------|
| EKS with IAM roles for S3 access | `terraform/aws/main.tf` |
| Druid deep storage on S3 | `helm/druid-aws-values.yaml` |
| Druid deep storage on Azure Blob | `helm/druid-azure-values.yaml` |
| Cross-cloud segment copy (AzCopy) | `scripts/3-migrate.sh` |
| PostgreSQL dump/restore | `scripts/3-migrate.sh` |
| MongoDB dump/restore | `scripts/3-migrate.sh` |
| Data validation between clusters | `scripts/4-validate.sh` |
