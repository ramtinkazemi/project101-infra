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
  name_prefix = "${include.stack.locals.name}-${include.component.locals.name}-${include.env.locals.name}"

  vpc_name                = "${include.stack.locals.name}-${include.component.locals.name}-${include.env.locals.name}"
  cidr_block              = "10.1.0.0/16"
  public_subnet_cidrs     = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs    = ["10.1.101.0/24", "10.1.102.0/24"]
  enable_nat_gateway      = true
  single_nat_gateway      = true
  vpce_interface_services = ["logs", "sts", "eks", "ecr.api", "ecr.dkr"]
  enable_s3_gateway       = true

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
