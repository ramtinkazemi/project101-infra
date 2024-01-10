.PHONY: all check-aws init validate plan apply destroy

export TG_DESTROY ?= false
export TG_CONFIG_PATH

setup-local-env:
ifeq ($(GITHUB_ACTIONS),true)
	@echo "Running on GitHub Actions => Skipping .env.local export
else
	@rm -f .env.local.tmp 2> /dev/null || true
	@sed -E "s/=(['\"])([^'\"]+)(['\"])/=\2/" .env.local > .env.local.tmp
	$(eval include .env.local.tmp)
	$(eval export)
	@echo "Running locally => .env.local variables exported"
endif

check-config-path:
	@if [ -z "$(TG_CONFIG_PATH)" ]; then \
		echo "ERROR: TG_CONFIG_PATH is not set."; \
		exit 1; \
	fi ;\
	echo "TG_CONFIG_PATH=$(TG_CONFIG_PATH)"

clean-up:
	@echo "Cleaning up Terragrunt cache..."
	@find config/ -type d -name .terragrunt-cache -exec rm -rf {} \; 2>/dev/null || true

check-aws: setup-local-env
	@echo "Checking AWS credentials..."; \
	AWS_USER=$$(aws sts get-caller-identity --output text --query 'Arn'); \
	if [ -z "$${AWS_USER}" ]; then \
		echo "Failed to retrieve AWS identity."; \
		exit 1; \
	else \
		echo "AWS User: $${AWS_USER}"; \
	fi

init: setup-local-env check-config-path check-aws
	@echo TG_INIT_ARGS=$(TG_INIT_ARGS)
	@echo "Initializing Terragrunt..."
	@./bin/init.sh

format: setup-local-env check-config-path
	@echo "Formatting Terragrunt configuration..."
	@echo TG_FORMAT_ARGS=$(TG_FORMAT_ARGS)
	@./bin/format.sh $(TG_CONFIG_PATH)

validate: setup-local-env init
	@echo "Validating Terragrunt configuration..."
	@echo TG_VALIDATE_ARGS=$(TG_VALIDATE_ARGS)
	@./bin/validate.sh $(TG_CONFIG_PATH)

sure: format validate

plan: setup-local-env check-config-path check-aws
	@echo "TG_DESTROY=$(TG_DESTROY)"
	@echo TG_PLAN_ARGS=$(TG_PLAN_ARGS)
	@if [ "$${TG_DESTROY}" = "true" ]; then \
		echo "Generating destroy plan..."; \
		./bin/plan.sh $(TG_CONFIG_PATH) -destroy; \
	elif [ "$${TG_DESTROY}" = "false" ]; then \
		echo "Generating deploy plan..."; \
		./bin/plan.sh $(TG_CONFIG_PATH); \
	fi

apply: setup-local-env check-config-path check-aws
	@echo TG_APPLY_ARGS=$(TG_APPLY_ARGS)
	@echo "Deploying resources..."
	@./bin/apply.sh $(TG_CONFIG_PATH)

destroy: setup-local-env check-aws
	@echo TG_DESTROY_ARGS=$(TG_DESTROY_ARGS)
	@echo "Destroying resources..."
	@./bin/destroy.sh $(TG_CONFIG_PATH)
