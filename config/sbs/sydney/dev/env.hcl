### ---------------------------------------------------------------------------------------------------------------------
### These parameters apply to all the components across all stacks in this environment.
### ---------------------------------------------------------------------------------------------------------------------

locals {
  override = ""

  tf_env = split("/", trimprefix(get_original_terragrunt_dir(), "${get_repo_root()}/config/"))[2]
  name   = coalesce(local.override, local.tf_env)
}

inputs = {
}
