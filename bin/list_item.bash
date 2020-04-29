#!/usr/bin/env bash
###
### SCRIPTNAME [ options ] - DESCRIPTION
###
###	-h | --help		display this message and exit
###	-v | --verbose		provide extra comments for verbose output
###	-d | --debug		run the script in complete verbose mode for debugging purposes
###	-s | --site		specify the Sumo Logic Site
###	-a | --apikey		specify the API credentials to use
###	-c | --child		specify the Sumo Logic Object child identifier
###	-p | --parent		specify the Sumo Logic Object parent identifier
###	-n | --name		specify the Sumo Logic Object name
###	-t | --type		specify the Sumo Logic Object Type
###
### Starting_Directory: BASEDIR
###

display_help () {

  scriptname=$( basename "$0" ) 
  startdir=$( ls -Ld "$PWD" ) 
  description="A wrapper for the Sumo Logic API to list collectors"

  (
    grep -i -E '^###' | sed  's/^###//g' | \
    sed "s/SCRIPTNAME/$scriptname/g" | \
    sed "s#BASEDIR#$startdir#g"  | \
    sed "s#DESCRIPTION#$description#g"
  ) < "${0}"
  exit 0

}

initialize_variables () {

  ${debugflag}

  base=$( ls -Ld "$PWD" )			&& export base

  scriptname="${0%.*}"				&& export scriptname
  scripttag=$( basename "$scriptname" )		&& export scripttag

  cmddir=$( dirname "${scriptname}" )		&& export cmddir
  bindir=$( cd "$cmddir" ; pwd -P . )		&& export bindir

  basedir=$( dirname "${bindir}" )


  etcdir="$basedir/etc"				&& export etcdir
  cfgdir="$basedir/cfg" 			&& export cfgdir

  dstamp=$(date '+%Y%m%d')          		&& export dstamp
  tstamp=$(date '+%H%M%S')          		&& export tstamp
  lstamp="${dstamp}.${tstamp}"			&& export lstamp

  verboseflag=${verboseflag:-"false"}		&& export verboseflag
  content="Content-Type: application/json" 	&& export content
  jqcmd=$( which jq )				&& export jqcmd
  curlcmd=$( which curl )			&& export curlcmd

  sumo_target="${sumo_type:-"collectors"}"	&& export sumo_target

  child_id="${sumo_child:-"undefined"}"		&& export child_id
  parent_id="${sumo_parent:-"undefined"}"	&& export parent_id

}

complain_and_exit () {

        exitmessage="$2"
        exitstatus="$1"
        echo "ERROR: ${exitmessage}"
        exit "${exitstatus}"

}

initialize_environment () {

  ${debugflag}
  PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"
  export PATH

  [[ ${BASH_VERSION%%.*} -ge 4 ]] || complain_and_exit 1 "script requires bash 4 or higher to run"

}

initialiize_apiarray () {

  declare -Ag name2url
  name2url[collectors]="https://api.${sumo_site}.sumologic.com/api/v1/collectors"
  name2url[collector]="https://api.${sumo_site}.sumologic.com/api/v1/collectors/${child_id}"
  name2url[sources]="https://api.${sumo_site}.sumologic.com/api/v1/collectors/${parent_id}/sources"
  name2url[source]="https://api.${sumo_site}.sumologic.com/api/v1/collectors/${parent_id}/sources/${child_id}"
  name2url[ingestbudgets]="https://api.${sumo_site}.sumologic.com/api/v1/ingestBudgets"
  name2url[ingestbudget]="https://api.${sumo_site}.sumologic.com/api/v1/ingestBudgets/${child_id}"
  name2url[healthevents]="https://api.${sumo_site}.sumologic.com/api/v1/healthEvents"
  name2url[healthresources]="https://api.${sumo_site}.sumologic.com/api/v1/healthEvents/resources"
  name2url[apps]="https://api.${sumo_site}.sumologic.com/api/v1/apps"
  name2url[app]="https://api.${sumo_site}.sumologic.com/api/v1/apps/${child_id}"

}

execute_request () {

  ${debugflag}

  sumo_target_url="${name2url[$sumo_target]}"

  [[ $child_id =~ "undefined" ]] && {
     "${curlcmd}" -s -u "${sumo_apikey}" -X GET "${sumo_target_url}" | \
     "${jqcmd}" --arg base "$sumo_type" -r '.[$base] | keys[] as $k | "\(.[$k] | .id),\(.[$k] | .name)"'
  }

  [[ $child_id != "undefined" ]] && {
     "${curlcmd}" -s -u "${sumo_apikey}" -X GET "${sumo_target_url}" | \
     "${jqcmd}" -r '. | keys[] as $k | "\(.[$k] | .id),\(.[$k] | .name)"'
  }

}

main_logic () { 

  umask 022

  initialize_variables
  initialize_environment
  initialize_apiarray
  execute_request

}
  
while getopts "hvds:a:c:p:n:t:" options;
do
  case "${options}" in
    h) display_help ; exit 0 ;;
    v) verboseflag='true'	; export verboseflag ;;
    d) debugflag='set -x'	; export debugflag ;;
    s) sumo_site=$OPTARG	; export sumo_site ;;
    a) sumo_apikey=$OPTARG	; export sumo_apikey ;;
    c) sumo_child=$OPTARG	; export sumo_child ;;
    p) sumo_parent=$OPTARG	; export sumo_parent ;;
    n) sumo_name=$OPTARG	; export sumo_name ;;
    t) sumo_type=$OPTARG	; export sumo_type ;;
    *) display_help ; exit 0 ;;
  esac
done
shift $((OPTIND-1))

main_logic
