#!/bin/bash
# created by: Zell
#===============================================================================
# variables
CRONFILE='/etc/cron.d/saucelabs'  # crontab file
DEFTUN='DefaultTunnel'  # default tunnel name (if no name is provided)
DOCTOR='false'  # initialize value (for function: f_connect)
MINUTES='2'  # how often the cronjob, that checks the connection, should run
NOFILE='8192'  # Sauce Labs recommends 8000
SAUCELIB='/etc/.saucelabs.lib'  # source file that holds credentials
SCLINK='/usr/sbin/sauceconnect'  # symlink to executable command
SCVERSION='sc-4.5.3-linux'  # the version you wish to work with
SRCDIR='/usr/local/src'  # the installation directory
SYSCFGDIR='/etc/sysconfig'  # sysconfig directory

BASEPATH="`readlink -e $0`"  # full path to this script
INSTALLDIR="$SRCDIR/$SCVERSION"  # specific install directory for sauce connect
IPTMAIN="$SYSCFGDIR/iptables"  # main iptables config file
IPTORIG="$SYSCFGDIR/iptables.sc-orig"  # backup of static config
IPTRUN="$SYSCFGDIR/iptables.sc-running"  # backup of running config
SCEXEC="$INSTALLDIR/bin/sc"  # initial path to executable command
SCFILE="$SCVERSION.tar.gz"  # downloaded file in compressed form

#===============================================================================
# functions

#---------------------------------------
# help text
f_helptext () {
  echo "
This script executes different Sauce Connect funcitons.

REFERENCES:
  https://wiki.saucelabs.com/display/DOCS/Basic+Sauce+Connect+Proxy+Setup

SYNTAX:
  # `basename $0` [OPTIONS]

OPTIONS:
  -h, --help
    Displays this help text.
  -i, --install
    Installs the Sauce Connect binaries under the $SRCDIR/ directory.
  -m, --make-source-file
    prompts you for creation of the source file: $SAUCELIB
  -d, --doctor <OptionalTunnelName>
    Perform checks to detect possible misconfiguration or problems.
  -c, --connect <OptionalTunnelName>
    Establishes a connection to new Sauce Labs' cloud VM.
    If no tunnel name is provided, the default tunnel name will be used: $DEFTUN
    Requires the source file ($SAUCELIB) to be populated with 2 variables:
      SAUCE_USERNAME=''
      SAUCE_ACCESS_KEY=''
  -ac, --auto-connect
    Ensure at least one tunnel is running:
      If so, do nothing
      If not, this will create the default tunnel with '--connect'
  -j, --cronjob
    Creates a cronjob that runs the '--auto-connect' option.
    Set to run every $MINUTES minute(s) as the root user.
  -s, --security
    Sets up security measures:
      use iptables to block user-provided CIDR address.
  --initialize
    runs the following options sequentially:
      --install
      --make-source-file
      --security
      --cronjob

NOTES:
  Only one option at a time:
    Correct:         # `basename $0` -j
    Incorrect:       # `basename $0` -is
    Incorrect:       # `basename $0` -i -m
"
  exit
}

#---------------------------------------
# print error message & exit
f_errmsg () { echo "!!! ERROR: $1 !!!" ;f_helptext ; }

#---------------------------------------
# install sauce connect proxy
f_install () {

  # ensure that sauce connect is NOT already installed
  if [[ -f $SCEXEC ]] || [[ -f $SCLINK ]];then
    f_errmsg "It appears Sauce Connect is already installed"
  fi

  # download & extract saucelabs tar file
  cd $SRCDIR/
  curl -O "https://saucelabs.com/downloads/$SCFILE"
  tar xzfv ./$SCFILE

  # ensure the tar file was downloaded OK, then delete it
  if [[ ! -f $SRCDIR/$SCFILE ]] ;then
    f_errmsg "Could not find file: $SRCDIR/$SCFILE"
  fi
  rm -f $SRCDIR/$SCFILE

  # fix permissions on install directory
  chown -R root:root $INSTALLDIR
  chmod 0755 $SCEXEC

  # create symlink to executable so it's available in $PATH
  if [[ -f $SCLINK ]] ;then rm -f $SCLINK ;fi  # remove symlink if already there
  ln -s $SCEXEC $SCLINK

  # set root's ulimit (hard limit) for number of open files
  echo "# Default limit for user's number of open files
root    hard    nofile    $NOFILE
" > /etc/security/limits.d/99-sauce_connect.conf

  # message
  echo "Successfully installed Sauce Connect under $INSTALLDIR/"
}

