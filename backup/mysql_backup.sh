#!/bin/bash
set -x
HOUR=`date +%H`
MIN=`date +%M`
MON=`date +%m`
DAY=`date +%d`
YEA=`date +%y`
SUFFIX_CBMG="mysqldump_cbmg_${MIN}${HOUR}${MON}${DAY}${YEA}.txt.gz"
DUMP_CBMG="/bin/nice /usr/bin/mysqldump --add-drop-table --create-options --disable-keys --extended-insert --set-charset -u prfdb --password=drevil"
$DUMP_CBMG prfdb_test | gzip > "prfdb_test_${SUFFIX_CBMG}" && rm `ls -t prfdb_test_mysqldump_cbmg* | tail -1`
