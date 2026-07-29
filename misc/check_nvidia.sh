#!/bin/bash

# input
DLOG=/root/logs
FLOG=$DLOF/nvidiacount.log

# processing
if [[ ! -d $DLOG ]] ;then mkdir $DLOG ;fi
if [[ ! -f $FLOG ]] ;then touch $FLOG ;fi

echo "
`date`
GPU Count: `lspci -vnn |grep -i nvidia |grep VGA |wc -l`
`lspci -vnn |grep -i nvidia |grep VGA`" >> $FLOG

# output
tail $FLOG
