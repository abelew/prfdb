#!/usr/local/bin/bash
HOME=/users/umcp/belewa
BASE=${HOME}/browser
/usr/local/bin/find ${BASE}/work -mmin +600 -name 'slip_*' -exec rm {} ';'
date > ${HOME}/public_html/qstat.txt
echo "" >> ${HOME}/public_html/qstat.txt 
${BASE}/queue.sh 2>> ${HOME}/public_html/qstat.txt 1>&2
echo "" >> ${HOME}/public_html/qstat.txt 
/usr/local/abccbatch/bin/qstat | /usr/bin/grep belewa >> ${HOME}/public_html/qstat.txt
echo "" >> ${HOME}/public_html/qstat.txt 
/usr/bin/chmod 644 ${HOME}/public_html/qstat.txt
echo "The next refresh of this status will be:" >> ${HOME}/public_html/qstat.txt
/usr/bin/at -l 2>> ${HOME}/public_html/qstat.txt 1>&2
/usr/bin/at -f ${BASE}/qstat.sh 'now + 4 hours'
