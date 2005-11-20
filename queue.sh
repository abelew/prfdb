#!/bin/sh
set -x
for i in `ls jobs/*/*`; do
  qsub $i
done
