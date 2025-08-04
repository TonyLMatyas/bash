#!/bin/bash

# Input
################################################################################

# Variables
########################################
FLLPTH="`readlink -e $0`"  # full path to this script (basepath)

# Functions
########################################

# Display help text
f_hlp () {
  echo "
DESCRIPTION:
  This script ...

SYNTAX:
  # `basename $0` [OPTIONS]

OPTIONS:
  -h, --help
    Displays this help text.
  -r, --run
    Disables dry run and actually executes this script.

NOTES:
  ...
" ; exit ; }

# Print error message & help text
f_errr () {
  echo "
!!! ERROR: $1 !!!"
f_hlp ; }

# Arguments
########################################

# Filter options
if [[ "$#" < 1 ]] ;then f_hlp ;fi
COUNT=0
while (( "$#" > 0 )) ;do
  COUNT=$((COUNT + 1))
  if [[ $COUNT > 99 ]] ;then f_errr "Script is looping" ;fi
  case $1 in
    '-h'|'--help')  f_hlp  ;;
#    '-r'|'--run')  RUN='true' ;shift  ;;
#    *)  break  ;;
    *)  f_errr "Invalid argument(s)"  ;;
  esac ;done

# Check dry run
#if [[ $RUN != 'true' ]] ;then f_hlp ;fi

# Processing
################################################################################

# Check for root privilege execution
#if [[ `whoami` != 'root' ]] && [[ $1 != '-h' ]] && [[ $1 != '--help' ]];then f_errrmsg 'use "sudo" for execution' ;fi

# Output
################################################################################

