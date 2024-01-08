### softly disable components listed in TG_DISABLED_COMPONENTS env var
function  soft_disable_components {
    local path=${1:-"$config_path"}
    for component in ${TG_DISABLED_COMPONENTS//,/ }; do
        # remove leading whitespace characters
        component="${component#"${component%%[![:space:]]*}"}"
        # remove trailing whitespace characters
        component="${component%"${component##*[![:space:]]}"}"
        if [ -d $path/$component ]; then 
            touch $path/$component/.terragrunt-disabled
            touch $path/$component/.terragrunt-disabled-softly
        else
            warn "Component $component not found to be softly disabled."       
        fi
    done
}

### Recursively enable Terragrunt on any component inside the path if it is marked by .terragrunt-disabled file
function do_disable_components {
    local path=${1:-"$config_path"}
    local forced=${2:-"false"}
    ### .terragrunt-disabled-exception always take precedence to .terragrunt-disabled
    if [[ ! -f $path/.terragrunt-disabled-exception && ($forced == "true" || ($forced != "true" && -f $path/.terragrunt-disabled)) ]]; then
        if [[ -f $path/terragrunt.hcl ]]; then
            ### remove preceeding */config/
            component=${path#*config/} 
            mv $path/terragrunt.hcl $path/disabled.hcl
            warn "Component disabled: $component"
        fi
    fi
    [ -f $path/.terragrunt-disabled ] && forced='yes'
    for dir in $(find $path -mindepth 1 -maxdepth 1 -type d  | awk '!/.terragrunt-cache/'); do
        do_disable_components $dir $forced
    done
}

### Wrapper function calling do_disable_components after processing TG_DISABLED_COMPONENTS (soft disable)
function disable_components {
    soft_disable_components $@
    do_disable_components $@
}

## Recursively disable Terragrunt on all component inside the path if it marked by .terragrunt-disabled file
function enable_components {
    local path=${1:-"$config_path"}
    local forced=${2:-"false"}
    if [[ $forced == "true" || ($forced == "false" && -f $path/.terragrunt-disabled) ]]; then
        if [[ -f $path/disabled.hcl ]]; then
            ### remove preceeding */config/
            component=${path#*config/} 
            mv -f $path/disabled.hcl $path/terragrunt.hcl
            ### check if softly disabled, remove disbale marker
            if [ -f $path/.terragrunt-disabled-softly ]; then
                rm $path/.terragrunt-disabled
                rm $path/.terragrunt-disabled-softly
            fi
            warn "Component enbabled: $component"
        fi
    fi
    [ -f $path/.terragrunt-disabled ] && forced='yes'
    for dir in $(find $path -mindepth 1 -maxdepth 1 -type d  | awk '!/.terragrunt-cache/'); do
        enable_components $dir $forced
    done
}


### Render templates in $path/templates/ folder
function render_component {
    local component=$1
    local path=$2
    ### create a temp key/value for rendering parameters
    vars_file=$(mktemp)
    ### auto add component path segement parameters (namespace, region, stack, ...)
    IFS='/' read -ra segments <<< $component
    echo "TG_NAMESPACE=${segments[0]}" > $vars_file
    echo "TG_REGION=${segments[1]}" >> $vars_file
    echo "TG_ENV=${segments[2]}" >> $vars_file
    echo "TG_STACK=${segments[3]}" >> $vars_file
    echo "TG_COMPONENT=${segments[4]}" >> $vars_file
    ### append rendering-vars.hcl key/values if existing
    [ -f $path/rendering-vars.hcl ] && cat $path/rendering-vars.hcl >> $vars_file || warn "rendering-vars.hcl not found."
    ### locate templates folder and adjust base path accordingly
    if [ ! -d $path/templates ]; then
        ### check also the parrent folder as templates folder might be outside terraform folder
        if [ -d $path/../templates ]; then
            path=$(realpath $path/..)
        else
            return 0
        fi
    fi
    for template in $(find $path/templates/ -type f); do
        filename=$(basename $template)
        ### skip if template starts with .terragrunt
        [[ $filename =~ ^\.terragrunt.* ]] && continue
        dir=$(dirname $template)
        ### get the relative destination path for rendered template (relative to $path/templates/)
        dstDir=${dir#${path}/templates/}
        ### make sure destination dir exists
        mkdir -p $path/$dstDir > /dev/null
        ## render template with no strip
        $bin_path/render.sh $template $vars_file no > $path/$dstDir/$filename
        info "Template successfully rendered => $dstDir/$filename"
    done    
} 


### Recursivly look for components within $path and render their templates if there is any
function render_components {
    local path=${1:-"$config_path"}
    local run_time=${2:-"true"} ### run-time means use component root after terragrunt init
    if [ "$run_time" = "true" ]; then
        lookup='.terragrunt-component-root'
    else
        lookup='terragrunt.hcl'
    fi
    for file in $(find $path -name $lookup -type f); do
        ### get terragrunt component root directory
        dir=${file%/$lookup*}
        ### do not render if the component is disabled
        [ -f $dir/disabled.hcl ] && continue
        ### remove preceeding */config/
        component=${dir#*config/}
        ### remove trailing /.terragrunt-cache/* if run-time otherwise skip
        if [ "$run_time" = "true" ]; then
            component=${component%/.terragrunt-cache*}
        else
            ### if this is a run-time root skip it
            [[ $component == */.terragrunt-cache* ]] && continue
        fi
        info "Rendering component: $component"
        render_component $component $dir
    done
}


