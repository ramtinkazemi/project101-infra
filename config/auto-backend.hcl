### ---------------------------------------------------------------------------------------------------------------------
### Remote state
### ---------------------------------------------------------------------------------------------------------------------

# for Terragrunt to auto create the backend, uncomment this
remote_state {
  backend = "${local.Backend.name}"
  config = {
    bucket = "${local.Backend.bucket}"
    key    = "${local.Backend.key}"
    region = "${local.Backend.region}"
    encrypt = true
    dynamodb_table = "${local.Backend.dynamodb_table}"
    assume_role {
      role_arn       = "${local.Backend.role_arn}"
    }
}
