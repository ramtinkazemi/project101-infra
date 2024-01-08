### ---------------------------------------------------------------------------------------------------------------------
### This file defines the terraform remote state backend. It can be added to any level (namespace, region, env, stack, component)
### ---------------------------------------------------------------------------------------------------------------------

locals {
  name   = "s3-with-lock"
  aws_account_id = "211125726495"
  bucket = "terraform-state-211125726495-ap-southeast-2"
  key = "${trimprefix(get_original_terragrunt_dir(), "${get_repo_root()}/config/")}/terraform.tfstate"
  role_arn        = "arn:aws:iam::211125726495:role/github-action-infra-role-ap-southeast-2"
  encrypt = true
  dynamodb_table = "${replace(trimsuffix(local.key, ".tfstate"), "/", "-")}.lock"
}
