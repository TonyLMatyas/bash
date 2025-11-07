#!/bin/bash

# Input
################################################################################

# Variables
########################################

# Default Variables
HOME=~
FULL="`readlink -f $0`"  # The full path to this script (basepath)
BASE="`basename $0`"
DATE="`date +%F`"

# Backup Variables
VBND="$BASE/$DATE"
DBMN="$HOME/backups/$VBND"

# Working Variables
DWMN="/tmp/$VBND"
FWTO="$DWMN/tempone.tmp"
FWTT="$DWMN/temptwo.tmp"

# Custom Variables

# Functions
########################################

# Display help text
f_hlp () { echo "
DESCRIPTION:
  This script ...

SYNTAX:
  # $BASE [OPTIONS]

OPTIONS:
  -h, --help
    Displays this help text.
  -r, --run
    Executes this script.

EXAMPLES:
  # $BASE -h

NOTES:
  ...
" ; exit ; }

# Print error message & help text
f_errr () { echo ;echo "!!! ERROR: $1 !!!" ;f_hlp ; }

# If needed, make directory
f_ifdir () { if [[ ! -d "$1" ]] ;then mkdir -p "$1" ;fi ; }

# Initialize files/directories
f_initdirs () {
  cat /dev/null > $FWTO
  cat /dev/null > $FWTT
  f_ifdir "$DBMN"
  f_ifdir "$DWMN" ; }

# Print message with dots
f_dots () {
  echo ;echo -n "$1"
  for dots in {1..5} ;do
    sleep 0.2 ;echo -n '.' ;done ;echo ; }

# Display variables
f_display () {
  f_initdirs
  declare -p > $FWTO
  for var in `grep '=' $FWTO |grep '^[A-Z]' |awk -F'=' '{print $1}'` ;do
    if [[ `grep "$var" "$FLLP"` ]];then
      grep ^$var\= $FWTO ;fi ;done ; }

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

# Check for help
if [[ $HELP == 'true' ]] ;then f_hlp ;fi

# Check for root privilege execution
#if [[ `whoami` != 'root' ]] ;then f_errr 'use "sudo" for execution' ;fi

# Script Start
########################################

# Process options
if [[ $RUN != 'true' ]] ;then exit ;fi

# Output
################################################################################

