#!/bin/sh
set -x
for i in `ls jobs/linux/*`; do
  qsub $i
done
for i in `ls jobs/aix4/*`; do
  qsub $i
done
for i in `ls jobs/irix6/*`; do
  qsub $i
done

