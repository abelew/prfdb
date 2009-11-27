#!/bin/bash
. ~/.bashrc
cd $PRFDB_HOME
QSTAT=/usr/local/torque/bin/qstat
USERID=`id | awk -F'(' '{print $2}' | awk -F ')' '{print $1}'`
PARTIAL=`grep pbs_partialname prfdb.conf | awk -F= '{print $2}' | sed 's/'\''//g'`
for arch in lin
  do
  for num in {1..70}

    do
    EXIST=`$QSTAT | grep $USERID | grep $PARTIAL | awk '{print $2}' | grep $arch | awk -F'_' '{print $3}' | grep $num`
    if [ "$EXIST" = "" ]; then
	if [ $arch = "lin" ]; then
          /usr/local/bin/qsub jobs/linux/$num
        elif [ $arch = "aix" ]; then
          /usr/local/bin/qsub jobs/aix/$num
        elif [ $arch = "iri" ]; then
          /usr/local/bin/qsub jobs/irix/$num
        fi
     else
        echo "The job $num in arch $arch is already running."
     fi 
     done
  done
at 12am < queue.sh 2>/dev/null 1>&2
