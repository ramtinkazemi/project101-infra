#!/bin/bash
set -e -o pipefail

bin_path=$(realpath $(dirname $0))
root_path=$(realpath $bin_path/..)
source $bin_path/log.sh
source $bin_path/utils.sh

function print_usage(){
    echo -e "USAGE:\n${0##*/} <config-path> [-destroy] [Terragrunt/Terraform options]\nTG_CONFIG_PATH=<config-path> ${0##*/} [-destroy] [Terragrunt/Terraform options]"
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

### empty plans folder
rm -rf $root_path/plans

TG_ALLOW_DISABLING=${TG_ALLOW_DISABLING:=true}
if [ "${TG_ALLOW_DISABLING}" = "true" ]; then
    ### on exit re-enable component
    trap enable_components EXIT
    ### disable component which are marked to be disabled using .terragrunt-disabled
    disable_components $config_path
else
    warn "Disabling feature is turned off."
fi

### move into the config path folder and plan all components within config_path
pushd $config_path > /dev/null
# terragrunt run-all plan -input=false --terragrunt-non-interactive --terragrunt-no-auto-init $@ 
terragrunt run-all plan ${TG_PLAN_ARGS} $@ 
status=$?
popd > /dev/null
[[ $status = 0 ]] || fatal "Failed to plan components." $status

pushd $bin_path > /dev/null
go run wrap.go -colorfull=true | tee $root_path/plans/wrap1
status=$?
popd > /dev/null
[[ $status = 0 ]] || fatal "Failed to generate plan wrap." $status
