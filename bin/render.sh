#!/bin/bash
set -e -o pipefail

bin_path=$(realpath $(dirname $0))
root_path=$(realpath $bin_path/..)
source $bin_path/log.sh


PREFIX=${PREFIX:-"{{"}
SUFFIX=${SUFFIX:-"}}"}

function print_usage(){
    echo -e "USAGE:\n1) ${0##*/} <template-path> <parameters-path>\n2) cat <template-path> <parameters-path> | ${0##*/}"
}

case $# in
    1)
      contents="$(</dev/stdin)"
      parameters="$(<$1)"
      strip=false
      ;;
    2)
      contents="$(<$1)"
      parameters="$(<$2)"
      strip=false
      ;;
    3)
      contents="$(<$1)"
      parameters="$(<$2)"
      strip=$3
      ;;

    *)
      print_usage
      fatal "Inavlid number of arguments." 1
      ;;      
esac

function trim_string() {
    local str="$*"
    # remove leading whitespace characters
    str="${str#"${str%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    str="${str%"${str##*[![:space:]]}"}"
    # remove leading double quotes
    str="${str%\"}"
    # remove trailing double quotes
    str="${str#\"}"
    # remove leading quotes
    str="${str%\'}"
    # remove trailing quotes
    str="${str#\'}"
    printf '%s' "$str"
}

pattern=
while IFS='\n' read key_value; do  
  ### skip empty lines
  [ -z "$key_value" ] && continue
  key="$(trim_string ${key_value%=*})"
  value="$(trim_string ${key_value#*=})"
  value="$(eval echo $value)"
  ### remove PREFIX and SUFFIX from param, and get value of the resulted param name as an environment variable 
  # value="$(eval echo \$${param:${#PREFIX}:${#param}-${#PREFIX}-${#SUFFIX}})"
  if [[ (-n "$value") || (-z "$value" && $strip == "true" )]]; then
    pattern="$pattern -e 's|${PREFIX}${key}${SUFFIX}|${value}|g' "
  fi
done <<< "$parameters"
eval sed "$pattern" <<< "$contents"
