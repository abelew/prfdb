#!/bin/bash
date >> crontab.out
cd /usr/local/prfdb/prfdb_test
cd backup && ./mysql_backup.sh 2>mysql_backup.out 1>&2 &
cd /usr/local/prfdb/prfdb_test
cd folds && rm -f *.err *.svg *.html *.seq *.fasta *.ct *.bpseq 2>/dev/null 1>&2
cd /usr/local/prfdb/prfdb_test
./prf_daemon.pl --maintain 2>>crontab.out 1>&2
