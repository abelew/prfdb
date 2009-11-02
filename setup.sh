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

cd NUPACK1.2_pseudoknot/source
make clean ; make
cp Fold.out ../../../work/Fold.out.nopairs
cd ../../

cd NUPACK1.2_no_pseudoknot/source
make clean ; make
cp Fold.out ../../../work/Fold.out.boot.nopairs
cd ../../

cd rnamotif-3.0.4
make clean ; make
cd src
make
EXECS="efn2_drv efn_drv rm2ct rmfmt rmprune rnamotif"
for i in "EXECS" do
 cp $i ../../../work
done
cd ../../

cd squid-1.9g
./configure ; make
EXECS="afetch alistat compalign compstruct revcomp seqsplit seqstat sfetch shuffle sindex sreformat translate weight"
for i in "EXECS" do
 cp $i ../../work
done
cd ..

cd pknots-1.05
cd src/squid
make
cp libsquid.a ..
cd ..
make
cp pknots ../../../work
cd ../../

cd ViennaRNA-1.7.2
./configure --prefix=`pwd`/../../ --bindir=`pwd`/../../work
make
cd Progs
make ; make install
cd ../Readseq
cp readseq ../../../work
cd ../Kinfold
make ; make install
cd ../../



