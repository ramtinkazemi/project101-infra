### ---------------------------------------------------------------------------------------------------------------------
### These parameters apply to all the components across all regions in this namespace. To be component-specific, use common/ folder.
### ---------------------------------------------------------------------------------------------------------------------

locals {
  override     = ""
  tf_namespace = split("/", trimprefix(get_original_terragrunt_dir(), "${get_repo_root()}/config/"))[0]
  name         = coalesce(local.override, local.tf_namespace, "NS")

}

inputs = {
}