#---------------------------------------
# make source file with restricted info
f_make_source_file () {

  # ensure source file doesn't already exist
  if [[ -f $SAUCELIB ]] ;then
    f_errmsg "Source file already exists: $SAUCELIB"
  fi

  # prompt for username
  read -p "What is the Sauce Labs username?
[(q)uit]: " SAUCE_USERNAME
  case $SAUCE_USERNAME in
    'q'|'quit')  exit  ;;
    '')  f_errmsg "Invalid selection"  ;;
  esac

  # prompt for access key
  read -p "What is the Sauce Labs access key?
[(q)uit]: " SAUCE_ACCESS_KEY
  case $SAUCE_ACCESS_KEY in
    'q'|'quit')  exit  ;;
    '')  f_errmsg "Invalid selection"  ;;
  esac

  # create source file from scratch
  cat << EOF > $SAUCELIB
SAUCE_USERNAME=$SAUCE_USERNAME
SAUCE_ACCESS_KEY=$SAUCE_ACCESS_KEY
EOF

  # fix permissions
  chown root:root $SAUCELIB ;chmod 0400 $SAUCELIB

  # message
  echo "Source file creation complete: $SAUCELIB"
}

#---------------------------------------
# establish sauce connect tunnel
f_connect () {

  # ensure that sauce connect is already installed
  if [[ ! -f $SCEXEC ]] || [[ ! -f $SCLINK ]];then
    f_errmsg "It appears Sauce Connect is not installed correctly"
  fi

  # ensure that source file exists, then source/import it
  if [[ ! -f $SAUCELIB ]] ;then f_make_source_file ;fi
  source $SAUCELIB

  # ensure the source file contains the required variables
  if [[ -z $SAUCE_USERNAME ]] ;then
    f_errmsg 'No value for variable: $SAUCE_USERNAME'
  elif [[ -z $SAUCE_ACCESS_KEY ]] ;then
    f_errmsg 'No value for variable: $SAUCE_ACCESS_KEY'
  fi

  # if no custom name is provided, use the default tunnel name
  if [[ -z $TUNNEL ]] ;then TUNNEL=$DEFTUN ;fi

  # set running ulimit (soft limit) for number of open files
  ulimit -n $NOFILE

  # run diagnostics (doctor) or establish shared tunnel
  if [[ $DOCTOR == true ]] ;then
    $SCLINK -u $SAUCE_USERNAME -k $SAUCE_ACCESS_KEY -i $TUNNEL -s --doctor
  else
    $SCLINK -u $SAUCE_USERNAME -k $SAUCE_ACCESS_KEY -i $TUNNEL -s
  fi

  # message
  echo "Tunnel established: $TUNNEL"
}

#---------------------------------------
# check & establish sauce connect tunnel automatically
f_auto_connect () {

  # if no processes running, create connection with default tunnel
  if [[ `ps -ef |grep $SCLINK |grep -v grep |wc -l` == 0 ]] ;then
    f_connect
  else
    echo "Tunnel(s) already running - No need to start another Tunnel."
  fi
}

#---------------------------------------
# setup cronjob
f_cronjob () {

  # ensure cronjob file doesn't already exist
  if [[ -f $CRONFILE ]] ;then f_errmsg "Cronjob already exists: $CRONFILE" ;fi

  # create cronjob
  echo "SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/var/ops/bin
*/$MINUTES * * * * root $BASEPATH --auto-connect > /dev/null 2>&1" > $CRONFILE

  # fix permissions
  chown root:root $CRONFILE ;chmod 0600 $CRONFILE

  # message
  echo "Tunnel should connect in $MINUTES minute(s) or less: $DEFTUN"
}

