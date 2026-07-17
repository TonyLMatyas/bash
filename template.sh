#!/bin/bash

# Input
################################################################################

# Variables
########################################

# Functions
########################################

# Display help text
f_hlp () { echo "
DESCRIPTION:
  This script ...

OPTIONS:
  -h, --help  Displays this help text.
  -r, --run   Executes this script.
" ; exit ; }

# Print error message & help text
f_errr () { echo ;echo "!!! ERROR: $1 !!!" ;f_hlp ; }

# If needed, make directory
f_ifdir () { if [[ ! -d "$1" ]] ;then mkdir -p "$1" ;fi ; }

# Print message with dots
f_dots () { echo ;echo -n "$1"
  for dots in {1..5} ;do
    sleep 0.2 ;echo -n '.' ;done ;echo ; }

# Display variables
f_display () { echo "
HOME=$HOME
" ; }

# Arguments
########################################

# Filter options
case $1 in
  '-r'|'--run')  RUN='true' ;shift  ;;
  *)  HELP='true' ;shift  ;; ; esac

# Check for help
if [[ $HELP == 'true' ]] ;then f_hlp ;fi

# Check for root privilege execution
#if [[ `whoami` != 'root' ]] ;then f_errr 'use "sudo" for execution' ;fi

# Processing (Script Start)
################################################################################

# Process options
if [[ $RUN != 'true' ]] ;then
  exit
fi

# Output
################################################################################

