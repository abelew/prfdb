#!/bin/bash
export PRFDB_HOME=/usr/local/prfdb/prfdb_test
cd $PRFDB_HOME
date >> crontab.out
if [ $1 ]; then
  ./prf_daemon.pl --dbexec "INSERT IGNORE INTO gene_info (genome_id, accession, species, genename, comment, defline) SELECT id, accession, species, genename, comment, defline FROM genome"
else
  cd backup && ./mysql_backup.sh 2>mysql_backup.out 1>&2 &
  cd ..
  cd folds && rm -f *.err *.svg *.html *.seq *.fasta *.ct *.bpseq 2>/dev/null 1>&2
  cd ..
  ./prf_daemon.pl --maintain 2>>crontab.out 1>&2
fi
  

