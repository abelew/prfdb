#!/bin/sh
## ILM takes as input MWM input files
## NAME: Sequence 
## on one line.

## For non-aligned sequences, the process is: hlxplot mwmfile > matrix_file

./hlxplot $1 > $1.matrix
## ./xhlxplot $1 > $1.xhlx_matrix
./ilm $1.matrix > ilm.out
## ./ilm $1.xhlx_matrix

## Convert the output from ilm to something which is like:
#AAAACCCCCCUUUUUU
#((((......))))..
## Importantly, the number of characters on each line must be equivalent.
## ilm_convert ilm.out > ilm.converted
## RNAeval < ilm.converted
