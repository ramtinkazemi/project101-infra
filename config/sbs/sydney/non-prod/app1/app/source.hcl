### ---------------------------------------------------------------------------------------------------------------------
### This file defines the terraform module source for this component.
### ---------------------------------------------------------------------------------------------------------------------

locals {
  stack         = read_terragrunt_config("../stack.hcl").locals
  repo          = "git@github.com:ramtinkazemi/project101-blueprints.git"
  path          = "modules/app"
  version       = coalesce("${get_env("TG_COMPONENT_VERSION", "")}", local.stack.version, "main")
  module_source = "git::${local.repo}//${local.path}?ref=${local.version}"
}
