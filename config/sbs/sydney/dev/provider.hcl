### ---------------------------------------------------------------------------------------------------------------------
### This file defines the terraform cloud provider (aws, gcp, multi-account, ...) used to deploy the component(s). It can be added to any level (namespace, region, env, stack, component)
### ---------------------------------------------------------------------------------------------------------------------

### for aws provider, uncomment this 
locals {
  name       = "aws"
  account_id = "${get_env("AWS_ACCOUNT_ID")}"
  role_arn   = "arn:aws:iam::${local.account_id}:role/gha-infra-role-ap-southeast-2"
}
