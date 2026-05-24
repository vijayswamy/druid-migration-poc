# POC Progress Status

Last updated: 2026-05-24

## Infrastructure ✅ DONE
- AWS EKS: `druid-poc-eks` (us-east-1) — kubectl context: `eks-source`
- Azure AKS: `druid-poc-aks` (eastus) — kubectl context: `aks-destination`
- S3 Bucket: `druid-poc-druid-segments`
- Azure Blob: `druidpocdruid` / container: `druid-segments`

## Apps Deployed ✅ DONE
- PostgreSQL: both clusters (`databases` namespace)
- MongoDB: both clusters (`databases` namespace)
- Druid: both clusters (`druid` namespace) — all pods Running

## Data Loaded ✅ DONE
- PostgreSQL EKS: `employees` table, 5 rows
- MongoDB EKS: `orders` collection, 5 documents
- Druid EKS: `wikipedia` datasource, 2 segments in S3

## Migration ✅ DONE
- [x] PostgreSQL: dumped from EKS, restored on AKS
- [x] MongoDB: dumped from EKS, restored on AKS
- [x] Druid segments: copied S3 → Azure Blob via AzCopy

## Validation ✅ DONE
- PostgreSQL: 5 rows match on both clusters
- MongoDB: 5 documents match on both clusters
- Druid: wikipedia datasource queryable on AKS

## Infrastructure Destroyed ✅
- All AWS + Azure resources destroyed via `make destroy`
- Zero cloud cost

## To Run Again
```bash
cd ~/druid-migration-poc
make up       # creates everything (~35-40 min)
make destroy  # tears everything down
```
