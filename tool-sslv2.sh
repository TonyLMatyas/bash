#!/bin/bash

# variables
################################################################################

# functions
################################################################################

# script start
################################################################################

# help text
if [[ $1 != '-r' ]] && [[ $1 != '--run' ]] ;then
	echo "
This script will create a self-signed certificate for a single domain (with or without a subdomain).

SYNTAX:
	$0 [OPTIONS]

OPTIONS:
	-h, --help
		display this help text
	-r, --run
   		execute this script

EXAMPLES:
	$0 -r
		execute this script
" ;exit ;fi

# check for executable
if [[ ! -f "`which openssl`" ]] ;then
	echo "Error: 'openssl' not installed." ;exit ;fi

# input
########################################

# define domain
read -p "
What domain, or subdomain, is this for?
	Examples:
		domain only:
			domain.com
		subdomain:
			www.example.net
		multi-domain cert:
			main.domain.com
			(You'll have the option to add more domains later.)
		wildcard cert:
			*.something.org
[(q)uit]: " ANSWER
if [[ "$ANSWER" == 'q' ]] || [[ "$ANSWER" == 'quit' ]] ;then
	echo "Exiting..." ;exit ;fi

TLD=`echo "$ANSWER" |awk -F. '{print $NF}'`
DOM=`echo "$ANSWER" |awk -F. '{print $(NF-1)}'`
SUB=`echo "$ANSWER" |awk -F".$DOM.$TLD" '{print $1}'`
if [[ -z "$SUB" ]] || [[ "$SUB" == "$ANSWER" ]] ;then
	SUB='<null>'
	FQDN="$DOM.$TLD"
else
	FQDN="$SUB.$DOM.$TLD" ;fi

read -p "
Does this look correct?
	Subdomain = $SUB
	Domain = $DOM
	Top Level Domain = $TLD
	Fully Qualified Domain Name = $FQDN
[(y)es, (n)o]: " ANSWER
if [[ $ANSWER != 'y' ]] && [[ $ANSWER != 'yes' ]] ;then
	echo "Exiting..." ;exit ;fi

if [[ $SUB == \* ]] ;then 
	WILDCARD='true' ;fi

# choose directory that the files will go in
read -p "
What new directory should the files go in?
[(q)uit]: " ANSWER
if [[ "$ANSWER" == 'q' ]] || [[ "$ANSWER" == 'quit' ]] ;then
	echo "Exiting..." ;exit ;fi

DIR="`readlink -f $ANSWER`"
if [[ -z "$DIR" ]] ;then
	echo "Error: Unable to create null directory. Check permissions."; exit ;fi
if [[ -d "$DIR" ]] ;then
	echo "Error: $DIR already exists."; exit ;fi
mkdir -p "$DIR"
if [[ ! -d "$DIR" ]] ;then
	echo "Error: Unable to create $DIR."; exit ;fi

# choose editor
read -p "
Which editor would you like to use?
	Examples:
		vi
		vim
		nano
		emacs
[(q)uit]: " EDITOR
if [[ "$EDITOR" == 'q' ]] || [[ "$EDITOR" == 'quit' ]] ;then
	echo "Exiting..." ;exit ;fi
if [[ ! -f "`which $EDITOR`" ]] ;then
	echo "Error: $EDITOR not available." ;exit ;fi

# self-signed query
read -p "
Do you want a self-signed version of this certificate?
[(y)es, (n)o]: " ANSWER
if [[ $ANSWER == 'y' ]] || [[ $ANSWER == 'yes' ]] ;then
	SSFLAG='true'
	read -p "
When should the self-signed cert expire (days)?
[(q)uit]: " DAYS
	if [[ "$DAYS" == 'q' ]] || [[ "$DAYS" == 'quit' ]] ;then
		echo "Exiting..." ;exit ;fi
	if [[ $DAYS -lt 1 ]] ;then
		echo "Error: unacceptable duration."; exit ;fi
fi

# process
########################################

# assign file name
if [[ $WILDCARD == true ]] ;then
	FILENAME="wildcard.$DOM.$TLD"
else
	FILENAME="$FQDN" ;fi

# create config file: self-signed
SSCFG="$DIR/$FILENAME-ss.cfg"
echo "[ req ]
default_md = sha256
default_bits = 4096
prompt = no
distinguished_name = req_distinguished_name
req_extensions = req_ext
#x509_extensions = v3_ca
[ req_distinguished_name ]
commonName = $FQDN
countryName = US
stateOrProvinceName = NY
localityName = New York
organizationName = Company Inc.
organizationalUnitName = Web Division
[ req_ext ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
keyUsage = critical, digitalSignature
#keyUsage = critical, digitalSignature, dataEncipherment, keyEncipherment
extendedKeyUsage = serverAuth
#extendedKeyUsage = critical, serverAuth, clientAuth
basicConstraints = critical, CA:false
subjectAltName = @alt_names
[ alt_names ]
DNS.0 = $DOM.$TLD
DNS.1 = $SUB.$DOM.$TLD" > $SSCFG

# edit csr config file
read -p "
Config file created.
	Edit as needed:
		Change locale, key usage, extensions, etc.
	If you are configuring a multi-domain certificate, edit the following lines:
		DNS.0 = $DOM.$TLD
		DNS.1 = $SUB.$DOM.$TLD
	If you are configuring a single-domain or wildcard certificate, remove the following lines:
		subjectAltName = @alt_names
		[ alt_names ]
		DNS.0 = $DOM.$TLD
		DNS.1 = $SUB.$DOM.$TLD
[(c)ontinue]: " ANSWER
if [[ $ANSWER != 'c' ]] && [[ $ANSWER != 'continue' ]] ;then
	echo "Exiting..." ;exit ;fi

$EDITOR $SSCFG

# create config file: csr
CSRCFG="$DIR/$FILENAME-csr.cfg"

grep -v ^subjectKeyIdentifier $SSCFG |grep -v ^authorityKeyIdentifier > $CSRCFG

# generate encrypted key & csr
read -p "
Generating encrypted key & CSR.  Next, you'll need to input the same password for the encrypted key multiple times.
[(c)ontinue]: " ANSWER
if [[ $ANSWER != 'c' ]] && [[ $ANSWER != 'continue' ]] ;then
	echo "Exiting..." ;exit ;fi

ENCKEY="$DIR/$FILENAME.enckey"
CSR="$DIR/$FILENAME.csr"
openssl req -newkey rsa:4096 -keyout $ENCKEY -out $CSR -sha256 -config $CSRCFG

# generate plaintext key
PTKEY="$DIR/$FILENAME.key"
openssl rsa -in $ENCKEY -out $PTKEY

# generate self-signed cert file
CRT="$DIR/$FILENAME.crt"
if [[ $SSFLAG == 'true' ]] ;then
	openssl req -x509 -in $CSR -days $DAYS -key $PTKEY -config $CSRCFG -extensions req_ext -nameopt utf8 -utf8 -out $CRT ;fi

# output
########################################

echo "
Your new files:"
ls -ald $DIR/*
