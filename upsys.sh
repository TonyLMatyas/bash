#!/bin/bash

# variables
################################################################################
LOG='/var/log/upsys.log'

# functions
################################################################################

f_append_log () { echo "`date` $1" >> $LOG ; }

f_update_apt () {
	apt -y update ;f_append_log "Update Complete"
	apt -y upgrade ;f_append_log "Upgrade Complete"
	apt -y autoremove ;f_append_log "Autoremove Complete"
}

# script start
################################################################################

# input
########################################

# process
########################################
echo "`date` Script Start" > $LOG
f_append_log "Reference: `readlink -f $0`"

# filter package manager
if [[ `apt --version` ]] ;then
	f_update_apt
else
	echo "Error: Acceptable package manager not found." ;exit
fi

# output
########################################
echo '' ;cat $LOG
