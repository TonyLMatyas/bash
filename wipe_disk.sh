#!/bin/bash

# variables
################################################################################

# functions
################################################################################
f_help () {
	echo "
This script wipes out (erases all data) on a given disk.

SYNTAX:
  # $0 <Disk/Device> [OPTIONS]

OPTIONS:
  -h, --help    display this help text
  -w, --wipe    wipe disk

EXAMPLE:
  # $0 /dev/sda -w

" ;exit
}

# script start
################################################################################

# input
########################################

# check package manager
if [[ `apt` ]] ;then
	PCKMNG='apt'
elif [[ `yum` ]] ;then
	PCKMNG='yum' ;fi
echo $PCKMNG

# install software
if [[ ! `which dd` ]] ;then
	$PCKMNG install -y dd ;fi

if [[ ! `which shred` ]] ;then
	$PCKMNG install -y core-utils ;fi

# identify disk
DISK="$1"

# display results
lsblk

# processing
########################################

# error check: disk
if [[ $DISK == '' || ! `echo $DISK |grep dev` ]] ;then
	echo "$DISK is not a device." ;exit ;fi

# zero out disk for 30 seconds
echo "timeout 30 dd if=/dev/zero of=$DISK..."
timeout 30 dd if=/dev/zero of=$DISK

# format drive: msdos
parted $DISK mklabel msdos

# wipe disk w/utility
# -v   verbose
# -n1  wipe disk once randomly
# -z   wipa disk again with all zeroes
echo "shred -vzn1 $DISK..."
shred -vzn1 $DISK

# format drive: gpt
parted $DISK mklabel gpt

# output
########################################

# display results
lsblk
