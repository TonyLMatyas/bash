#!/bin/bash

# variables
################################################################################
HELPTXT="
This script fixes perms of corrupted CTs when 100000 has been added to the uid/gid.

OPTIONS:
  -h, --help        View this help file.
  -dr, --dry-run    Safely run script without changing anything.
  -fp, --fix-perms  Fix permissions.
"
SCRIPT="`mktemp`"

# library
################################################################################

# help
########################################
f_help () { echo "$HELPTXT" ;echo "$MSG" ;echo ;exit ; }

# error
########################################
f_err () { MSG="!!! ERROR !!! $1" ;f_help ; }

# dry run
########################################
f_dry () {
  if [[ $DRYRUN == 'true' ]] ;then echo "Dry Run: $1"
  else echo "Live Run: $1" ;eval "$1" ;fi ; }

# error check: root exec
########################################
f_root () {
if [[ `whoami` != 'root' ]] ;then
  f_err "This script needs to be executed as the 'root' user." ;fi ; }

# functions
################################################################################

# fix permissions
########################################
f_fix_perms () {

# create script to change all uids
echo '#!/bin/bash' > $SCRIPT
awk -F: '{print "find / -uid "$3+100000" -exec chown "$1" \"{}\" \\;"}' /etc/passwd >> $SCRIPT

# execute script
f_dry "bash $SCRIPT"

# create script to change all gids
echo '#!/bin/bash' > $SCRIPT
awk -F: '{print "find / -gid "$3+100000" -exec chown :"$1" \"{}\" \\;"}' /etc/group >> $SCRIPT

# execute script
f_dry "bash $SCRIPT"
}

# script start
################################################################################

# process arguments
########################################
EXEC=false
while (( "$#" > 0 )) ;do
  case $1 in
    '-h'|'--help')  f_help  ;;
    '-dr'|'--dry-run')  DRYRUN='true' ;shift ;;
    '-fp'|'--fix-perms')  FIXPERMS='true' ;EXEC='true' ;shift ;;
    *)  f_err "Invalid argument: $1"  ;;
  esac
done

# error checks
########################################

# check if root
f_root

# process flags
########################################

if [[ $EXEC == 'true' ]] ;then
  if [[ $FIXPERMS == 'true' ]] ;then
    f_fix_perms ;fi
else f_help ;fi

