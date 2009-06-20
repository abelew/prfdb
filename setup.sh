#!/bin/sh
mkdir -p bin/params
cd src/
SOURCE_FILES="HotKnots_v2.0.tar.gz NUPACK1.2_pseudoknot_nopairs.tar.gz pknots.tar.gz NUPACK1.2_nopseudoknot_nopairs.tar.gz  rnamotif-3.0.4.tar.gz squid.tar.gz ViennaRNA-1.7.2.tar.gz"
for i in "$SOURCE_FILES" do
  tar zxf $i
done
cd HotKnots_v2.0
cp bin/HotKnot ../../work
cp bin/params/* ../../bin/params
cd ../../