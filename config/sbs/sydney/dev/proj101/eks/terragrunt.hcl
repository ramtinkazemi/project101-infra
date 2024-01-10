### ---------------------------------------------------------------------------------------------------------------------
### Add component-specific inputs that depend on cross-level or dependency values.
### ---------------------------------------------------------------------------------------------------------------------

inputs = {
  namespace   = "${include.namespace.locals.name}"
  region      = "${include.region.locals.name}"
  stack       = "${include.stack.locals.name}"
  env         = "${include.env.locals.name}"
  component   = "${include.component.locals.name}"
  aws_region  = "${include.region.locals.name}"
  name_prefix = "${include.stack.locals.name}-${include.env.locals.name}-${include.component.locals.name}"

  vpc_id                               = "${dependency.network.outputs.vpc_id}"
  cluster_name                         = "${include.stack.locals.name}-${include.env.locals.name}-${include.component.locals.name}"
  public_subnet_ids                    = "${dependency.network.outputs.public_subnet_ids}"
  private_subnet_ids                   = "${dependency.network.outputs.private_subnet_ids}"
  additional_eks_admin_role_arn        = "arn:aws:iam::211125726495:role/AWSReservedSSO_AdministratorAccess_0430e0c9a67472c7"
  cluster_version                      = "1.28"
  cluster_endpoint_private_access      = false
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
}


### ---------------------------------------------------------------------------------------------------------------------
### Component-specific Terragunt hooks
### ---------------------------------------------------------------------------------------------------------------------

// terraform {
//   before_hook "<name>" {
//     commands = ["plan"]
//     execute  = ["bash", "-c", ""]
//   }
//   after_hook "<name>" {
//     commands = ["apply"]
//     execute  = ["bash", "-c", ""]
//   }  
// }

### ---------------------------------------------------------------------------------------------------------------------
### Include the root and global configurations
### ---------------------------------------------------------------------------------------------------------------------

include "root" {
  path           = find_in_parent_folders("terragrunt-root.hcl")
  merge_strategy = "deep"
  expose         = true
}

include "global" {
  path           = find_in_parent_folders("global.hcl")
  merge_strategy = "deep"
  expose         = true
}

### ---------------------------------------------------------------------------------------------------------------------
### Include the component common configuration. 
### Make sure the file name matches the component type.  
### ---------------------------------------------------------------------------------------------------------------------

include "common" {
  ### cannot use vars (such as namespace) in the path here due to Terragrunt limitations requiring static path
  path           = "${get_repo_root()}/config/sbs/common/default.hcl"
  merge_strategy = "deep"
  expose         = true
}

### ---------------------------------------------------------------------------------------------------------------------
### Uncomment the following block if you want Terragrunt to create the backend automatically
### ---------------------------------------------------------------------------------------------------------------------

// include "auto_backend" {
//   path = find_in_parent_folders("auto-backend.hcl")
// }

### ---------------------------------------------------------------------------------------------------------------------
### No change is needed below.
### ---------------------------------------------------------------------------------------------------------------------

include "namespace" {
  path           = find_in_parent_folders("namespace.hcl")
  merge_strategy = "deep"
  expose         = true
}

include "region" {
  path           = find_in_parent_folders("region.hcl")
  merge_strategy = "deep"
  expose         = true
}

include "env" {
  path           = find_in_parent_folders("env.hcl")
  merge_strategy = "deep"
  expose         = true
}

include "stack" {
  path           = find_in_parent_folders("stack.hcl")
  merge_strategy = "deep"
  expose         = true
}

include "component" {
  path           = "${get_terragrunt_dir()}/component.hcl"
  merge_strategy = "deep"
  expose         = true
}

### ---------------------------------------------------------------------------------------------------------------------
### Include dependencies
### ---------------------------------------------------------------------------------------------------------------------

include "dependency" {
  path = "${get_terragrunt_dir()}/dependency.hcl"
}
