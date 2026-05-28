# Druid Migration POC — Claude Context

This POC proves Apache Druid, PostgreSQL, and MongoDB can be migrated
from AWS EKS to Azure AKS with zero downtime using shared deep storage.

## What this project is

```
AWS EKS (Source)                  Azure AKS (Destination)
────────────────                  ───────────────────────
Apache Druid  ──── migrate ────►  Apache Druid
PostgreSQL    ──── migrate ────►  PostgreSQL
MongoDB       ──── migrate ────►  MongoDB
     │                                   │
     └────── S3 → Azure Blob ────────────┘
              (AzCopy segments)
```

## Key facts to know immediately

**kubectl contexts:**
- AWS EKS: `eks-source`
- Azure AKS: `aks-destination`

**Namespaces:**
- `druid` — Apache Druid (both clusters)
- `databases` — PostgreSQL + MongoDB (both clusters)

**Storage:**
- EKS deep storage: S3 bucket `druid-poc-druid-segments`
- AKS deep storage: Azure Blob `druidpocdruid` / container `druid-segments`

**Cost: ~$0.38/hr. Always run `make destroy` after demo.**

**No credentials in code** — all secrets in GitHub Secrets only.

## Migration stages
1. `make apply` — Terraform: EKS + AKS + S3 + Azure Blob (~20 min)
2. `make deploy` — Helm: Druid + PostgreSQL + MongoDB on both clusters
3. `make load` — Load dummy data into EKS (source)
4. `make migrate` — Copy data EKS → AKS (pg_dump + mongodump + AzCopy)
5. `make validate` — Compare counts — all must PASS
6. `make destroy` — Destroy all resources

Or all in one: `make up` then `make destroy`

## Agents available
| Agent | When to use |
|---|---|
| `terraform` | Infrastructure failures, state issues, EKS/AKS creation |
| `druid` | Pod failures, segment loading, deep storage issues |
| `databases` | PostgreSQL/MongoDB migration failures, count mismatches |
| `github-actions` | Pipeline failures, missing secrets, Gitleaks blocks |
| `cloud-infra` | AWS/Azure cluster issues, S3/Blob access, kubeconfig |

## Slash commands available
| Command | Purpose |
|---|---|
| `/rca` | Root Cause Analysis for a migration incident |
| `/investigation` | Structured investigation of unexpected behaviour |
| `/migrate` | Guided step-by-step migration walkthrough |
| `/validate` | Compare data counts EKS vs AKS |
| `/cost-check` | Check if resources are still running (cost alert) |

## Rules (auto-applied)
- `changes.md` — applies when editing terraform/, helm/, scripts/, .github/workflows/
- `investigations.md` — applies during any incident investigation
- `rca.md` — applies when writing RCA documents

## Project structure
```
druid-migration-poc/
├── CLAUDE.md                    ← This file
├── .claude/
│   ├── agents/                  ← terraform, druid, databases, github-actions, cloud-infra
│   ├── commands/                ← rca, investigation, migrate, validate, cost-check
│   └── rules/                   ← changes, investigations, rca
├── terraform/                   ← main.tf + aws/ + azure/ modules
├── helm/                        ← Druid + PostgreSQL + MongoDB values
├── scripts/                     ← 0-create to 5-destroy
├── .github/workflows/           ← create.yml, destroy.yml
├── docs/                        ← architecture, runbook
├── investigations/              ← INV-*.md files
├── rca/                         ← RCA-*.md files
├── changes/                     ← CHG-*.md files
└── notes/methodology.md         ← 10 lessons learned
```

## GitHub repo
https://github.com/vijayswamy/druid-migration-poc
