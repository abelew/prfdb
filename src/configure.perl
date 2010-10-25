#!/bin/sh
cd $@
CFLAGS="-I${PRFDB_HOME}/usr/include -L${PRFDB_HOME}/usr/lib"
LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${PRFDB_HOME}/usr/lib"
PREFIX=${PRFDB_HOME}/usr
/usr/local/bin/perl -I ${PREFIX} Makefile.PL PREFIX=${PREFIX}
make
