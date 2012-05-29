#!/usr/bin/env bash
echo "Following is a partial listing or required components to compile and use the PRFdb."
echo "1.  gcc (to compile everything)"
echo "2.  g++ (to compile HotKnots)"
echo "3.  bison (to compile rnamotif)"
echo "4.  perl"
echo "5.  flex (to compile rnamotif, unafold, Vienna)"
echo "6.  libgd (for graphing routines)"
echo "7.  java (for jViz)"
echo "8.  Appropriate headers for c, c++"
echo "9.  Apache (if you wish to run a webserver"
sleep 10

if [ ! -n "$PRFDB_HOME" ]; then
  echo "The environment variable PRFDB_HOME is not set."
  echo "Please set it.  Temporarily setting it to $PWD"
  echo "Unless you set it, future invocations of the prfdb will fail."
  echo "To set it, type the following two commands:

echo \"export PRFDB_HOME=$PWD\" >> ~/.bashrc
. ~/.bashrc
"
  export PRFDB_HOME=$PWD
  sleep 5
fi
echo "Running fixdeps to set up the perl dependencies."
${PRFDB_HOME}/fixdeps.pl
mkdir -p ${PRFDB_HOME}/bin/params ${PRFDB_HOME}/bin/TestSeq
ln -s ${PRFDB_HOME}/bin/params ${PRFDB_HOME}/work/params
ln -s ${PRFDB_HOME}/bin/TestSeq ${PRFDB_HOME}/work/TestSeq
cd src/
CONFIGURE_CMD="./configure --prefix=$PRFDB_HOME --bindir=$PRFDB_HOME/bin"
echo "Please see the AUTHORS file for the authors of software upon which the PRFdb depends."
for source in `cat $PRFDB_HOME/src/MANIFEST`
  do
  echo "Untarring $source"
  tar zxf $source
done

RET=0

echo "Copying jviz and xvfb to $PRFDB_HOME/bin"
cp $PRFDB_HOME/src/jViz.jar $PRFDB_HOME/bin
cp $PRFDB_HOME/src/xvfb-run $PRFDB_HOME/bin

if [ -r $PRFDB_HOME/bin/Hotknot ]; then
  echo "Hotknots is already installed."
