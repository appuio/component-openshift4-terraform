MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:

include Makefile.vars.mk

.PHONY: all
all: lint open

.PHONY: lint
lint: lint_jsonnet lint_yaml docs-vale

.PHONY: lint_jsonnet
lint_jsonnet: $(JSONNET_FILES)
	$(JSONNET_DOCKER) $(JSONNETFMT_ARGS) --test -- $?

.PHONY: lint_yaml
lint_yaml: $(YAML_FILES)
	$(YAMLLINT_DOCKER) -f parsable -c $(YAMLLINT_CONFIG) $(YAMLLINT_ARGS) -- $?

.PHONY: format
format: format_jsonnet

.PHONY: format_jsonnet
format_jsonnet: $(JSONNET_FILES)
	$(JSONNET_DOCKER) $(JSONNETFMT_ARGS) -- $?

.PHONY: docs-serve
docs-serve:
	$(ANTORA_PREVIEW_CMD)

.PHONY: docs-vale
docs-vale:
	$(VALE_CMD) $(VALE_ARGS)

.PHONY: test-cloudscale
test-cloudscale: testfile = cloudscale.yaml
test-cloudscale: extra_args = -e CLOUDSCALE_TOKEN=sometoken
test-cloudscale: .test

.PHONY: test-exoscale
test-exoscale: testfile = exoscale.yaml
test-exoscale: extra_args = -e TF_VAR_lb_exoscale_api_key=ApiKeyForLoadBalancer -e TF_VAR_lb_exoscale_api_secret=ApiSecretForLoadBalancer
test-exoscale: .test

.PHONY: .test
.test:
	$(COMMODORE_CMD) -f tests/$(testfile)
	rm compiled/$(COMPONENT_NAME)/$(COMPONENT_NAME)/backend.tf.json # either this, or make backend configurable
	$(TERRAFORM_CMD) gitlab-terraform init
	$(TERRAFORM_CMD) gitlab-terraform validate
	$(GITLABCI_LINT_CMD)

.PHONY: clean
clean:
	rm -rf compiled manifests dependencies vendor || true
