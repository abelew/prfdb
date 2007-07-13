#!/bin/sh
find /users/umcp/belewa/browser/work -mtime 2 -name 'slip_*' -exec rm {} ';'
/usr/local/abccbatch/bin/qstat | /usr/bin/grep belewa > /users/umcp/belewa/public_html/qstat.txt
/usr/bin/chmod 644 /users/umcp/belewa/public_html/qstat.txt
/usr/bin/at -f /users/umcp/belewa/qstat.sh 'now + 4 hours'
