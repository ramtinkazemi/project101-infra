### ---------------------------------------------------------------------------------------------------------------------
### This file defines the terraform remote state backend. It can be added to any level (namespace, region, env, stack, component)
### ---------------------------------------------------------------------------------------------------------------------

// ## for S3 backend, uncomment this
// locals {
//   name   = "s3"
//   bucket = "${get_env("AWS_ACCOUNT_ID")}-terraform-state"
//   key = "/tf_state/${get_env("TG_STACK")}/${get_env("TG_COMPONENT")}/${trimprefix(get_original_terragrunt_dir(), "${get_repo_root()}/config/")}/terraform.tfstate"
//   region = "ap-southeast-2"
//   role_arn        = "arn:aws:iam::211125726495:role/gha-infra-role-ap-southeast-2"
//   encrypt = false
//   dynamodb_table = "${replace(trimsuffix(local.key, ".tfstate"), "/", ".")}.lock"
// }
