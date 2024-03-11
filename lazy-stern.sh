#!/bin/bash

# HELPERS
iso () {
  gdate --iso-8601=ns $@ | sed 's/,/./g'
}
has_argument() {
    [[ ("$1" == *=* && -n ${1#*=}) || ( ! -z "$2" && "$2" != -*)  ]];
}
extract_argument() {
  echo "${2:-${1#*=}}"
}
select_interactive_option () {
  if [ -z "$1" ]; then
    echo "No prompt provided" >&2
    return
  fi
  echo -e "yes\nno" | fzf --height 40% --reverse --prompt $1
}
check_command_exists () {
  if [ -z "$1" ]; then
    echo false
    return
  fi

  if ! command -v $1 &> /dev/null
  then
    echo false
    return
  fi

  echo true
}
_fetching_logs_until () {
  if [ -z "$toIso"] ; then
    echo "now"
  else
    echo "$toIso"
  fi
} 

# MAIN FUNCTIONS

# Function to display script usage
_lazy_stern_usage() {
 echo "Usage: service-logs [OPTIONS]"
 echo "Options:"
 echo " -h, --help      Display this help message"
 echo " -i, --interactive  Enable interactive mode"
 echo " -s, --since     Display logs since the specified time (passed to stern)"
 echo "\t Default: 48h, Format: [<num>m, <num>h] days, weeks, months & years are not valid"
 echo " -t, --to         Display logs until the specified time (used to filter logs with awk)"
 echo "\t Format: ISO 8601, e.g. 2021-08-01T00:00:00.000Z"
 echo " -n, --namespace  Specify the kubernetes namespace to fetch logs from"
 echo " -c, --context    Specify the kubernetes context to fetch logs from"
}

# Function to handle options and arguments
_handle_lazy_stern_options() {
  # Set Global Variables
  # Command options
  since="48h"
  toIso=""
  context=""
  namespace=""
  # Flags
  help=""
  interactive=false

  while [ $# -gt 0 ]; do
    case $1 in
      -h | --help)
        help="true"
        _lazy_stern_usage
        ;;
      -i | --interactive)
        interactive=true
        ;;
      -s | --since)
        if has_argument $@; then
          since=$(extract_argument $@)
        fi
        shift
        ;;
      -t | --to)
        if ! has_argument $@; then
          echo "To, not specified." >&2
          _lazy_stern_usage
        else
          toIso=$(extract_argument $@)  
        fi
        shift
        ;;
      -n | --namespace)
        if ! has_argument $@; then
          echo "Namespace not specified." >&2
          _lazy_stern_usage
        else
          namespace=$(extract_argument $@)
        fi
        shift
        ;;
      -c | --context)
        if ! has_argument $@; then
          echo "Context not specified." >&2
          _lazy_stern_usage
        else
          context=$(extract_argument $@)
        fi
        shift
        ;;
      *)
        echo "Invalid option: $1" >&2
        _lazy_stern_usage
        ;;
    esac
    shift
  done
}

# Function to run interactive mode
_run_lazy_stern_interactive_mode () {
  # Select Context
  local cur_context="$(kubectl config current-context)"
  local select_context=$(select_interactive_option "Current context: $cur_context, Select new context?")
  if [[ "$select_context" = "yes" ]]; then
    context=$(kubectl config get-contexts -o name | fzf --height 33% --reverse)
    echo "selected context: $context"  >&2
  fi
  

  # Select Namespace
  local cur_namespace="$(kubectl config view --minify --output 'jsonpath={}' | jq -r '.contexts[].context.namespace')"
  local select_namespace=$(select_interactive_option "Current namespace: $cur_namespace, Select new namespace?")
  if [[ "$select_namespace" = "yes" ]]; then
    namespace=$(kubectl --context=$context get ns | awk 'NR > 1 { print $1 }' | fzf --height 33% --reverse)
    echo "selected namespace: $namespace"  >&2
  fi
  
  # Select logs since
  local select_since=$(select_interactive_option "currently fetching logs since: $since, Do you wish to change this?")
  if [[ "$select_since" = "yes" ]]; then
    echo "Enter time to start getting logs from:"  >&2
    echo " Default: 48h"  >&2
    echo " Format: <number><unit>"  >&2
    echo "\tValid units: s, m, h"  >&2
    echo "\tdays, weeks, months & years are NOT valid (i.e. d, w, M, Y)"  >&2
    
    local _since_items
    read _since_items
    since="$_since_items"
    echo "fetching logs since: $since"  >&2
  fi

  # Select logs until
  local select_to=$(select_interactive_option "currently fetching logs until $(_fetching_logs_until). Do you wish to change this?")
  if [[ "$select_to" = "yes" ]]; then
    echo -e "\nEnter modifiers relative to now in order to build ISO datetime from"  >&2
    echo -e "\tSee GNU date coreutil relative items docs for syntax.\n\thttps://www.gnu.org/software/coreutils/manual/html_node/Relative-items-in-date-strings.html"  >&2
    echo -e "\n\tExample:"  >&2
    echo -e "\t+1 day -4 hour -2 weeks +2 minutes +1 second\n\n"  >&2
    local _rel_items
    read _rel_items
    toIso="$(iso -d "$_rel_items")"
  fi
  if ! [ -z "$toIso"] ; then
    echo "skipping logs after: $toIso"  >&2
  fi
}

# Lazystern function
#  Fetches logs from kubernetes pods using stern
#  Accepts a To and Since option to filter logs allowing for a time range
#  Includes an interactive mode to simplify the process of fetching logs
lazystern () {
  # Check Dependencies
  local all_dependencies_installed=true
  local dependencies=("kubectl" "stern" "fzf" "jq")
  for dep in "${dependencies[@]}"; do
    local command_exists=$(check_command_exists $dep)
    if ! $command_exists; then
      echo "$dep not found"  >&2
      all_dependencies_installed=false
    fi
  done
  if ! $all_dependencies_installed; then
    echo "Please install missing dependencies before running this script."  >&2
    return
  fi

  _handle_lazy_stern_options "$@"

  # Fetch context from kubectl if not provided
  if [ -z "$context"]; then
    context=$(kubectl config current-context)
  fi

  # Fetch namespace from context if not provided
  if [ -z "$namespace"]; then
    namespace=$(kubectl config view --minify --output 'jsonpath={}' | jq -r '.contexts[].context.namespace')
  fi

  # Display help message only
  if ! [ -z "$help" ]; then
    return
  fi

  # Run interactive mode
  if $interactive; then
    _run_lazy_stern_interactive_mode;
  fi

  # Fetch logs with options
  if [ -z "$toIso"] ; then
    stern --namespace $namespace --context $context --since $since -o raw --no-follow --only-log-lines ".*"
  else
    stern --namespace $namespace --context $context --since $since -o raw --no-follow -t --only-log-lines ".*" | awk -v to="$toIso" '$1 <= to {first = $1; $1=""; print $0}'
  fi

  # Clear globals
  unset toIso
  unset since
  unset help
  unset namespace
  unset context
}
alias lstern=lazystern
