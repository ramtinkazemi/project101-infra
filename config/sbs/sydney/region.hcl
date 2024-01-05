### ---------------------------------------------------------------------------------------------------------------------
### These parameters apply to all the components across all environments in this region.
### ---------------------------------------------------------------------------------------------------------------------

locals {
  override = "ap-southeast-2"
  tf_region = split("/", trimprefix(get_original_terragrunt_dir(), "${get_repo_root()}/config/"))[1]
  name = coalesce(local.override, local.tf_region)

}

inputs = {
  aws_region   = local.name
}
