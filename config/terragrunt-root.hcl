### ---------------------------------------------------------------------------------------------------------------------
### locals
### ---------------------------------------------------------------------------------------------------------------------

locals {
  ### config path is structured as <namespace>([0])/<region>([1])/<env>([2])/<stack>([3])/<component>([4])
  path_segments = split("/", trimprefix(get_original_terragrunt_dir(), "${get_repo_root()}/config/"))
  # path_segments = split("/", trimprefix(get_original_terragrunt_dir(), "${abspath(path.cwd)}/config/"))

  tf_namespace = local.path_segments[0]
  tf_region    = local.path_segments[1]
  tf_env       = local.path_segments[2]
  tf_stack     = local.path_segments[3]
  tf_component = local.path_segments[4]

  ### load namespace-level parameters
  Namespace = read_terragrunt_config(find_in_parent_folders("namespace.hcl")).locals
  namespace = local.Namespace.name

  ### load region-level parameters
  Region = read_terragrunt_config(find_in_parent_folders("region.hcl")).locals
  region = local.Region.name

  ### load env-level parameters
  Env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  env = local.Env.name

  ### load stack-level parameters
  Stack = read_terragrunt_config(find_in_parent_folders("stack.hcl")).locals
  stack = local.Stack.name

  ### load component-level parameters
  Component        = read_terragrunt_config("${get_terragrunt_dir()}/component.hcl").locals
  component = local.Component.name

  ### load component-level parameters
  Source        = read_terragrunt_config("${get_terragrunt_dir()}/source.hcl").locals
  module_source = local.Source.module_source
  # revision       = local.Component.revision
  # module_source    = local.Component.module_source

  ### load backend variables, allows component-level overriding
  backend_overriden          = fileexists("${get_terragrunt_dir()}/backend.hcl")
  Backend                    = local.backend_overriden ? read_terragrunt_config("${get_terragrunt_dir()}/backend.hcl").locals : read_terragrunt_config(find_in_parent_folders("backend.hcl")).locals
  backend_template_overriden = fileexists("${get_repo_root()}/templates/backend-${local.Backend.name}.tpl")
  backend_template           = local.backend_template_overriden ? "${get_repo_root()}/templates/backend-${local.Backend.name}.tpl" : find_in_parent_folders("backend-${local.Backend.name}.tpl")

  ### load provider variables, allows component-level overriding
  provider_overriden          = fileexists("${get_terragrunt_dir()}/provider.hcl")
  Provider                    = local.provider_overriden ? read_terragrunt_config("${get_terragrunt_dir()}/provider.hcl").locals : read_terragrunt_config(find_in_parent_folders("provider.hcl")).locals
  provider_template_overriden = fileexists("${get_repo_root()}/templates/provider-${local.Provider.name}.tpl")
  provider_template           = local.provider_template_overriden ? "${get_repo_root()}/templates/provider-${local.Provider.name}.tpl" : find_in_parent_folders("provider-${local.Provider.name}.tpl")

  ### load common inputs for the component, if any
  common_config_path = "${get_repo_root()}/config/${local.tf_namespace}/common/${local.tf_component}.hcl"
  Common = fileexists(local.common_config_path) ? read_terragrunt_config("${get_repo_root()}/config/${local.tf_namespace}/common/${local.tf_component}.hcl").locals : null

  ### load global inputs across all namespaces
  Global = read_terragrunt_config("${get_repo_root()}/config/global.hcl").locals

  Version           = read_terragrunt_config("${get_repo_root()}/config/version.hcl").locals
  terraform_version = lookup(local.Version, "terraform_version", null)

  ### this is not a deep merge => FIX-ME
  merged_locals = merge(
    local.Global,
    local.Namespace,
    local.Common,
    local.Region,
    local.Env,
    local.Stack,
    local.Source,
    local.Backend,
    local.Provider,
    local.Version,
    {
      namespace                   = local.namespace,
      region                      = local.region,
      env                         = local.env,
      stack                       = local.stack,
      component                   = local.component
      provider_overriden          = local.provider_overriden
      provider_template_overriden = local.provider_template_overriden
      backend_overriden           = local.backend_overriden
      backend_template_overriden  = local.backend_template_overriden
    }
  )

}

### ---------------------------------------------------------------------------------------------------------------------
### Add some global tags applied to all the components across all the namespaces.
### ---------------------------------------------------------------------------------------------------------------------

inputs = {
  tags = {
    managed   = "terragrunt"
    namespace = "${local.namespace}"
    region    = "${local.region}"
    stack     = "${local.stack}"
    component = "${local.component}"
    env       = "${local.env}"
  }
}


