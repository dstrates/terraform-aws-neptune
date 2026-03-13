SHELL := /bin/bash

TEST_DIR     := test
TEST_TIMEOUT := 60m
UNIT_TIMEOUT := 5m

##@ Testing

.PHONY: test
test: test-unit ## Run all safe-to-run tests (no AWS credentials required)

.PHONY: test-unit
test-unit: ## Run plan-only validation tests
	cd $(TEST_DIR) && go test -v -count=1 -run 'TestNeptuneValidation_' -timeout $(UNIT_TIMEOUT)

.PHONY: test-acc
test-acc: ## Run acceptance tests (creates real AWS resources)
	cd $(TEST_DIR) && RUN_ACC_TESTS=true go test -v -count=1 -timeout $(TEST_TIMEOUT)

##@ Linting

.PHONY: lint
lint: ## Run all pre-commit hooks
	pre-commit run --all-files

.PHONY: fmt
fmt: ## Format Terraform files
	terraform fmt -recursive .

##@ Docs

.PHONY: docs
docs: ## Generate Terraform module documentation
	terraform-docs markdown table --output-file README.md --output-mode inject .
