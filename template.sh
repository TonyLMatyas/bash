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
    Executes this script.

NOTES:
  ...
" ; exit ; }

# Print error message & help text
f_errr () {
  echo "
!!! ERROR: $1 !!!"
f_hlp ; }

# Run script
f_run () {
  ;
}

# Arguments
########################################

# Filter options
if [[ "$#" < 1 ]] ;then f_hlp ;fi
COUNT=0
while (( "$#" > 0 )) ;do
  COUNT=$((COUNT + 1))
  if [[ $COUNT > 99 ]] ;then f_errr "Script is looping" ;fi
  case $1 in
    '-h'|'--help')  HELP='true' ;shift  ;;
    '-r'|'--run')  RUN='true' ;shift  ;;
#    *)  break  ;;
    *)  f_errr "Invalid argument(s)"  ;;
  esac ;done

# Processing
################################################################################

# Error Checks
########################################

# Check for Help
if [[ $HELP == 'true' ]] ;then f_hlp ;fi

# Check for root privilege execution
#if [[ `whoami` != 'root' ]] ;then f_errr 'use "sudo" for execution' ;fi

# Script Start
########################################

# Process Options
if [[ $RUN == 'true' ]] ;then f_run ;fi

# Output
################################################################################

