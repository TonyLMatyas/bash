#!/bin/bash

# Input
################################################################################

# Variables
########################################

# Default
FLLP="`readlink -f $0`"  # The full path to this script (basepath)
BASE="`basename $0`"
HOME=~
DATE="`date +%F`"

# Backup Variables
VBNM="custom"
VBND="$VBNM/$DATE"
DBMN="$HOME/backups/$VBND"

# Working Variables
DWMN="/tmp/$VBND"
FWTO="$DWMN/tempone.tmp"
FWTT="$DWMN/temptwo.tmp"

# Custom

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

NOTES:
  ...
" ; exit ; }

# Print error message & help text
f_errr () { echo ;echo "!!! ERROR: $1 !!!" ;f_hlp ; }

# If needed, make directory
f_ifdir () { if [[ ! -d "$1" ]] ;then mkdir -p "$1" ;fi ; }

# Initialize Files/Directories
f_initdirs () {
	cat /dev/null > $FWTO
	cat /dev/null > $FWTT
	f_ifdir "$DBMN"
	f_ifdir "$DWMN" ; }

# Display Variables
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

