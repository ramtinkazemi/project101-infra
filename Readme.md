# Terraform Infrastructure Management on AWS (Infra)

This repository is dedicated to managing AWS infrastructure using Terragrunt in the project. It contains Terragrunt configurations for deploying AWS resources, leveraging Terraform modules from the `blueprints` repository. This README explains how to use the configurations and outlines the available Makefile commands.

## Makefile Commands

- `check-aws`: Validates AWS credentials.
- `init`: Initializes Terragrunt, preparing for deployment.
- `validate`: Checks Terragrunt configurations for correctness.
- `format`: Formats Terragrunt files for consistency.
- `sure`: Runs a series of checks (`format`, `validate`) for thorough configuration validation.
- `plan`: Creates an execution plan for Terraform.
- `apply`: Applies the Terraform plan to deploy resources.
- `destroy`: Removes deployed resources.

## Usage

1. Ensure AWS CLI and Terragrunt are installed and configured.
2. Clone the repository and navigate to the desired environment configuration within the `config` directory.
3. Use Makefile commands to manage and deploy AWS infrastructure:
   - Start with `make check-aws` to verify AWS credentials.
   - Run `make init` to initialize the environment.
   - Use `make sure` for comprehensive checks.
   - Deploy with `make apply` or remove resources with `make destroy`.

## Troubleshooting

- Regularly use `make sure` to catch potential issues early.
- For deployment errors, refer to the specific error logs and Terragrunt documentation for resolution.

## Notes

- The repository is tailored for the project and uses specific configurations for AWS.
- Manage AWS credentials and Terragrunt state files with strict security practices.
- The repository relies on the `blueprints` repository for Terraform modules.