### ---------------------------------------------------------------------------------------------------------------------
### These parameters apply to all the components in this stack.
### ---------------------------------------------------------------------------------------------------------------------

locals {
  override = ""
  tf_stack = split("/", trimprefix(get_original_terragrunt_dir(), "${get_repo_root()}/config/"))[3]
  name     = coalesce(local.override, local.tf_stack)

  version     = "${get_env("TG_STACK_VERSION", "")}"
  description = "Web app stack with network, eks, and app components"
}

inputs = {}
