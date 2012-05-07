#!/bin/bash
set -x
export PRFDB_HOME=/usr/local/prfdb/prfdb_test
cd $PRFDB_HOME
string="Started at: `date`"
echo "$string" >> crontab.out
if [ $1 ]; then
#  ./prf_daemon --dbexec "INSERT IGNORE INTO gene_info (genome_id, accession, species, genename, comment, defline) SELECT id, accession, species, genename, comment, defline FROM genome"
   echo "Dropped the insert ignore for the moment"
else
  cd $PRFDB_HOME && ./prf_daemon --mysql_backup 2>mysql_backup.out 1>&2 &
  cd $PRFDB_HOME/folds && rm -f *.err *.svg *.html *.ext *-auth *.png *.seq *fasta *.ct *.dG *.plot *.run *.bpseq 2>/dev/null 1>&2
  cd $PRFDB_HOME/sessions && find $PRFDB_HOME/sessions -mtime -7 -exec rm {} ';'
#  cd $PRFDB_HOME && ./prf_daemon --maintain 2>>crontab.out 1>&2
fi
string="Finished at: `date`"
echo "$string" >> crontab.out
