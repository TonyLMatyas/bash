#!/bin/bash

# Variables
########################################
VVRS='6100'  # v6.1.0.0

# Functions
########################################

# Display help text
f_hlp () { echo "
DESCRIPTION:
  This script installs the Dell iDrac Service Module (iSM) on Linux (Ubuntu & Debian).
  This script needs to be tested on Debian.

  Default version: $VVRS
  See: https://linux.dell.com/repo/community/openmanage/

OPTIONS:
  -h, --help  Displays this help text.
    $0 -h
  -v, --version  Use specific version.
    $0 -v 5400
  -r, --run   Executes this script.
    $0 -r
" ; exit ; }

# Print error message & help text
f_errr () { echo ;echo "!!! ERROR: $1 !!!" ;f_hlp ; }

# Display variables
f_display () { echo "
RUN=$RUN
VVRS=$VVRS
VCDN=$VCDN
VSBD=$VSBD
" ; }

# Input
########################################

# Filter options
case $1 in
  '-r'|'--run')  RUN='true' ;shift  ;;
  '-v'|'--version')  RUN='true' ;VVRS="$2" ;shift ;shift  ;;
  *)  HELP='true' ;shift  ;;
esac

# Check: help
if [[ $HELP == 'true' ]] ;then f_hlp ;fi

# Check: version
if [[ -z "$VVRS" ]] ;then
	f_errr "No version specified"
elif [[ ! "$VVRS" =~ ^[0-9]+$ ]] ;then
	f_errr "Version is not a number: $VVRS" ;fi

# Check: root privilege execution
#if [[ `whoami` != 'root' ]] ;then f_errr 'use "sudo" for execution' ;fi

# Check: run flag
if [[ $RUN != 'true' ]] ;then exit ;fi

# Processing
########################################
clear

# download repo key
VSBD='linux.dell.com'
FASC="0x1285491434D8786F.asc"
VURL="https://$VSBD/repo/pgp_pubkeys/$FASC"
DKYR="/etc/apt/keyrings"
FDPA="$DKYR/dell-pgre-2012.asc"
curl -fsSL -o $FDPA $VURL
echo "ls $DKYR/
`ls $DKYR/`
"

# add repo w/key
FDST="/etc/apt/sources.list.d/$VSBD.sources.list"
VCDN="`lsb_release -cs`"
echo "deb [signed-by=$FDPA] https://$VSBD/repo/community/openmanage/iSM/$VVRS/$VCDN $VCDN main" > $FDST
echo "cat $FDST
`cat $FDST`
"

# update package index
apt -y update

# install iSM prereq & iSM package
apt -y install dcism-osc && apt -y install dcism-osc

# enable iSM service
VSRV="dcismeng.service"
systemctl enable $VSRV

# start iSM service
systemctl start $VSRV

# Output
########################################
systemctl status $VSRV
