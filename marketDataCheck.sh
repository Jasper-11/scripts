#!/bin/bash
############################################################################################################
#
#  Script: marketDataCheck.sh
#  Version: 1.0
#  Author: Jasper Karlen - TechOps
#  Date: 20/10/2017
#
############################################################################################################
LOG="symtest.log"
HOME="/home/flexapp/app/scripts"
cd $HOME

# Run symbol test in a new process and redirect output to symtest.log
symtest localhost 14100 vod.l > $LOG 2>&1 &

# Kill symbol test after 5 seconds
sleep 5
ps -ef | grep -i "symtest localhost 14100 vod.l" | grep -v grep | awk '{print $2}' | xargs kill -9

# Read log and determine result
CHECK=`cat $LOG|grep -c 'Received Subscription data'`

cat $LOG
rm $LOG

echo "Found 'Received Subscription data' $CHECK times."

if [ $CHECK -gt 0 ]
  then
    exit 0
  else
    exit 1
fi
