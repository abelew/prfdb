#!/bin/sh
cd /home/trey/prfdb07
nice -n 20 ./prf_daemon.pl 2>prf.out 1>&2 &
