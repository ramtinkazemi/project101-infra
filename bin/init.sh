#!/bin/bash
set -e -o pipefail

bin_path=$(realpath $(dirname $0))
root_path=$(realpath $bin_path/..)
source $bin_path/log.sh
source $bin_path/utils.sh

function print_usage(){
    echo -e "USAGE:\n${0##*/} <config-path> [Terragrunt/Terraform options]\nTG_CONFIG_PATH=<config-path> ${0##*/} [Terragrunt/Terraform options]"
}

### validate input arguments
case $# in
    0)
        if [ -z "${TG_CONFIG_PATH}" ]; then
            print_usage
            fatal "Config path is not provided." 1
        fi
        config_path=${TG_CONFIG_PATH%\/}
        ;;
    *)
        config_path=${1%\/}
        [ -z "${config_path/"config"/""}" ] && fatal "Invald config path."
        [ -d $config_path ] || fatal "Config path not found: $config_path"
        config_path=$(realpath $config_path)  ### get absolute path
        shift
        ;;
esac

info "config path=${TG_CONFIG_PATH}"

TG_ALLOW_DISABLING=${TG_ALLOW_DISABLING:=true}
if [ "${TG_ALLOW_DISABLING}" = "true" ]; then
    ### on exit re-enable component
    trap enable_components EXIT
    ### disable component which are marked to be disabled using .terragrunt-disabled
    disable_components $config_path
else
    warn "Disabling feature is turned off."
fi

### move into the config path folder and initialize all components within config_path
pushd $config_path > /dev/null
### this will also generate .terragrunt-component-root file which is used to locate componenets' runtime terragrunt paths
# terragrunt run-all init -reconfigure $@
terragrunt run-all init ${TG_INIT_ARGS} $@
status=$?
popd > /dev/null
[[ $status = 0 ]] || fatal "Failed to initilaize components." $status


TG_ALLOW_RENDERING=${TG_ALLOW_RENDERING:=true}
if [[ "${TG_ALLOW_RENDERING}" == "true" ]]; then
    ### recursivly look for components and render templates if there is any
    ### This needs to be done after terragrunt init for the templates folder to be pulled first
    info "Rendering components..."
    render_components $config_path

    if [[ "$TG_POST_RENDER_INIT" == "true" ]]; then
        info "Performing post render initialization..."
        for path in $(find $config_path -name .terragrunt-component-root -type f); do
            dir=${path%/.terragrunt-component-root*}
            component=${dir#*config/} ### remove preceeding */config/
            component=${component%/.terragrunt-cache*} ### remove trailing /.terragrunt-cache/*
            info "Component: $component"
            info "Component run-time path: $dir"
            pushd $dir > /dev/null
            # info "Terragrunt parameters:"
            # cat locals-debug.json && echo
            terraform init -reconfigure -lock=false
            info "Component successfully reinitialized: $component"
            # info "Listing component contents:"
            # ls -al
            # info "Listing component remote state:"
            # terraform state list 2>/dev/null || true
            # echo "Backend:"
            # cat backend_override.tf
            # echo "Provider:"
            # cat provider_override.tf
            popd > /dev/null
        done
    fi
else
    warn "Rendering feature is turned off."
fi