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
  This script sorts files from a specified folder.

SYNTAX:
  $ $BASE [OPTIONS] <TargetFolder>

OPTIONS:
  -h, --help
    Displays this help text.
  -c, --consolidate
    Recursively move all files into the folder.
      $ $BASE --consolidate ~/Documents
  -d, --date
    Sort files by year & month.
      $ $BASE --date ~/Pictures
  -r, --rename
    Rename files with spaces to underscores.
      $ $BASE --rename ~/Documents/
  -t, --type
    Sort files by file extension.
      $ $BASE --type ~/Downloads/
  -cd, --consolidate-date
    Same as running '-c' then '-d'
      $ $BASE -cd ~/Pictures
  -ct, --consolidate-type
    Same as running '-c' then '-t'
      $ $BASE -ct ~/Downloads/
  -cr, -rc, --rename-consolidate
    Same as running '-r' then '-c'
      $ $BASE -cr ~/Pictures/
" ; exit ; }

# Print error message & help text
f_errr () { echo ;echo "!!! ERROR: $1 !!!" ;f_hlp ; }

# If needed, make directory
f_ifdir () { if [[ ! -d "$1" ]] ;then mkdir -p "$1" ;fi ; }

# Initialize files/directories
f_initdirs () {
  f_ifdir "$DBMN"
  f_ifdir "$DWMN"
  cat /dev/null > $FWTO
  cat /dev/null > $FWTT ; }

# Print message with dots
f_dots () {
  echo ;echo -n "$1"
  for dots in {1..5} ;do
    sleep 0.2 ;echo -n '.' ;done ;echo ; }

# Display variables
f_display () {
  f_initdirs
  echo "
DTSP=$DTSP
DWSP=$DWSP
CONS=$CONS
YRMN=$YRMN
TYPE=$TYPE
" ; }

# Arguments
########################################

# Filter options
case $1 in
  '-c'|'--consolidate')  CONS='true' ;DWSP="$2" ;shift ;shift  ;;
  '-d'|'--date')  YRMN='true' ;DWSP="$2" ;shift ;shift  ;;
  '-r'|'--rename')  NAME='true' ;DWSP="$2" ;shift ;shift  ;;
  '-t'|'--type')  TYPE='true' ;DWSP="$2" ;shift ;shift  ;;
  '-cd'|'--consolidate-date')  CONS='true' ;YRMN='true' ;DWSP="$2" ;shift ;shift  ;;
  '-ct'|'--consolidate-type')  CONS='true' ;TYPE='true' ;DWSP="$2" ;shift ;shift  ;;
  '-cr'|'-rc'|'--rename-consolidate')  CONS='true' ;NAME='true' ;DWSP="$2" ;shift ;shift  ;;
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

# target is a directory
if [[ ! -d $DWSP ]] ;then f_errr "Not a directory: $DWSP" ;fi

# Script Start
########################################

# fix input
DTSP=$DWSP
DWSP="`readlink -f $DTSP`"

# Process options
if [[ $NAME == 'true' ]] ;then
  cd "$DWSP" || { f_errr "Directory not found." ; }
  for file in *; do
    if [[ "$file" == *" "* ]]; then
      new_file=$(echo "$file" | tr ' ' '_')
      mv "$file" "$new_file"
      echo "Renamed '$file' to '$new_file'"
    fi ;done ;fi

if [[ $CONS == 'true' ]] ;then
  find $DWSP/ -type f -exec mv "{}" $DWSP/ \; ;fi

if [[ $YRMN == 'true' ]] || [[ $TYPE == 'true' ]] ;then
  # iterate through all files in the working directory
  for file in `find $DWSP/ -maxdepth 1 -type f` ;do

    # error check: file exists
    if [[ -f "$file" ]] ;then

      # get info
      YEAR="`ls -al $file |awk '{print $8}'`"
      if [[ `echo "$YEAR" |grep ':'` ]] ;then
        YEAR="`date +%Y`" ;fi
      MONTH="`ls -al $file |awk '{print $6}'`"
      FEXT="`ls $file |awk -F'.' '{print $NF}'`"
      if [[ "$file" == "$FEXT" ]] || [[ `echo "$FEXT" |grep '/'` ]] ;then
        FEXT='noextension' ;fi
      if [[ $YRMN == 'true' ]] ;then
        DEST="$DWSP/$YEAR/$MONTH"
      elif [[ $TYPE == 'true' ]] ;then
        DEST="$DWSP/$FEXT" ;fi

      # if it doesn't exist, make destination directory
      if [[ ! -d $DEST ]] ;then mkdir -p $DEST ;fi

      # move file into date directory
      mv $file $DEST/

      # display file info
      echo "
file=  $file
YEAR=  $YEAR
MONTH= $MONTH
FEXT=  $FEXT
DEST=  $DEST"
    fi ;done ;fi

# remove empty directories
find $DWSP/ -type d -empty -delete

# Output
################################################################################
echo "
New Directories:
`find $DWSP/ -type d`"

