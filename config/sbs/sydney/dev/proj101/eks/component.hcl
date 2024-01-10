### ---------------------------------------------------------------------------------------------------------------------
### Component-specific local parameters (not Terraform inputs)
### ---------------------------------------------------------------------------------------------------------------------

locals {
  override     = ""
  tf_component = split("/", trimprefix(get_original_terragrunt_dir(), "${get_repo_root()}/config/"))[4]
  name         = coalesce(local.override, local.tf_component)
  description  = "eks component"
}
