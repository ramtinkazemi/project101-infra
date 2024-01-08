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

TG_ALLOW_DISABLING=${TG_ALLOW_DISABLING:=true}
if [ "${TG_ALLOW_DISABLING}" = "true" ]; then
    ### on exit re-enable component
    trap enable_components EXIT
    ### disable component which are marked to be disabled using .terragrunt-disabled
    disable_components $config_path
else
    warn "Disabling feature is turned off."
fi

### check approved plan 
[ -f plans/wrap1 ] || fatal "Plan wrap not found. Run' make plan' first."

# ### move into the config path folder and replan to make sure remote state hasn't changed since planning
# info "Plan found, generating cross-check plan..."

# ### backup plan wrap1 and empty plans folder
# cp $root_path/plans/wrap1 /tmp/wrap1 && rm -rf $root_path/plans/* && cp /tmp/wrap1 $root_path/plans/wrap1

# pushd $config_path > /dev/null
# terragrunt run-all plan ${TG_APPLY_ARGS} $@
# status=$?
# popd > /dev/null
# [[ $status = 0 ]] || fatal "Failed to generate cross-check plans." $status

# ### generate a cross-check plan wrap
# pushd $bin_path > /dev/null
# go run wrap.go -colorfull=true | tee $root_path/plans/wrap2
# status=$?
# popd > /dev/null

# [[ $status = 0 ]] || fatal "Failed to generate crossp-check plan wrap." $status

# ### compare the new plan to the old one
# sum1="$(sha256sum $root_path/plans/wrap1 | cut -d ' ' -f 1)"
# sum2="$(sha256sum $root_path/plans/wrap2 | cut -d ' ' -f 1)"
# [[ "$sum1" == "$sum2" ]] || fatal "Plans are stale. Run 'make plan TG_CONFIG=<config/xxx>' first."
# info "Plans are up to date, proceeding..."

### now apply plan to all components within config_path
pushd $config_path > /dev/null
# terragrunt run-all apply -input=false --terragrunt-non-interactive --terragrunt-no-auto-init $@
terragrunt run-all apply ${TG_APPLY_ARGS} $@
status=$?
popd > /dev/null
[[ $status = 0 ]] || fatal "Failed to apply plans." $status
