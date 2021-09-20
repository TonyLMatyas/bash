#!/bin/bash

# variables
################################################################################

# functions
################################################################################
f_help () {
	echo "
This script sorts files, from a specified folder, into new folders by year & month.

SYNTAX:
	# $0 <TargetFolder>

OPTIONS:
	-h, --help  display this help text
	<Nothing>   run/execute this script

EXAMPLE:
	# $0 ~/Downloads
" ;exit
}

# script start
################################################################################

# process options
while (( "$#" > 0 )) ;do
	case $1 in
		'-h'|'--help')  f_help ;;
		"")  break ;;
		*)  WORKDIR="$1" ;shift ;;
	esac
done

# error check: parameter is a folder
if [[ ! -d $WORKDIR ]] ;then echo "Error: $WORKDIR is not a directory"; exit ;fi

# fix directory
TEMPDIR=$WORKDIR
WORKDIR="`readlink -f $TEMPDIR`"

# iterate: find all files in working directory
for file in `find $WORKDIR/ -maxdepth 1 -type f` ;do

	# error check: file exists
	if [[ -f $file ]] ;then

		# get info
		DATE="`ls -ald --time-style=long-iso $file |awk '{print $6}'`"
		YEAR="`echo $DATE |awk -F'-' '{print $1}'`"
		MONTH="`echo $DATE |awk -F'-' '{print $2}'`"
		DEST="$WORKDIR/$YEAR/$MONTH"

		# display
		echo "
File=  $file
DATE=  $DATE
YEAR=  $YEAR
MONTH= $MONTH
DEST=  $DEST"

		# if it doesn't exist, make date directory
		if [[ ! -d $DEST ]] ;then mkdir -p $DEST ;fi

		# move file into date directory
		mv $file $DEST/
	fi
done
