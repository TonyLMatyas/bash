#!/bin/bash

# Variables
########################################
DLKC=~/Library/Keychains
VLKC='login.keychain'
FLKC="$DLKC/$VLKC-db"
FBKC="$FLKC.orig"
FPWF="$DLKC/.password"
VSPW="`cat $FPWF`"

# Functions
########################################
f_list () { security list-keychains ; }
f_show () { security show-keychain-info $VLKC ; }
f_lock () { security lock-keychain $VLKC ; }
f_unlock () { security unlock-keychain -p "$VSPW" $VLKC ; }
f_create () { security create-keychain -p "$VSPW" $VLKC ; }
f_backup () {
  if [[ ! -f $FLKC ]] ;then echo "error: file not found" ;exit ;fi
  if [[ -f $FBKC ]] ;then echo "error: backup already exists" ;exit ;fi
  cp -a $FLKC $FBKC ; }
f_delete () { rm -f $FLKC ; }
f_restore () {
  if [[ ! -f $FBKC ]] ;then echo "error: backup not found" ;exit ;fi
  f_delete ;cp -a $FBKC $FLKC ; }
f_help () { echo "
Files:
  Keychain directory: $DLKC
  Keychain name: $VLKC
  Keychain file: $FLKC
  Backup file: $FBKC
  Password file: $FPWF

Options:
  -ls, --list
  -s, --show
  -l, --lock
  -u, --unlock
  -c, --create
  -b, --backup
  -d, --delete
  -r, --restore
" ; }

# Start
########################################
if [[ ! -f $FPWF ]] ;then
  date > $FPWF ;fi
chmod 600 $FPWF

case $1 in
  '-ls'|'--list') f_list ;;
  '-s'|'--show') f_show ;;
  '-l'|'--lock') f_lock ;;
  '-u'|'--unlock') f_unlock ;;
  '-c'|'--create') f_create ;;
  '-b'|'--backup') f_backup ;;
  '-d'|'--delete') f_delete ;;
  '-r'|'--restore') f_restore ;;
  *) f_help ;;
esac

