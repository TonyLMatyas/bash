#!/bin/bash

# Input
################################################################################

# Variables
########################################
TMPDR="/tmp/`date +%s`"

# Functions
########################################

# Display help text
f_hlp () {
  echo "
DESCRIPTION:
  This script test disk performance.

SYNTAX:
  # `basename $0` [OPTIONS]

OPTIONS:
  -h, --help
    Displays this help text.
  -r, --run
    Disables dry run.
  -d, --disk <Disk>
    Executes this script against a defined disk
  -f, --folder <Folder> <Username>
    Executes this script against a defined folder/directory
    Note: needs to define a non-root user account for exexecution

OPTIONS (unfinished):
  -p, --partition <Partition>
    Executes this script against a defined disk partition

EXAMPLES:
  # `basename $0` --run --disk /dev/sda
  # `basename $0` -r -f /mnt/some/folder charlie
  # `basename $0` -r -d /dev/sda -f /home/charlie/Documents charlie
" ;exit ; }

# Print error message & help text
f_errr () {
  echo "
!!! ERROR: $1 !!!"
f_hlp ; }

# Display variables
f_vars () { echo "
  TMPDR=$TMPDR
  RUN=$RUN
  DISK=$DISK
  TDSK=$TDSK
  PART=$PART
  TPRT=$TPRT
  FOLD=$FOLD
  TFLD=$TFLD
  USRN=$USRN
" ; }

# install function
f_install () {
  if [[ `which apt` ]] ;then apt -y install $1
  elif [[ `which yum` ]] ;then yum -y install $1
  else f_errr "No package manager found." ;fi ; }

f_skip () { echo "
Skipping $1..." ; }

f_catfile () { echo "
Contents of: $TXTFL
`cat $TXTFL`" ; }

# Run against disk
f_disk () {
  echo "
Testing $TDSK..."
  if [[ ! -e $TDSK ]] ;then f_errr "Doesn't exist: $TDSK" ;fi

  echo "
Testing $TDSK with hdparm..."
  if [[ ! `which hdparm` ]] ;then f_install hdparm ;fi
  TXTFL="$TMPDR/hdparm.txt"
  hdparm -Tt $TDSK > $TXTFL
  f_catfile ; }

# Run against partition
f_part () { echo TBD ; }

# Run against folder
f_fold () {
  echo "
Testing $TFLD..."
  if [[ ! -d $TFLD ]] ;then f_errr "Doesn't exist: $TFLD" ;fi
  if [[ ! `id $USRN` ]] ;then f_errr "No such user: $USRN" ;fi

  echo "
Testing $TFLD with bonnie++..."
  if [[ ! `which bonnie++` ]] ;then f_install bonnie++ ;fi
  RAM="`free -m |awk '/^Mem:/{print $2 *2}'`"
  TXTFL="$TMPDR/bonnie++.txt"
  bonnie++ -d $TFLD -s $RAM\M -u $USRN > $TXTFL
  f_catfile

  echo "
Testing $TFLD with fio..."
  if [[ ! `which fio` ]] ;then f_install fio ;fi
  TXTFL="$TMPDR/fio.txt"
  fio --name=randwrite --ioengine=libaio --rw=randwrite --bs=4k --size=1G --directory=$TFLD --numjobs=2 --runtime=60 --time_based --group_reporting --output=$TXTFL
  f_catfile

  echo "
Testing $TFLD with ioping..."
  if [[ ! `which ioping` ]] ;then f_install ioping ;fi
  TXTFL="$TMPDR/ioping.txt"
  ioping -c 10 $TFLD > $TXTFL
  f_catfile ; }

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
    '-d'|'--disk')  DISK='true' ;TDSK="$2" ;shift ;shift  ;;
    '-p'|'--partition')  PART='true' ;TPRT="$2" ;shift ;shift  ;;
    '-f'|'--folder')  FOLD='true' ;TFLD="$2" ;USRN="$3" ;shift ;shift ;shift  ;;
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
if [[ `whoami` != 'root' ]] ;then f_errr 'use "sudo" for execution' ;fi

# dry run?
if [[ $RUN != 'true' ]] ;then
  f_errr "Specify run" ;fi

# Script Start
########################################

# make temp directory
mkdir -p $TMPDR

# Process Options
if [[ $DISK == 'true' ]] ;then f_disk ;else f_skip disk ;fi
if [[ $PART == 'true' ]] ;then f_part ;else f_skip partition ;fi
if [[ $FOLD == 'true' ]] ;then f_fold ;else f_skip folder ;fi

# Output
################################################################################
