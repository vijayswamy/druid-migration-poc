# Druid Migration POC — Lessons Learned

Lessons from building and running the AWS EKS → Azure AKS migration POC.

---

## Lesson 1 — AzCopy can succeed with partial transfers
**Lesson:** AzCopy exits 0 even if some blobs failed to copy. Never trust the exit code alone.
**Why:** Silent partial transfers mean Druid on AKS loads fewer segments and queries return wrong results.
**How to apply:** Always compare `aws s3 ls ... | wc -l` vs `az storage blob list ... | wc -l` after AzCopy.

---

## Lesson 2 — Druid on AKS won't auto-load segments after AzCopy
**Lesson:** After copying segments to Azure Blob, Druid coordinator must be restarted to pick them up.
**Why:** Druid coordinator polls deep storage on startup and on a schedule. It won't detect new blobs mid-run.
**How to apply:** After AzCopy, restart the coordinator: `kubectl rollout restart deployment/druid-coordinator -n druid --context aks-destination`

---

## Lesson 3 — Standard_DC2s_v3 has limited Azure region availability
**Lesson:** DC-series VMs (confidential compute) are not available in all Azure regions.
**Why:** AKS node pool creation fails if the VM type isn't available.
**How to apply:** Use `eastus` or `eastus2`. If quota error, file a quota increase request or switch to `Standard_D2s_v3`.

---

## Lesson 4 — terraform.tfstate must not be committed to git
**Lesson:** terraform.tfstate contains resource IDs and sometimes sensitive values. It's in .gitignore — keep it that way.
**Why:** State files can contain output values including secrets like DB endpoints.
**How to apply:** Use remote state (S3 backend) for real projects. For this POC, local state is fine but never `git add terraform.tfstate`.

---

## Lesson 5 — Gitleaks blocks on terraform.tfvars if values are real
**Lesson:** If terraform.tfvars contains real AWS keys or Azure credentials, Gitleaks will fail the pipeline.
**Why:** Secret scanning runs as the first pipeline stage before any cloud operations.
**How to apply:** terraform.tfvars should only contain non-secret values (prefix, region). All secrets go in GitHub Secrets.

---

## Lesson 6 — PostgreSQL dump/restore requires matching versions
**Lesson:** pg_dump on EKS version X cannot always restore on AKS version Y if major versions differ.
**Why:** pg_dump format changes between major versions.
**How to apply:** Pin PostgreSQL Helm chart to the same version on both clusters in helm/postgresql-values.yaml.

---

## Lesson 7 — MongoDB mongorestore needs --drop for clean restore
**Lesson:** Without `--drop`, mongorestore appends to existing documents, causing duplicate count.
**Why:** AKS MongoDB is initialized with an empty database but may have system collections.
**How to apply:** Always use `mongorestore --drop` to ensure clean restore.

---

## Lesson 8 — EKS IRSA (IAM Roles for Service Accounts) needed for S3
**Lesson:** Druid on EKS needs an IAM role annotated on the service account to read/write S3.
**Why:** Pods don't inherit EC2 instance IAM roles by default in EKS — they need IRSA.
**How to apply:** Check `terraform/aws/main.tf` — IRSA role is created and annotated on the druid service account.

---

## Lesson 9 — Always run make destroy — never close the terminal mid-demo
**Lesson:** If you close your terminal without running `make destroy`, resources keep running and cost accumulates.
**Why:** There is no automatic TTL on EKS/AKS clusters.
**How to apply:** Add `make destroy` as the last step in every demo runbook. Consider adding a GitHub Actions scheduled destroy as a safety net.

---

## Lesson 10 — validate.sh is the source of truth — not the UI
**Lesson:** Druid UI may show the datasource as loaded but with wrong segment count if AzCopy was partial.
**Why:** Druid UI shows what the coordinator thinks is loaded — not what's in storage.
**How to apply:** Always run `scripts/4-validate.sh` and check all 3 PASS before declaring migration successful.
