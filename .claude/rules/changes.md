---
name: changes
description: Rules that apply before making any infrastructure or migration change
paths:
  - terraform/**
  - helm/**
  - scripts/**
  - .github/workflows/**
---

# Change Rules

## Rule 1 — Always destroy after demo
Never leave EKS + AKS running. Cost is ~$0.38/hr = $9/day.
Run `make destroy` immediately after every demo.

**Why:** A forgotten cluster overnight = $9 wasted. A forgotten cluster over a weekend = $65.

## Rule 2 — Never hardcode credentials in any file
terraform.tfvars must never contain real AWS keys, Azure credentials, or passwords.
All secrets go in GitHub Secrets only.

**Why:** Gitleaks runs as the first pipeline stage and will block the deploy — but more importantly, credentials in git can be scraped even from private repos.

## Rule 3 — Validate on EKS before migrating
Always confirm source data exists and is correct before starting migration.
Run `make validate` on EKS first, then migrate, then validate again on AKS.

**Why:** Migrating empty or corrupt data to AKS and then destroying EKS = data loss with no recovery.

## Rule 4 — Never modify AKS data before validation passes
Do not run any write operations on AKS databases until the full validation (`make validate`) passes.

**Why:** If you write to AKS before verifying migration, you can't tell if a count mismatch is from migration failure or your additional writes.

## Rule 5 — Record every migration run
Every `make up` + `make destroy` cycle should have a change record in changes/.
Use: `changes/CHG-<date>-<title>.md`

**Why:** Helps track which demo runs succeeded, what was tested, and how long it took.

## Rule 6 — Check costs before and after
Run `/cost-check` before starting and after destroying to confirm $0 balance.

**Why:** terraform destroy can fail silently on some resources — spot check keeps costs under control.
