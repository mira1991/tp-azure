# Outillage local — les mêmes contrôles que le stage validate de la pipeline.

TERRAFORM ?= terraform
TOOLBOX_VERSION ?= 1.0.0
TOOLBOX_IMAGE ?= toolbox:$(TOOLBOX_VERSION)

TF_ROOTS := terraform/substrate terraform/openstack-config

.PHONY: help fmt lint test tftest unit lock toolbox-build toolbox-push clean

help: ## Affiche cette aide
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-16s %s\n", $$1, $$2}'

fmt: ## terraform fmt + ruff format
	$(TERRAFORM) fmt -recursive terraform/
	ruff format scripts/ tests/

lint: ## Tous les linters (comme le stage validate)
	yamllint --strict -c .yamllint.yml .
	python3 scripts/validate-inputs.py
	$(TERRAFORM) fmt -check -recursive terraform/
	@for root in $(TF_ROOTS); do \
		echo "== validate $$root =="; \
		$(TERRAFORM) -chdir=$$root init -backend=false -input=false > /dev/null; \
		$(TERRAFORM) -chdir=$$root validate; \
	done
	tflint --init --config "$(CURDIR)/.tflint.hcl"
	@for root in $(TF_ROOTS); do tflint --chdir $$root --config "$(CURDIR)/.tflint.hcl"; done
	checkov --config-file .checkov.yaml --directory terraform
	ansible-lint ansible/
	ruff check scripts/ tests/
	mypy scripts/

unit: ## Tests unitaires Python
	pytest tests/unit -v

tftest: ## Tests Terraform (providers mockés)
	$(TERRAFORM) -chdir=terraform/substrate init -backend=false -input=false > /dev/null
	$(TERRAFORM) -chdir=terraform/substrate test

test: unit tftest ## Tous les tests exécutables hors plateforme

lock: ## (Re)génère les lock files providers multi-plateformes
	@for root in $(TF_ROOTS); do \
		echo "== providers lock $$root =="; \
		$(TERRAFORM) -chdir=$$root providers lock \
			-platform=linux_amd64 -platform=linux_arm64 \
			-platform=darwin_amd64 -platform=darwin_arm64; \
	done

toolbox-build: ## Construit l'image toolbox (versions épinglées dans ci/Dockerfile)
	docker build -t $(TOOLBOX_IMAGE) ci/

toolbox-push: ## Pousse l'image toolbox vers la registry du projet
	@test -n "$(CI_REGISTRY_IMAGE)" || { echo "CI_REGISTRY_IMAGE requis"; exit 1; }
	docker tag $(TOOLBOX_IMAGE) $(CI_REGISTRY_IMAGE)/$(TOOLBOX_IMAGE)
	docker push $(CI_REGISTRY_IMAGE)/$(TOOLBOX_IMAGE)

clean: ## Nettoie les artefacts locaux
	rm -rf reports/ artifacts/ .kolla/ .osc/ .terraform.d/
	find terraform -name '.terraform' -type d -prune -exec rm -rf {} +
	find terraform -name 'tfplan*.bin' -delete