### ---------------------------------------------------------------------------------------------------------------------
### Terraform version enforcement
### ---------------------------------------------------------------------------------------------------------------------

### set tarraform version to use
generate "terraform_version" {
  path      = "terraform_version_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
%{if local.terraform_version != null}
  required_version = "${local.terraform_version}"
%{endif}
}
EOF
}

### ---------------------------------------------------------------------------------------------------------------------
### Backend config enforcement
### ---------------------------------------------------------------------------------------------------------------------

### generate terraform backend config
generate "backend" {
  path      = "backend_override.tf"
  if_exists = "overwrite"
  contents  = templatefile(local.backend_template, merge(local.merged_locals, local.Backend))
}

### ---------------------------------------------------------------------------------------------------------------------
### Provider config enforcement
### ---------------------------------------------------------------------------------------------------------------------

### generate terraform provider config
generate "provider" {
  path      = "provider_override.tf"
  if_exists = "overwrite"
  contents  = templatefile(local.provider_template, merge(local.merged_locals, local.Provider))
}


### ---------------------------------------------------------------------------------------------------------------------
### mark down the component folder
### ---------------------------------------------------------------------------------------------------------------------

generate "component-root" {
  path      = ".terragrunt-component-root"
  if_exists = "overwrite"
  contents  = "Only to make the component's actual folder used by Terragrunt at run-time. "
}

### ---------------------------------------------------------------------------------------------------------------------
### generate terragrunt local blocks fro debuggig purpose
### ---------------------------------------------------------------------------------------------------------------------
generate "debug" {
  path      = "locals-debug.json"
  if_exists = "overwrite"
  contents  = jsonencode(local.merged_locals)
}


### ---------------------------------------------------------------------------------------------------------------------
### Terraform arguments and hooks
### ---------------------------------------------------------------------------------------------------------------------

terraform {

  # source = "${local.module_source}//${local.module_source}?ref=${local.revision}"
  source = local.module_source


  extra_arguments "init_extra_args" {
    commands  = ["init"]
    arguments = ["-lock=false", "-input=false"]
  }

  extra_arguments "plan_extra_args" {
    commands  = ["plan"]
    arguments = ["-input=false", "-out=${get_repo_root()}/plans/${trimprefix(get_original_terragrunt_dir(), "${get_repo_root()}/config/")}/tfplan"]
  }

  extra_arguments "plan_extra_args" {
    commands  = ["apply"]
    arguments = ["-input=false"]
  }

  ### FIX-ME: does not work due to an issue with Terragrunt by default adding -auto-aprove and -input=false to terraform apply <plan>
  # extra_arguments "use_plan" {
  #   commands = ["apply"]
  #   arguments = ["-auto-approve", "${get_repo_root()}/plans/${trimprefix(get_original_terragrunt_dir(), "${get_repo_root()}/config/")}/plan"]
  # }

  extra_arguments "retry_lock" {
    commands = get_terraform_commands_that_need_locking()
    arguments = [
      "-lock=false",
      "-lock-timeout=20m"
    ]
  }

  # extra_arguments "aws_profile" {
  #     commands = [
  #       "init",
  #       "apply",
  #       "refresh",
  #       "import",
  #       "plan",
  #       "taint",
  #       "untaint"
  #     ]
  #     Env = {
  #       AWS_PROFILE = "${local.aws_profile}"
  #     }
  #   }

  before_hook "mkdir-plan" {
    commands = ["plan"]
    execute  = ["mkdir", "-p", "${get_repo_root()}/plans/${trimprefix(get_original_terragrunt_dir(), "${get_repo_root()}/config/")}/"]
  }

  before_hook "component" {
    commands = ["init", "plan", "apply", "destroy"]
    execute  = ["printf", "Component: %s\n", trimprefix(get_original_terragrunt_dir(), "${get_repo_root()}/config/")]
  }

  before_hook "tarraform-source" {
    commands = ["init", "plan", "apply", "destroy"]
    execute  = ["printf", "Terraform source: %s\n", "${local.module_source}"]
  }

  after_hook "success" {
    commands     = ["apply"]
    execute      = ["echo", "Changes have been applied successfully!"]
    run_on_error = false
  }

  after_hook "jsonify-plan" {
    commands = ["plan"]
    execute  = ["sh", "-c", "terraform show -json ${get_repo_root()}/plans/${trimprefix(get_original_terragrunt_dir(), "${get_repo_root()}/config/")}/tfplan > ${get_repo_root()}/plans/${trimprefix(get_original_terragrunt_dir(), "${get_repo_root()}/config/")}/tfplan.json"]
  }

}