else
  echo "Installing HotKnots"
  cd $PRFDB_HOME/src/HotKnots_v2.0
  cp bin/HotKnot $PRFDB_HOME/bin
  cp bin/params/* $PRFDB_HOME/bin/params
  ## hotknots expects some text files for its parambeters, they live in both the 'TestSeq' and 'params' directories
  rsync -av ${PRFDB_HOME}/src/HotKnots_v2.0/bin/params/ ${PRFDB_HOME}/bin/params
  rsync -av ${PRFDB_HOME}/src/HotKnots_v2.0/bin/TestSeq/ ${PRFDB_HOME}/bin/TestSeq
fi

if [ -r $PRFDB_HOME/bin/Fold.out.nopairs ]; then
  echo "Nupack is already installed."
else
  echo "Installing a slightly hacked version of NUPACK"
  cd $PRFDB_HOME/src/NUPACK1.2_pseudoknot/source
  make clean ; make
  RET=$?
  cp Fold.out $PRFDB_HOME/work/Fold.out.nopairs
  cp $PRFDB_HOME/src/NUPACK1.2_pseudoknot/data* $PRFDB_HOME/work
  ln -s $PRFDB_HOME/work/Fold.out.nopairs $PRFDB_HOME/bin/
  if [ -n $RET ]; then
    cd $PRFDB_HOME/src
    rm -rf $PRFDB_HOME/src/NUPACK1.2_pseudoknot
  fi
fi

if [ -r $PRFDB_HOME/bin/Fold.out.boot.nopairs ]; then
  echo "Pseudoknot-less nupack is already installed."
else
  echo "... and another version of nupack."
  cd $PRFDB_HOME/src/NUPACK1.2_no_pseudoknot/source
  make clean ; make
  RET=$?
  cp Fold.out $PRFDB_HOME/work/Fold.out.boot.nopairs
  ln -s $PRFDB_HOME/work/Fold.out.boot.nopairs $PRFDB_HOME/bin/
  if [ -n $RET ]; then
   cd $PRFDB_HOME/src
   rm -rf $PRFDB_HOME/src/NUPACK1.2_pseudoknot
  fi
fi

if [ -r $PRFDB_HOME/bin/rnamotif ]; then
  echo "rnamotif is already installed."
else
  echo "Installing rnamotif."
  cd $PRFDB_HOME/src/rnamotif-3.0.7
  make clean ; make
  RET=$?
  cd src
  make
  EXECS="efn2_drv efn_drv rm2ct rmfmt rmprune rnamotif"
  for i in $EXECS
    do
    cp $i $PRFDB_HOME/bin
  done
  if [ -n $RET ]; then
    cd $PRFDB_HOME/src
    rm -rf $PRFDB_HOME/src/rnamotif-3.0.7
  fi
fi

if [ -r $PRFDB_HOME/bin/shuffle ]; then
  echo "squid is already installed."
else
  echo "Installing the squid nucleic acid routines."
  cd $PRFDB_HOME/src/squid-1.9g
  $CONFIGURE_CMD
  make
  RET=$?
  EXECS="afetch alistat compalign compstruct revcomp seqsplit seqstat sfetch shuffle sindex sreformat translate weight"
  for i in $EXECS
    do
    cp $i $PRFDB_HOME/bin
  done
  if [ -n $RET ]; then
    cd $PRFDB_HOME/src
    rm -rf $PRFDB_HOME/src/squid-1.9g
  fi
fi

if [ -r $PRFDB_HOME/bin/pknots ]; then
  echo "pknots is already installed."
else
  echo "Installing pknots."
  cd $PRFDB_HOME/src/pknots_v1.07
  cd easel
  make
  cd ..
  make
  RET=$?
  cp src/pknots $PRFDB_HOME/bin
  if [ -n $RET ]; then
    cd $PRFDB_HOME/src
    rm -rf $PRFDB_HOME/src/pknots_v1.07
  fi
fi

if [ -r $PRFDB_HOME/bin/RNAeval ]; then
  echo "Vienna is at least partially installed."
else
  echo "Installing ViennaRNA."
  cd $PRFDB_HOME/src/ViennaRNA-1.7.2
  $CONFIGURE_CMD
  make
  cd Progs
  make ; make install
  RET=$?
  cd ../Readseq
  cp readseq ../../../work
  cd ../Kinfold
  make ; make install
  if [ -n $RET ]; then
    cd $PRFDB_HOME/src
    rm -rf $PRFDB_HOME/src/ViennaRNA-1.7.2
  fi
fi

if [ -r $PRFDB_HOME/bin/miranda ]; then
  echo "miranda is already installed."
else
  echo "Installing miRanda."
  cd $PRFDB_HOME/src/miRanda-3.3a
  $CONFIGURE_CMD
  make ; make install
  RET=$?
  if [ -n $RET ]; then
    cd $PRFDB_HOME/src
    rm -rf $PRFDB_HOME/src/miRanda-3.3a
  fi
fi

if [ -r $PRFDB_HOME/bin/RNAhybrid ]; then
  echo "RNAhybrid is already installed."
else
  echo "Installing RNAHybrid."
  cd $PRFDB_HOME/src/RNAHybrid-2.1
  $CONFIGURE_CMD
  make ; make install
  RET=$?
  if [ -n $RET ]; then
    cd $PRFDB_HOME/src
    rm -rf $PRFDB_HOME/src/RNAHybrid-2.1
  fi
fi

## Unafold took over for mfold, don't do this anymore
#if [ -r $PRFDB_HOME/bin/mfold ]; then
#  echo "mfold is already installed."
#else
#  echo "Installing mFold."
#  cd $PRFDB_HOME/src/mfold-3.5
#  $CONFIGURE_CMD
#  make ; make install
#  RET=$?
#  if [ -n $RET ]; then
#    cd $PRFDB_HOME/src
#    rm -rf $PRFDB_HOME/src/mfold-3.5
#  fi
#fi

if [ -r $PRFDB_HOME/bin/unafold ]; then
  echo "unafold is already installed."
else
  echo "Installing Unafold."
  cd $PRFDB_HOME/src/unafold-3.8
  $CONFIGURE_CMD
  make ; make install
  RET=$?
  if [ -n $RET ]; then
    cd $PRFDB_HOME/src
    rm -rf $PRFDB_HOME/src/unafold-3.8
  fi
fi

touch $PRFDB_HOME/backup/prfdb_test_1
touch $PRFDB_HOME/backup/prfdb_test_2
echo "Please run something like:
sudo chown -R www-data:www-data $PRFDB_HOME"
