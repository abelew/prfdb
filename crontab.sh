#!/bin/bash
date >> crontab.out
cd /usr/local/prfdb/prfdb_test
./prf_daemon.pl --stats 2>>crontab.out 1>&2
cd /usr/local/prfdb/prfdb_test/folds/ && rm `ls | grep -v dhandler`
cd backup && ./mysql_backup.sh 2>mysql_backup.out 1>&2
