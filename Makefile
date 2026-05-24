# Druid Migration POC — EKS to AKS
# Usage:
#   make up       → full demo: infra + apps + data + migration + validation (ONE COMMAND)
#   make destroy  → tear down everything (AWS + Azure)
#
# Step by step (alternative to make up):
#   make apply    → spin up infrastructure only (AWS EKS + Azure AKS)
#   make deploy   → install Druid, PostgreSQL, MongoDB via Helm on both clusters
#   make load     → load dummy data into EKS (source)
#   make migrate  → migrate data from EKS to AKS
#   make validate → compare data between EKS and AKS

.PHONY: up apply deploy load migrate validate destroy

## ONE COMMAND: full demo end-to-end (infra → apps → data → migration → validation)
up: apply deploy load migrate validate
	@echo ""
	@echo "========================================"
	@echo " DEMO READY!"
	@echo " EKS (source):      kubectl port-forward -n druid svc/druid-router 8888:8888 --context eks-source &"
	@echo " AKS (destination): kubectl port-forward -n druid svc/druid-router 8889:8888 --context aks-destination &"
	@echo " Then open: http://localhost:8888 and http://localhost:8889"
	@echo "========================================"

## Spin up all infrastructure on AWS + Azure
apply:
	cd terraform && terraform init && terraform apply -auto-approve

## Install all apps via Helm on both clusters
deploy:
	bash scripts/1-deploy-apps.sh

## Load dummy data into EKS (source)
load:
	bash scripts/2-load-data.sh

## Migrate PostgreSQL + MongoDB + Druid segments to AKS
migrate:
	bash scripts/3-migrate.sh

## Validate data matches between EKS and AKS
validate:
	bash scripts/4-validate.sh

## Destroy all infrastructure on AWS + Azure
destroy:
	cd terraform && terraform destroy -auto-approve
