.PHONY: all check-aws init validate plan apply destroy


# Export TG_DESTROY and TG_CONFIG_PATH so it's available to the shell commands
# Set TG_DESTROY to 'false' if not provided
export TG_DESTROY ?= false
export TG_CONFIG_PATH

all: clean-up check-aws init validate plan apply destroy

check-config-path:
	@if [ -z "$(TG_CONFIG_PATH)" ]; then \
		echo "ERROR: TG_CONFIG_PATH is not set."; \
		exit 1; \
	fi ;\
	echo "TG_CONFIG_PATH=$(TG_CONFIG_PATH)"

clean-up:
	@echo "Cleaning up Terragrunt cache..."
	@find config/ -type d -name .terragrunt-cache -exec rm -rf {} \; 2>/dev/null || true

check-aws:
	@echo "Checking AWS credentials..."
	@AWS_IDENTITY=$$(aws sts get-caller-identity --output text --query 'Account'); \
	AWS_USER=$$(aws sts get-caller-identity --output text --query 'Arn'); \
	if [ -z "$$AWS_IDENTITY" ]; then \
		echo "Failed to retrieve AWS identity."; \
		exit 1; \
	else \
		echo "AWS User: $$AWS_USER"; \
	fi

init: check-config-path check-aws
	@echo "Initializing Terragrunt..."
	@./bin/init.sh $(TG_CONFIG_PATH)

format: check-config-path
	@echo "Formatting Terragrunt configuration..."
	@./bin/format.sh $(TG_CONFIG_PATH)

validate: init
	@echo "Validating Terragrunt configuration..."
	@./bin/validate.sh $(TG_CONFIG_PATH)

sure: format validate

plan: check-config-path check-aws
	@echo "TG_DESTROY=$(TG_DESTROY)"
	@if [ "$${TG_DESTROY}" = "true" ]; then \
		echo "Generating destroy plan..."; \
		./bin/plan.sh $(TG_CONFIG_PATH) -destroy; \
	elif [ "$${TG_DESTROY}" = "false" ]; then \
		echo "Generating deploy plan..."; \
		./bin/plan.sh $(TG_CONFIG_PATH); \
	fi

apply: check-config-path check-aws
	@echo "Deploying resources..."
	@./bin/apply.sh $(TG_CONFIG_PATH)

destroy: check-aws
	@echo "Destroying resources..."
	@./bin/destroy.sh $(TG_CONFIG_PATH)
