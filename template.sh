#!/bin/bash
# created by: Zell

# source file
#===============================================================================
source /usr/local/sbin/zellib

# variables
#===============================================================================

# preset variables (optional)
#SKIP=true
VERBOSE=true

# help text: contents
#---------------------------------------
HELP_TXT="
This script ...

SYNTAX:
  # $PROG [OPTIONS]

$HELP_TXT_OPTIONS

$HELP_TXT_EXAMPLES

$HELP_TXT_NOTES

"

# functions
#===============================================================================

# process options
#---------------------------------------
f_process_custom_options () {
while (( "$#" > 0 )) ;do
  case $1 in
    "")  break  ;;
    *)   f_msg -e "Unknown option(s): $INITARGS" ;break  ;;
  esac
done
}

# script start
#===============================================================================
f_msg -l -d "SCRIPT START"

# process arguments
#---------------------------------------
INITARGS=$@
f_process_options $INITARGS
f_process_custom_options $REMAINARGS
f_arguments  # display arguments (optional)

# error checks
#---------------------------------------
f_vroot   # verify root execution
f_prompt  # prompt for execution

# body
#---------------------------------------

# example: display free disk space
f_msg "printing free disk space..." ;f_run "df -h"

# cleanup
#---------------------------------------
f_logro ;f_exit # rotate log & exit script
