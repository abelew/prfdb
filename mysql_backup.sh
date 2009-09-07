#!/bin/bash
set -x
cd ~abelew/mysql
HOUR=`date +%H`
MIN=`date +%M`
MON=`date +%m`
DAY=`date +%d`
YEA=`date +%y`
SUFFIX_CBMG="mysqldump_cbmg_${MIN}${HOUR}${MON}${DAY}${YEA}.txt.gz"
DUMP_CBMG="/bin/nice /usr/bin/mysqldump -u prfdb --password=drevil"
$DUMP_CBMG prfdb_test | gzip > "prfdb_test_${SUFFIX_CBMG}" && rm `ls -t prfdb_test_mysqldump_cbmg* | tail -1`
