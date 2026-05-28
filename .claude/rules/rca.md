---
name: rca
description: Rules for writing RCAs for migration incidents
paths:
  - rca/**
---

# RCA Rules

## Rule 1 — Every failed migration run gets an RCA
If `make up` or any migration stage fails and you had to retry — write an RCA.
Even if you fixed it in 5 minutes.

**Why:** Patterns emerge. Your 3rd RCA on the same Druid coordinator issue tells you it needs a permanent fix.

## Rule 2 — Note the cost impact
Every RCA must include how long resources were running during the incident.
Example: "Resources ran for 3 extra hours due to debugging = $1.14 additional cost."

## Rule 3 — Blameless — blame the system not the person
Never write "I forgot to destroy" — write "There is no automated destroy after demo completes."

## Rule 4 — Prevention must be actionable
Bad: "Be more careful with AzCopy"
Good: "Add segment count comparison to validate.sh — fail if counts don't match within 5%"

## Rule 5 — RCA file naming
`rca/RCA-<YYYY-MM-DD>-<short-kebab-title>.md`
Example: `rca/RCA-2026-05-28-druid-coordinator-crashloop-aks.md`

## Rule 6 — Link to the pipeline run
Always include the GitHub Actions run ID in the RCA so the full logs can be found:
```
Pipeline run: https://github.com/vijayswamy/druid-migration-poc/actions/runs/<run-id>
```
