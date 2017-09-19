#!/bin/bash
############################################################################################################
#
#  Script: EODCancelsCheck.sh
#  Version: 1.0
#  Author: Jasper Karlen - TechOps
#  Date: 20/10/2017
#
############################################################################################################

LOGDIR="/opt/fxt/flexsys/logs/trades/yesterday"
cd $LOGDIR

CHECK=`ls|grep sender|xargs cat| grep -cEz '(Connected to OM).*(Buffered command).*(COMMAND SENT)'`

ls|grep sender|xargs cat| grep 'Connected to OM' -A 2

if [ $CHECK -eq 1 ]
  then
    exit 0
  else
    exit 1
fi
