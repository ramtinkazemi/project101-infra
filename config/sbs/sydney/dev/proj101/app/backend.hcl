### ---------------------------------------------------------------------------------------------------------------------
### This file defines the terraform remote state backend. It can be added to any level (namespace, region, env, stack, component)
### ---------------------------------------------------------------------------------------------------------------------

locals {
  name           = "s3-with-lock"
  aws_account_id = "${get_env("AWS_ACCOUNT_ID")}"
  bucket         = "terraform-state-${get_env("AWS_ACCOUNT_ID")}-${get_env("AWS_REGION")}"
  key            = "${trimprefix(get_original_terragrunt_dir(), "${get_repo_root()}/config/")}/terraform.tfstate"
  role_arn       = "arn:aws:iam::${get_env("AWS_ACCOUNT_ID")}:role/gha-oidc-infra-role-${get_env("AWS_REGION")}"
  encrypt        = true
  dynamodb_table = "${replace(trimsuffix(local.key, ".tfstate"), "/", "-")}.lock"
}

