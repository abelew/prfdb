#!/bin/bash
#set -x
. ~/.bashrc
USERID=`id | awk -F'(' '{print $2}' | awk -F ')' '{print $1}'`
PARTIAL=`grep pbs_partialname prfdb.conf | awk -F= '{print $2}' | sed 's/'\''//g'`
for arch in lin
  do
  for num in 01 02 03 04 05 06 07 08 09 10
    do
    EXIST=`/usr/local/bin/qstat | grep $USERID | grep $PARTIAL | awk '{print $2}' | grep $arch | awk -F'_' '{print $3}' | grep $num`
    if [ "$EXIST" = "" ]; then
	if [ $arch = "lin" ]; then
          qsub jobs/linux/$num
        elif [ $arch = "aix" ]; then
          qsub jobs/aix/$num
        elif [ $arch = "iri" ]; then
          qsub jobs/irix/$num
        fi
     else
        echo "The job $num in arch $arch is already running."
     fi 
     done
  done
