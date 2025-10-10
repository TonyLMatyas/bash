#!/bin/bash

# Input
################################################################################

# Variables
########################################
#FLLPTH="`readlink -e $0`"  # The full path to this script (basepath)

# Functions
########################################

# Display help text
f_hlp () { echo "
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
f_errr () { echo ;echo "!!! ERROR: $1 !!!" ;f_hlp ; }

# Display
f_display () { echo "
=
" ; }

# Arguments
########################################

# Filter options
case $1 in
  '-r'|'--run')  RUN='true' ;shift  ;;
  *)  HELP='true' ;shift  ;;
esac

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
if [[ $RUN != 'true' ]] ;then exit ;fi

# Output
################################################################################