#---------------------------------------
# validate that variable is a number
f_number () {

  # ensure that the $NUMBER variable:
  #   is the correct number of characters long: between $CHARLO & $CHARHI
  #   has no letters and start & ends with a number between 0 & 9
  #   is within the specified range: between $NUMLO & $NUMHI
  CHAR=`echo $NUMBER |wc -m`
  if [[ $CHAR -lt $CHARLO ]] || [[ $CHAR -gt $CHARHI ]] ;then
    f_errmsg "Too few/many characters: $NUMBER"
  elif [[ $NUMBER =~ [a-Z] ]] || [[ ! $NUMBER =~ [0-9] ]] ;then
    f_errmsg "Not a number: $NUMBER"
  elif [[ $NUMBER -lt $NUMLO ]] || [[ $NUMBER -gt $NUMHI ]] ;then
    f_errmsg "Number is out of range: $NUMBER"
  fi
}

#---------------------------------------
# setup security considerations
f_security () {

  # ensure iptables hasn't already been modified
  if [[ -f $IPTORIG ]] || [[ -f $IPTRUN ]];then
    f_errmsg "It appears iptables has already been modified"
  fi

  # get CIDR (to block in iptables firewall)
  read -p "What is the CIDR you want to block?
Example: 192.168.1.0/24
[(q)uit]: " IPCIDR
  case $IPCIDR in
    'q'|'quit')  exit  ;;
    '')  f_errmsg "Invalid selection"  ;;
  esac

  # break CIDR into constituent pieces for processing
  MASK=`echo $IPCIDR |awk -F'/' '{print $2}'`
  IPADDR=`echo $IPCIDR |awk -F'/' '{print $1}'`
  OCTONE=`echo $IPADDR |awk -F'.' '{print $1}'`
  OCTTWO=`echo $IPADDR |awk -F'.' '{print $2}'`
  OCTTHREE=`echo $IPADDR |awk -F'.' '{print $3}'`
  OCTFOUR=`echo $IPADDR |awk -F'.' '{print $4}'`

  # ensure CIDR is a valid entry
  NUMBER=$MASK ;CHARLO=2 ;CHARHI=3; NUMLO=0 ;NUMHI=24 ;f_number
  NUMBER=$OCTONE ;CHARLO=2 ;CHARHI=4; NUMLO=0 ;NUMHI=255 ;f_number
  NUMBER=$OCTTWO ;f_number
  NUMBER=$OCTTHREE ;f_number
  NUMBER=$OCTFOUR ;f_number

  # ensure iptables is enabled
  chkconfig iptables on ;service iptables save

  # backup firewall rules
  cp -a $IPTMAIN $IPTORIG  # static config
  iptables-save > $IPTRUN  # running config

  # fix permissions
  chown root:root $IPTORIG $IPTRUN ;chmod 0400 $IPTORIG $IPTRUN

  # restrict current firewall rules from reaching CIDR range
  iptables -I INPUT -s $IPCIDR -j DROP
  iptables -I OUTPUT -s $IPCIDR -j DROP
  iptables -I FORWARD -s $IPCIDR -j DROP

  # save new firewall rules (persistent through reboots)
  iptables-save > $IPTMAIN

  # message
  echo "New Firewall Rules:
`iptables -L -n`"
}

#===============================================================================
# script start

#---------------------------------------
# check for root privilege execution
if [[ `whoami` != 'root' ]] && [[ $1 != '-h' ]] && [[ $1 != '--help' ]];then
  f_errmsg 'use "sudo" for execution'
fi

#---------------------------------------
# process arguments
case $1 in
  '-h'|'--help')  f_helptext  ;;
  '-i'|'--install')  f_install  ;;
  '-m'|'--make-source-file')  f_make_source_file  ;;
  '-d'|'--doctor')  TUNNEL=$2 ;DOCTOR=true ;f_connect  ;;
  '-c'|'--connect')  TUNNEL=$2 ;f_connect  ;;
  '-ac'|'--auto-connect')  f_auto_connect  ;;
  '-j'|'--cronjob')  f_cronjob  ;;
  '-s'|'--security')  f_security  ;;
  '--initialize')  f_install ;f_make_source_file ;f_security ;f_cronjob  ;;
  *)  f_errmsg "Invalid argument(s)"  ;;
esac

#---------------------------------------
# message
echo "Script execution complete"
