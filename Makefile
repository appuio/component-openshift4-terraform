MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help
.DELETE_ON_ERROR:
.SUFFIXES:

include Makefile.vars.mk

.PHONY: help
help: ## Show this help
	@grep -E -h '\s##\s' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = "(: ).*?## "}; {gsub(/\\:/,":", $$1)}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: all
all: lint

.PHONY: lint
lint: lint_jsonnet lint_yaml docs-vale ## All-in-one linting

.PHONY: lint_jsonnet
lint_jsonnet: $(JSONNET_FILES) ## Lint jsonnet files
	$(JSONNET_DOCKER) $(JSONNETFMT_ARGS) --test -- $?

.PHONY: lint_yaml
lint_yaml: $(YAML_FILES) ## Lint yaml files
	$(YAMLLINT_DOCKER) -f parsable -c $(YAMLLINT_CONFIG) $(YAMLLINT_ARGS) -- $?

.PHONY: format
format: format_jsonnet ## All-in-one formatting

.PHONY: format_jsonnet
format_jsonnet: $(JSONNET_FILES) ## Format jsonnet files
	$(JSONNET_DOCKER) $(JSONNETFMT_ARGS) -- $?

.PHONY: docs-serve
docs-serve: ## Preview the documentation
	$(ANTORA_PREVIEW_CMD)

.PHONY: docs-vale
docs-vale: ## Lint the documentation
	$(VALE_CMD) $(VALE_ARGS)

.PHONY: test-cloudscale
test-cloudscale: testfile = cloudscale.yaml
test-cloudscale: extra_args = -e CLOUDSCALE_TOKEN=sometoken
test-cloudscale: .test ## Run tests for cloudscale provider

.PHONY: test-exoscale
test-exoscale: testfile = exoscale.yaml
test-exoscale: .test ## Run tests for exoscale provider

.PHONY: .test
.test:
	$(COMMODORE_CMD) -f tests/$(testfile)
	rm compiled/$(COMPONENT_NAME)/$(COMPONENT_NAME)/backend.tf.json # either this, or make backend configurable
	$(TERRAFORM_CMD) gitlab-terraform init
	$(TERRAFORM_CMD) gitlab-terraform validate
	$(GITLABCI_LINT_CMD)

.PHONY: clean
clean: ## Clean the project
	rm -rf compiled manifests dependencies vendor || true
