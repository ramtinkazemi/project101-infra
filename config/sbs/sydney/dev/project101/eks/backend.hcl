### ---------------------------------------------------------------------------------------------------------------------
### This file defines the terraform remote state backend. It can be added to any level (namespace, region, env, stack, component)
### ---------------------------------------------------------------------------------------------------------------------

locals {

  ### load env-level parameters
  Env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  env = local.Env.name

  ### load stack-level parameters
  Stack = read_terragrunt_config(find_in_parent_folders("stack.hcl")).locals
  stack = local.Stack.name

  ### load component-level parameters
  Component        = read_terragrunt_config("${get_terragrunt_dir()}/component.hcl").locals
  component = local.Component.name

  name           = "s3-with-lock"
  aws_account_id = "${get_env("AWS_ACCOUNT_ID")}"
  bucket         = "terraform-state-${get_env("AWS_ACCOUNT_ID")}-${get_env("AWS_REGION")}"
  key            = "${trimprefix(get_original_terragrunt_dir(), "${get_repo_root()}/config/")}/terraform.tfstate"
  role_arn       = "arn:aws:iam::${get_env("AWS_ACCOUNT_ID")}:role/gha-oidc-infra-role-${get_env("AWS_REGION")}"
  encrypt        = true
  // dynamodb_table = "${replace(trimsuffix(local.key, ".tfstate"), "/", "-")}.lock"
  dynamodb_table = "${local.stack}-${local.component}-${local.env}-terraform-lock"
}

