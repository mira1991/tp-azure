# Layered creation of the OpenStack stack, mirroring the CI stages.
#
#   make plan ENV=dev          # full plan, nothing applied
#   make network ENV=dev       # create the network layer only
#   make security ENV=dev      # add the security layer
#   make compute ENV=dev       # converge the whole stack
#   make up ENV=dev            # all three layers in order
#   make destroy ENV=dev
#
# Credentials come from the TF_VAR_* environment variables listed in
# docs/infrastructure.md.

ENV ?= dev
TF_DIR := terraform
VARS := -var-file=environments/$(ENV).tfvars
TF := terraform -chdir=$(TF_DIR)

.PHONY: init fmt validate plan network security compute up destroy

init:
	$(TF) init

fmt:
	$(TF) fmt -recursive

validate:
	$(TF) init -backend=false
	$(TF) validate

plan: init
	$(TF) plan $(VARS)

# Each layer applies only its own target, so a failure stops the rollout at
# the layer that broke. Terraform pulls in whatever a target depends on.
network: init
	$(TF) apply $(VARS) -target=module.network

security: init
	$(TF) apply $(VARS) -target=module.security

# No target: the last step converges the whole configuration and picks up
# anything the targeted runs left out.
compute: init
	$(TF) apply $(VARS)

up: network security compute

destroy: init
	$(TF) destroy $(VARS)
